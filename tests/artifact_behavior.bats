#!/usr/bin/env bats

@test "artifact help succeeds" {
  run "$RAC_ARTIFACT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == Usage:* ]]
}

@test "artifact has generated build provenance" {
  grep -Fq 'RESIGN_AGENT_COMMITS_VERSION=' "$RAC_ARTIFACT"
  grep -Fq 'RESIGN_AGENT_COMMITS_BUILD_DATE=' "$RAC_ARTIFACT"
  grep -Fq 'RESIGN_AGENT_COMMITS_BUILD_COMMIT=' "$RAC_ARTIFACT"
}

@test "artifact is executable Bash" {
  [ -x "$RAC_ARTIFACT" ]
  run bash -n "$RAC_ARTIFACT"
  [ "$status" -eq 0 ]
}

@test "artifact checksum companion verifies" {
  checksum="${RAC_ARTIFACT}.sha256"
  [ -f "$checksum" ]
  (
    cd "$(dirname "$RAC_ARTIFACT")"
    sha256sum -c "$(basename "$checksum")"
  )
}
