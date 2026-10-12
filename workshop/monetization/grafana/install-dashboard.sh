#!/usr/bin/env bash
set -euo pipefail

KCTL="${KUBECTL:-$(command -v kubectl || command -v oc || true)}"
NS="${NS:-connectivity-link-workshop}"
GRAFANA_NS="${GRAFANA_NS:-grafana}"
CONFIGMAP="${CONFIGMAP:-connectivity-link-metering}"
DASHBOARD_CONFIGMAP="${DASHBOARD_CONFIGMAP:-connectivity-link-metering-dashboard}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="$ROOT/monetization/grafana/connectivity-link-metering.json.tpl"

[[ -n "$KCTL" ]] || { echo "kubectl or oc is required."; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required."; exit 1; }
RATE=$("$KCTL" -n "$NS" get configmap "$CONFIGMAP" -o jsonpath='{.data.price_per_1000_successful_requests_usd}')
[[ "$RATE" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "Invalid demo tariff in ConfigMap: $RATE"; exit 1; }
"$KCTL" get namespace "$GRAFANA_NS" >/dev/null || { echo "Grafana namespace $GRAFANA_NS was not found."; exit 1; }

OUTPUT="${TMPDIR:-/tmp}/connectivity-link-metering-dashboard.json"
python3 - "$TEMPLATE" "$OUTPUT" "$RATE" <<'PY'
import json, pathlib, sys
template = pathlib.Path(sys.argv[1]).read_text()
output = pathlib.Path(sys.argv[2])
rate = sys.argv[3]
rendered = template.replace("__PRICE_PER_1000_SUCCESSFUL_REQUESTS_USD__", rate)
json.loads(rendered)
output.write_text(rendered)
PY

"$KCTL" -n "$GRAFANA_NS" create configmap "$DASHBOARD_CONFIGMAP" \
  --from-file=connectivity-link-metering.json="$OUTPUT" \
  --dry-run=client -o yaml | "$KCTL" apply -f -
"$KCTL" -n "$GRAFANA_NS" label configmap "$DASHBOARD_CONFIGMAP" grafana_dashboard=1 --overwrite
echo "Dashboard ConfigMap published. Rendered JSON: $OUTPUT"
echo "Grafana must have a dashboard sidecar watching ConfigMaps labeled grafana_dashboard=1."
