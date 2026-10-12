#!/usr/bin/env bash
set -euo pipefail

: "${MOESIF_APPLICATION_ID:?Set the non-production Moesif Application ID from an approved secret store}"
: "${ISTIO_CONTROL_PLANE_NS:?Set the Istio control-plane namespace}"
: "${GATEWAY_POD_LABEL_KEY:?Set a label key from the actual Gateway proxy pods}"
: "${GATEWAY_POD_LABEL_VALUE:?Set the matching label value}"
command -v python3 >/dev/null || { echo "python3 is required."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/moesif-wasm-plugin.yaml.tpl"
python3 - "$TEMPLATE" <<'PY'
import os, pathlib, sys
content = pathlib.Path(sys.argv[1]).read_text()
for name in ("ISTIO_CONTROL_PLANE_NS", "GATEWAY_POD_LABEL_KEY", "GATEWAY_POD_LABEL_VALUE", "MOESIF_APPLICATION_ID"):
    content = content.replace("${" + name + "}", os.environ[name])
if "${" in content:
    raise SystemExit("Unexpanded template variable remains")
print(content, end="")
PY
