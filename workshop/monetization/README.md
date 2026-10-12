# Connectivity Link monetization workshop

This module compares four patterns using the Toy Store API from the core labs. Each option has a different purpose and operating model.

## What “monetization” means in each lab

- **Observe and estimate:** Prometheus and Grafana show request volume and an illustrative estimate. The ConfigMap stores dashboard settings. This is not a billing ledger.
- **Meter and bill events:** Lago ingests billable usage events and calculates customer/subscription usage.
- **Enforce commercial plans for AI inference:** Platform Billing Operator compiles billing plans into Kuadrant enforcement policies for its OpenShift AI Models-as-a-Service focus.
- **Analyze and monetize API traffic:** Moesif can capture Envoy/Istio API traffic and support analytics, usage meters, quotas, and billing workflows.

A Grafana time series is not invoice truth: counters can reset, scrapes can miss samples, and metric labels are not a durable customer ledger. Define billable events, identity, retries, deduplication, retention, and dispute handling before charging.

## Option 1 — Basic: ConfigMap + Prometheus + Grafana

This lab uses Istio's **istio_requests_total** counter for request-rate and status-code panels. It estimates a sample price per 1,000 successful responses.

1. Complete the core Connect lab so the **toystore** HTTPRoute receives traffic.
2. Confirm user-workload metrics are scraped and Grafana has a Prometheus data source.
3. Validate the metric series in Prometheus or Grafana Explore:

~~~promql
sum by (destination_workload_namespace, destination_workload) (
  increase(istio_requests_total{destination_workload="toystore"}[5m])
)
~~~

4. Set the namespace and illustrative tariff:

~~~sh
export NS=connectivity-link-workshop
kubectl apply -n "$NS" -f workshop/monetization/grafana/metering-config.yaml
~~~

5. Choose the namespace watched by the Grafana dashboard sidecar and publish the dashboard:

~~~sh
export GRAFANA_NS=grafana
NS="$NS" GRAFANA_NS="$GRAFANA_NS" bash workshop/monetization/grafana/install-dashboard.sh
~~~

6. If the Grafana instance does not watch labeled ConfigMaps, import the rendered JSON file manually in Grafana.
7. Send requests through the core workshop route. Inspect request rate, successful calls, non-2xx responses, and the estimate.

Change the demo price in **metering-config.yaml**. The script renders it into the dashboard. The unit is dollars per 1,000 successful calls. Labels and metric availability depend on the mesh and scrape configuration.

**Limit:** This does not create accounts, durable events, invoices, or payment collection. Do not use scraped counters as the sole billing source or label metrics with API keys, emails, or high-cardinality identities.

## Option 2 — Lago: usage events and billable metrics

Lago is an event-based billing platform. The included script sends five synthetic **api_requests** events to a Lago test subscription; each event has a unique transaction ID. The script demonstrates the event contract and does not connect the Connectivity Link request path to Lago.

1. Use a Lago test environment and test customer/subscription.
2. Create a billable metric with code **api_requests** and COUNT aggregation. Its code must match **LAGO_EVENT_CODE**.
3. Create a plan, price, customer, and subscription for that metric. Record the external subscription ID.
4. Load a test API key into your local shell or an approved secret store; never commit it:

~~~sh
export LAGO_URL=https://api.getlago.com
export LAGO_API_KEY='test-key-from-your-secret-store'
export LAGO_EXTERNAL_SUBSCRIPTION_ID='sub_test_001'
export LAGO_EVENT_CODE=api_requests
~~~

5. Submit the synthetic events:

~~~sh
bash workshop/monetization/lago/send-demo-events.sh
~~~

6. Inspect event ingestion and usage in the Lago test tenant.

For a real integration, use a durable asynchronous consumer that receives trusted application or gateway usage records, maps them to a customer/subscription, retries safely, and uses a stable unique transaction ID for deduplication. Do not call Lago synchronously for every API request.

## Option 3 — Platform Billing Operator (PBO)

The linked ArtifactHub package is version **0.0.1**. Upstream describes billing, metering, and FinOps for OpenShift AI Models-as-a-Service and compiling Plans into Kuadrant policies. Treat this route as a **preview/experimental evaluation**. Validate package source, support status, security posture, and compatibility with the exact OpenShift, RHCL/Kuadrant, and AI serving stack before use.

This is a focused fit for AI inference billing, including token-oriented usage, rather than a generic billing engine for every HTTP API.

1. Review the [ArtifactHub package](https://artifacthub.io/packages/olm/community-operators/platform-billing-operator/0.0.1) and upstream [getting started guide](https://github.com/rdwj/platform-billing-operator/blob/main/docs/getting-started.md).
2. In an isolated cluster, install only after platform owners approve its channel, image source, RBAC, and CRDs.
3. Create a PriceBook and Plan using the templates in **platform-billing-operator/**. Replace **REPLACE_WITH_FUTURE_UTC_TIMESTAMP** with a date later than current time plus **noticeDays**.
4. Target the Gateway in the Plan namespace unless the exact operator version documents another arrangement.
5. Inspect the Plan's **Compiled**, **Drifted**, or error conditions and generated Kuadrant policies.
6. For AI inference, generate test requests with known token usage and reconcile ledger/charges against the PriceBook. Do not activate real payment processing in this workshop.

The sample files are starting points for the upstream operator, not supported Red Hat product manifests.

## Option 4 — Moesif: Envoy/Istio capture and API monetization

Moesif provides API analytics and monetization. Its open source Envoy plugin has an Istio WASM example. The application ID and proxy selector must match your test environment.

1. Create a non-production Moesif application and obtain its Application ID.
2. Review the [Envoy WASM guide](https://www.moesif.com/docs/server-integration/envoy-wasm-plugin/) and [official Istio example](https://github.com/Moesif/moesif-envoy-wasm-plugin/tree/master/examples/istio).
3. Inspect labels on the actual Gateway proxy pods. Set **GATEWAY_POD_LABEL_KEY** and **GATEWAY_POD_LABEL_VALUE**. The upstream example's ingress selector may not match a Gateway API provider's data plane.
4. Render the plugin without committing the Application ID:

~~~sh
export MOESIF_APPLICATION_ID='test-app-id-from-secret-store'
export ISTIO_CONTROL_PLANE_NS=istio-system
export GATEWAY_POD_LABEL_KEY=istio
export GATEWAY_POD_LABEL_VALUE=ingressgateway
bash workshop/monetization/moesif/render-plugin.sh
~~~

5. Review the rendered manifest and current WasmPlugin compatibility. The renderer writes YAML to stdout for review; it does not install the plugin.
6. Apply only in a non-production mesh after approving the data path and selector. Send test traffic and verify events in the Moesif test application.
7. Configure a meter and quota in Moesif. Derive user/company identity from trusted authentication results; never trust arbitrary client headers.
8. Disable body capture or mask sensitive fields before real traffic. Test data-handling, retention, egress, and residency first.

The WASM plugin is external to Connectivity Link. Confirm its compatibility with the installed mesh, Gateway provider, Wasm runtime, and policies.

## Comparison

| Option | Best for | Produces | Billing-grade? |
| --- | --- | --- | --- |
| ConfigMap + Grafana | Basic usage dashboard | Prometheus panels and an estimate | No |
| Lago | Event/subscription billing | Billable usage events and rating | Yes, with durable and idempotent delivery |
| Platform Billing Operator | OpenShift AI MaaS | Billing plans, metering, ledger, policy compilation | For its stated target use case; verify maturity |
| Moesif | API analytics and monetization | Captured API events, meters, quotas, billing workflows | Depends on capture, identity, retention, and workflow |

## Cleanup

Remove the demo dashboard and usage ConfigMap from their namespaces. Delete any WasmPlugin and service-entry resources only if this workshop created them. Clean up Lago test events/subscriptions in the Lago test tenant.
