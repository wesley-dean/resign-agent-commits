# ADR-019: Report Unsigned Agent-Identified Merge Tips as Signing-Blocked

Date: 2026-11-09

## Status

Accepted

## Intent and Documentation Posture

This decision refines the observable outcome and process exit status of the
existing commit-signing workflow.  It does not expand the commits the tool may
rewrite or authorize using the signing key against a merge commit.  ADR-018
remains authoritative for the single-parent signing boundary, remote race
checks, and restricted force-with-lease operation.

## Context

RAC signs a contiguous branch-tip suffix of agent-identified, single-parent
commits.  Its predecessor behavior reported every branch tip without such a
suffix as `HUMAN_BOUNDARY` and counted it as a successful skip.  That report
could be misleading when the tip was an unsigned merge commit created with the
configured agent author and committer emails.

The incident on `wesley-dean/mktext` PR #29 demonstrated the operational
consequence.  An unsigned, two-parent merge tip was emitted as
`HUMAN_BOUNDARY ... (tip is not agent-owned)`.  A downstream protected-branch
workflow required signed commits, but RAC returned no actionable incomplete
signing status.  An operator used a manual policy override to merge.  This
record addresses the misleading tool outcome; it does not endorse that override
or assert that merge-commit signing should be automatically supported.

Task #12 first distinguishes merge-topology and human-ownership boundaries.
This decision governs task #13's further handling of unsigned merge tips.

## Constraints and Assumptions

- `ADR-018` prohibits rewriting human-owned history and multi-parent commits.
- Git author and committer emails are asserted metadata and can be spoofed.
  An email match is an identification heuristic, not authentication.
- `git verify-commit` provides signature verification under the configured
  Git trust state; the presence of a `gpgsig` header is not proof of validity.
- The signer may process many branches and repositories in one run.
- The command is used by unattended CI or Jenkins, where exit status must
  communicate inability to fulfill the selected signing operation.
- A successful branch classification cannot prove every reachable ancestor
  is signed, because RAC deliberately limits its review to an eligible suffix.
- Existing reporting distinguishes invalid signatures, remote races, and safe
  no-ops; those results retain separate meanings.

## Decision Drivers

- Make incomplete signing visible to operators and CI.
- Preserve the narrowly authorized rewrite boundary.
- Avoid treating an unsigned agent-identified merge tip as a harmless skip.
- Differentiate structural merge topology from asserted ownership.
- Retain safe skips for tips that are not identified as agent-owned.
- Preserve valid signature verification and negative security guarantees.
- Keep changes contained to status classification, aggregation, documentation,
  and tests without introducing a new signing mode or credential exposure.

## Decision

### Classify Merge Tips by Topology First

A branch tip with more than one parent is a merge boundary.  RAC SHALL NOT
rewrite it or traverse across it for signing under this decision.  The status
`MERGE_BOUNDARY` reports multi-parent topology rather than making a claim
about who created the commit.  `HUMAN_BOUNDARY` remains the classification for
a distinct, ineligible single-parent tip.

An unexpected zero-parent tip in a unique-history evaluation SHALL be reported
as an unexpected or rejected history case rather than called a merge.

### Treat Unsigned Agent-Identified Merge Tips as Blocking

If the current tip is a multi-parent commit whose author email and committer
email both match the configured agent identity, and the tip contains no
signature, RAC SHALL report `SIGNING_BLOCKED`.  The output SHALL explain
that the unsigned merge cannot be rewritten under the current policy and
that manual or linear-history remediation is required.

This classification SHALL increment the failed-branch count and a separately
reported signing-blocked count.  A run containing at least one such branch SHALL
exit nonzero even if all other repositories and branches are successful or
safely skipped.

The failure communicates incomplete tool work, not proof that the purported
author was actually the agent.  A matching email MUST NOT change rewrite
eligibility or cause the merge to be signed.

### Preserve Conservative Behavior for Other Merge Tips

If a merge tip is not identified by both configured email fields, RAC SHALL
continue to treat it as an unmodified merge boundary and safe skip.  The tool
does not claim to have audited or signed the inaccessible history.

If an agent-identified merge tip has a signature, RAC SHALL validate that
signature using its existing verifier.  Invalid signatures SHALL result in a
policy rejection; valid signatures MAY retain `MERGE_BOUNDARY` with explicit
wording that ancestor history was not audited.  A signed tip does not guarantee
that all ancestors are signed.

### Preserve Other Outcomes and Signing Boundaries

Existing `SIGNED`, `ALREADY_SIGNED`, `HUMAN_BOUNDARY`,
`RACE_SKIPPED`, and `POLICY_REJECTED` meanings remain independent of
`SIGNING_BLOCKED`.  No existing signature failure may be silently replaced.
Dry-run remains nonmutating but MUST report policy-blocked work truthfully.

The signer SHALL retain exact remote-tip race checks, lease-bound pushes,
credential isolation, and the prohibition against rewriting merge or human
history.  A manually supplied policy override is not part of RAC's interface.

## Alternatives Considered

### Continue to Report All Merge Tips as Safe Skips

Rejected.  A benign return status masks a signing task that cannot be finished
under a signed-commit requirement and incentivizes troubleshooting or policy
overrides outside the tool.

### Fail for Every Merge Tip

Rejected.  Merges owned by other actors are outside the signer's authorized
scope, and treating them as failures would conflate harmless boundaries with
eligible work that RAC cannot finish.

### Authenticate Commit Ownership from Email Metadata

Rejected as technically unsupported.  Git metadata can be authored freely.
The configured email is used only to decide when an otherwise ignored unsigned
merge warrants attention; no additional signing authority follows.

### Rewrite or Sign Agent-Identified Merge Commits

Deferred to a separate explicit architectural change.  Preserving all parents,
trees, reachable signed history, and trust boundaries requires a different
rewriting algorithm and far more comprehensive testing.  This decision does not
supersede ADR-018's multi-parent prohibition.

### Add a Flag to Ignore Signing-Blocked Cases

Not adopted.  An opt-out could silently recreate the misleading CI success
that caused this defect.  Operators can decide on remediation outside RAC
rather than asking the tool to misrepresent completion.

## Security and Failure Model

The direct risk is an unsigned merge tip passing through RAC as a successful
no-op even when downstream branch rules require signatures.  The revised
classification improves the signal for that failure mode.  It does not prove
upstream authorship, commit integrity, global signature completeness, or the
effectiveness of GitHub branch protection.

An attacker can spoof agent email metadata to force a signing-blocked
classification, causing denial of service to an unattended signing job.
This is preferable to granting signing authority over an unverifiable merge.
A malicious or malformed signature remains separately policy-rejected.
Concurrent remote changes remain protected by the existing remote-tip
recheck and exact force-with-lease mechanism.

Status messages SHALL avoid credentials, private-key contents, token-bearing
URLs, and other secrets.  Automated consumers should distinguish a nonzero
completion status from verification of repository-wide signed-commit policy.

## Compatibility and Migration

This changes documented exit semantics for a specific branch state.  Jenkins
or CI pipelines that previously treated an unsigned agent-identified merge tip
as a successful skip will now receive a nonzero final status.  This is an
intentional, fail-closed compatibility change.

The command names, arguments, branch patterns, artifact filenames, and
signing-key handling remain unchanged.  There is no data migration, feature
flag, or new runtime dependency.  Operators may resolve a blocked branch by
preparing an eligible linear branch tip or through a separately authorized
manual process, without weakening RAC's history policy.

## Verification and Expected Outcomes

Tests SHALL cover at least:

- an unsigned agent-identified merge tip with a nonzero aggregate completion
  result and no rewrite or push;
- a differently owned merge tip that remains an unmodified safe skip;
- a single-parent human-owned boundary distinct from a merge boundary;
- a mixed branch batch that fails when one branch is signing-blocked;
- a healthy batch with successful aggregate completion;
- continued nonmutation in dry-run; and
- source and generated artifact flavors under the established Bats matrix.

The resulting behavior should make signing failures actionable without
introducing new repository-history mutations.

## Consequences

Operators receive a clearer explanation and a failing CI exit status where
RAC cannot complete an otherwise expected signing task.  A branch with an
agent-identified unsigned merge tip must be handled rather than silently
accepted.  Failure reporting may increase, especially where agents regularly
merge `main` into feature branches; that is a deliberate signal for users to
prefer linear branch maintenance or an explicitly reviewed future capability.

## Relationships to Prior Decisions

- **ADR-018** retains authority over which commits may be rewritten and how
  signing and lease-bound pushes work.  ADR-019 refines only status and
  completion behavior for blocked merge tips.
- **ADR-009** requires observable Bats coverage across published artifacts.
- **ADR-016** requires review of changes to security-sensitive failure and
  reporting boundaries.
