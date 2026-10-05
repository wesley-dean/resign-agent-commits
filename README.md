# resign-agent-commits

resign-agent-commits provides two Bash commands for discovering machine-work
branches across GitHub repositories and applying verified SSH commit signatures
to the eligible agent-owned suffix of those branches.

## Commands

`list_repos.bash` enumerates repositories for one owner and writes only
repositories that expose at least one configured matching branch.  The default
patterns are `agent/*,ai/*,codex/*`.

`resign_commits.bash` independently rechecks matching branches and rewrites only
the contiguous single-parent branch-tip suffix whose author and committer email
match the configured agent identity.  Human-owned and merge commits are hard
boundaries.  Existing invalid signatures are rejected, remote state is rechecked
before push, and updates use exact force-with-lease semantics.

The normal composition is:

```bash
src/list_repos.bash |
  src/resign_commits.bash
```

Dry-run mode performs discovery and policy evaluation without rewriting or
pushing:

```bash
src/list_repos.bash |
  src/resign_commits.bash --dry-run
```

See [the specification](doc/resign-agent-commits-spec.md) and
[threat model](doc/threat-model.md).

## Dependencies

GNU Make is the canonical orchestration surface.  The Makefile bootstraps only
the pinned released `bashdeps` executable and verifies its SHA-256 digest.
`bashdeps` then synchronizes `dependencies.txt`.

The manifest currently pins released bash-doxygen, Bash-Minifier, bashlog, and
adrctl artifacts.  Downloaded dependencies live under `vendor/` and are not
committed.  bashlog is intentionally downloaded now but is not yet used by either
runtime command; that migration is separate backlog work.

```bash
make deps
make deps-check
```

## Build and Release Files

`make build` injects version, build date, and build commit provenance and creates
three flavors of each command plus SHA-256 companions:

```text
dist/list_repos.dev.bash
dist/list_repos.dev.bash.sha256
dist/list_repos.bash
dist/list_repos.bash.sha256
dist/list_repos.min.bash
dist/list_repos.min.bash.sha256
dist/resign_commits.dev.bash
dist/resign_commits.dev.bash.sha256
dist/resign_commits.bash
dist/resign_commits.bash.sha256
dist/resign_commits.min.bash
dist/resign_commits.min.bash.sha256
```

Releases therefore contain twelve files.

## Testing

Bats exercises all six executables.  Unit tests cover maintained functions,
temporary local Git repositories provide integration-style history tests, and
pull-request CI performs a read-only live GitHub smoke test with `gh` and
`resign_commits.bash --dry-run`.

```bash
make test
make test-report
```

## Documentation

Maintained Bash follows
[the adopted Bash documentation standard](doc/standards/bash/documentation-standard.md).

`make docs` generates Doxygen HTML under `doc/reference/`.  The Pages workflow
publishes that generated directory; it is not committed.

The exact coding-standards release is recorded in [`.codingstandardrc`](.codingstandardrc)
and materialized under `doc/standards/`.

## License

This project is dedicated to the public domain under CC0 1.0 Universal.
