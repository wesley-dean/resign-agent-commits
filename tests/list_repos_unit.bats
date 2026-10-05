#!/usr/bin/env bats

load test_helper.bash

setup() {
  setup_artifact
}

@test "list_repos defines usage" {
  require_function usage
  run declare -F usage
  [ "$status" -eq 0 ]
}

@test "list_repos defines log_debug" {
  require_function log_debug
  run declare -F log_debug
  [ "$status" -eq 0 ]
}

@test "list_repos defines warn" {
  require_function warn
  run declare -F warn
  [ "$status" -eq 0 ]
}

@test "list_repos defines error" {
  require_function error
  run declare -F error
  [ "$status" -eq 0 ]
}

@test "list_repos defines die" {
  require_function die
  run declare -F die
  [ "$status" -eq 0 ]
}

@test "list_repos defines trim" {
  require_function trim
  run declare -F trim
  [ "$status" -eq 0 ]
}

@test "list_repos defines strip_env_quotes" {
  require_function strip_env_quotes
  run declare -F strip_env_quotes
  [ "$status" -eq 0 ]
}

@test "list_repos defines valid_owner" {
  require_function valid_owner
  run declare -F valid_owner
  [ "$status" -eq 0 ]
}

@test "list_repos defines valid_git_host" {
  require_function valid_git_host
  run declare -F valid_git_host
  [ "$status" -eq 0 ]
}

@test "list_repos defines is_true_or_false" {
  require_function is_true_or_false
  run declare -F is_true_or_false
  [ "$status" -eq 0 ]
}

@test "list_repos defines capture_process_environment" {
  require_function capture_process_environment
  run declare -F capture_process_environment
  [ "$status" -eq 0 ]
}

@test "list_repos defines set_defaults" {
  require_function set_defaults
  run declare -F set_defaults
  [ "$status" -eq 0 ]
}

@test "list_repos defines find_env_file_argument" {
  require_function find_env_file_argument
  run declare -F find_env_file_argument
  [ "$status" -eq 0 ]
}

@test "list_repos defines load_env_file" {
  require_function load_env_file
  run declare -F load_env_file
  [ "$status" -eq 0 ]
}

@test "list_repos defines apply_process_environment" {
  require_function apply_process_environment
  run declare -F apply_process_environment
  [ "$status" -eq 0 ]
}

@test "list_repos defines parse_options" {
  require_function parse_options
  run declare -F parse_options
  [ "$status" -eq 0 ]
}

@test "list_repos defines prepare_branch_patterns" {
  require_function prepare_branch_patterns
  run declare -F prepare_branch_patterns
  [ "$status" -eq 0 ]
}

@test "list_repos defines branch_ref_arguments" {
  require_function branch_ref_arguments
  run declare -F branch_ref_arguments
  [ "$status" -eq 0 ]
}

@test "list_repos defines validate_configuration" {
  require_function validate_configuration
  run declare -F validate_configuration
  [ "$status" -eq 0 ]
}

@test "list_repos defines remote_for_repository" {
  require_function remote_for_repository
  run declare -F remote_for_repository
  [ "$status" -eq 0 ]
}

@test "list_repos defines repository_has_matching_branch" {
  require_function repository_has_matching_branch
  run declare -F repository_has_matching_branch
  [ "$status" -eq 0 ]
}

@test "list_repos defines create_git_askpass" {
  require_function create_git_askpass
  run declare -F create_git_askpass
  [ "$status" -eq 0 ]
}

@test "list_repos defines list_repositories" {
  require_function list_repositories
  run declare -F list_repositories
  [ "$status" -eq 0 ]
}

@test "list_repos defines main" {
  require_function main
  run declare -F main
  [ "$status" -eq 0 ]
}

@test "trim removes surrounding whitespace" {
  require_function trim
  run trim "  value  "
  [ "$status" -eq 0 ]
  [ "$output" = "value" ]
}

@test "strip_env_quotes removes matching outer quotes only" {
  require_function strip_env_quotes
  run strip_env_quotes '"value"'
  [ "$status" -eq 0 ]
  [ "$output" = "value" ]
  run strip_env_quotes "'value'"
  [ "$output" = "value" ]
  run strip_env_quotes '"value'
  [ "$output" = '"value' ]
}

@test "owner and host validation reject unsafe syntax" {
  require_function valid_owner
  valid_owner wesley-dean
  ! valid_owner '../owner'
  valid_git_host github.com
  ! valid_git_host 'github.com/path'
}

@test "boolean validation is exact" {
  require_function is_true_or_false
  is_true_or_false true
  is_true_or_false false
  ! is_true_or_false TRUE
  ! is_true_or_false 1
}

@test "default branch patterns include agent ai and codex" {
  require_function set_defaults
  set_defaults
  prepare_branch_patterns
  [ "${BRANCH_PATTERN_LIST[*]}" = "agent/* ai/* codex/*" ]
}

@test "plural branch patterns override legacy single pattern" {
  require_function prepare_branch_patterns
  BRANCH_PATTERNS='ai/*,codex/*'
  BRANCH_PATTERN='agent/*'
  prepare_branch_patterns
  [ "${BRANCH_PATTERN_LIST[*]}" = "ai/* codex/*" ]
}

@test "legacy branch pattern remains supported" {
  require_function prepare_branch_patterns
  BRANCH_PATTERNS=''
  BRANCH_PATTERN='agent/*'
  prepare_branch_patterns
  [ "${BRANCH_PATTERN_LIST[*]}" = "agent/*" ]
}

@test "branch pattern expansion writes refs heads globs" {
  require_function branch_ref_arguments
  BRANCH_PATTERN_LIST=('agent/*' 'ai/*')
  run branch_ref_arguments
  [ "$status" -eq 0 ]
  [ "$output" = $'refs/heads/agent/*\nrefs/heads/ai/*' ]
}

@test "remote_for_repository renders https and ssh transports" {
  require_function remote_for_repository
  GIT_HOST=github.com
  GIT_TRANSPORT=https
  run remote_for_repository wesley-dean/example
  [ "$output" = "https://github.com/wesley-dean/example.git" ]
  GIT_TRANSPORT=ssh
  GIT_USER=git
  run remote_for_repository wesley-dean/example
  [ "$output" = "git@github.com:wesley-dean/example.git" ]
}

@test "environment file supports export and quoted values" {
  require_function load_env_file
  file="$BATS_TEST_TMPDIR/settings.env"
  cat >"$file" <<'ENV'
export OWNER="wesley-dean"
BRANCH_PATTERNS='ai/*,codex/*'
VERBOSE=true
ENV
  OWNER=''
  BRANCH_PATTERNS=''
  VERBOSE=false
  load_env_file "$file"
  [ "$OWNER" = "wesley-dean" ]
  [ "$BRANCH_PATTERNS" = "ai/*,codex/*" ]
  [ "$VERBOSE" = true ]
}

@test "askpass helper has private executable permissions" {
  require_function create_git_askpass
  GIT_ASKPASS="$BATS_TEST_TMPDIR/askpass"
  create_git_askpass
  [ -x "$GIT_ASKPASS" ]
  mode="$(stat -c '%a' "$GIT_ASKPASS")"
  [ "$mode" = 700 ]
}

@test "repository matching finds configured local remote branch" {
  require_function repository_has_matching_branch
  root="$BATS_TEST_TMPDIR/git"
  mkdir -p "$root"
  make_temp_repo "$root" repo
  (
    cd "$root/work"
    git checkout --quiet -b ai/test
    printf '%s\n' change >>README.md
    git commit --quiet -am change
    git push --quiet origin ai/test
  )
  remote_for_repository() { printf '%s\n' "$root/repo.git"; }
  BRANCH_PATTERN_LIST=('agent/*' 'ai/*' 'codex/*')
  repository_has_matching_branch owner/repo
}

@test "repository matching returns false when no configured branch exists" {
  require_function repository_has_matching_branch
  root="$BATS_TEST_TMPDIR/git"
  mkdir -p "$root"
  make_temp_repo "$root" repo
  remote_for_repository() { printf '%s\n' "$root/repo.git"; }
  BRANCH_PATTERN_LIST=('agent/*' 'ai/*' 'codex/*')
  ! repository_has_matching_branch owner/repo
}
