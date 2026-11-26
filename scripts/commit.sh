#!/bin/sh
set -eu

usage() {
    printf 'Usage: scripts/commit.sh "<subject>" [-m "<body>"] [git commit args...]\n' >&2
    exit 2
}

[ "$#" -ge 1 ] || usage
subject=$1
shift
case "$subject" in
    '') printf 'error: subject must not be empty\n' >&2; exit 2 ;;
    *[![:space:]]*) ;;
    *) printf 'error: subject must not be empty\n' >&2; exit 2 ;;
esac

ai_name=${GIT_AUTHOR_NAME:-${AI_AUTHOR_NAME:-Claude}}
ai_email=${GIT_AUTHOR_EMAIL:-${AI_AUTHOR_EMAIL:-noreply@anthropic.com}}
committer_name=yurika-sudo
committer_email=yurika0uu@gmail.com
author="$ai_name <$ai_email>"
explicit_author=false
has_coauthored=false
for arg in "$@"; do
    case "$arg" in
        --author=*) author=${arg#--author=}; explicit_author=true ;;
        *Co-authored-by:*) has_coauthored=true ;;
    esac
done

printf 'Committing: author=%s; committer=%s <%s>; subject=%s\n' \
    "$author" "$committer_name" "$committer_email" "$subject"

if $explicit_author; then
    if ! $has_coauthored; then
        set -- "--trailer=Co-authored-by: $ai_name <$ai_email>" "$@"
    fi
else
    set -- "--author=$author" "$@"
fi

GIT_COMMITTER_NAME=$committer_name GIT_COMMITTER_EMAIL=$committer_email \
    git commit -s -m "$subject" "$@"
