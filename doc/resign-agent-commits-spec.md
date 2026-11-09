# resign-agent-commits Specification

## Scope

resign-agent-commits provides two Bash commands for discovering repositories with
machine-work branches and applying verified SSH signatures to eligible
agent-owned branch-tip commits.

The commands do not decide whether a pull request should be approved or merged.
They do not infer trust from branch names alone.  They do not sign arbitrary
history.

## Commands

### list_repos.bash

The command enumerates repositories for one configured owner.

STDOUT contains only repositories selected for downstream processing, one
`OWNER/NAME` value per line.  Diagnostics belong on STDERR.

By default, archived repositories and forks are excluded.  Repositories without a
branch matching one of the configured branch patterns are excluded before clone.

The default branch patterns are:

```text
agent/*,ai/*,codex/*
```

### resign_commits.bash

Repositories may be supplied as positional arguments or newline-delimited STDIN.

The command independently verifies matching remote branches, discovers the
default branch, and evaluates unique branch history.

Only a contiguous branch-tip suffix may be rewritten.  Every commit in that
suffix must:

- have the configured agent author email;
- have the configured agent committer email;
- have exactly one parent; and
- contain either no signature or a signature that verifies successfully.

A differently owned commit or merge commit ends eligibility.  The signer never
rewrites across that boundary.  When a tip has no eligible agent-owned suffix,
RAC reports `MERGE_BOUNDARY` for a multi-parent tip and `HUMAN_BOUNDARY` for
a single-parent tip with a non-agent author or committer.  A root tip outside
the expected ancestry is rejected as unexpected history.  These classifications
describe history topology and declared identity only; they neither authenticate
the original author nor authorize rewriting across the boundary.

An unsigned merge tip with both author and committer emails matching the
configured agent identity reports `SIGNING_BLOCKED`.  RAC does not rewrite
this history: the branch counts as a signing failure and the overall signer
returns nonzero, even when other branches succeed.  Matching email fields
are only identification metadata; they cannot authorize rewriting a merge.

A merge tip with different author or committer identity remains a benign
`MERGE_BOUNDARY` skip.  For an agent-identified merge tip with an existing
signature, RAC verifies that signature; an invalid signature is a
`POLICY_REJECTED` failure, while a valid tip remains a merge-boundary skip.
Neither result asserts that every ancestor was signed.  Remediation for an
unsigned agent-identified merge tip requires linear branch history or
separately authorized manual handling under repository policy.

If every eligible commit is already signed, the branch is a no-op.

If rewriting is required, every rewritten commit must verify before push.  The
remote tip is compared with the originally observed SHA immediately before push,
and the push uses exact force-with-lease semantics.

## Configuration Precedence

The commands use this precedence from highest to lowest:

1. command-line arguments;
2. process environment;
3. selected environment file;
4. built-in defaults.

The environment-file parser accepts only recognized assignment keys.  It does not
source or evaluate the file as shell code.

## Authentication

HTTPS Git transport uses `GH_TOKEN` through `GIT_ASKPASS`.

SSH transport is optional.

Commit signing uses an SSH private key supplied by path.  A public key may be
provided separately or derived from the private key with `ssh-keygen -y`.

## Dry Run

`--dry-run` performs discovery and policy analysis and reports what would be
signed.  It does not rewrite commits or push a branch.

## Exit Behavior

Configuration errors terminate the command with failure.

The signer summarizes branch and repository outcomes.  Policy-rejected or failed
branches/repositories make the final signer status non-zero.  Safe no-op and
race-skip classifications do not authorize mutation.

## Non-Promises

The project does not promise that:

- an `agent/*`, `ai/*`, or `codex/*` branch is actually agent-owned;
- a valid signature means the content is correct or safe;
- a GitHub token or signing key is protected from a hostile CI host;
- signing resolves semantic merge conflicts;
- concurrent remote changes will be retried automatically; or
- bashlog is not currently used by either runtime command.
