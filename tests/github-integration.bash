#!/usr/bin/env bash
# shellcheck shell=bash
## @file tests/github-integration.bash
## @brief Exercises the released commands against GitHub without mutation.
## @details
## This CI smoke test validates authenticated gh discovery, live Git ref
## filtering, command composition, and resign_commits dry-run behavior against
## the pull-request branch itself.  It deliberately generates an ephemeral SSH
## signing key because configuration validation and allowed-signers generation
## are part of the production path even though --dry-run prevents rewriting and
## pushing commits.  The test intentionally uses an agent identity that does not
## match the pull-request tip so production signatures made by another key are
## treated as a safe ownership boundary rather than as signatures to verify.
##
## The caller supplies the exact branch to inspect.  This keeps the live test
## narrow and prevents unrelated repositories or branches from affecting the
## expected result.
##
## @par Examples
## @code
## tests/github-integration.bash dist/list_repos.bash \
##   dist/resign_commits.bash agent/feat/example
## @endcode

set -Eeuo pipefail
umask 077

if (($# != 3)); then
  printf 'Usage: %s LIST_REPOS RESIGN_COMMITS BRANCH\n' "$0" >&2
  exit 64
fi

list_repos=$1
resign_commits=$2
branch=$3

: "${GH_TOKEN:?GH_TOKEN is required}: GH_TOKEN is required"

owner="$(gh repo view --json owner --jq '.owner.login')"
repository="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf -- "${tmpdir}"
}
trap cleanup EXIT HUP INT TERM

signing_key="${tmpdir}/signing-key"
ssh-keygen -q -t ed25519 -N '' -f "$signing_key"

discovered="$(
  "$list_repos" \
    --owner "$owner" \
    --branch-pattern "$branch"
)"

grep -Fxq "$repository" <<<"$discovered"

output="$(
  printf '%s\n' "$repository" |
    "$resign_commits" \
      --owner "$owner" \
      --branch-pattern "$branch" \
      --agent-name "resign-agent-commits CI" \
      --agent-email "resign-agent-commits-ci@example.invalid" \
      --signing-key "$signing_key" \
      --dry-run
)"

grep -Fq "Repository: $repository" <<<"$output"
grep -Fq "$branch" <<<"$output"
grep -Fq 'HUMAN_BOUNDARY' <<<"$output"
