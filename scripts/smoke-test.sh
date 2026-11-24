#!/usr/bin/env bash
#
# Post-deployment smoke test: liveness, readiness and greeting through the ALB.
#
# Usage: ./scripts/smoke-test.sh http://my-alb.eu-north-1.elb.amazonaws.com

set -euo pipefail

BASE_URL="${1:?usage: smoke-test.sh <base-url>}"
ATTEMPTS="${SMOKE_ATTEMPTS:-12}"
DELAY="${SMOKE_DELAY_SECONDS:-5}"

check() {
  local path="$1"

  local body
  body=$(curl --silent --show-error --fail --max-time 5 "${BASE_URL}${path}")
  printf '%s' "$body"
}

for attempt in $(seq 1 "$ATTEMPTS"); do
  health=$(check /health || true)
  ready=$(check /ready || true)
  root=$(check / || true)

  if [[ "$health" == *'"status":"ok"'* ]] \
    && [[ "$ready" == *'"status":"ready"'* ]] \
    && [[ "$root" == "Hello from ECS on Fargate!"* ]]; then
    echo "Smoke test passed against ${BASE_URL} (attempt ${attempt}/${ATTEMPTS})"
    exit 0
  fi

  echo "Attempt ${attempt}/${ATTEMPTS} failed, retrying in ${DELAY}s..."
  sleep "$DELAY"
done

echo "::error::Smoke test failed against ${BASE_URL} after ${ATTEMPTS} attempts"
echo "Last /health response: ${health:-<empty>}"
echo "Last /ready response: ${ready:-<empty>}"
exit 1
