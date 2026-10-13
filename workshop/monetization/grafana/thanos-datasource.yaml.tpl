apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: thanos
  namespace: ${GRAFANA_NAMESPACE}
spec:
  instanceSelector:
    matchLabels:
      ${GRAFANA_INSTANCE_LABEL_KEY}: ${GRAFANA_INSTANCE_LABEL_VALUE}
  datasource:
    name: ${GRAFANA_DATASOURCE_NAME}
    type: prometheus
    url: ${THANOS_URL}
    access: proxy
    isDefault: true
