# Contributing

Contributions are welcome.

Before consequential changes, read `README.md`, `AGENTS.md`,
`doc/resign-agent-commits-spec.md`, `doc/decisions.md`, the relevant ADRs, and
the adopted standards under `doc/standards/`.

Prepare dependencies and validate changes with:

```bash
make deps
make deps-check
make check
make test
make test-report
make docs
```

Generated state under `dist/`, `vendor/`, `doc/reference/`, and
`test-results/` is not maintained source.

Changes to branch eligibility, commit ownership, signature verification,
credential handling, force-push semantics, race detection, dependency authority,
or release behavior are consequential and should update or add an ADR.

Bash source must follow
`doc/standards/bash/documentation-standard.md`.  Formatting uses
`shfmt -i 2 -bn -ci -sr -kp`.

Suspected vulnerabilities should follow `SECURITY.md` rather than a public issue.
