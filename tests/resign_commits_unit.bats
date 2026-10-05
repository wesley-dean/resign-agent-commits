#!/usr/bin/env bats

load test_helper.bash

setup() {
  setup_artifact
  VERBOSE=false
}

@test "resign_commits defines usage" {
  require_function usage
  run declare -F usage
  [ "$status" -eq 0 ]
}

@test "resign_commits defines log" {
  require_function log
  run declare -F log
  [ "$status" -eq 0 ]
}

@test "resign_commits defines debug" {
  require_function debug
  run declare -F debug
  [ "$status" -eq 0 ]
}

@test "resign_commits defines warn" {
  require_function warn
  run declare -F warn
  [ "$status" -eq 0 ]
}

@test "resign_commits defines error" {
  require_function error
  run declare -F error
  [ "$status" -eq 0 ]
}

@test "resign_commits defines die" {
  require_function die
  run declare -F die
  [ "$status" -eq 0 ]
}

@test "resign_commits defines trim" {
  require_function trim
  run declare -F trim
  [ "$status" -eq 0 ]
}

@test "resign_commits defines strip_env_quotes" {
  require_function strip_env_quotes
  run declare -F strip_env_quotes
  [ "$status" -eq 0 ]
}

@test "resign_commits defines valid_owner" {
  require_function valid_owner
  run declare -F valid_owner
  [ "$status" -eq 0 ]
}

@test "resign_commits defines valid_repository_name" {
  require_function valid_repository_name
  run declare -F valid_repository_name
  [ "$status" -eq 0 ]
}

@test "resign_commits defines valid_git_host" {
  require_function valid_git_host
  run declare -F valid_git_host
  [ "$status" -eq 0 ]
}

@test "resign_commits defines report_result" {
  require_function report_result
  run declare -F report_result
  [ "$status" -eq 0 ]
}

@test "resign_commits defines is_true_or_false" {
  require_function is_true_or_false
  run declare -F is_true_or_false
  [ "$status" -eq 0 ]
}

@test "resign_commits defines load_env_file" {
  require_function load_env_file
  run declare -F load_env_file
  [ "$status" -eq 0 ]
}

@test "resign_commits defines capture_process_environment" {
  require_function capture_process_environment
  run declare -F capture_process_environment
  [ "$status" -eq 0 ]
}

@test "resign_commits defines apply_process_environment" {
  require_function apply_process_environment
  run declare -F apply_process_environment
  [ "$status" -eq 0 ]
}

@test "resign_commits defines find_env_file_argument" {
  require_function find_env_file_argument
  run declare -F find_env_file_argument
  [ "$status" -eq 0 ]
}

@test "resign_commits defines parse_options" {
  require_function parse_options
  run declare -F parse_options
  [ "$status" -eq 0 ]
}

@test "resign_commits defines prepare_branch_patterns" {
  require_function prepare_branch_patterns
  run declare -F prepare_branch_patterns
  [ "$status" -eq 0 ]
}

@test "resign_commits defines branch_ref_arguments" {
  require_function branch_ref_arguments
  run declare -F branch_ref_arguments
  [ "$status" -eq 0 ]
}

@test "resign_commits defines validate_configuration" {
  require_function validate_configuration
  run declare -F validate_configuration
  [ "$status" -eq 0 ]
}

@test "resign_commits defines read_repositories_from_stdin" {
  require_function read_repositories_from_stdin
  run declare -F read_repositories_from_stdin
  [ "$status" -eq 0 ]
}

@test "resign_commits defines normalize_repository" {
  require_function normalize_repository
  run declare -F normalize_repository
  [ "$status" -eq 0 ]
}

@test "resign_commits defines prepare_repositories" {
  require_function prepare_repositories
  run declare -F prepare_repositories
  [ "$status" -eq 0 ]
}

@test "resign_commits defines default_branch_for" {
  require_function default_branch_for
  run declare -F default_branch_for
  [ "$status" -eq 0 ]
}

@test "resign_commits defines commit_has_signature" {
  require_function commit_has_signature
  run declare -F commit_has_signature
  [ "$status" -eq 0 ]
}

@test "resign_commits defines verify_commit" {
  require_function verify_commit
  run declare -F verify_commit
  [ "$status" -eq 0 ]
}

@test "resign_commits defines find_agent_suffix_base" {
  require_function find_agent_suffix_base
  run declare -F find_agent_suffix_base
  [ "$status" -eq 0 ]
}

@test "resign_commits defines suffix_needs_signing" {
  require_function suffix_needs_signing
  run declare -F suffix_needs_signing
  [ "$status" -eq 0 ]
}

@test "resign_commits defines verify_rewritten_history" {
  require_function verify_rewritten_history
  run declare -F verify_rewritten_history
  [ "$status" -eq 0 ]
}

@test "resign_commits defines process_branch" {
  require_function process_branch
  run declare -F process_branch
  [ "$status" -eq 0 ]
}

@test "resign_commits defines process_repository" {
  require_function process_repository
  run declare -F process_repository
  [ "$status" -eq 0 ]
}

@test "resign_commits defines create_git_askpass" {
  require_function create_git_askpass
  run declare -F create_git_askpass
  [ "$status" -eq 0 ]
}

@test "resign_commits defines create_allowed_signers_file" {
  require_function create_allowed_signers_file
  run declare -F create_allowed_signers_file
  [ "$status" -eq 0 ]
}

@test "resign_commits defines main" {
  require_function main
  run declare -F main
  [ "$status" -eq 0 ]
}

@test "repository validation accepts safe names and rejects paths" {
  require_function valid_repository_name
  valid_repository_name example-repo
  valid_repository_name example.repo
  ! valid_repository_name '../repo'
  ! valid_repository_name 'owner/repo'
}

@test "normalize_repository qualifies names with OWNER" {
  require_function normalize_repository
  OWNER=wesley-dean
  run normalize_repository example
  [ "$status" -eq 0 ]
  [ "$output" = "wesley-dean/example" ]
}

@test "normalize_repository rejects a different configured owner" {
  require_function normalize_repository
  OWNER=wesley-dean
  run normalize_repository other/example
  [ "$status" -eq 1 ]
}

@test "prepare_repositories deduplicates normalized input" {
  require_function prepare_repositories
  OWNER=wesley-dean
  REPOSITORIES=(example wesley-dean/example)
  FAILED_REPOSITORIES=0
  prepare_repositories
  [ "${#REPOSITORIES[@]}" -eq 1 ]
  [ "${REPOSITORIES[0]}" = "wesley-dean/example" ]
}

@test "default branch resolution works against a local bare remote" {
  require_function default_branch_for
  root="$BATS_TEST_TMPDIR/git"
  mkdir -p "$root"
  make_temp_repo "$root" repo
  run default_branch_for "$root/repo.git"
  [ "$status" -eq 0 ]
  [ "$output" = main ]
}

@test "unsigned commit is detected as unsigned" {
  require_function commit_has_signature
  root="$BATS_TEST_TMPDIR/repo"
  git init --quiet "$root"
  (
    cd "$root"
    git config user.name Test
    git config user.email test@example.test
    printf '%s\n' x >x
    git add x
    git commit --quiet -m x
    ! commit_has_signature HEAD
  )
}

@test "agent suffix base stops before a human-owned tip" {
  require_function find_agent_suffix_base
  root="$BATS_TEST_TMPDIR/repo"
  git init --quiet "$root"
  (
    cd "$root"
    git config user.name Test
    git config user.email human@example.test
    printf '%s\n' base >f
    git add f
    git commit --quiet -m base
    base="$(git rev-parse HEAD)"
    git config user.email agent@example.test
    printf '%s\n' agent >>f
    git commit --quiet -am agent
    git config user.email human@example.test
    printf '%s\n' human >>f
    git commit --quiet -am human
    AGENT_EMAIL=agent@example.test
    run find_agent_suffix_base "$base" HEAD
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  )
}

@test "suffix_needs_signing reports an unsigned eligible commit" {
  require_function suffix_needs_signing
  root="$BATS_TEST_TMPDIR/repo"
  git init --quiet "$root"
  (
    cd "$root"
    git config user.name Test
    git config user.email agent@example.test
    printf '%s\n' base >f
    git add f
    git commit --quiet -m base
    base="$(git rev-parse HEAD)"
    printf '%s\n' next >>f
    git commit --quiet -am next
    suffix_needs_signing "$base" HEAD
  )
}

@test "allowed signers file uses provided public key" {
  require_function create_allowed_signers_file
  SIGNING_PUBLIC_KEY_PATH="$BATS_TEST_TMPDIR/key.pub"
  ALLOWED_SIGNERS_FILE="$BATS_TEST_TMPDIR/allowed"
  AGENT_EMAIL=agent@example.test
  printf '%s\n' 'ssh-ed25519 AAAATEST key' >"$SIGNING_PUBLIC_KEY_PATH"
  create_allowed_signers_file
  run cat "$ALLOWED_SIGNERS_FILE"
  [ "$status" -eq 0 ]
  [ "$output" = 'agent@example.test ssh-ed25519 AAAATEST key' ]
}

@test "askpass helper returns x-access-token username" {
  require_function create_git_askpass
  GIT_ASKPASS="$BATS_TEST_TMPDIR/askpass"
  create_git_askpass
  run "$GIT_ASKPASS" Username
  [ "$status" -eq 0 ]
  [ "$output" = x-access-token ]
}

@test "report_result includes status subject and detail" {
  require_function report_result
  run report_result SIGNED ai/example 'old -> new'
  [ "$status" -eq 0 ]
  [[ "$output" == *SIGNED* ]]
  [[ "$output" == *ai/example* ]]
  [[ "$output" == *'old -> new'* ]]
}
