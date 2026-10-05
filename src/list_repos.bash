#!/usr/bin/env bash
# shellcheck shell=bash
## @file src/list_repos.bash
## @brief Discovers repositories that contain branches eligible for the signing workflow.
## @details
## This maintained executable implements one half of the resign-agent-commits
## workflow.  It is designed for deterministic composition through ordinary
## text streams, explicit configuration precedence, narrow Git operations, and
## fail-closed validation around repository and signing boundaries.
##
## Generated release artifacts add build provenance without modifying maintained
## source.  Development dependencies are prepared through bashdeps and are not
## required by the generated commands at runtime.
## @author Wes Dean
## @see doc/resign-agent-commits-spec.md
## @see doc/threat-model.md
##
## @par Examples
## @code
## OWNER=wesley-dean ./src/list_repos.bash
## @endcode

set -Eeuo pipefail

umask 077

PROGRAM_NAME="${0##*/}"

DEFAULT_GIT_HOST="github.com"
DEFAULT_GIT_USER="git"
DEFAULT_GIT_TRANSPORT="https"
DEFAULT_BRANCH_PATTERNS="agent/*,ai/*,codex/*"
DEFAULT_REPO_LIMIT="1000"
DEFAULT_INCLUDE_ARCHIVED="false"
DEFAULT_INCLUDE_FORKS="false"
DEFAULT_VERBOSE="false"

## @fn usage()
## @brief Writes the command's complete usage and configuration contract.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Human-readable usage text.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Human-readable usage text.
##
## @retval 0 Usage text was written.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
usage() {
  cat <<USAGE
Usage:
  ${PROGRAM_NAME} [options]

List repositories for an owner, one OWNER/NAME value per line on STDOUT.
The output is suitable for piping directly to resign_commits.bash.

Configuration precedence:
  command-line arguments
  process environment
  environment file
  built-in defaults

Options:
  --env-file FILE
      Read configuration from FILE.  If omitted, .env is read when present.

  --owner OWNER
      Repository owner to enumerate.  Required.

  --git-host HOST
      GitHub host used by gh.  Default: ${DEFAULT_GIT_HOST}

  --git-user USER
      Git SSH user.  Accepted for configuration compatibility with
      resign_commits.bash.  Default: ${DEFAULT_GIT_USER}

  --git-transport TRANSPORT
      Git transport setting accepted for configuration compatibility with
      resign_commits.bash.  Values: https or ssh.  Default: ${DEFAULT_GIT_TRANSPORT}

  --branch-patterns PATTERNS
      Comma-separated branch patterns.  Accepted for configuration
      compatibility with resign_commits.bash.
      Default: ${DEFAULT_BRANCH_PATTERNS}

  --branch-pattern PATTERN
      Deprecated single-pattern alias retained for compatibility.

  --agent-name NAME
      Accepted for configuration compatibility with resign_commits.bash.

  --agent-email EMAIL
      Accepted for configuration compatibility with resign_commits.bash.

  --signing-key FILE
      Accepted for configuration compatibility with resign_commits.bash.

  --signing-public-key FILE
      Accepted for configuration compatibility with resign_commits.bash.

  --limit NUMBER
      Maximum number of repositories returned.  Default: ${DEFAULT_REPO_LIMIT}

  --include-archived
      Include archived repositories.  By default, archived repositories are
      excluded.

  --include-forks
      Include forked repositories.  By default, only source repositories are
      returned.

  --verbose
      Enable diagnostic output on STDERR.

  -h, --help
      Display this help.

Environment variables:
  ENV_FILE
  OWNER
  GIT_HOST
  GIT_USER
  GIT_TRANSPORT
  GH_TOKEN
  BRANCH_PATTERNS
  BRANCH_PATTERN
  AGENT_NAME
  AGENT_EMAIL
  SIGNING_KEY_PATH
  SIGNING_PUBLIC_KEY_PATH
  REPO_LIMIT
  INCLUDE_ARCHIVED
  INCLUDE_FORKS
  VERBOSE

Examples:
  OWNER=wesley-dean ${PROGRAM_NAME}

  ${PROGRAM_NAME} --owner wesley-dean | \
    ./resign_commits.bash \
      --owner wesley-dean \
      --agent-name wesley-dean-agent \
      --agent-email wesley-dean-agent@wesleydean.com \
      --signing-key /run/secrets/agent-signing-key

  ${PROGRAM_NAME} --env-file ./resign_commits.env | \
    ./resign_commits.bash --env-file ./resign_commits.env
USAGE
}

## @fn log_debug()
## @brief Emits a diagnostic only when verbose mode is enabled.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The diagnostic was emitted or verbose mode was disabled.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
log_debug() {
  if [[ "${VERBOSE}" == "true" ]]; then
    printf 'DEBUG: %s\n' "$*" >&2
  fi
}

## @fn warn()
## @brief Emits a warning diagnostic to standard error.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The diagnostic was written.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

## @fn error()
## @brief Emits an error diagnostic to standard error.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The diagnostic was written.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
error() {
  printf 'ERROR: %s\n' "$*" >&2
}

## @fn die()
## @brief Emits an error diagnostic and terminates the command with failure.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 1 The command terminates after reporting the error.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
die() {
  error "$*"
  exit 1
}

## @fn trim()
## @brief Removes leading and trailing shell whitespace without evaluating the value.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## The trimmed value followed by a newline.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns The trimmed value followed by a newline.
##
## @retval 0 The trimmed value was written.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  printf '%s\n' "${value}"
}

## @fn strip_env_quotes()
## @brief Removes one matching outer quote pair from a configuration value.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## The normalized value followed by a newline.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns The normalized value followed by a newline.
##
## @retval 0 The normalized value was written.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
strip_env_quotes() {
  local value="$1"
  local length

  length=${#value}
  if ((length >= 2)); then
    if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:length-2}"
    elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
      value="${value:1:length-2}"
    fi
  fi

  printf '%s\n' "${value}"
}

## @fn valid_owner()
## @brief Validates the restricted repository-owner grammar accepted by the tool.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The owner is valid.
## @retval 1 The owner is invalid.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
valid_owner() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]
}

## @fn valid_git_host()
## @brief Validates the restricted Git host grammar accepted by the tools.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The host is valid.
## @retval 1 The host is invalid.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
valid_git_host() {
  [[ "$1" =~ ^[A-Za-z0-9.-]+$ ]]
}

## @fn is_true_or_false()
## @brief Validates boolean configuration tokens.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The value is exactly true or false.
## @retval 1 The value is not accepted.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
is_true_or_false() {
  case "$1" in
    true | false)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

## @fn capture_process_environment()
## @brief Captures whether supported process-environment variables were explicitly set.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Process configuration was captured.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
capture_process_environment() {
  local name

  for name in \
    ENV_FILE OWNER GIT_HOST GIT_USER GIT_TRANSPORT GH_TOKEN BRANCH_PATTERNS BRANCH_PATTERN \
    AGENT_NAME AGENT_EMAIL SIGNING_KEY_PATH SIGNING_PUBLIC_KEY_PATH REPO_LIMIT \
    INCLUDE_ARCHIVED INCLUDE_FORKS VERBOSE; do
    printf -v "PROCESS_${name}_SET" '%s' "false"
    printf -v "PROCESS_${name}" '%s' ""

    if [[ -v ${name} ]]; then
      printf -v "PROCESS_${name}_SET" '%s' "true"
      printf -v "PROCESS_${name}" '%s' "${!name}"
    fi
  done
}

## @fn set_defaults()
## @brief Initializes built-in defaults before higher-precedence configuration is applied.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Defaults were initialized.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
set_defaults() {
  ENV_FILE=""
  OWNER=""
  GIT_HOST="${DEFAULT_GIT_HOST}"
  GIT_USER="${DEFAULT_GIT_USER}"
  GIT_TRANSPORT="${DEFAULT_GIT_TRANSPORT}"
  GH_TOKEN=""
  BRANCH_PATTERNS=""
  BRANCH_PATTERN=""
  AGENT_NAME=""
  AGENT_EMAIL=""
  SIGNING_KEY_PATH=""
  SIGNING_PUBLIC_KEY_PATH=""
  REPO_LIMIT="${DEFAULT_REPO_LIMIT}"
  INCLUDE_ARCHIVED="${DEFAULT_INCLUDE_ARCHIVED}"
  INCLUDE_FORKS="${DEFAULT_INCLUDE_FORKS}"
  VERBOSE="${DEFAULT_VERBOSE}"
}

## @fn find_env_file_argument()
## @brief Resolves the environment-file selector before loading lower-precedence configuration.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The selector was resolved.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
find_env_file_argument() {
  local argument
  local next_is_value=false

  ENV_FILE_EXPLICIT=false
  if [[ "${PROCESS_ENV_FILE_SET}" == "true" ]]; then
    ENV_FILE="${PROCESS_ENV_FILE}"
    ENV_FILE_EXPLICIT=true
  else
    ENV_FILE=""
  fi

  for argument in "$@"; do
    if [[ "${next_is_value}" == "true" ]]; then
      ENV_FILE="${argument}"
      ENV_FILE_EXPLICIT=true
      next_is_value=false
      continue
    fi

    case "${argument}" in
      --env-file)
        next_is_value=true
        ;;
      --env-file=*)
        ENV_FILE="${argument#*=}"
        ENV_FILE_EXPLICIT=true
        ;;
    esac
  done

  [[ "${next_is_value}" == "false" ]] || die "--env-file requires a value"
}

## @fn load_env_file()
## @brief Parses the supported non-executable environment-file grammar and applies recognized keys.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The file was parsed successfully.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
load_env_file() {
  local file="$1"
  local line
  local key
  local value

  [[ -r "${file}" ]] || die "Unable to read environment file: ${file}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="$(trim "${line}")"

    [[ -n "${line}" ]] || continue
    [[ "${line}" == \#* ]] && continue

    if [[ "${line}" == export[[:space:]]* ]]; then
      line="$(trim "${line#export}")"
    fi

    [[ "${line}" == *=* ]] || die "Invalid environment file entry: ${line}"

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"
    value="$(strip_env_quotes "${value}")"

    case "${key}" in
      OWNER | GIT_HOST | GIT_USER | GIT_TRANSPORT | GH_TOKEN | BRANCH_PATTERNS | BRANCH_PATTERN | \
        AGENT_NAME | AGENT_EMAIL | SIGNING_KEY_PATH | SIGNING_PUBLIC_KEY_PATH | \
        REPO_LIMIT | INCLUDE_ARCHIVED | INCLUDE_FORKS | VERBOSE)
        printf -v "${key}" '%s' "${value}"
        ;;
      DRY_RUN)
        ;;
      *)
        warn "Ignoring unknown environment-file variable: ${key}"
        ;;
    esac
  done <"${file}"
}

## @fn apply_process_environment()
## @brief Applies captured process configuration over values loaded from the environment file.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Captured values were applied.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
apply_process_environment() {
  local name
  local set_variable
  local value_variable

  for name in \
    OWNER GIT_HOST GIT_USER GIT_TRANSPORT GH_TOKEN BRANCH_PATTERNS BRANCH_PATTERN \
    AGENT_NAME AGENT_EMAIL SIGNING_KEY_PATH SIGNING_PUBLIC_KEY_PATH REPO_LIMIT \
    INCLUDE_ARCHIVED INCLUDE_FORKS VERBOSE; do
    set_variable="PROCESS_${name}_SET"
    value_variable="PROCESS_${name}"

    if [[ "${!set_variable}" == "true" ]]; then
      printf -v "${name}" '%s' "${!value_variable}"
    fi
  done
}

## @fn parse_options()
## @brief Parses command-line options without evaluating caller-controlled text.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT except when --help is selected.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT except when --help is selected.
##
## @retval 0 Options were parsed or help was written.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
parse_options() {
  while (($#)); do
    case "$1" in
      --env-file)
        shift
        [[ $# -gt 0 ]] || die "--env-file requires a value"
        ENV_FILE="$1"
        ;;
      --env-file=*)
        ENV_FILE="${1#*=}"
        ;;
      --owner)
        shift
        [[ $# -gt 0 ]] || die "--owner requires a value"
        OWNER="$1"
        ;;
      --owner=*)
        OWNER="${1#*=}"
        ;;
      --git-host)
        shift
        [[ $# -gt 0 ]] || die "--git-host requires a value"
        GIT_HOST="$1"
        ;;
      --git-host=*)
        GIT_HOST="${1#*=}"
        ;;
      --git-user)
        shift
        [[ $# -gt 0 ]] || die "--git-user requires a value"
        GIT_USER="$1"
        ;;
      --git-user=*)
        GIT_USER="${1#*=}"
        ;;
      --git-transport)
        shift
        [[ $# -gt 0 ]] || die "--git-transport requires a value"
        GIT_TRANSPORT="$1"
        ;;
      --git-transport=*)
        GIT_TRANSPORT="${1#*=}"
        ;;
      --branch-patterns)
        shift
        [[ $# -gt 0 ]] || die "--branch-patterns requires a value"
        BRANCH_PATTERNS="$1"
        ;;
      --branch-patterns=*)
        BRANCH_PATTERNS="${1#*=}"
        ;;
      --branch-pattern)
        shift
        [[ $# -gt 0 ]] || die "--branch-pattern requires a value"
        BRANCH_PATTERN="$1"
        ;;
      --branch-pattern=*)
        BRANCH_PATTERN="${1#*=}"
        ;;
      --agent-name)
        shift
        [[ $# -gt 0 ]] || die "--agent-name requires a value"
        AGENT_NAME="$1"
        ;;
      --agent-name=*)
        AGENT_NAME="${1#*=}"
        ;;
      --agent-email)
        shift
        [[ $# -gt 0 ]] || die "--agent-email requires a value"
        AGENT_EMAIL="$1"
        ;;
      --agent-email=*)
        AGENT_EMAIL="${1#*=}"
        ;;
      --signing-key)
        shift
        [[ $# -gt 0 ]] || die "--signing-key requires a value"
        SIGNING_KEY_PATH="$1"
        ;;
      --signing-key=*)
        SIGNING_KEY_PATH="${1#*=}"
        ;;
      --signing-public-key)
        shift
        [[ $# -gt 0 ]] || die "--signing-public-key requires a value"
        SIGNING_PUBLIC_KEY_PATH="$1"
        ;;
      --signing-public-key=*)
        SIGNING_PUBLIC_KEY_PATH="${1#*=}"
        ;;
      --limit)
        shift
        [[ $# -gt 0 ]] || die "--limit requires a value"
        REPO_LIMIT="$1"
        ;;
      --limit=*)
        REPO_LIMIT="${1#*=}"
        ;;
      --include-archived)
        INCLUDE_ARCHIVED="true"
        ;;
      --include-forks)
        INCLUDE_FORKS="true"
        ;;
      --verbose)
        VERBOSE="true"
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        (($# == 0)) || die "Unexpected positional argument: $1"
        break
        ;;
      -*)
        die "Unknown option: $1"
        ;;
      *)
        die "Unexpected positional argument: $1"
        ;;
    esac

    shift
  done
}

## @fn prepare_branch_patterns()
## @brief Validates the comma-separated configured ref globs and expands them into an array.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 At least one safe branch pattern was prepared.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
prepare_branch_patterns() {
  local raw_patterns
  local pattern
  local -a parsed=()

  if [[ -n "${BRANCH_PATTERNS}" ]]; then
    raw_patterns="${BRANCH_PATTERNS}"
  elif [[ -n "${BRANCH_PATTERN}" ]]; then
    raw_patterns="${BRANCH_PATTERN}"
  else
    raw_patterns="${DEFAULT_BRANCH_PATTERNS}"
  fi

  IFS=',' read -r -a parsed <<<"${raw_patterns}"

  BRANCH_PATTERN_LIST=()
  for pattern in "${parsed[@]}"; do
    pattern="$(trim "${pattern}")"
    [[ -n "${pattern}" ]] || die "BRANCH_PATTERNS contains an empty pattern"

    [[ "${pattern}" =~ ^[A-Za-z0-9._/?*-]+$ ]] ||
      die "Branch pattern contains unsupported characters: ${pattern}"
    [[ "${pattern}" != *..* && "${pattern}" != *//* && "${pattern}" != *@\{* ]] ||
      die "Branch pattern contains an unsafe ref pattern: ${pattern}"

    BRANCH_PATTERN_LIST+=("${pattern}")
  done

  (("${#BRANCH_PATTERN_LIST[@]}" > 0)) ||
    die "At least one branch pattern must be configured"
}

## @fn branch_ref_arguments()
## @brief Expands configured branch patterns to refs/heads globs suitable for Git.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## One fully qualified ref glob per line.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns One fully qualified ref glob per line.
##
## @retval 0 Ref arguments were written.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
branch_ref_arguments() {
  local pattern

  for pattern in "${BRANCH_PATTERN_LIST[@]}"; do
    printf 'refs/heads/%s\n' "${pattern}"
  done
}

## @fn validate_configuration()
## @brief Validates required values, booleans, transports, files, and command dependencies before remote work.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Configuration is valid.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
validate_configuration() {
  command -v gh >/dev/null 2>&1 || die "gh is required"
  command -v git >/dev/null 2>&1 || die "git is required"

  [[ -n "${OWNER}" ]] || die "OWNER must be provided"
  valid_owner "${OWNER}" || die "Invalid OWNER: ${OWNER}"
  valid_git_host "${GIT_HOST}" || die "Invalid GIT_HOST: ${GIT_HOST}"

  case "${GIT_TRANSPORT}" in
    https)
      [[ -n "${GH_TOKEN}" ]] || die "GH_TOKEN must be provided when GIT_TRANSPORT=https"
      ;;
    ssh)
      ;;
    *)
      die "GIT_TRANSPORT must be https or ssh"
      ;;
  esac

  [[ "${REPO_LIMIT}" =~ ^[1-9][0-9]*$ ]] || die "REPO_LIMIT must be a positive integer"
  is_true_or_false "${INCLUDE_ARCHIVED}" || die "INCLUDE_ARCHIVED must be true or false"
  is_true_or_false "${INCLUDE_FORKS}" || die "INCLUDE_FORKS must be true or false"
  is_true_or_false "${VERBOSE}" || die "VERBOSE must be true or false"
}

## @fn remote_for_repository()
## @brief Builds the configured HTTPS or SSH remote URL for one normalized repository.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## One Git remote URL followed by a newline.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns One Git remote URL followed by a newline.
##
## @retval 0 The remote URL was written.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
remote_for_repository() {
  local repository="$1"

  case "${GIT_TRANSPORT}" in
    https)
      printf 'https://%s/%s.git\n' "${GIT_HOST}" "${repository}"
      ;;
    ssh)
      printf '%s@%s:%s.git\n' "${GIT_USER}" "${GIT_HOST}" "${repository}"
      ;;
  esac
}

## @fn repository_has_matching_branch()
## @brief Queries the remote for at least one configured branch pattern without cloning the repository.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 A matching branch exists.
## @retval 1 No configured branch pattern exists.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
repository_has_matching_branch() {
  local repository="$1"
  local remote
  local status
  local -a branch_ref_args=()

  remote="$(remote_for_repository "${repository}")"
  mapfile -t branch_ref_args < <(branch_ref_arguments)

  if git ls-remote --exit-code --heads "${remote}" "${branch_ref_args[@]}" >/dev/null; then
    return 0
  else
    status=$?
  fi

  case "${status}" in
    2)
      return 1
      ;;
    *)
      die "Unable to inspect branches for ${repository} (git ls-remote exit ${status})"
      ;;
  esac
}

## @fn create_git_askpass()
## @brief Creates the private temporary GIT_ASKPASS helper used for HTTPS token authentication.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The helper was created.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
create_git_askpass() {
  cat >"${GIT_ASKPASS}" <<'ASKPASS'
#!/usr/bin/env bash

case "${1-}" in
  *Username*)
    printf '%s\n' 'x-access-token'
    ;;
  *Password*)
    printf '%s\n' "${GH_TOKEN:?GH_TOKEN is required}"
    ;;
  *)
    exit 1
    ;;
esac
ASKPASS

  chmod 0700 "${GIT_ASKPASS}"
}

## @fn list_repositories()
## @brief Enumerates owner repositories and emits only repositories having a configured matching branch.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## One OWNER/NAME repository per line.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns One OWNER/NAME repository per line.
##
## @retval 0 Repository enumeration completed.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
list_repositories() {
  local -a args
  local -a repositories
  local jq_filter
  local repository

  args=(
    repo list "${OWNER}"
    --limit "${REPO_LIMIT}"
    --json nameWithOwner,isArchived
  )

  if [[ "${INCLUDE_FORKS}" != "true" ]]; then
    args+=(--source)
  fi

  if [[ "${INCLUDE_ARCHIVED}" == "true" ]]; then
    jq_filter='.[] | .nameWithOwner'
  else
    jq_filter='.[] | select(.isArchived == false) | .nameWithOwner'
  fi

  log_debug "owner=${OWNER} host=${GIT_HOST} limit=${REPO_LIMIT} include_archived=${INCLUDE_ARCHIVED} include_forks=${INCLUDE_FORKS} branch_patterns=${BRANCH_PATTERN_LIST[*]}"

  mapfile -t repositories < <(
    GH_HOST="${GIT_HOST}" gh "${args[@]}" --jq "${jq_filter}"
  )

  for repository in "${repositories[@]}"; do
    if repository_has_matching_branch "${repository}"; then
      printf '%s\n' "${repository}"
    else
      log_debug "Skipping ${repository}: no branch matching configured patterns"
    fi
  done
}

## @fn main()
## @brief Coordinates configuration precedence, temporary state, repository processing, reporting, and final status.
## @details
## This function preserves a narrow, inspectable part of the command contract.
## Caller-controlled values are handled as data and must not be evaluated as
## shell source.  Security-sensitive callers rely on failures remaining visible
## rather than silently falling back to broader behavior.
##
## @par STDIN
## Nothing is read from STDIN unless the function description explicitly says so.
## @par STDOUT
## Repository data or signing progress according to the command's public contract.
## @par STDERR
## Diagnostics may be written when validation or an external command fails.
##
## @returns Repository data or signing progress according to the command's public contract.
##
## @retval 0 The command completed without policy or repository failures.
## @retval 1 One or more branches or repositories failed.
## @note Additional non-zero statuses from subordinate Git, gh, ssh-keygen,
## awk, grep, or shell operations may be propagated where they are not translated.
##
## @par Examples
## @code
## # Exercised through the command's Bats unit and behavior suites.
## @endcode
main() {
  capture_process_environment
  set_defaults
  find_env_file_argument "$@"

  if [[ "${ENV_FILE_EXPLICIT}" == "true" ]]; then
    [[ -z "${ENV_FILE}" ]] || load_env_file "${ENV_FILE}"
  elif [[ -r .env ]]; then
    load_env_file .env
  fi

  apply_process_environment
  parse_options "$@"
  validate_configuration
  prepare_branch_patterns

  WORK_ROOT="$(mktemp -d)"
  readonly WORK_ROOT
  trap 'rm -rf -- "${WORK_ROOT}"' EXIT

  GIT_ASKPASS="${WORK_ROOT}/git-askpass"
  export GIT_ASKPASS
  export GIT_TERMINAL_PROMPT=0
  export GH_TOKEN

  if [[ "${GIT_TRANSPORT}" == "https" ]]; then
    create_git_askpass
  fi

  list_repositories
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
