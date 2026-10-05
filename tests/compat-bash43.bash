#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

: "${RAC_ARTIFACT:?RAC_ARTIFACT is required}: RAC_ARTIFACT is required"

bash -n "$RAC_ARTIFACT"
"$RAC_ARTIFACT" --help >/dev/null
