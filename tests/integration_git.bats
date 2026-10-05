#!/usr/bin/env bats

load test_helper.bash

@test "local git remote exposes unique ai branch to ls-remote patterns" {
  root="$BATS_TEST_TMPDIR/git"
  mkdir -p "$root"
  make_temp_repo "$root" repo
  (
    cd "$root/work"
    git checkout --quiet -b ai/integration
    printf '%s\n' integration >>README.md
    git commit --quiet -am integration
    git push --quiet origin ai/integration
  )
  run git ls-remote --heads "$root/repo.git" 'refs/heads/agent/*' 'refs/heads/ai/*' 'refs/heads/codex/*'
  [ "$status" -eq 0 ]
  [[ "$output" == *refs/heads/ai/integration* ]]
}

@test "local git worktree can identify commits unique to a machine branch" {
  root="$BATS_TEST_TMPDIR/git"
  mkdir -p "$root"
  make_temp_repo "$root" repo
  (
    cd "$root/work"
    git checkout --quiet -b codex/integration
    printf '%s\n' integration >>README.md
    git commit --quiet -am integration
    base="$(git merge-base main HEAD)"
    [ "$(git rev-list --count "$base..HEAD")" -eq 1 ]
  )
}
