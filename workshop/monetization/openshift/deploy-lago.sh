#!/usr/bin/env bash
set -euo pipefail

: "${LAGO_NAMESPACE:?Set LAGO_NAMESPACE}"
: "${LAGO_RELEASE:?Set LAGO_RELEASE}"
: "${LAGO_CHART_VERSION:?Set LAGO_CHART_VERSION}"
: "${LAGO_VALUES_FILE:?Set LAGO_VALUES_FILE to your private values file}"
: "${OPENSHIFT_REGISTRY:?Set OPENSHIFT_REGISTRY}"
: "${LAGO_IMAGE_PROJECT:?Set LAGO_IMAGE_PROJECT}"
: "${LAGO_API_IMAGE_TAG:?Set LAGO_API_IMAGE_TAG}"
: "${LAGO_FRONT_IMAGE_TAG:?Set LAGO_FRONT_IMAGE_TAG}"
: "${LAGO_FRONT_HTTP_PORT:?Set LAGO_FRONT_HTTP_PORT}"

API_IMAGE="${OPENSHIFT_REGISTRY}/${LAGO_IMAGE_PROJECT}/lago-api-ocp"
FRONT_IMAGE="${OPENSHIFT_REGISTRY}/${LAGO_IMAGE_PROJECT}/lago-front-ocp"

helm upgrade --install "$LAGO_RELEASE" lago/lago \
  --version "$LAGO_CHART_VERSION" \
  --namespace "$LAGO_NAMESPACE" \
  --values "$LAGO_VALUES_FILE" \
  --set-string "api.image.repository=$API_IMAGE" \
  --set-string "api.image.tag=$LAGO_API_IMAGE_TAG" \
  --set-string "migrate.image.repository=$API_IMAGE" \
  --set-string "migrate.image.tag=$LAGO_API_IMAGE_TAG" \
  --set-string "front.image.repository=$FRONT_IMAGE" \
  --set-string "front.image.tag=$LAGO_FRONT_IMAGE_TAG" \
  --set "front.container.ports.http=$LAGO_FRONT_HTTP_PORT" \
  --wait --wait-for-jobs --timeout 15m

echo "Check pods: oc get pods -n $LAGO_NAMESPACE"
echo "Check Jobs: oc get jobs -n $LAGO_NAMESPACE"
echo "Check release: helm status $LAGO_RELEASE -n $LAGO_NAMESPACE"
