# ADR-020: Consolidate GitHub Actions Dependabot Version Updates

Date: 2026-11-12

## Status

Accepted

## Context

The existing weekly GitHub Actions Dependabot schedule has a seven-day
cooldown but groups only minor/patch routine updates. Major upgrades can
therefore generate separate PRs and repeated review effort. The verified
`coding_standards@v3.2.0` release recommends grouping eligible major,
minor, and patch version updates per ecosystem while preserving independent
security updates, major scrutiny, and existing review protections.

RAC controls Git repository discovery, SSH signature verification, and
potential history rewriting with exact remote-tip checks and
`--force-with-lease`. It may execute in CI/Jenkins with signing credentials.
Changes to privileged GitHub Actions, dependency acquisition, build tests,
and release publication deserve heightened scrutiny even when runtime
source is untouched.

## Decision Drivers

- Reduce routine dependency PR fragmentation while preserving visibility.
- Continue timely security-update handling independently of scheduling.
- Retain the existing seven-day release cooldown.
- Keep meaningful review gates for breaking major Action updates.
- Avoid any change to signing authority, history-rewrite behavior, runtime
  dependencies, published artifacts, or existing release authority.

## Decision

Keep the weekly GitHub Actions version-update schedule, seven-day
cooldown, root directory, and commit-message convention. Replace
`minor-and-patch` with `actions-version-updates`, explicitly setting
`applies-to: version-updates` and `patterns: ["*"]` without
`update-types`. All eligible routine major/minor/patch versions may
be included in the same ecosystem group.

Dependabot security updates remain separate and must not wait for the
routine weekly cycle or its cooldown. Preserve the current
`dependabot/fetch-metadata` non-major-only auto-merge condition.
Any group containing a major version must receive explicit manual
review, including affected trust boundaries and release/testing evidence.
Leave previously opened Dependabot PRs intact until actually superseded
with sufficient evidence.

## Operational Constraints

- GitHub Actions remains the only configured Dependabot ecosystem.
- No additional token scopes, workflow permissions, signing-key
  capabilities, branch push authority, or release publication authority
  are granted by this maintenance change.
- ADR-018's rewrite boundaries, exact remote-tip race checks, and
  force-with-lease semantics remain authoritative.
- ADR-019's `SIGNING_BLOCKED` behavior for unsigned agent-identified
  merge tips remains authoritative and unchanged.
- Per-artifact testing and checksums remain governed by ADR-006,
  ADR-009, ADR-011, and ADR-012.
- Security update settings, GitHub rulesets, required checks, and
  CODEOWNERS enforcement must be verified independently; YAML alone
  does not establish effective protection.
- A version bump of a write-capable Action requires review of the
  release notes, migration behavior, permissions, and code paths.
- No optional `test-gate` or ruleset example is automatically installed.

## Alternatives Considered

1. Continue minor/patch-only grouping. Rejected as the default because
   major upgrades remain separate without necessarily receiving more
   meaningful review than a flagged group.
2. Broadly group eligible routine major/minor/patch versions. Chosen
   with mandatory manual review of any major-containing group.
3. Use monthly maintenance or longer cooldown. Rejected without evidence
   that slower routine dependency visibility is appropriate.
4. Enable auto-merge for major-containing groups. Rejected because
   breaking changes to privileged Actions may affect signing, history
   integrity, test evidence, or release authority.
5. Close existing Dependabot PRs immediately. Rejected because
   configuration alone does not demonstrate replacement coverage.

## Consequences and Tradeoffs

Eligible routine version updates may produce fewer GitHub PRs; no exact
one-PR-per-week outcome is promised. A grouped failure can obscure
which dependency caused it. Sensitive or incompatible Actions may need
narrow, separately documented grouping exceptions rather than ignored
updates.

Every grouped PR requires review of every changed Action, its authority,
migration notes, and the actual CI/release verification paths exercised.
The highest-risk component governs review depth. Do not infer overall
signing or release safety from a green linter. Existing open Dependabot
PR #10 remains open until independently covered and tested.

## Expected Outcomes and Verification

Observe the next scheduled Dependabot update, actual group contents,
major-version auto-merge exclusion, tests, security alert settings,
effective branch protection, and CODEOWNERS review requirements.
Measure PR volume and review effort over successive updates rather
than assume improvement. No runtime or release-facing migration is
needed because this changes only dependency maintenance policy.

## Related Decisions

ADR-018 governs discovery and safe signing/rewrite boundaries; ADR-019
governs blocked merge-tip reporting. ADR-005/015/016 govern supply-chain
security and threat modeling; ADR-006/009/011/012 govern release
artifact integrity. This decision supplements but does not supersede
those constraints.
