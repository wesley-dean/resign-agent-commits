# ADR-018: Two-Command Repository Discovery and Commit Re-Signing Workflow

## Status

Accepted

## Context

This project packages two cooperating Bash commands originally developed in
`wesley-dean/wesdean-movein`:

- `list_repos.bash` discovers repositories that contain branches matching the
  configured machine-work branch patterns; and
- `resign_commits.bash` inspects those branches and rewrites only the eligible
  contiguous agent-owned suffix with SSH-signed commits.

The commands are intended for scheduled automation such as Jenkins.  That
automation may hold a GitHub token and an SSH signing private key, so the project
operates across meaningful authentication, repository-mutation, and secret
boundaries.

The repository is derived from template-bash.  Its runtime registry/noop plugin
example is not relevant to this product, while the template's Make, bashdeps,
artifact, documentation, testing, and late-release patterns remain applicable.

## Decision Drivers

- Keep discovery and signing independently composable through ordinary text.
- Minimize the authority exercised by each step.
- Treat branch names as routing signals, never proof of commit ownership.
- Refuse to rewrite human-authored or merge history.
- Detect races immediately before push.
- Preserve a useful dry-run path that executes discovery and policy checks.
- Keep generated consumer artifacts independent of repository dependency state.
- Follow the established Bash-project build, documentation, test, and release
  model as literally as the two-command product shape permits.

## Decision

The project SHALL ship two standalone executable commands:

```text
list_repos.bash
resign_commits.bash
```

The normal orchestration contract is:

```text
list_repos.bash | resign_commits.bash
```

### Discovery

`list_repos.bash` SHALL enumerate repositories for one configured owner and
write only normalized `OWNER/NAME` values to STDOUT.

It SHALL filter candidate repositories before clone by checking for at least one
configured matching branch.  The default branch-pattern set is:

```text
agent/*,ai/*,codex/*
```

Multiple patterns are comma-separated configuration values and are passed to Git
as independent ref globs rather than interpreted as regular expressions.

### Signing Boundary

`resign_commits.bash` SHALL independently repeat branch discovery before clone.
Discovery output is not trusted merely because it came from `list_repos.bash`.

For each matching branch, only the contiguous branch-tip suffix whose commits
have the configured agent author and committer email and exactly one parent is
eligible for rewriting.

A human-owned commit, differently owned commit, or merge commit is a hard signing
boundary.  The tool SHALL NOT rewrite through that boundary.

An existing signature that fails verification causes policy rejection rather than
replacement.

### Rewriting and Push Safety

Eligible unsigned commits are rewritten with Git SSH signing.  Rewritten commits
must verify before any push is attempted.

Immediately before push, the remote branch tip is checked again against the SHA
observed during discovery.  A changed remote tip causes a safe skip.

Pushes SHALL use an exact `--force-with-lease` expectation.  The workflow MUST
NOT use an unconstrained force push.

Dry-run mode SHALL perform discovery and policy evaluation but SHALL NOT rewrite
or push commits.

### Authentication and Temporary State

HTTPS Git access uses `GH_TOKEN` through a temporary `GIT_ASKPASS` helper.
The token SHALL NOT be embedded in remote URLs.

SSH signing uses the configured private key path.  The public key may be supplied
explicitly or derived with `ssh-keygen -y`.

Temporary signer state, including allowed-signers and askpass files, SHALL be
created beneath a private `mktemp` directory and removed at command exit.

### Build and Dependencies

GNU Make remains the canonical orchestration interface.

The Makefile SHALL bootstrap only a pinned released `bashdeps` executable.
`bashdeps` SHALL then synchronize all repository dependencies from
`dependencies.txt`.

The manifest includes current released versions of bash-doxygen, Bash-Minifier,
bashlog, and adrctl.  Those downloaded dependencies SHALL remain generated
`vendor/` state and SHALL NOT be committed.

bashlog is intentionally prepared now but SHALL NOT be integrated into the two
commands in this design iteration.  Migrating diagnostics to bashlog is separate
backlog work so repository/bootstrap changes do not conceal a logging-behavior
refactor.

### Release Artifacts

Each command SHALL have three release representations:

```text
<command>.dev.bash
<command>.bash
<command>.min.bash
```

Each executable SHALL have an adjacent `.sha256` companion, producing twelve
release files total.

Build provenance including version, build date, and build commit is injected
during `make build`; generated provenance is not maintained manually in source.

### Testing

Bats is the behavior-test framework.

All six executable artifacts SHALL be exercised.  Sourceable unit tests SHALL
exercise every maintained function directly.  Git rewrite/boundary behavior
SHOULD use temporary local repositories and bare remotes where practical.

CI SHALL also perform a read-only live GitHub smoke test on pull requests using
the GitHub CLI, the exact pull-request branch, an ephemeral SSH key, and
`resign_commits.bash --dry-run`.

## Operational Constraints

- Discovery STDOUT MUST remain suitable for piping into the signer.
- Both commands MUST independently enforce branch-pattern constraints.
- Branch names MUST NOT be trusted as proof of commit identity.
- Signing MUST stop at the first non-agent or merge boundary.
- Invalid existing signatures MUST fail closed.
- A remote-tip race MUST prevent push.
- Pushes MUST use exact force-with-lease semantics.
- `--dry-run` MUST NOT mutate local or remote branch history.
- Only bashdeps may be bootstrapped directly by the Makefile.
- Repository dependencies MUST remain uncommitted generated state.
- bashlog MUST remain unused by runtime code until separately designed and
  reviewed.
- Builds MUST produce six executables and six SHA-256 companions.
- Release artifacts MUST remain standalone without `vendor/` at runtime.

## Alternatives Considered

### One Monolithic Command

Rejected because repository enumeration and signing have different responsibilities
and compose naturally through newline-delimited repository identifiers.

### Trust Discovery Output Without Rechecking

Rejected because pipeline stages are separate trust boundaries and repository
state can change between them.

### Rewrite Every Unique Commit on a Machine-Named Branch

Rejected because branch naming is a routing signal rather than proof of ownership.
Human and merge boundaries must remain protected.

### Integrate bashlog During Repository Bootstrap

Rejected for this iteration.  Fetching the dependency prepares the repository for
the later migration without mixing logging behavior changes into the initial
productization work.

## Consequences

The workflow remains deliberately conservative.  Some branches that require
manual cleanup are reported rather than automatically repaired, and concurrent
changes may cause safe skips.

The two-command interface remains easy to inspect and compose.  Jenkins and other
automation can hold the signing credential outside the commands while the signer
enforces repository-history policy before using that authority.

The repository build/release layout remains recognizably aligned with the other
Bash projects even though two commands expand the release file matrix.

## Related Decisions

This decision specializes ADR-003, ADR-005, ADR-006, ADR-009, ADR-014, ADR-015,
and ADR-016 for resign-agent-commits.
