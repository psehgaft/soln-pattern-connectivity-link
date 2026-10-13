#!/usr/bin/env bash
set -euo pipefail

: "${LAGO_NAMESPACE:?Set LAGO_NAMESPACE}"
: "${LAGO_FRONT_IMAGE_TAG:?Set a unique tag for the built frontend image}"
BUILD_CONFIG="${LAGO_FRONT_BUILD_CONFIG:-lago-front-ocp}"
IMAGE_STREAM="${LAGO_FRONT_IMAGE_STREAM:-lago-front-ocp}"
CONTEXT="$(cd "$(dirname "${BASH_SOURCE[0]}")/front-image" && pwd)"

oc -n "$LAGO_NAMESPACE" patch bc "$BUILD_CONFIG" --type=merge \
  -p "{\"spec\":{\"output\":{\"to\":{\"name\":\"${IMAGE_STREAM}:${LAGO_FRONT_IMAGE_TAG}\"}}}}"
oc -n "$LAGO_NAMESPACE" start-build "$BUILD_CONFIG" \
  --from-dir="$CONTEXT" --follow
oc -n "$LAGO_NAMESPACE" get istag "${IMAGE_STREAM}:${LAGO_FRONT_IMAGE_TAG}"
