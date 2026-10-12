#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-connectivity-link-workshop}"
GATEWAY_NAME="${GATEWAY_NAME:-workshop}"
GATEWAY_SERVICE="${GATEWAY_SERVICE:-kuadrant-${GATEWAY_NAME}-istio}"
HOST="${HOST:-api.toystore.test}"
BLOCKED_HOST="${BLOCKED_HOST:-blocked.toystore.test}"
LOCAL_PORT="${LOCAL_PORT:-9080}"
MODE="${1:-all}"
KCTL="${KUBECTL:-$(command -v kubectl || command -v oc || true)}"

[[ -n "$KCTL" ]] || { echo "kubectl or oc is required."; exit 1; }
command -v curl >/dev/null || { echo "curl is required."; exit 1; }

"$KCTL" -n "$NS" get svc "$GATEWAY_SERVICE" >/dev/null || {
  echo "Gateway service $GATEWAY_SERVICE was not found in namespace $NS."
  echo "Find the generated service with: $KCTL get svc -A | grep '$GATEWAY_NAME'"
  echo "Then rerun with GATEWAY_SERVICE=<service-name>."
  exit 1
}

"$KCTL" -n "$NS" port-forward "svc/$GATEWAY_SERVICE" "$LOCAL_PORT:80" >/tmp/cl-workshop-port-forward.log 2>&1 &
PF_PID=$!
cleanup() { kill "$PF_PID" >/dev/null 2>&1 || true; }
trap cleanup EXIT
for _ in $(seq 1 30); do
  if curl --silent --output /dev/null "http://127.0.0.1:$LOCAL_PORT/" 2>/dev/null; then break; fi
  sleep 1
done

request() {
  local key="${1:-}"
  local host="${2:-$HOST}"
  local code
  if [[ -n "$key" ]]; then
    code=$(curl --silent --output /dev/null --write-out '%{http_code}' \
      -H "Host: $host" -H "Authorization: APIKEY $key" \
      "http://127.0.0.1:$LOCAL_PORT/toy")
  else
    code=$(curl --silent --output /dev/null --write-out '%{http_code}' \
      -H "Host: $host" "http://127.0.0.1:$LOCAL_PORT/toy")
  fi
  printf '%s' "$code"
}

case "$MODE" in
  route)
    code=$(request)
    [[ "$code" == "200" ]] || { echo "Expected 200 before AuthPolicy; received $code"; exit 1; }
    echo "PASS: unauthenticated route returned HTTP 200."
    ;;
  auth)
    code=$(request)
    [[ "$code" == "401" ]] || { echo "Expected 401 without API key; received $code"; exit 1; }
    for key in IAMALICE IAMBOB; do
      code=$(request "$key")
      [[ "$code" == "200" ]] || { echo "Expected 200 for $key; received $code"; exit 1; }
    done
    echo "PASS: no key returned 401; Alice and Bob returned 200."
    ;;
  limits)
    for spec in "IAMALICE 5" "IAMBOB 2"; do
      read -r key allowed <<< "$spec"
      sleep 11
      echo "Checking $key (expected $allowed successful requests, then 429)..."
      for ((i=1; i<=allowed; i++)); do
        code=$(request "$key")
        [[ "$code" == "200" ]] || { echo "Expected 200 on request $i; received $code"; exit 1; }
        sleep 0.1
      done
      code=$(request "$key")
      [[ "$code" == "429" ]] || { echo "Expected 429 after $allowed requests; received $code"; exit 1; }
    done
    echo "PASS: per-user rate limits returned 429 at the configured thresholds."
    ;;
  default-deny)
    code=$(request "" "$BLOCKED_HOST")
    [[ "$code" == "403" ]] || { echo "Expected 403 from the Gateway default-deny policy; received $code"; exit 1; }
    echo "PASS: route without an application AuthPolicy returned HTTP 403."
    ;;
  all)
    "$0" auth
    "$0" limits
    "$0" default-deny
    ;;
  *)
    echo "Usage: $0 [route|auth|limits|default-deny|all]"
    exit 2
    ;;
esac
