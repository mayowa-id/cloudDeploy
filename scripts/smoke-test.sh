#!/usr/bin/env bash
set -euo pipefail

base_url=${1:?Usage: smoke-test.sh BASE_URL [EXPECTED_COMMIT]}
expected_commit=${2:-}
base_url=${base_url%/}

request() {
  curl --fail --silent --show-error --connect-timeout 2 --max-time 5 \
    --retry 3 --retry-delay 1 --retry-all-errors "$base_url/$1"
}

request health | jq -e '.status == "ok"' >/dev/null
request ready | jq -e '.status == "ready"' >/dev/null
request version | jq -e --arg expected "$expected_commit" '
  .application == "clouddeploy" and (.version | type == "string" and length > 0)
  and (.commit | type == "string" and length > 0)
  and ($expected == "" or .commit == $expected)
' >/dev/null
printf 'CloudDeploy health, readiness, and version checks passed.\n'
