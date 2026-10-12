#!/usr/bin/env bash
set -euo pipefail

: "${LAGO_API_KEY:?Set LAGO_API_KEY from a test secret store}"
: "${LAGO_EXTERNAL_SUBSCRIPTION_ID:?Set a test external subscription ID}"
LAGO_URL="${LAGO_URL:-https://api.getlago.com}"
LAGO_EVENT_CODE="${LAGO_EVENT_CODE:-api_requests}"

command -v curl >/dev/null || { echo "curl is required."; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required."; exit 1; }

for i in 1 2 3 4 5; do
  payload=$(python3 - "$LAGO_EXTERNAL_SUBSCRIPTION_ID" "$LAGO_EVENT_CODE" "$i" <<'PY'
import json, sys, time, uuid
subscription, code, sequence = sys.argv[1:]
print(json.dumps({"event": {
    "transaction_id": f"cl-workshop-{uuid.uuid4()}",
    "external_subscription_id": subscription,
    "code": code,
    "timestamp": int(time.time()),
    "properties": {
        "source": "connectivity-link-workshop",
        "demo_sequence": int(sequence),
        "meter": "successful_api_request"
    }
}}))
PY
)
  printf 'Submitting synthetic Lago event %s/5...\n' "$i"
  curl --fail-with-body --silent --show-error \
    --request POST "$LAGO_URL/api/v1/events" \
    --header "Authorization: Bearer $LAGO_API_KEY" \
    --header 'Content-Type: application/json' \
    --data "$payload"
  printf '\n'
done
