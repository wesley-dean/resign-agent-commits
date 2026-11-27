# ADR-021: Migrate Routine Dependency Updates to Centrally Managed Renovate

Date: 2026-11-26

## Status

Accepted

## Decision

This repository SHALL explicitly enroll in the centrally managed Jenkins
Renovate service through the minimal root `renovate.json`. The existing
GitHub Actions Dependabot version-update ecosystem SHALL set
`open-pull-requests-limit: 0` while retaining directory, scheduling,
cooldown, grouping, and commit-message metadata. This disables scheduled
routine version PRs without disabling independent Dependabot vulnerability
alerts or advisory-driven security-update PRs.

The existing `dependabot[bot]`-scoped non-major auto-merge workflow SHALL
remain independent and SHALL NOT grant Renovate automatic approval or
privileges bypassing required checks, CODEOWNERS, or branch protections.

This ADR **partially supersedes ADR-020** as to the active provider for
scheduled routine updates, ordinary PR-limit rules, and the prior instruction
to retain routine PRs until replacements have run. ADR-020's security,
major upgrade review, and supply-chain guarantees remain authoritative.

## Context and Constraints

The maintainer operates a centralized Jenkins-run Renovate service for
`wesley-dean/*` with dependency scanning, policy, and signed commits.
Parallel scheduled Dependabot update PRs duplicate work and review.

This repository's protected contracts include signing authority, lease-protected Git rewrites, signer identity, Jenkins integration, and released Bash tooling. Runtime interfaces,
security boundaries, artifact formats, verified download digests, release
permissions, and adopted shared coding standards SHALL NOT change as part
of this maintenance provider migration.

## Assumptions

- Jenkins already discovers the repository and requires explicit root
  enrollment rather than another repository-local workflow.
- The maintainer grants the Renovate account repository access when
  approving the PR.
- Native auto-merge remains subject to required human code-owner review
  and CI protections.
- GitHub alert and Dependabot security-update settings remain separately
  configured; YAML does not itself verify effective security coverage.
- Merging configuration is not proof that Renovate has executed.

## Alternatives Considered

1. Keep scheduled Dependabot routine updates: rejected because it duplicates
   the centrally administered runner.
2. Delete Dependabot YAML: rejected to retain security-update context and
   documented historical ecosystem settings.
3. Run a separate Renovate Action per repository: rejected due to duplicate
   credentials, signing, scheduling, and operations.
4. Extend Dependabot non-major auto-merge to Renovate: rejected to preserve
   bot-identity and human approval boundaries.
5. Convert verified immutable SHAs to mutable tags: rejected because it
   weakens provenance without an update benefit.

## Migration, Tradeoffs, and Threats

Add the root enrollment, disable ordinary Dependabot version PR generation,
and normalize existing GitHub Actions version annotations only when
tag-to-SHA mappings are verified against upstream Git refs. If an existing
SHA cannot be verified against a release, the migration MAY replace that
SHA and obsolete `# pin@` comment with a valid `@version` reference.
Such a moving ref weakens supply-chain immutability until Renovate
proposes a reviewed, verified SHA-pinned update and must be documented
as an exception. Do not emit an invalid `uses:` reference.

Once the migration PR exists, conclusively routine bot-authored Dependabot
PRs may be closed with explanatory migration links. Independent security,
ambiguous, and human-modified changes remain open. No promise is made
that the next Jenkins run will produce or successfully test replacements.

Centralized update authority creates a credential concentration risk.
Continue least-privilege, signed changes, immutable pins where verified,
required CI, code-owner approval, and targeted scrutiny of privileged
signing, credential, publication, and release actions.

## Related Decisions

ADR-020 governs the preceding grouped Dependabot policy and continues
to constrain security and review. All other accepted decisions governing
signing authority, lease-protected Git rewrites, signer identity, Jenkins integration, and released Bash tooling remain applicable.
