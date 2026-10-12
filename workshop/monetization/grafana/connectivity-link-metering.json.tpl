{
  "__inputs": [
    {
      "name": "DS_PROMETHEUS",
      "label": "Prometheus",
      "description": "",
      "type": "datasource",
      "pluginId": "prometheus",
      "pluginName": "Prometheus"
    }
  ],
  "annotations": {"list": []},
  "editable": true,
  "graphTooltip": 1,
  "panels": [
    {
      "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
      "fieldConfig": {"defaults": {"unit": "reqps", "color": {"mode": "palette-classic"}}, "overrides": []},
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "id": 1,
      "targets": [
        {
          "expr": "sum by (response_code) (rate(istio_requests_total{destination_workload=\"toystore\",destination_workload_namespace=\"connectivity-link-workshop\"}[5m]))",
          "legendFormat": "{{response_code}}",
          "refId": "A"
        }
      ],
      "title": "Toy Store requests per second by response code",
      "type": "timeseries"
    },
    {
      "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
      "fieldConfig": {"defaults": {"unit": "short", "color": {"mode": "thresholds"}}, "overrides": []},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
      "id": 2,
      "targets": [
        {
          "expr": "sum(increase(istio_requests_total{destination_workload=\"toystore\",destination_workload_namespace=\"connectivity-link-workshop\",response_code=~\"2..\"}[$__range]))",
          "legendFormat": "successful requests",
          "refId": "A"
        }
      ],
      "title": "Successful requests in selected time range",
      "type": "stat"
    },
    {
      "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
      "fieldConfig": {"defaults": {"unit": "currencyUSD", "decimals": 4, "color": {"mode": "thresholds"}}, "overrides": []},
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
      "id": 3,
      "targets": [
        {
          "expr": "sum(increase(istio_requests_total{destination_workload=\"toystore\",destination_workload_namespace=\"connectivity-link-workshop\",response_code=~\"2..\"}[$__range])) * __PRICE_PER_1000_SUCCESSFUL_REQUESTS_USD__ / 1000",
          "legendFormat": "estimated gross amount",
          "refId": "A"
        }
      ],
      "title": "Illustrative gross estimate (successful requests × sample tariff)",
      "type": "stat"
    },
    {
      "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
      "fieldConfig": {"defaults": {"unit": "short", "color": {"mode": "thresholds"}}, "overrides": []},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
      "id": 4,
      "targets": [
        {
          "expr": "sum(increase(istio_requests_total{destination_workload=\"toystore\",destination_workload_namespace=\"connectivity-link-workshop\",response_code=~\"4..|5..\"}[$__range]))",
          "legendFormat": "non-2xx requests",
          "refId": "A"
        }
      ],
      "title": "Non-2xx requests in selected time range",
      "type": "stat"
    }
  ],
  "schemaVersion": 39,
  "tags": ["connectivity-link", "workshop", "estimate"],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "title": "Connectivity Link API usage — workshop estimate",
  "version": 1
}
