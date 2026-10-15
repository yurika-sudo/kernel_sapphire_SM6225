## Commit Messages
Use Conventional Commits format: `<type>(<scope>): <description>`

Types: feat, fix, ci, chore, refactor, docs
Scope examples: build, scripts, config, workflow
- Imperative mood, English
- Max 72 chars, no period at end
- No body unless change is non-obvious

## Examples
- `refactor(scripts): simplify section comment headers`
- `fix(ccache): replace run_id key with hashFiles`
- `ci(build): gate the release job on kernel verification`
- `fix(setup-ksu): fail when the SUSFS patch leaves rejects`

## Repo facts

- **CI-only automation** — the kernel tree is cloned by CI into `${{ github.workspace }}/kernel_src`; there is no local build environment, so do not suggest running a build or a kernel test locally.
- CI runners: `ubuntu-latest` only (4 vCPU / 16 GB); the build step needs its 50-minute timeout.
- AnyKernel3 identity (`anykernel.sh`, `dtbFile`, device names) is per-device and not tracked here — do not add device identity to this repo.

## Sources and variants

- There is **one** build: GKI `android13-5.15-lts` + KernelSU-Next (`pershoot/dev-susfs`) with built-in SUSFS + DroidSpaces. Do not reintroduce a variant matrix (`SOURCE_TYPE`, `KSU_TYPE`, CLO, SukiSU, NoKSU, gki-compat were removed on purpose).
- [sources/source-pins.json](../sources/source-pins.json) is the single source of truth for versions. Scripts read it; never hardcode a tag or branch in a workflow `env:` block. `check-sources.sh` proposes, `check-updates.yml` verifies by compiling, and only then is a pin rewritten.
- Every build step lives in `scripts/*.sh` and is invoked as `bash $GITHUB_WORKSPACE/scripts/<name>.sh`, so a repo edit changes behaviour without bumping a pinned action. Keep the YAML thin.
- Steps must **fail loudly**, never skip silently: a half-applied SUSFS patch, a missing SYSVIPC kABI padding patch, or a required `CONFIG_KSU*` symbol that vanished upstream has to stop the build. A kernel that boots with root visible is a bug, not a warning.
