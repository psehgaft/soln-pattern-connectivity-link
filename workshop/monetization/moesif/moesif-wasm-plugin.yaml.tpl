apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: moesif-workshop
  namespace: ${ISTIO_CONTROL_PLANE_NS}
spec:
  selector:
    matchLabels:
      ${GATEWAY_POD_LABEL_KEY}: ${GATEWAY_POD_LABEL_VALUE}
  url: oci://docker.io/moesif/moesif-envoy-wasm-plugin:latest
  imagePullPolicy: Always
  phase: AUTHZ
  priority: 10
  pluginConfig:
    moesif_application_id: ${MOESIF_APPLICATION_ID}
    upstream: outbound|443||api.moesif.net
    debug: false
