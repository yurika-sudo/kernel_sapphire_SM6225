# Commit attribution

This repository uses two commit kinds.

## Reference-derived code

Code taken from upstream Linux, Templar, BORE, SUSFS, KSU-Next, or another
reference keeps the original author and follows a cherry-pick message shape.
Do not use `ANDROID:` for these subjects:

- Author: the original code author.
- Co-authored-by: the AI agent that did the port.
- Committer: `yurika-sudo <yurika0uu@gmail.com>`.
- Subject: `UPSTREAM: <original subject>` or `BACKPORT: <original subject>`.
- Body: `[ Upstream commit <full sha> ]`, the original message and trailers,
  then `(cherry picked from commit <full sha>)`.

Use `scripts/commit.sh` with an explicit `--author=...`. The helper keeps the
original author and adds the AI `Co-authored-by:` trailer if it is missing:

```sh
scripts/commit.sh "UPSTREAM: original subject" -m "commit body" \
  --author="Original Author <email>"
```

## Repository-owned AI work

New scripts, CI, docs, and other code written by the AI assistant use the
helper with a plain scope prefix, such as `scripts:` or `docs:`. Do not use
`ANDROID:`:

```sh
scripts/commit.sh "scripts: describe the change" -m "- Explain the change."
```

The helper uses `Claude <noreply@anthropic.com>` as author by default. Override
that identity with `AI_AUTHOR_NAME` and `AI_AUTHOR_EMAIL`. The committer remains
`yurika-sudo <yurika0uu@gmail.com>`, and `-s` adds the owner's
`Signed-off-by:` trailer. Own work has no `Co-authored-by:` trailer because the
AI identity is already the author. The helper refuses an empty subject and
passes extra Git commit arguments through unchanged.

This repository does not use an `Assisted-by:` trailer. The only AI attribution
trailer is the reference-derived `Co-authored-by:` trailer described above.
