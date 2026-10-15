# CI / Fork Setup

Two workflows. Both are safe to run on a fresh fork with no secrets configured.

| Workflow | When | What |
|---|---|---|
| **Build & Release — Seiran GKI** (`build.yml`) | manual, or every 5 days | Clone → patch → KernelSU-Next + SUSFS → DroidSpaces → build → pack → release → Telegram |
| **Check Source Updates** (`check-updates.yml`) | Mondays 02:00 UTC, or manual | Read upstream versions, verify-build a candidate, bump `sources/source-pins.json` |

The scheduled build never publishes: `release` is skipped for `schedule` events, it only runs on a manual dispatch.

---

## Inputs

**build.yml**

| Input | Default | Meaning |
|---|---|---|
| `build_type` | `stable` | `testing` additionally applies `patches/testing/` and tags the release `-testing`/prerelease |
| `nuke_release` | `true` | Delete the assets already on the release tag before uploading, instead of adding to them |
| `skip_release` | `false` | Build only — no release, no manager fetch. Artifacts are kept 7 days, so this is the "does it boot" button |

**check-updates.yml** takes nothing. It reads, verifies, and commits the pin file itself.

## Secrets (all optional)

| Secret | Used by | Without it |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | notify steps | No Telegram messages; nothing else changes |
| `TELEGRAM_CHAT_ID` | notify steps | same |
| `TELEGRAM_TOPIC_ID` | notify steps | Posts to the chat's general topic |

`GITHUB_TOKEN` is provided by Actions; it needs `actions: read` (already set) to pull the manager APK out of KernelSU-Next's CI.

---

## How the update gate works

`scripts/check-sources.sh` compares upstream with [sources/source-pins.json](../sources/source-pins.json):

- **KernelSU-Next** — latest release tag of `KernelSU-Next/KernelSU-Next`, plus the head of the fork branch actually built
- **SUSFS** — `SUSFS_VERSION` parsed out of `kernel_patches/include/linux/susfs.h` on the pinned branch
- **SUSFS module** — latest release of the userspace module repo (this tag is also the *release tag* of this project, so the kernel release rolls with the SUSFS module revision)
- **DroidSpaces** — latest release, **and** a check that the kABI patch file still exists at that tag
- **GKI** — `VERSION/PATCHLEVEL/SUBLEVEL` from the branch's `Makefile`

Then:

1. If KSU-Next, SUSFS or DroidSpaces moved → `verify` runs a full build with the candidate DroidSpaces tag (`skip_release: true`).
2. `apply-pins` writes the new values **only if that build compiled**; on a failure it keeps the last known-good versions and says so. The GKI sublevel and the SUSFS module tag are written ungated — they don't feed the KSU/SUSFS integration.
3. `notify` reports what moved, what was held back, and any lookup that could not reach upstream (a failed lookup is never treated as "no update").

So: a broken upstream bump costs one red CI run and does *not* land in the pin file.

## When upstream does break something

The integration fails loudly, on purpose. What each message means:

| Log line | Where | Fix |
|---|---|---|
| `SUSFS vX did not apply cleanly to this tree` | `setup-ksu.sh` | Port the rejected hunks in `susfs4ksu/kernel_patches/50_add_susfs_in_*.patch` to the current tree. Only the `fs/namespace.c` preamble hunk is auto-shimmed |
| `no susfs_init() call in KernelSU-Next/kernel` | `setup-ksu.sh` | Upstream moved the init path; update the grep in `_verify_integration` |
| `fs/namespace.c has no CL_COPY_MNT_NS` | `setup-ksu.sh` | Patch reported success but landed nowhere — check the `-p1` level / fuzz |
| `CONFIG_X is not a Kconfig symbol of this KernelSU-Next — dropped` | `setup-configs.sh` | Symbol renamed or removed upstream; the line is pruned so `olddefconfig` can't silently ignore the whole block |
| `CONFIG_KSU_SUSFS_SUS_MOUNT must be =y for the SUSFS build` | `setup-configs.sh` | A required hiding feature vanished — port the config block, don't delete the check |
| `droidspaces_sysvipc_kabi — download failed` / `refusing to enable SYSVIPC` | `droidspaces.sh` | Upstream moved the patch; find the new path, bump `droidspaces_tag` |
| `⚠️ N local patch(es) did not apply` | `apply-patches.sh` | Rebase those patches against the new sublevel |

Nothing here is allowed to degrade into a kernel that boots with root visible: a half-applied SUSFS or a missing kABI padding patch stops the build.

---

## Caches

`ccache-gki-<hash of source-pins.json>` — one cache, keyed on the pin file so a version bump starts a cold cache instead of mixing object files across kernel revisions. Restore-keys fall back to the previous pin, so a bump is a partial hit rather than a full rebuild of ~40k files.

The kernel source is cloned fresh each run (no source cache): the GKI branch head floats, and a cache keyed on a *recorded* sublevel would happily hand back an older tree.
