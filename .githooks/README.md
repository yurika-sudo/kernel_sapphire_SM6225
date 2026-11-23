# Commit attribution hooks

`prepare-commit-msg` adds `Assisted-by: Claude <claude-opus-5-5>` automatically
when a commit message does not already contain an `Assisted-by:` trailer. Set
`AI_ASSISTED_BY` to use a different identity.

Use `git aicommit "subject" -m "body"` to commit with the AI as author and the
owner as committer. `AI_AUTHOR_NAME` and `AI_AUTHOR_EMAIL` override the AI
identity.

For code ported from an upstream reference, pass `--author` explicitly. The
hook still adds the `Assisted-by` trailer.

Use `git commit --no-verify` to skip commit hooks for one commit. Note that Git
still runs `prepare-commit-msg` with `--no-verify`; remove the trailer manually
if that hook must not run.
