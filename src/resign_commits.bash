#!/usr/bin/env bash
# shellcheck shell=bash
## @file src/resign_commits.bash
## @brief Rewrites eligible agent-owned branch suffixes with verified SSH commit signatures.
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
## printf '%s\n' wesley-dean/example | ./src/resign_commits.bash --dry-run
## @endcode

set -Eeuo pipefail

umask 077

PROGRAM_NAME="${0##*/}"

DEFAULT_GIT_HOST="github.com"
DEFAULT_GIT_USER="git"
DEFAULT_GIT_TRANSPORT="https"
DEFAULT_BRANCH_PATTERNS="agent/*,ai/*,codex/*"
DEFAULT_DRY_RUN="false"
DEFAULT_VERBOSE="false"

## @fn usage()
## @brief Writes command usage and configuration guidance.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Human-readable usage text.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Human-readable usage text.
##
## @retval 0 Usage text was written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## usage
## @endcode
usage() {
  cat <<USAGE
Usage:
  ${PROGRAM_NAME} [options] [repository ...]

Resign eligible commits on matching Git branches using an SSH signing key.

Repositories may be supplied as positional arguments or one per line on STDIN.
A repository may be specified as OWNER/NAME or, when --owner is supplied, NAME.

Configuration precedence:
  command-line arguments
  process environment
  environment file
  built-in defaults

Options:
  --env-file FILE
      Read configuration from FILE.  If omitted, .env is read when present.

  --owner OWNER
      Restrict repositories to this owner.  Required when repository names are
      supplied without an owner.

  --git-host HOST
      Git host.  Default: ${DEFAULT_GIT_HOST}

  --git-user USER
      Git SSH user when --git-transport=ssh.  Default: ${DEFAULT_GIT_USER}

  --git-transport TRANSPORT
      Git transport: https or ssh.  Default: ${DEFAULT_GIT_TRANSPORT}
      HTTPS authentication uses GH_TOKEN.

  --branch-patterns PATTERNS
      Comma-separated branch patterns eligible for processing.
      Default: ${DEFAULT_BRANCH_PATTERNS}

  --branch-pattern PATTERN
      Deprecated single-pattern alias retained for compatibility.

  --agent-name NAME
      Committer name to use when rewriting commits.  Required.

  --agent-email EMAIL
      Required author and committer email for eligible commits.  Required.

  --signing-key FILE
      SSH private key used to sign commits.  Required.

  --signing-public-key FILE
      SSH public signing key.  Optional; when omitted, it is derived from the
      private key with ssh-keygen.

  --dry-run
      Inspect repositories and report proposed changes without rewriting or
      pushing commits.

  --verbose
      Enable diagnostic output.

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
  DRY_RUN
  VERBOSE

Examples:
  printf '%s
' bootstrap bashlog |     OWNER=wesley-dean     AGENT_NAME=wesley-dean-agent     AGENT_EMAIL=wesley-dean-agent@wesleydean.com     SIGNING_KEY_PATH=/run/secrets/agent-signing-key     ${PROGRAM_NAME}

  ${PROGRAM_NAME}     --owner wesley-dean     --agent-name wesley-dean-agent     --agent-email wesley-dean-agent@wesleydean.com     --signing-key /run/secrets/agent-signing-key     --dry-run     wesley-dean/bootstrap
USAGE
}

## @fn log()
## @brief Writes one progress message to standard output.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param args[] Message words to render as one progress record.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The supplied message followed by one newline.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns The supplied message followed by one newline.
##
## @retval 0 The message was written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## log 'Repository: wesley-dean/example'
## @endcode
log() {
  printf '%s
' "$*"
}

## @fn debug()
## @brief Writes a debug diagnostic when verbose mode is enabled.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param args[] Message words to render as one diagnostic.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## A DEBUG diagnostic when VERBOSE is true.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The diagnostic was emitted or verbose mode was disabled.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## VERBOSE=true; debug 'branch discovered'
## @endcode
debug() {
  if [[ "${VERBOSE}" == "true" ]]; then
    printf 'DEBUG: %s
' "$*" >&2
  fi
}

## @fn warn()
## @brief Writes one warning diagnostic to standard error.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param args[] Message words to render as one warning.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## A WARNING diagnostic followed by one newline.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The warning was written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## warn 'branch changed during discovery'
## @endcode
warn() {
  printf 'WARNING: %s
' "$*" >&2
}

## @fn error()
## @brief Writes one error diagnostic to standard error.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param args[] Message words to render as one error.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## An ERROR diagnostic followed by one newline.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The error was written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## error 'clone failed'
## @endcode
error() {
  printf 'ERROR: %s
' "$*" >&2
}

## @fn die()
## @brief Reports an error and terminates the current command.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param args[] Message words passed to error().
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## An ERROR diagnostic is written before termination.
##
## @returns Nothing is written to STDOUT.
##
## @retval 1 The command terminates after reporting the error.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## die 'invalid configuration'
## @endcode
die() {
  error "$*"
  exit 1
}

## @fn trim()
## @brief Removes leading and trailing shell whitespace from a value.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param value Value to normalize without evaluation.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The trimmed value followed by one newline.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns One normalized string followed by one newline.
##
## @retval 0 The normalized value was written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## trim '  value  '
## @endcode
trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  printf '%s
' "${value}"
}

## @fn strip_env_quotes()
## @brief Removes one matching pair of outer quotes from a value.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param value Value whose outer quote pair may be removed.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The normalized value followed by one newline.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns One normalized string followed by one newline.
##
## @retval 0 The normalized value was written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## strip_env_quotes '"value"'
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
## @brief Validates the restricted repository-owner grammar.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param owner Repository owner token to validate.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The owner token is valid.
## @retval 1 The owner token is invalid.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## valid_owner wesley-dean
## @endcode
valid_owner() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]
}

## @fn valid_repository_name()
## @brief Validates the restricted repository-name grammar.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param name Repository name token to validate.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The repository name is valid.
## @retval 1 The repository name is invalid.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## valid_repository_name example-repo
## @endcode
valid_repository_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

## @fn valid_git_host()
## @brief Validates the restricted Git host grammar.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param host Git host token to validate.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The host token is valid.
## @retval 1 The host token is invalid.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## valid_git_host github.com
## @endcode
valid_git_host() {
  [[ "$1" =~ ^[A-Za-z0-9.-]+$ ]]
}

## @fn report_result()
## @brief Writes one aligned branch or repository result record.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param status Result status token.
## @param subject Branch or repository subject.
## @param detail Optional explanatory detail.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## One aligned result record followed by one newline.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns One human-readable result record.
##
## @retval 0 The result record was written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## report_result SIGNED ai/example 'old -> new'
## @endcode
report_result() {
  local status="$1"
  local subject="$2"
  local detail="${3-}"

  if [[ -n "${detail}" ]]; then
    printf '    %-18s %s (%s)\n' "${status}" "${subject}" "${detail}"
  else
    printf '    %-18s %s\n' "${status}" "${subject}"
  fi
}

## @fn is_true_or_false()
## @brief Validates an exact boolean configuration token.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param value Candidate boolean token.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The value is exactly true or false.
## @retval 1 The value is not an accepted boolean token.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## is_true_or_false true
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

## @fn load_env_file()
## @brief Parses supported assignments from a non-executable environment file.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param file Readable environment-file path.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Warnings or errors are written for unsupported or invalid entries.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The file was parsed successfully.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## load_env_file ./signer.env
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
        DRY_RUN | VERBOSE)
        printf -v "${key}" '%s' "${value}"
        ;;
      *)
        warn "Ignoring unknown environment-file variable: ${key}"
        ;;
    esac
  done <"${file}"
}

## @fn capture_process_environment()
## @brief Captures explicitly set process-environment configuration.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Process configuration was captured.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## capture_process_environment
## @endcode
capture_process_environment() {
  local name

  for name in \
    ENV_FILE OWNER GIT_HOST GIT_USER GIT_TRANSPORT GH_TOKEN BRANCH_PATTERNS BRANCH_PATTERN \
    AGENT_NAME AGENT_EMAIL SIGNING_KEY_PATH SIGNING_PUBLIC_KEY_PATH DRY_RUN VERBOSE; do
    printf -v "PROCESS_${name}_SET" '%s' "false"
    printf -v "PROCESS_${name}" '%s' ""

    if [[ -v ${name} ]]; then
      printf -v "PROCESS_${name}_SET" '%s' "true"
      printf -v "PROCESS_${name}" '%s' "${!name}"
    fi
  done
}

## @fn apply_process_environment()
## @brief Applies captured process configuration over lower-precedence values.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Captured process values were applied.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## apply_process_environment
## @endcode
apply_process_environment() {
  local name
  local set_variable
  local value_variable

  for name in \
    OWNER GIT_HOST GIT_USER GIT_TRANSPORT GH_TOKEN BRANCH_PATTERNS BRANCH_PATTERN \
    AGENT_NAME AGENT_EMAIL SIGNING_KEY_PATH SIGNING_PUBLIC_KEY_PATH DRY_RUN VERBOSE; do
    set_variable="PROCESS_${name}_SET"
    value_variable="PROCESS_${name}"

    if [[ "${!set_variable}" == "true" ]]; then
      printf -v "${name}" '%s' "${!value_variable}"
    fi
  done
}

## @fn find_env_file_argument()
## @brief Resolves the environment-file selector before configuration loading.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param args[] Command-line arguments to scan for --env-file.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## An error is written if --env-file lacks a value.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The environment-file selector was resolved.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## find_env_file_argument --env-file ./signer.env
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

## @fn parse_options()
## @brief Parses supported command-line options without evaluating input.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param args[] Command-line arguments to parse.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Usage text is written only when --help is selected.
## @par STDERR
## An error is written for invalid or incomplete options.
##
## @returns Nothing is normally written to STDOUT.
##
## @retval 0 Options were parsed or help was written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## parse_options --owner wesley-dean
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
      --dry-run)
        DRY_RUN="true"
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
        REPOSITORIES+=("$@")
        break
        ;;
      -*)
        die "Unknown option: $1"
        ;;
      *)
        REPOSITORIES+=("$1")
        ;;
    esac

    shift
  done
}

## @fn prepare_branch_patterns()
## @brief Validates and expands configured comma-separated branch patterns.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## An error is written when a pattern is empty or unsafe.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 At least one safe branch pattern was prepared.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## BRANCH_PATTERNS='agent/*,ai/*'; prepare_branch_patterns
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
## @brief Writes configured branch patterns as fully qualified Git ref globs.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## One refs/heads glob per configured pattern.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Zero or more newline-delimited Git ref globs.
##
## @retval 0 Ref arguments were written.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## branch_ref_arguments
## @endcode
branch_ref_arguments() {
  local pattern

  for pattern in "${BRANCH_PATTERN_LIST[@]}"; do
    printf 'refs/heads/%s\n' "${pattern}"
  done
}

## @fn validate_configuration()
## @brief Validates signing configuration before repository processing.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## An error is written when required state is invalid.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Signing configuration is valid.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## validate_configuration
## @endcode
validate_configuration() {
  command -v git >/dev/null 2>&1 || die "git is required"
  command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is required"
  command -v awk >/dev/null 2>&1 || die "awk is required"

  [[ -n "${AGENT_NAME}" ]] || die "AGENT_NAME must be provided"
  [[ -n "${AGENT_EMAIL}" ]] || die "AGENT_EMAIL must be provided"
  [[ -n "${SIGNING_KEY_PATH}" ]] || die "SIGNING_KEY_PATH must be provided"
  [[ -r "${SIGNING_KEY_PATH}" ]] || die "Unable to read signing key: ${SIGNING_KEY_PATH}"

  [[ -z "${OWNER}" ]] || valid_owner "${OWNER}" || die "Invalid OWNER: ${OWNER}"
  valid_git_host "${GIT_HOST}" || die "Invalid GIT_HOST: ${GIT_HOST}"

  if [[ -n "${SIGNING_PUBLIC_KEY_PATH}" ]]; then
    [[ -r "${SIGNING_PUBLIC_KEY_PATH}" ]] ||
      die "Unable to read public signing key: ${SIGNING_PUBLIC_KEY_PATH}"
  fi

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

  is_true_or_false "${DRY_RUN}" || die "DRY_RUN must be true or false"
  is_true_or_false "${VERBOSE}" || die "VERBOSE must be true or false"
}

## @fn read_repositories_from_stdin()
## @brief Reads newline-delimited repository identifiers from piped input.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Zero or more repository identifiers, one per line.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Input was consumed or STDIN was a terminal.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## printf '%s\n' wesley-dean/example | read_repositories_from_stdin
## @endcode
read_repositories_from_stdin() {
  local line

  [[ -t 0 ]] && return 0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="$(trim "${line}")"

    [[ -n "${line}" ]] || continue
    [[ "${line}" == \#* ]] && continue

    REPOSITORIES+=("${line}")
  done
}

## @fn normalize_repository()
## @brief Validates and normalizes one repository identifier.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param repository OWNER/NAME or unqualified repository identifier.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The normalized OWNER/NAME value on success.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns One normalized repository identifier followed by one newline.
##
## @retval 0 The repository is valid.
## @retval 1 The repository is outside configured OWNER.
## @retval 2 An unqualified name lacks OWNER.
## @retval 3 Repository syntax is invalid.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## OWNER=wesley-dean; normalize_repository example
## @endcode
normalize_repository() {
  local repository="$1"
  local owner
  local name

  repository="${repository%.git}"

  if [[ "${repository}" != */* ]]; then
    [[ -n "${OWNER}" ]] || return 2
    repository="${OWNER}/${repository}"
  fi

  [[ "${repository}" != */*/* ]] || return 3

  owner="${repository%%/*}"
  name="${repository#*/}"

  valid_owner "${owner}" || return 3
  valid_repository_name "${name}" || return 3

  if [[ -n "${OWNER}" && "${owner}" != "${OWNER}" ]]; then
    return 1
  fi

  printf '%s\n' "${repository}"
}

## @fn prepare_repositories()
## @brief Normalizes, owner-checks, and deduplicates repository inputs.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Rejected repositories and verbose duplicate diagnostics may be written.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Repository inputs were processed.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## REPOSITORIES=(example); prepare_repositories
## @endcode
prepare_repositories() {
  local input
  local repository
  local status
  local -A seen=()
  local -a prepared=()

  for input in "${REPOSITORIES[@]}"; do
    if repository="$(normalize_repository "${input}")"; then
      if [[ -z "${seen[${repository}]+x}" ]]; then
        seen["${repository}"]=1
        prepared+=("${repository}")
      else
        debug "Ignoring duplicate repository input: ${repository}"
      fi
      continue
    else
      status=$?
    fi

    case "${status}" in
      1)
        die "Repository outside configured owner: ${input}"
        ;;
      2)
        die "Repository '${input}' is unqualified and OWNER is not set"
        ;;
      3)
        die "Invalid repository name: ${input}"
        ;;
      *)
        die "Unable to normalize repository: ${input}"
        ;;
    esac
  done

  REPOSITORIES=("${prepared[@]}")
}

## @fn default_branch_for()
## @brief Resolves a remote repository's default branch.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param remote Git remote URL or path.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The default branch name when the remote advertises one.
## @par STDERR
## Git failures may be written by subordinate commands.
##
## @returns Zero or one branch name followed by a newline.
##
## @retval 0 Remote HEAD inspection completed.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## default_branch_for ./example.git
## @endcode
default_branch_for() {
  local remote="$1"

  git ls-remote --symref "${remote}" HEAD |
    awk '
      $1 == "ref:" {
        sub("^refs/heads/", "", $2)
        print $2
        exit
      }
    '
}

## @fn commit_has_signature()
## @brief Tests whether a commit object contains a signature header.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param commit Commit object name or SHA.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Git object lookup failures may be written.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The commit contains a signature.
## @retval 1 No signature header was found.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## commit_has_signature HEAD
## @endcode
commit_has_signature() {
  local commit="$1"

  git cat-file commit "${commit}" |
    grep -q '^gpgsig '
}

## @fn verify_commit()
## @brief Verifies one commit signature using configured Git trust state.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param commit Commit object name or SHA.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Verification diagnostics are intentionally suppressed.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Git verified the commit signature.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## verify_commit HEAD
## @endcode
verify_commit() {
  local commit="$1"

  git verify-commit "${commit}" >/dev/null 2>&1
}

## @fn find_agent_suffix_base()
## @brief Finds the base of the contiguous agent-owned branch-tip suffix.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param base Merge-base SHA that bounds unique branch history.
## @param head Branch-tip SHA to inspect.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The boundary commit SHA when an eligible suffix exists.
## @par STDERR
## Warnings are written for invalid signatures or unexpected history.
##
## @returns One boundary SHA followed by one newline when eligible history exists.
## Nothing is written when the branch tip is not agent-owned.
##
## @retval 0 Suffix evaluation completed; output is empty when no eligible agent suffix exists.
## @retval 1 An existing agent signature failed verification.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## find_agent_suffix_base BASE HEAD
## @endcode
find_agent_suffix_base() {
  local base="$1"
  local head="$2"
  local commit
  local author_email
  local committer_email
  local parent_count
  local suffix_base="${head}"
  local found=false

  while read -r commit; do
    [[ -n "${commit}" ]] || continue

    author_email="$(git show -s --format='%ae' "${commit}")"
    committer_email="$(git show -s --format='%ce' "${commit}")"
    parent_count="$(
      git rev-list --parents -n 1 "${commit}" |
        awk '{ print NF - 1 }'
    )"

    if ((parent_count != 1)); then
      debug "${commit}: merge commit is a signing boundary"
      break
    fi

    if [[ "${author_email}" != "${AGENT_EMAIL}" || "${committer_email}" != "${AGENT_EMAIL}" ]]; then
      debug "${commit}: non-agent commit is a signing boundary"
      break
    fi

    if commit_has_signature "${commit}" && ! verify_commit "${commit}"; then
      warn "${commit}: existing agent signature verification failed"
      return 1
    fi

    suffix_base="$(git rev-parse "${commit}^")"
    found=true
  done < <(git rev-list --first-parent "${head}" "^${base}")

  if [[ "${found}" == "true" ]]; then
    printf '%s\n' "${suffix_base}"
  fi
}

## @fn suffix_needs_signing()
## @brief Tests whether an eligible suffix contains any unsigned commit.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param base Boundary commit SHA.
## @param head Eligible branch-tip SHA.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Git object failures may be written by subordinate commands.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 At least one eligible commit is unsigned.
## @retval 1 Every eligible commit has a signature header.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## suffix_needs_signing BASE HEAD
## @endcode
suffix_needs_signing() {
  local base="$1"
  local head="$2"
  local commit

  while read -r commit; do
    [[ -n "${commit}" ]] || continue
    if ! commit_has_signature "${commit}"; then
      return 0
    fi
  done < <(git rev-list --reverse "${base}..${head}")

  return 1
}

## @fn verify_rewritten_history()
## @brief Verifies signatures across every rewritten commit above a boundary.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param base Boundary commit SHA below rewritten history.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Verification diagnostics are suppressed by verify_commit().
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 Every rewritten commit verified.
## @retval 1 A rewritten commit was unsigned or failed verification.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## verify_rewritten_history BASE
## @endcode
verify_rewritten_history() {
  local base="$1"
  local commit

  while read -r commit; do
    [[ -n "${commit}" ]] || continue
    commit_has_signature "${commit}" || return 1
    verify_commit "${commit}" || return 1
  done < <(git rev-list --reverse "${base}..HEAD")
}

## @fn process_branch()
## @brief Evaluates and optionally re-signs one matching remote branch.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param repository Normalized OWNER/NAME repository identifier.
## @param default_branch Repository default branch name.
## @param branch Matching branch name.
## @param expected_head Remote branch SHA observed during discovery.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Branch progress and classification records.
## @par STDERR
## Warnings and errors describe races or policy failures.
##
## @returns Human-readable branch processing output.
##
## @retval 0 Branch processing completed, including safe skips.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## process_branch owner/repo main ai/example HEAD_SHA
## @endcode
process_branch() {
  local repository="$1"
  local default_branch="$2"
  local branch="$3"
  local expected_head="$4"
  local base
  local suffix_base
  local remote_head
  local new_head
  local commit_count

  log "  ${branch}"

  git fetch --quiet --no-tags origin \
    "refs/heads/${default_branch}:refs/remotes/origin/${default_branch}" \
    "refs/heads/${branch}:refs/remotes/origin/${branch}"

  if [[ "$(git rev-parse "refs/remotes/origin/${branch}")" != "${expected_head}" ]]; then
    warn "${repository}:${branch}: branch changed during discovery"
    report_result "RACE_SKIPPED" "${branch}" "changed during discovery"
    ((SKIPPED_BRANCHES += 1))
    ((RACE_SKIPPED_BRANCHES += 1))
    return 0
  fi

  base="$(
    git merge-base \
      "refs/remotes/origin/${default_branch}" \
      "refs/remotes/origin/${branch}"
  )"

  if [[ "${base}" == "${expected_head}" ]]; then
    report_result "NO_UNIQUE_COMMITS" "${branch}"
    ((SKIPPED_BRANCHES += 1))
    return 0
  fi

  if ! suffix_base="$(find_agent_suffix_base "${base}" "${expected_head}")"; then
    error "${repository}:${branch}: unable to validate agent-owned suffix"
    report_result "POLICY_REJECTED" "${branch}" "agent signature validation failed"
    ((FAILED_BRANCHES += 1))
    ((POLICY_REJECTED_BRANCHES += 1))
    return 0
  fi

  if [[ -z "${suffix_base}" ]]; then
    report_result "HUMAN_BOUNDARY" "${branch}" "tip is not agent-owned"
    ((SKIPPED_BRANCHES += 1))
    ((HUMAN_BOUNDARY_BRANCHES += 1))
    return 0
  fi

  if ! suffix_needs_signing "${suffix_base}" "${expected_head}"; then
    report_result "ALREADY_SIGNED" "${branch}"
    ((SKIPPED_BRANCHES += 1))
    ((ALREADY_SIGNED_BRANCHES += 1))
    return 0
  fi

  commit_count="$(git rev-list --count "${suffix_base}..${expected_head}")"

  if [[ "${suffix_base}" != "${base}" ]]; then
    log "    signing boundary: $(git rev-parse --short "${suffix_base}")"
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    report_result "WOULD_SIGN" "${branch}" "${commit_count} agent-owned commit(s)"
    ((SKIPPED_BRANCHES += 1))
    return 0
  fi

  log "    signing ${commit_count} agent-owned commit(s)"

  git checkout --quiet -B "${branch}" "refs/remotes/origin/${branch}"

  git rebase \
    --force-rebase \
    --exec 'git commit --amend --no-edit -S' \
    "${suffix_base}"

  if ! verify_rewritten_history "${suffix_base}"; then
    error "${repository}:${branch}: rewritten signature verification failed"
    report_result "POLICY_REJECTED" "${branch}" "rewritten verification failed"
    ((FAILED_BRANCHES += 1))
    ((POLICY_REJECTED_BRANCHES += 1))
    return 0
  fi

  remote_head="$(
    git ls-remote origin "refs/heads/${branch}" |
      awk '{ print $1 }'
  )"

  if [[ "${remote_head}" != "${expected_head}" ]]; then
    warn "${repository}:${branch}: remote branch changed before push"
    report_result "RACE_SKIPPED" "${branch}" "changed before push"
    ((SKIPPED_BRANCHES += 1))
    ((RACE_SKIPPED_BRANCHES += 1))
    return 0
  fi

  new_head="$(git rev-parse HEAD)"

  git push \
    --quiet \
    --force-with-lease="refs/heads/${branch}:${expected_head}" \
    origin \
    "HEAD:refs/heads/${branch}"

  report_result "SIGNED" "${branch}" "${expected_head} -> ${new_head}"
  ((SIGNED_BRANCHES += 1))
}

## @fn process_repository()
## @brief Discovers and processes configured matching branches in one repository.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param repository Normalized OWNER/NAME repository identifier.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Repository progress and branch classification records.
## @par STDERR
## Repository and branch failures are reported as diagnostics.
##
## @returns Human-readable repository processing output.
##
## @retval 0 Repository processing completed, including safe skips.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## process_repository wesley-dean/example
## @endcode
process_repository() {
  local repository="$1"
  local repository_name
  local remote
  local default_branch
  local directory
  local original_directory
  local matching_branches
  local head
  local ref
  local branch

  repository_name="${repository//\//_}"

  case "${GIT_TRANSPORT}" in
    https)
      remote="https://${GIT_HOST}/${repository}.git"
      ;;
    ssh)
      remote="${GIT_USER}@${GIT_HOST}:${repository}.git"
      ;;
  esac
  directory="${WORK_ROOT}/${repository_name}"

  log "Repository: ${repository}"

  local -a branch_ref_args=()
  mapfile -t branch_ref_args < <(branch_ref_arguments)

  if ! matching_branches="$(git ls-remote --heads "${remote}" "${branch_ref_args[@]}")"; then
    error "${repository}: unable to inspect matching branches"
    report_result "ERROR" "${repository}" "ls-remote failed"
    ((FAILED_REPOSITORIES += 1))
    return 0
  fi

  if [[ -z "${matching_branches}" ]]; then
    report_result "NO_MATCHING_BRANCH" "${repository}"
    ((NO_MATCHING_BRANCH_REPOSITORIES += 1))
    return 0
  fi

  if ! default_branch="$(default_branch_for "${remote}")" || [[ -z "${default_branch}" ]]; then
    error "${repository}: unable to determine default branch"
    report_result "ERROR" "${repository}" "default branch unavailable"
    ((FAILED_REPOSITORIES += 1))
    return 0
  fi

  if ! git clone --quiet --no-tags "${remote}" "${directory}"; then
    error "${repository}: clone failed"
    report_result "ERROR" "${repository}" "clone failed"
    ((FAILED_REPOSITORIES += 1))
    return 0
  fi

  original_directory="${PWD}"
  if ! cd "${directory}"; then
    error "${repository}: unable to enter clone directory"
    report_result "ERROR" "${repository}" "unable to enter clone"
    ((FAILED_REPOSITORIES += 1))
    rm -rf -- "${directory}"
    return 0
  fi

  git config core.hooksPath /dev/null
  git config user.name "${AGENT_NAME}"
  git config user.email "${AGENT_EMAIL}"
  git config gpg.format ssh
  git config user.signingkey "${SIGNING_KEY_PATH}"
  git config commit.gpgsign true
  git config gpg.ssh.allowedSignersFile "${ALLOWED_SIGNERS_FILE}"

  while read -r head ref; do
    [[ -n "${head}" ]] || continue
    [[ -n "${ref}" ]] || continue

    branch="${ref#refs/heads/}"
    process_branch "${repository}" "${default_branch}" "${branch}" "${head}"
  done <<<"${matching_branches}"

  cd "${original_directory}" || die "Unable to return to ${original_directory}"
  rm -rf -- "${directory}"
}

## @fn create_git_askpass()
## @brief Creates the temporary Git HTTPS credential helper.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## A shell or filesystem error may be propagated.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The private executable helper was created.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## create_git_askpass
## @endcode
create_git_askpass() {
  cat >"${GIT_ASKPASS}" <<'ASKPASS'
#!/usr/bin/env bash

case "${1-}" in
  *Username*)
    printf '%s
' 'x-access-token'
    ;;
  *Password*)
    printf '%s
' "${GH_TOKEN:?GH_TOKEN is required}"
    ;;
  *)
    exit 1
    ;;
esac
ASKPASS

  chmod 0700 "${GIT_ASKPASS}"
}

## @fn create_allowed_signers_file()
## @brief Creates the temporary SSH allowed-signers file.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## ssh-keygen or filesystem failures may be propagated.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The allowed-signers file was created.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## create_allowed_signers_file
## @endcode
create_allowed_signers_file() {
  local public_key

  if [[ -n "${SIGNING_PUBLIC_KEY_PATH}" ]]; then
    public_key="$(<"${SIGNING_PUBLIC_KEY_PATH}")"
  else
    public_key="$(ssh-keygen -y -f "${SIGNING_KEY_PATH}")"
  fi

  printf '%s %s
' "${AGENT_EMAIL}" "${public_key}" >"${ALLOWED_SIGNERS_FILE}"
}

## @fn main()
## @brief Coordinates configuration, temporary state, and command execution.
## @details
## This function is part of the command's maintained contract.  Inputs are
## handled as data and are not evaluated as shell source.  Callers rely on its
## documented stream separation and fail-closed behavior.
##
## @param args[] Command-line arguments supplied to the executable.
##
## @par STDIN
## Repository identifiers may be read when the command supports piped input.
## @par STDOUT
## The command-specific data or progress contract is written to STDOUT.
## @par STDERR
## Diagnostics are written to STDERR.
##
## @returns Command-specific output as documented by the executable contract.
##
## @retval 0 The command completed without a reported failure.
## @note Non-zero statuses from subordinate commands may be propagated when
## they are not explicitly translated by this function.
##
## @par Examples
## @code
## main --help
## @endcode
main() {
  capture_process_environment
  find_env_file_argument "$@"

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
  DRY_RUN="${DEFAULT_DRY_RUN}"
  VERBOSE="${DEFAULT_VERBOSE}"
  REPOSITORIES=()

  if [[ "${ENV_FILE_EXPLICIT}" == "true" ]]; then
    [[ -z "${ENV_FILE}" ]] || load_env_file "${ENV_FILE}"
  elif [[ -r .env ]]; then
    load_env_file .env
  fi

  apply_process_environment
  parse_options "$@"
  validate_configuration
  prepare_branch_patterns
  read_repositories_from_stdin

  ((${#REPOSITORIES[@]} > 0)) || die "No repositories supplied"
  prepare_repositories

  WORK_ROOT="$(mktemp -d)"
  readonly WORK_ROOT

  GIT_CONFIG_GLOBAL="${WORK_ROOT}/gitconfig-global"
  : >"${GIT_CONFIG_GLOBAL}"
  export GIT_CONFIG_GLOBAL
  export GIT_CONFIG_NOSYSTEM=1

  ALLOWED_SIGNERS_FILE="${WORK_ROOT}/allowed_signers"
  readonly ALLOWED_SIGNERS_FILE

  GIT_ASKPASS="${WORK_ROOT}/git-askpass"
  export GIT_ASKPASS
  export GIT_TERMINAL_PROMPT=0
  export GH_TOKEN

  trap 'rm -rf -- "${WORK_ROOT}"' EXIT

  if [[ "${GIT_TRANSPORT}" == "https" ]]; then
    create_git_askpass
  fi

  create_allowed_signers_file

  SIGNED_BRANCHES=0
  SKIPPED_BRANCHES=0
  FAILED_BRANCHES=0
  FAILED_REPOSITORIES=0
  ALREADY_SIGNED_BRANCHES=0
  HUMAN_BOUNDARY_BRANCHES=0
  RACE_SKIPPED_BRANCHES=0
  POLICY_REJECTED_BRANCHES=0
  NO_MATCHING_BRANCH_REPOSITORIES=0

  local repository
  for repository in "${REPOSITORIES[@]}"; do
    process_repository "${repository}"
  done

  printf '\nSummary:\n'
  printf '  Signed branches:            %d\n' "${SIGNED_BRANCHES}"
  printf '  Already signed branches:    %d\n' "${ALREADY_SIGNED_BRANCHES}"
  printf '  Human-boundary branches:    %d\n' "${HUMAN_BOUNDARY_BRANCHES}"
  printf '  Race-skipped branches:      %d\n' "${RACE_SKIPPED_BRANCHES}"
  printf '  Policy-rejected branches:   %d\n' "${POLICY_REJECTED_BRANCHES}"
  printf '  Other skipped branches:     %d\n' "$((SKIPPED_BRANCHES - ALREADY_SIGNED_BRANCHES - HUMAN_BOUNDARY_BRANCHES - RACE_SKIPPED_BRANCHES))"
  printf '  Repos without matching branch: %d\n' "${NO_MATCHING_BRANCH_REPOSITORIES}"
  printf '  Failed branches:            %d\n' "${FAILED_BRANCHES}"
  printf '  Failed repositories:        %d\n' "${FAILED_REPOSITORIES}"

  if ((FAILED_BRANCHES > 0 || FAILED_REPOSITORIES > 0)); then
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
