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


## OpenShift deployment notes from the workshop environment

The files in `openshift/` capture the OpenShift-specific path that reached a deployed Lago release. Review the image tags, namespace, registry, and private Helm values for the target cluster before using them.

1. Copy `env/workshop.env.example` to a private file, edit it, and export its values in the current shell. Keep the Lago values file and API key outside Git.
2. The chart was installed at version `2.1.1`. API, migration, and frontend images were built/published to the cluster's internal image registry and selected with explicit image tags. The frontend build helper and `openshift/deploy-lago.sh` provide reusable commands. The API image tag must already exist in the internal registry.
3. The upstream `getlago/front:v1.41.0` image failed under OpenShift's `restricted-v2` SCC. Startup needed writable `/usr/share/nginx/html`, writable nginx cache paths, a non-privileged listener, and a writable PID file. `openshift/front-image/Dockerfile` prepares those paths, moves the listener to `8080`, and writes the PID file to `/tmp/nginx.pid`.
4. Run the helpers after exporting values from your private environment file:

```sh
set -a
source /path/to/workshop.env
set +a
bash workshop/monetization/openshift/build-front-image.sh
bash workshop/monetization/openshift/deploy-lago.sh
```

5. API and frontend Services were exposed as Routes, and both Routes were configured for edge TLS with HTTP redirected to HTTPS. If Routes do not already exist, expose them once, then apply TLS:

```sh
oc expose service/lago-front -n "$LAGO_NAMESPACE" --name="$LAGO_FRONT_ROUTE"
oc expose service/lago-api -n "$LAGO_NAMESPACE" --name="$LAGO_API_ROUTE"
for route in "$LAGO_FRONT_ROUTE" "$LAGO_API_ROUTE"; do
  oc patch route "$route" -n "$LAGO_NAMESPACE" --type=merge \
    -p '{"spec":{"tls":{"termination":"edge","insecureEdgeTerminationPolicy":"Redirect"}}}'
done
oc get routes -n "$LAGO_NAMESPACE"
```

6. The cluster had Grafana Operator, Thanos, and the Kuadrant Console plugin. The Grafana datasource resource was named `thanos`, its display name was `Thanos`, and it selected Grafana instances with `dashboards=grafana`. The datasource URL was the in-cluster Thanos Querier endpoint.

### Confirmed state and remaining validation

- **Confirmed:** the Lago Helm release reached `deployed`; API, frontend, worker, clock, Redis, and PostgreSQL pods were running; the migration Job completed; and the frontend Service had a ready endpoint on port `8080`.
- **Confirmed:** the separate PostgreSQL 15 test service using `getlago/postgres-partman:15.0-alpine` exposed `pg_partman` version `5.4.0`. This extension check alone does not prove which database URI Lago currently uses. Inspect active configuration without printing credentials before changing database settings.
- **Not confirmed:** successful Lago UI login, creation/retrieval of a Lago API key, or ingestion of a billable event. The attempted event returned HTTP 401 with an empty/invalid API key. Treat Lago billing as unverified end to end until a test key, test subscription, and successful event response are confirmed.
- **Not confirmed:** the PromQL series returning data through the cluster's Thanos endpoint. The Grafana datasource was inspected, but the attempted local Thanos API request returned HTTP `000`; that indicates the request did not complete, not that the selected metrics have zero traffic.
- Grafana dollar panels are **illustrative estimates**. They do not read Lago-rated totals and are not invoices.

### Grafana API-usage dashboard template

`grafana/api-usage-billing.json` is a standard Grafana import JSON. It includes filters for metrics job, reporter, destination service, API user, and API application, plus an editable example price per request. Render environment-specific defaults and validate the JSON before importing:

```sh
set -a
source /path/to/workshop.env
set +a
python3 workshop/monetization/grafana/render-api-dashboard.py > /tmp/api-usage-billing.json
python3 -m json.tool /tmp/api-usage-billing.json >/dev/null
```

Import the result in Grafana and select the `Thanos` datasource. The environment variables control job, reporter, dashboard UID/title, example tariff, and currency display. Destination service, API user, and API application populate from metric labels. Replace selectors with values visible in Grafana Explore if this cluster differs. If the series or labels are absent, panels will be empty. The estimated amount is request count multiplied by the editable sample tariff; it is not linked to a Lago invoice.

The optional datasource template `grafana/thanos-datasource.yaml.tpl` reflects the observed Grafana Operator resource. Review it with `oc explain grafanadatasource.spec --api-version=grafana.integreatly.org/v1beta1` before applying it to another operator version. To render just its environment placeholders:

```sh
envsubst '${GRAFANA_NAMESPACE} ${GRAFANA_INSTANCE_LABEL_KEY} ${GRAFANA_INSTANCE_LABEL_VALUE} ${GRAFANA_DATASOURCE_NAME} ${THANOS_URL}' \
  < workshop/monetization/grafana/thanos-datasource.yaml.tpl | oc apply -f -
```

Do not replace an existing datasource that has different credentials or TLS settings. Never put a bearer token in the dashboard or datasource URL.

### OpenShift Console and Connectivity Link

The `kuadrant-console-plugin` was added to the cluster Console operator's plugin list and its pod ran in `kuadrant-system`. Verify those facts and refresh the OpenShift Console:

```sh
oc get console.operator.openshift.io cluster -o json | jq '.spec.plugins'
oc get consoleplugins.console.openshift.io
oc get pods -n kuadrant-system | grep kuadrant-console-plugin
```

If it is not already listed and `.spec.plugins` is an array, enable the plugin with:

```sh
oc patch console.operator.openshift.io cluster --type=json \
  -p '[{"op":"add","path":"/spec/plugins/-","value":"kuadrant-console-plugin"}]'
```

The Kuadrant plugin exposes Connectivity Link/Kuadrant console features; it is not the Grafana monetization dashboard. Use Grafana for request and estimate panels, and the Console plugin for API connectivity and policy resources. A custom monetization page embedded inside the OpenShift Console was not implemented or verified in this workshop.

The environment's Grafana route was:
https://api-usage-api-observability.apps.cluster-p6pgn.dyn.redhatworkshops.io/d/api-usage-billing/api-usage-and-cost-estimate?orgId=1&from=now-1h&to=now&timezone=browser&refresh=30s
Use the route created in your own cluster instead of assuming that hostname remains valid.
