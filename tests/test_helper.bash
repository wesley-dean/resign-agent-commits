#!/usr/bin/env bash
# shellcheck shell=bash

setup_artifact() {
  [[ -n "${RAC_ARTIFACT:-}" ]] || {
    printf '%s\n' 'RAC_ARTIFACT is required' >&2
    return 1
  }

  # shellcheck disable=SC1090
  source "${RAC_ARTIFACT}"
}

require_function() {
  local name="$1"
  declare -F "${name}" >/dev/null 2>&1 || skip "${name} is not part of this artifact"
}

make_temp_repo() {
  local root="$1"
  local name="$2"

  git init --quiet --bare "${root}/${name}.git"
  git init --quiet "${root}/work"
  (
    cd "${root}/work" || exit 1
    git config user.name "Test Agent"
    git config user.email "agent@example.test"
    printf '%s\n' initial >README.md
    git add README.md
    git commit --quiet -m "initial"
    git branch -M main
    git remote add origin "${root}/${name}.git"
    git push --quiet -u origin main
    git --git-dir="${root}/${name}.git" symbolic-ref HEAD refs/heads/main
  )
}
