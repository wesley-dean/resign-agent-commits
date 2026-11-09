#!/usr/bin/env bats

load test_helper.bash

setup() {
  setup_artifact
  VERBOSE=false
}

make_merge_fixture() {
  local root="$1"
  local branch="$2"
  local tip_email="$3"

  mkdir -p "$root"
  make_temp_repo "$root" repo
  (
    cd "$root/work"
    git checkout --quiet -b "$branch"
    git commit --quiet --allow-empty -m branch-work
    git checkout --quiet main
    git commit --quiet --allow-empty -m main-update
    git push --quiet origin main
    git checkout --quiet "$branch"
    git config user.email "$tip_email"
    git -c commit.gpgsign=false merge --quiet --no-ff main -m merge-main
    git push --quiet origin "$branch"
  )
}

forge_invalid_signed_commit() {
  local commit="$1"

  git cat-file commit "$commit" |
    sed '/^committer /a\gpgsig -----BEGIN SSH SIGNATURE-----\
 invalid-signature\
 -----END SSH SIGNATURE-----' |
    git hash-object --literally -t commit -w --stdin
}

set_boundary_counters() {
  AGENT_EMAIL=agent@example.test
  DRY_RUN=true
  SIGNED_BRANCHES=0
  SKIPPED_BRANCHES=0
  HUMAN_BOUNDARY_BRANCHES=0
  MERGE_BOUNDARY_BRANCHES=0
  SIGNING_BLOCKED_BRANCHES=0
  FAILED_BRANCHES=0
  FAILED_REPOSITORIES=0
  POLICY_REJECTED_BRANCHES=0
}

@test "unsigned agent-identified merge tip blocks signing without rewriting history" {
  require_function signing_result_status
  root="$BATS_TEST_TMPDIR/agent-merge"
  make_merge_fixture "$root" agent/merge-tip agent@example.test
  (
    cd "$root/work"
    set_boundary_counters
    expected_head="$(git rev-parse HEAD)"
    process_branch example/repo main agent/merge-tip "$expected_head"
    [ "$SIGNING_BLOCKED_BRANCHES" -eq 1 ]
    [ "$FAILED_BRANCHES" -eq 1 ]
    [ "$MERGE_BOUNDARY_BRANCHES" -eq 0 ]
    [ "$SKIPPED_BRANCHES" -eq 0 ]
    ! signing_result_status
    [ "$(git ls-remote origin refs/heads/agent/merge-tip | cut -f1)" = "$expected_head" ]
    [ "$(git rev-parse HEAD)" = "$expected_head" ]
  ) >"$root/stdout" 2>"$root/stderr"

  grep -Fq 'SIGNING_BLOCKED' "$root/stdout"
  grep -Fq 'unsigned merge tip' "$root/stdout"
  ! grep -Fq 'HUMAN_BOUNDARY' "$root/stdout"
  ! grep -Fq 'SIGNED ' "$root/stdout"
}

@test "non-agent merge tip is a safe boundary and does not fail the batch" {
  require_function signing_result_status
  root="$BATS_TEST_TMPDIR/human-merge"
  make_merge_fixture "$root" agent/human-merge human@example.test
  (
    cd "$root/work"
    set_boundary_counters
    expected_head="$(git rev-parse HEAD)"
    process_branch example/repo main agent/human-merge "$expected_head"
    [ "$MERGE_BOUNDARY_BRANCHES" -eq 1 ]
    [ "$SIGNING_BLOCKED_BRANCHES" -eq 0 ]
    [ "$FAILED_BRANCHES" -eq 0 ]
    [ "$SKIPPED_BRANCHES" -eq 1 ]
    signing_result_status
    [ "$(git ls-remote origin refs/heads/agent/human-merge | cut -f1)" = "$expected_head" ]
  ) >"$root/stdout" 2>"$root/stderr"

  grep -Fq 'MERGE_BOUNDARY' "$root/stdout"
  ! grep -Fq 'SIGNING_BLOCKED' "$root/stdout"
}

@test "one signing-blocked branch makes a mixed branch batch unsuccessful" {
  require_function signing_result_status
  root="$BATS_TEST_TMPDIR/mixed"
  make_merge_fixture "$root" agent/merge-tip agent@example.test
  (
    cd "$root/work"
    git checkout --quiet main
    git checkout --quiet -b agent/human-tip
    git config user.email human@example.test
    git commit --quiet --allow-empty -m human-update
    git push --quiet origin agent/human-tip
    set_boundary_counters

    agent_head="$(git rev-parse refs/heads/agent/merge-tip)"
    human_head="$(git rev-parse refs/heads/agent/human-tip)"
    process_branch example/repo main agent/merge-tip "$agent_head"
    process_branch example/repo main agent/human-tip "$human_head"

    [ "$SIGNING_BLOCKED_BRANCHES" -eq 1 ]
    [ "$HUMAN_BOUNDARY_BRANCHES" -eq 1 ]
    [ "$SKIPPED_BRANCHES" -eq 1 ]
    [ "$FAILED_BRANCHES" -eq 1 ]
    ! signing_result_status
    [ "$(git ls-remote origin refs/heads/agent/merge-tip | cut -f1)" = "$agent_head" ]
    [ "$(git ls-remote origin refs/heads/agent/human-tip | cut -f1)" = "$human_head" ]
  ) >"$root/stdout" 2>"$root/stderr"

  grep -Fq 'SIGNING_BLOCKED' "$root/stdout"
  grep -Fq 'HUMAN_BOUNDARY' "$root/stdout"
}

@test "a batch with no signing failures returns successful completion status" {
  require_function signing_result_status
  FAILED_BRANCHES=0
  FAILED_REPOSITORIES=0
  run signing_result_status
  [ "$status" -eq 0 ]

  FAILED_BRANCHES=1
  run signing_result_status
  [ "$status" -eq 1 ]

  FAILED_BRANCHES=0
  FAILED_REPOSITORIES=1
  run signing_result_status
  [ "$status" -eq 1 ]
}

@test "invalid signature on agent-identified merge tip remains a policy failure" {
  require_function process_branch
  root="$BATS_TEST_TMPDIR/invalid-merge"
  make_merge_fixture "$root" agent/merge-tip agent@example.test
  (
    cd "$root/work"
    set_boundary_counters
    original="$(git rev-parse HEAD)"
    invalid_head="$(forge_invalid_signed_commit "$original")"
    git update-ref refs/heads/agent/invalid-merge "$invalid_head"
    git push --quiet origin agent/invalid-merge
    process_branch example/repo main agent/invalid-merge "$invalid_head"
    [ "$SIGNING_BLOCKED_BRANCHES" -eq 0 ]
    [ "$MERGE_BOUNDARY_BRANCHES" -eq 0 ]
    [ "$POLICY_REJECTED_BRANCHES" -eq 1 ]
    [ "$FAILED_BRANCHES" -eq 1 ]
    ! signing_result_status
    [ "$(git ls-remote origin refs/heads/agent/invalid-merge | cut -f1)" = "$invalid_head" ]
  ) >"$root/stdout" 2>"$root/stderr"

  grep -Fq 'POLICY_REJECTED' "$root/stdout"
  ! grep -Fq 'SIGNING_BLOCKED' "$root/stdout"
}

@test "invalid signature on an eligible linear agent tip remains rejected" {
  require_function process_branch
  root="$BATS_TEST_TMPDIR/invalid-linear"
  mkdir -p "$root"
  make_temp_repo "$root" repo
  (
    cd "$root/work"
    git checkout --quiet -b agent/invalid-linear
    git commit --quiet --allow-empty -m agent-work
    original="$(git rev-parse HEAD)"
    invalid_head="$(forge_invalid_signed_commit "$original")"
    git update-ref refs/heads/agent/invalid-linear "$invalid_head"
    git push --quiet origin agent/invalid-linear
    set_boundary_counters

    process_branch example/repo main agent/invalid-linear "$invalid_head"
    [ "$POLICY_REJECTED_BRANCHES" -eq 1 ]
    [ "$SIGNING_BLOCKED_BRANCHES" -eq 0 ]
    [ "$FAILED_BRANCHES" -eq 1 ]
    ! signing_result_status
    [ "$(git ls-remote origin refs/heads/agent/invalid-linear | cut -f1)" = "$invalid_head" ]
  ) >"$root/stdout" 2>"$root/stderr"

  grep -Fq 'POLICY_REJECTED' "$root/stdout"
  ! grep -Fq 'SIGNING_BLOCKED' "$root/stdout"
}
