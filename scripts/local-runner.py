#!/usr/bin/env python3
# local-runner.py - run the repo's own GitHub workflow on any machine
# no build logic lives here: it reads build-staging.yml -> build-kernel.yml (+ composite actions)
# and executes every step in order, so editing scripts/ or the yaml is all you ever do.
#
# replaced locally (see hook()):
#   actions/checkout, actions/cache/*  -> repo is copied into a fresh workspace
#   actions/upload-artifact            -> copied to <root>/artifacts/<name>
#   scripts/notify.sh                  -> skipped unless --notify
#   scripts/setup-toolchain.sh         -> skipped when --clang-dir is given
import argparse, itertools, os, re, shutil, signal, subprocess, sys, time
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("[FAIL] python3-yaml missing (apt install python3-yaml)")

TTY = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def col(code, s):
    return f"\033[{code}m{s}\033[0m" if TTY else s


def bold(s): return col("1", s)
def dim(s): return col("2", s)
def red(s): return col("31", s)
def green(s): return col("32", s)
def yellow(s): return col("33", s)


class RunnerError(Exception):
    pass


# expression evaluator (the subset GitHub workflows here use)
TOKEN = re.compile(
    r"\s*(?:(?P<str>'(?:[^']|'')*')|(?P<num>\d+(?:\.\d+)?)"
    r"|(?P<op>==|!=|&&|\|\||[()!,.])|(?P<id>[A-Za-z_][\w-]*))")
INTERP = re.compile(r"\$\{\{((?:(?!\}\}).)*)\}\}", re.S)
EMPTY_CTX = ("secrets", "vars", "needs", "job", "runner")


def tokenize(s):
    pos, out = 0, []
    while s[pos:].strip():
        m = TOKEN.match(s, pos)
        if not m:
            raise RunnerError(f"cannot parse expression: {s.strip()!r}")
        pos = m.end()
        out.append((m.lastgroup, m.group(m.lastgroup)))
    return out


def truthy(v):
    return bool(v) if v is not None else False


def tostr(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return "" if v is None else str(v)


def loose_eq(a, b):
    if type(a) is type(b) and not isinstance(a, str):
        return a == b
    return tostr(a).lower() == tostr(b).lower()


def call(name, args, ctx):
    n = name.lower()
    rt = ctx["_rt"]
    if n == "endswith": return tostr(args[0]).lower().endswith(tostr(args[1]).lower())
    if n == "startswith": return tostr(args[0]).lower().startswith(tostr(args[1]).lower())
    if n == "contains": return tostr(args[1]).lower() in tostr(args[0]).lower()
    if n == "hashfiles": return "local"
    if n == "always": return True
    if n == "success": return not rt.failed
    if n == "failure": return rt.failed
    if n == "cancelled": return False
    raise RunnerError(f"unsupported function {name}()")


def lookup(path, ctx):
    top = path[0]
    if top in EMPTY_CTX:
        return ""
    if top not in ctx or top.startswith("_"):
        raise RunnerError(f"unsupported context '{top}' in expression")
    v = ctx[top]
    for p in path[1:]:
        v = v.get(p, "") if isinstance(v, dict) else ""
    return v


class Parser:
    def __init__(self, toks, ctx):
        self.t, self.i, self.ctx = toks, 0, ctx

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else (None, None)

    def expect(self, v):
        if self.peek()[1] != v:
            raise RunnerError(f"expected {v!r} in expression")
        self.i += 1

    def run(self):
        v = self.or_()
        if self.i != len(self.t):
            raise RunnerError("trailing tokens in expression")
        return v

    def or_(self):
        v = self.and_()
        while self.peek()[1] == "||":
            self.i += 1
            r = self.and_()
            v = v if truthy(v) else r
        return v

    def and_(self):
        v = self.eq()
        while self.peek()[1] == "&&":
            self.i += 1
            r = self.eq()
            v = r if truthy(v) else v
        return v

    def eq(self):
        v = self.unary()
        while self.peek()[1] in ("==", "!="):
            op = self.t[self.i][1]
            self.i += 1
            r = self.unary()
            res = loose_eq(v, r)
            v = res if op == "==" else not res
        return v

    def unary(self):
        if self.peek()[1] == "!":
            self.i += 1
            return not truthy(self.unary())
        return self.atom()

    def atom(self):
        k, v = self.peek()
        if k == "str":
            self.i += 1
            return v[1:-1].replace("''", "'")
        if k == "num":
            self.i += 1
            return float(v) if "." in v else int(v)
        if v == "(":
            self.i += 1
            r = self.or_()
            self.expect(")")
            return r
        if k == "id":
            self.i += 1
            if self.peek()[1] == "(":
                self.i += 1
                args = []
                if self.peek()[1] != ")":
                    args.append(self.or_())
                    while self.peek()[1] == ",":
                        self.i += 1
                        args.append(self.or_())
                self.expect(")")
                return call(v, args, self.ctx)
            if v in ("true", "false"):
                return v == "true"
            if v == "null":
                return None
            path = [v]
            while self.peek()[1] == ".":
                self.i += 1
                k2, v2 = self.peek()
                if k2 != "id":
                    raise RunnerError("bad property access in expression")
                self.i += 1
                path.append(v2)
            return lookup(path, self.ctx)
        raise RunnerError("unexpected token in expression")


def ev(expr, ctx):
    return Parser(tokenize(expr), ctx).run()


def interp(text, ctx):
    # whole-string expression keeps its type (bool stays bool)
    if not isinstance(text, str):
        return text
    m = INTERP.fullmatch(text.strip())
    if m:
        return ev(m.group(1), ctx)
    return INTERP.sub(lambda m: tostr(ev(m.group(1), ctx)), text)


def interp_s(text, ctx):
    return tostr(interp(text, ctx))


# runtime state for one variant build
class Runtime:
    def __init__(self, ws, state, logdir, home, args):
        self.ws, self.state, self.logdir, self.home, self.args = ws, state, logdir, home, args
        self.env = {}          # workflow env + job env + GITHUB_ENV
        self.base = {}         # variables the runner itself provides
        self.steps = {}        # steps.<id>.outputs
        self.path_extra = []
        self.failed = False
        self.counter = 0
        self.log = None
        self.cols = shutil_cols()
        self.t0 = time.time()


def shutil_cols():
    try:
        return shutil.get_terminal_size((100, 20)).columns
    except Exception:
        return 100


def read_kv(path):
    # GITHUB_ENV / GITHUB_OUTPUT format: K=V or K<<DELIM ... DELIM
    out = {}
    if not Path(path).exists():
        return out
    lines = Path(path).read_text(errors="replace").splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i]
        m = re.match(r"^([^=<]+)<<(.+)$", ln)
        if m:
            key, delim, buf = m.group(1), m.group(2), []
            i += 1
            while i < len(lines) and lines[i] != delim:
                buf.append(lines[i])
                i += 1
            out[key] = "\n".join(buf)
        elif "=" in ln:
            k, v = ln.split("=", 1)
            out[k] = v
        i += 1
    return out


def proc_env(rt, step_env, out_file):
    e = dict(os.environ)
    e["HOME"] = str(rt.home)
    e.update(rt.base)
    e.update(rt.env)
    e.update(step_env)
    e["GITHUB_OUTPUT"] = str(out_file)
    e["PATH"] = os.pathsep.join(rt.path_extra + [e.get("PATH", "")])
    return e


def show(rt, line):
    # progress bars (apt/dpkg/git) end a line with "\r": keep the last non-empty frame, drop blank frames
    parts = [p for p in line.split("\r") if p.strip()]
    if not parts:
        return
    line = parts[-1]
    if rt.args.quiet:
        if TTY:
            txt = "  " + line.strip()
            width = rt.cols - 1
            sys.stdout.write("\r\033[K" + dim((rt.cur_head + txt)[:width]))
            sys.stdout.flush()
    else:
        print(line, flush=True)


def stream(cmd, env, cwd, rt):
    p = subprocess.Popen(cmd, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         start_new_session=True)
    try:
        for raw in iter(p.stdout.readline, b""):
            line = raw.decode(errors="replace").rstrip("\n")
            rt.log.write(line + "\n")
            rt.log.flush()
            show(rt, line)
        return p.wait()
    except KeyboardInterrupt:
        os.killpg(p.pid, signal.SIGTERM)
        raise


def hook(run_text, rt):
    a = rt.args
    if "scripts/notify.sh" in run_text and not a.notify:
        return "notify off (use --notify)"
    if "scripts/setup-toolchain.sh" in run_text and a.clang_dir:
        rt.env["CLANG_DIR"] = a.clang_dir
        return f"using local clang {a.clang_dir}"
    return None


def head(rt, name, nested):
    if nested:
        return
    rt.cur_head = f"# {name}"
    if rt.args.quiet and TTY:
        sys.stdout.write("\r\033[K" + dim(rt.cur_head))
        sys.stdout.flush()
    elif not rt.args.quiet:
        print(bold(f"# {name}"), flush=True)


def finish(rt, name, ok, secs, nested, note=""):
    if nested:
        return
    tail = f"{secs:.0f}s" if secs >= 1 else ""
    if rt.args.quiet:
        mark = green("ok  ") if ok else red("FAIL")
        line = f"# {name}  {mark} {tail} {dim(note)}".rstrip()
        sys.stdout.write(("\r\033[K" if TTY else "") + line + "\n")
    elif not ok:
        print(red(f"# FAIL {name}"), flush=True)
    elif secs >= 5:
        print(dim(f"  {secs:.0f}s"), flush=True)


def exec_run(step, name, ctx, rt, nested):
    rt.counter += 1
    run_text = interp_s(step["run"], ctx)
    step_env = {k: interp_s(v, ctx) for k, v in (step.get("env") or {}).items()}
    cwd = interp_s(step.get("working-directory", str(rt.ws)), ctx)
    sid = step.get("id")
    out_file = rt.state / f"out-{rt.counter}"
    out_file.write_text("")
    note = hook(run_text, rt)
    if note:
        if not nested:
            print(dim(f"- {name} (skip: {note})"), flush=True)
        return True
    if rt.args.dry_run:
        if not nested:
            print(bold(f"# {name}") + dim(f"  [{len(run_text.splitlines())} line run]"))
        return True
    script = rt.state / f"step-{rt.counter}.sh"
    script.write_text(run_text + "\n")
    shell = step.get("shell")
    cmd = ["bash", "--noprofile", "--norc", "-eo", "pipefail", str(script)] if shell == "bash" \
        else ["bash", "-e", str(script)]
    head(rt, name, nested)
    t = time.time()
    own_log = None
    if not nested:
        slug = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip("-")[:40]
        rt.log_path = rt.logdir / f"{rt.counter:02d}-{slug}.log"
        own_log = open(rt.log_path, "w")
        rt.log = own_log
    try:
        rc = stream(cmd, proc_env(rt, step_env, out_file), cwd, rt)
    finally:
        if own_log:
            own_log.close()
    ok = rc == 0
    rt.env.update(read_kv(rt.state / "genv"))
    for p in (rt.state / "gpath").read_text().splitlines() if (rt.state / "gpath").exists() else []:
        if p and p not in rt.path_extra:
            rt.path_extra.insert(0, p)
    if sid:
        rt.steps[sid] = {"outputs": read_kv(out_file), "outcome": "success" if ok else "failure"}
    if not ok:
        finish(rt, name, False, time.time() - t, nested)
        if not nested:
            if rt.args.quiet:
                tail = rt.log_path.read_text(errors="replace").splitlines()[-40:]
                print("\n".join(tail))
            print(red(f"  exit {rc} - full log: {rt.log_path}"), flush=True)
        return False
    finish(rt, name, True, time.time() - t, nested)
    return True


def exec_uses(step, name, ctx, rt, nested):
    u = step["uses"]
    w = {k: interp(v, ctx) for k, v in (step.get("with") or {}).items()}
    if u.startswith("./"):
        act_dir = rt.ws / u[2:]
        f = next((act_dir / n for n in ("action.yml", "action.yaml") if (act_dir / n).exists()), None)
        if not f:
            raise RunnerError(f"composite action not found: {u}")
        act = yaml.safe_load(f.read_text())
        inputs = {k: (v or {}).get("default", "") for k, v in (act.get("inputs") or {}).items()}
        for k, v in w.items():
            if k not in inputs:
                raise RunnerError(f"{u}: unknown input '{k}'")
            inputs[k] = v
        missing = [k for k, v in (act.get("inputs") or {}).items()
                   if (v or {}).get("required") and inputs[k] in ("", None)]
        if missing:
            raise RunnerError(f"{u}: missing required input(s) {missing}")
        if (act.get("runs") or {}).get("using") != "composite":
            raise RunnerError(f"{u}: only composite actions are supported")
        inner = dict(ctx)
        inner["inputs"] = inputs
        if nested or rt.args.dry_run:
            if not nested:
                print(bold(f"# {name}") + dim(f"  [{u}]"))
            return run_steps(act["runs"]["steps"], inner, rt, True)
        head(rt, name, False)
        t = time.time()
        slug = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip("-")[:40]
        rt.counter += 1
        rt.log_path = rt.logdir / f"{rt.counter:02d}-{slug}.log"
        with open(rt.log_path, "w") as lg:
            rt.log = lg
            ok = run_steps(act["runs"]["steps"], inner, rt, True)
        finish(rt, name, ok, time.time() - t, False)
        if not ok:
            if rt.args.quiet:
                print("\n".join(rt.log_path.read_text(errors="replace").splitlines()[-40:]))
            print(red(f"  full log: {rt.log_path}"), flush=True)
        return ok
    if u.startswith("actions/checkout"):
        print(dim(f"- {name} (local: repo copied to workspace)"))
        return True
    if u.startswith("actions/cache"):
        print(dim(f"- {name} (skip: no remote cache locally)"))
        return True
    if u.startswith("actions/upload-artifact"):
        src = Path(tostr(w.get("path", ""))).expanduser()
        dst = rt.args.root_path / "artifacts" / tostr(w.get("name", "artifact"))
        if rt.args.dry_run:
            print(bold(f"# {name}") + dim(f"  [-> {dst}]"))
            return True
        if dst.exists():
            shutil.rmtree(dst)
        if not src.is_dir():
            print(red(f"# FAIL {name}: {src} missing"))
            return False
        shutil.copytree(src, dst)
        print(bold(f"# {name}") + dim(f"  -> {dst}"))
        if getattr(rt.args, "out_path", None):
            out = rt.args.out_path / f"{dst.name}-{time.strftime('%Y%m%d-%H%M%S')}"
            shutil.copytree(src, out)
            OUT_COPIES.append(out)
            print(dim(f"  + copy -> {out}"))
        return True
    raise RunnerError(f"unsupported action '{u}' (add a case in exec_uses)")


def step_name(step):
    if step.get("name"):
        return step["name"]
    if "uses" in step:
        return step["uses"]
    return (step.get("run") or "run").strip().splitlines()[0][:50]


def run_steps(steps, ctx, rt, nested=False):
    all_ok = True
    for step in steps:
        name = step_name(step)
        try:
            cond = step.get("if")
            if cond is None:
                go = not rt.failed
            else:
                expr = INTERP.sub(lambda m: m.group(1), str(cond)).strip() if isinstance(cond, str) else cond
                val = truthy(ev(expr, ctx)) if isinstance(expr, str) else bool(expr)
                has_status = isinstance(expr, str) and re.search(r"\b(success|failure|always|cancelled)\s*\(", expr)
                go = val and (True if has_status else not rt.failed)
            if not go:
                if not nested:
                    why = "previous step failed" if cond is None else "if false"
                    print(dim(f"- {name} (skip: {why})"), flush=True)
                continue
            ok = exec_uses(step, name, ctx, rt, nested) if "uses" in step \
                else exec_run(step, name, ctx, rt, nested)
        except RunnerError as e:
            raise RunnerError(f"step '{name}': {e}")
        if not ok:
            rt.failed = True
            all_ok = False
            if nested:
                break
    return all_ok


def load_yaml(p):
    d = yaml.safe_load(Path(p).read_text())
    if True in d and "on" not in d:   # YAML 1.1 reads `on:` as boolean True
        d["on"] = d.pop(True)
    return d


def slugify(s):
    return re.sub(r"[^A-Za-z0-9._-]+", "-", s).strip("-")


def git_out(repo, *a):
    try:
        return subprocess.check_output(["git", "-C", str(repo), *a], text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def coerce(inputs_def, given, label):
    out = {}
    for k, d in inputs_def.items():
        d = d or {}
        if k in given:
            v = given[k]
        elif "default" in d:
            v = d["default"]
        elif d.get("required"):
            raise RunnerError(f"{label}: missing required input '{k}'")
        else:
            v = ""
        if d.get("type") == "boolean" and isinstance(v, str):
            v = v.lower() == "true"
        out[k] = v
    for k in given:
        if k not in inputs_def:
            raise RunnerError(f"{label}: unknown input '{k}'")
    return out


def github_ctx(ws, repo, n):
    return {"workspace": str(ws), "sha": git_out(repo, "rev-parse", "HEAD") or "0" * 40,
            "run_number": n, "run_id": n, "event_name": "workflow_dispatch",
            "repository": "local/" + repo.name, "actor": "local"}


def prepare_runtime(ws, key, args, repo, n, inputs):
    root = args.root_path
    state = root / "state" / key
    logdir = root / "logs" / key
    home = root / "home"
    for d in (state, logdir, home):
        d.mkdir(parents=True, exist_ok=True)
    for f in ("genv", "gpath", "gsum"):
        (state / f).write_text("")
    rt = Runtime(ws, state, logdir, home, args)
    gh = github_ctx(ws, repo, n)
    rt.base = {
        "CI": "true", "GITHUB_ACTIONS": "true", "DEBIAN_FRONTEND": "noninteractive",
        "GITHUB_WORKSPACE": str(ws), "GITHUB_SHA": gh["sha"], "GITHUB_RUN_NUMBER": str(n),
        "GITHUB_RUN_ID": str(n), "GITHUB_REPOSITORY": gh["repository"],
        "GITHUB_ENV": str(state / "genv"), "GITHUB_PATH": str(state / "gpath"),
        "GITHUB_STEP_SUMMARY": str(state / "gsum"), "RUNNER_TEMP": str(state),
        "RUNNER_OS": "Linux", "GIT_CONFIG_COUNT": "1",
        "GIT_CONFIG_KEY_0": "safe.directory", "GIT_CONFIG_VALUE_0": "*",
    }
    # --kernel-src: make clone-source.sh clone from the local repo instead of the network
    if args.kernel_src and inputs.get("source_type") == "gki":
        rt.base.update({
            "GIT_CONFIG_COUNT": "2",
            "GIT_CONFIG_KEY_1": f"url.file://{args.kernel_src}.insteadOf",
            "GIT_CONFIG_VALUE_1": "https://android.googlesource.com/kernel/common",
        })
    # sudo stand-in (root in docker has no sudo; --no-apt skips apt entirely)
    real = shutil.which("sudo") or ""
    if args.no_apt or (os.geteuid() == 0 and not real):
        shimdir = state / "bin"
        shimdir.mkdir(exist_ok=True)
        shim = shimdir / "sudo"
        shim.write_text(
            "#!/bin/sh\n"
            'while [ $# -gt 0 ] && [ "${1#-}" != "$1" ]; do shift; done\n'
            'case "$1" in apt|apt-get) '
            + ('echo "[local] skip: $*"; exit 0;; esac\n' if args.no_apt else ";; esac\n")
            + ('exec "$@"\n' if os.geteuid() == 0 and not real else
               f'exec {real or "env"} "$@"\n'))
        shim.chmod(0o755)
        rt.path_extra.insert(0, str(shimdir))
    return rt, gh


def run_variant(wf, inputs, label, args, repo, n):
    slug = slugify(label)
    root = args.root_path
    ws = repo if args.dry_run else root / "ws" / slug
    if not args.dry_run:
        if ws.exists():
            shutil.rmtree(ws)
        ws.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(repo, ws, symlinks=True,
                        ignore=lambda d, names: ["out"] if Path(d) == repo else [])
    rt, gh = prepare_runtime(ws, slug, args, repo, n, inputs)
    rt.cur_head = ""
    ctx = {"inputs": inputs, "github": gh, "env": rt.env, "steps": rt.steps,
           "matrix": {}, "_rt": rt}
    results = []
    for jid, job in wf["jobs"].items():
        for k, v in (wf.get("env") or {}).items():
            rt.env[k] = interp_s(v, ctx)
        for k, v in (job.get("env") or {}).items():
            rt.env[k] = interp_s(v, ctx)
        results.append(run_steps(job["steps"], ctx, rt))
    return all(results), rt


def expand_variants(args, repo):
    wf_dir = repo / ".github" / "workflows"
    top = load_yaml(wf_dir / args.workflow)
    disp = ((top.get("on") or {}).get("workflow_dispatch") or {}).get("inputs") or {}
    out = []
    for jid, job in top["jobs"].items():
        uses = str(job.get("uses", ""))
        if not uses.startswith("./"):
            print(dim(f"- job '{jid}' (skip: not a build job)"))
            continue
        callee = load_yaml(repo / uses[2:])
        in_def = (((callee.get("on") or {}).get("workflow_call") or {}).get("inputs")) or {}
        mx = (job.get("strategy") or {}).get("matrix") or {}
        if any(k in mx for k in ("include", "exclude")):
            raise RunnerError("matrix include/exclude not supported")
        keys = list(mx)
        combos = [dict(zip(keys, c)) for c in itertools.product(*[mx[k] for k in keys])] or [{}]
        for combo in combos:
            top_in = coerce(disp, {"notify": args.notify}, "dispatch")
            ctx = {"inputs": top_in, "matrix": combo,
                   "github": github_ctx(repo, repo, 0), "env": {}, "_rt": type("R", (), {"failed": False})()}
            label = interp_s(job.get("name", jid), ctx)
            given = {k: interp(v, ctx) for k, v in (job.get("with") or {}).items()}
            out.append((label, coerce(in_def, given, label), callee, combo))
    return out


def pick(variants, args):
    sel = args.variant
    if not sel:
        if len(variants) > 1 and sys.stdin.isatty() and not args.yes and not args.dry_run:
            for i, (lab, inp, _, _) in enumerate(variants, 1):
                print(f"  [{i}] {lab}  ({inp.get('source_type')}/{inp.get('ksu_type')})")
            ans = input("variant [1..%d / a=all] (1): " % len(variants)).strip().lower() or "1"
            if ans == "a":
                return variants
            if ans.isdigit() and 1 <= int(ans) <= len(variants):
                return [variants[int(ans) - 1]]
            raise RunnerError("invalid choice")
        return variants
    if sel.lower() == "all":
        return variants
    toks = [t.strip().lower() for t in sel.split(",") if t.strip()]
    hit = []
    for v in variants:
        lab, inp = v[0].lower(), v[1]
        keys = {inp.get("ksu_type", ""), inp.get("source_type", ""), inp.get("artifact_name", "")}
        if any(t in keys or t in lab for t in toks):
            hit.append(v)
    if not hit:
        raise RunnerError(f"--variant '{sel}' matches none of: " + ", ".join(v[0] for v in variants))
    return hit


def preflight(args):
    miss = [t for t in ("git", "patch", "python3", "curl", "tar") if not shutil.which(t)]
    if miss and not args.dry_run:
        raise RunnerError("missing tools: " + " ".join(miss))
    if args.clang_dir and not args.dry_run:
        clang = Path(args.clang_dir) / "bin" / "clang"
        try:
            r = subprocess.run([str(clang), "--version"], capture_output=True, text=True, timeout=180)
        except Exception as e:
            raise RunnerError(f"clang does not run here: {e}")
        if r.returncode != 0:
            raise RunnerError("clang does not run here (wrong CPU arch? run via docker --platform linux/amd64)\n"
                              + (r.stderr or r.stdout).strip())
        print(dim("clang: " + r.stdout.splitlines()[0]))


OUT_COPIES = []


def main():
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description="run the repo's GitHub workflow locally")
    ap.add_argument("--repo", default=str(here.parent))
    ap.add_argument("--workflow", default="build-staging.yml")
    ap.add_argument("--root", default=os.path.expanduser("~/seiran-build"))
    ap.add_argument("--variant", default="")
    ap.add_argument("--kernel-src", default="")
    ap.add_argument("--clang-dir", default="")
    ap.add_argument("--notify", action="store_true")
    ap.add_argument("--no-apt", action="store_true")
    ap.add_argument("-q", "--quiet", action="store_true")
    ap.add_argument("-y", "--yes", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    args.root_path = Path(args.root).expanduser().resolve()
    args.out_path = Path(args.out).expanduser().resolve() if args.out else None
    repo = Path(args.repo).resolve()
    try:
        preflight(args)
        variants = pick(expand_variants(args, repo), args)
        args.root_path.mkdir(parents=True, exist_ok=True)
        cf = args.root_path / "run_number"
        n = (int(cf.read_text()) + 1) if cf.exists() else 1
        if not args.dry_run:
            cf.write_text(str(n))
        summary = []
        for label, inputs, wf, _ in variants:
            print(bold(f"\n## {label}") + dim(f"  (run #{n}, {inputs.get('source_type')}/{inputs.get('ksu_type')})"))
            t = time.time()
            ok, rt = run_variant(wf, inputs, label, args, repo, n)
            summary.append((label, ok, time.time() - t, inputs.get("artifact_name", "")))
    except RunnerError as e:
        print(red(f"[FAIL] runner: {e}"))
        sys.exit(2)
    except KeyboardInterrupt:
        print(red("\n[FAIL] interrupted"))
        sys.exit(130)
    print(bold("\n## summary"))
    for label, ok, secs, art in summary:
        mark = green("ok  ") if ok else red("FAIL")
        where = f"-> {args.root_path / 'artifacts' / art}" if ok and not args.dry_run else ""
        print(f"  {mark} {label}  {secs / 60:.1f}m {dim(where)}")
    for p in OUT_COPIES:
        print(f"  {dim('out')} {p}")
    sys.exit(0 if all(s[1] for s in summary) else 1)


if __name__ == "__main__":
    main()
