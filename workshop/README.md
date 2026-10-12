# Red Hat Connectivity Link workshop

A hands-on workshop for platform engineers and application developers. The labs use Kubernetes Gateway API and Kuadrant policy resources, the foundation of Red Hat Connectivity Link (RHCL).

> **Environment note:** these labs assume an OpenShift cluster where the RHCL/Kuadrant components and a Gateway API provider are already installed and healthy. Operator installation is cluster-admin work and is intentionally kept separate from the application labs. Follow the supported product documentation for the exact RHCL release and your environment.

## Outcomes

By the end, participants will be able to:

- Explain the responsibilities of GatewayClass, Gateway, HTTPRoute, and policy resources.
- Onboard an HTTP service behind a Gateway.
- Require API-key authentication and authorize route access.
- Apply authenticated rate limits and observe HTTP 401, 403, 200, and 429 outcomes.
- Inspect policy and route status and diagnose common attachment issues.
- Describe where TLS, DNS, observability, and multi-cluster capabilities fit.

## Workshop at a glance

| Lab | Topic | Persona |
| --- | --- | --- |
| 0 | Preflight and cluster access | Platform engineer |
| 1 | Deploy the sample API and connect it with Gateway API | Platform engineer + developer |
| 2 | Authenticate requests with API keys | Developer |
| 3 | Rate limit each authenticated user | Developer |
| 4 | Apply a platform default deny policy | Platform engineer |
| 5 | TLS, DNS, observability, and multi-cluster discussion | Platform engineer |
| 6 | Verify behavior and clean up | Everyone |

Suggested delivery: 3 hours, including breaks and discussion. Use the files in `manifests/` in numeric order.

## 0. Preflight

### Required

- OpenShift 4.16+ or a Kubernetes cluster supported by the installed RHCL release.
- `oc` (or `kubectl`), `curl`, and permission to create a namespace, Deployment, Service, Gateway, HTTPRoute, Secret, AuthPolicy, and RateLimitPolicy.
- RHCL/Kuadrant CRDs and controllers installed, including AuthPolicy and RateLimitPolicy.
- A Gateway API provider and a GatewayClass named `istio`. If your environment uses another class, edit `manifests/20-gateway-route.yaml`.
- Cluster-admin/operator tasks completed before attendees arrive. A live DNS zone and certificate issuer are optional for this base exercise.

Check the APIs and class:

```sh
kubectl api-resources | grep -E 'gatewayclasses|gateways|httproutes|authpolicies|ratelimitpolicies'
kubectl get gatewayclass istio
kubectl get pods -A | grep -E 'kuadrant|authorino|limitador|istio'
```

The GatewayClass must be accepted and the relevant controller pods must be ready. If an API is absent or pods are unhealthy, pause and resolve the platform setup before starting the labs.

For installation and platform setup, use the repository's [Platform Engineer workflow](../documentation/modules/ROOT/pages/03.1-platform.adoc) and the current [Red Hat Connectivity Link documentation](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/).

### Start the workshop

From the repository root, choose a namespace. The examples deliberately omit `metadata.namespace` so they can be applied to the selected namespace.

```sh
export NS=connectivity-link-workshop
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "$NS" -f workshop/manifests/10-app.yaml
kubectl rollout status -n "$NS" deployment/toystore --timeout=180s
kubectl apply -n "$NS" -f workshop/manifests/20-gateway-route.yaml
```

The default test hostname is `api.toystore.test`. It does not need public DNS: the verification script port-forwards to the Gateway service and sends the HTTP Host header.

## 1. Connect an application

Inspect `manifests/10-app.yaml` and `manifests/20-gateway-route.yaml`.

1. Identify which team owns the Deployment/Service, Gateway, and HTTPRoute.
2. Apply the manifests as shown above.
3. Check that the Gateway has `Accepted=True` and `Programmed=True`.
4. Check that the HTTPRoute has `Accepted=True` and `ResolvedRefs=True`.
5. Before applying security policies, test the route using the verification script:

```sh
bash workshop/scripts/verify.sh route
```

Expected result: an HTTP 200 from the sample API. The script discovers the generated `kuadrant-<gateway>-istio` Service; if your provider names its Service differently, set `GATEWAY_SERVICE` to its name.

## 2. Secure the API with API keys

The workshop uses two intentionally fake keys. Apply the AuthPolicy and secrets:

```sh
kubectl apply -n "$NS" -f workshop/manifests/30-auth-policy.yaml
kubectl apply -n "$NS" -f workshop/manifests/31-demo-api-keys.yaml
kubectl wait -n "$NS" authpolicy/toystore --for=condition=Accepted --timeout=180s
NS="$NS" bash workshop/scripts/verify.sh auth
```

Observe the expected behavior:

- No key: `401 Unauthorized`.
- Alice's or Bob's valid key: `200 OK`.

Discuss the separation between authentication (who presented a valid credential) and authorization (what that identity is allowed to do). The API key strings are public training values. Never use them outside an isolated lab, and never commit real credentials to Git.

## 3. Protect the service with per-user rate limits

Apply the policy:

```sh
kubectl apply -n "$NS" -f workshop/manifests/40-rate-limit.yaml
kubectl wait -n "$NS" ratelimitpolicy/toystore --for=condition=Accepted --timeout=180s
NS="$NS" bash workshop/scripts/verify.sh limits
```

Alice is allowed 5 requests per 10 seconds and Bob 2 requests per 10 seconds. The script sends requests quickly and expects the next request to receive `429 Too Many Requests`. Wait at least 10 seconds before repeating a user's test.

## 4. Platform default-deny policy

Apply `manifests/50-gateway-default-deny.yaml`. It creates a second route with no application AuthPolicy. The Gateway policy protects that route by default, while the Toy Store route keeps its more-specific application policy.

```sh
kubectl apply -n "$NS" -f workshop/manifests/50-gateway-default-deny.yaml
kubectl wait -n "$NS" authpolicy/gateway-default-deny --for=condition=Accepted --timeout=180s
NS="$NS" bash workshop/scripts/verify.sh default-deny
```

Expected result: a request to the unprotected route returns `403 Forbidden`. Inspect the target, scope, and status:

```sh
kubectl get authpolicy -n "$NS" -o wide
kubectl describe authpolicy gateway-default-deny -n "$NS"
kubectl get httproute,gateway -n "$NS" -o yaml
```

## 5. Extend the workshop: TLS, DNS, observability, multi-cluster

These are instructor-led extension labs because they need environment-specific infrastructure:

- **TLS:** install/verify cert-manager and a supported issuer, then create a `TLSPolicy` targeting the Gateway. Use a test issuer in a lab. Do not point a workshop at production ACME without an approved DNS/hostname plan.
- **DNS:** configure a DNS provider credential as a Kubernetes Secret and a `DNSPolicy` targeting the Gateway. Use a delegated test zone and least-privilege credentials; do not commit credentials.
- **Observability:** inspect Gateway, route, AuthPolicy, RateLimitPolicy conditions; correlate 401/403/429 responses; review the RHCL/Kuadrant dashboards and metrics. Enable user-workload monitoring only according to the cluster's platform policy.
- **Multi-cluster:** compare the single-cluster route/policy workflow with the multi-cluster DNS/load-balancing topology. Add a second cluster only when the workshop environment has the required control plane, DNS, and health-check setup.

Use the existing [Platform Engineer](../documentation/modules/ROOT/pages/03.1-platform.adoc), [Developer](../documentation/modules/ROOT/pages/03.2-developer.adoc), and [Observability](../documentation/modules/ROOT/pages/03.3-observability.adoc) walkthroughs as the guided extension material.

## 6. Verify and clean up

After all policies are applied:

```sh
NS="$NS" bash workshop/scripts/verify.sh all
kubectl delete namespace "$NS"
```

Deleting the namespace removes workshop app resources, routes, policies, and training API-key Secrets. It does not uninstall cluster-scoped operators or CRDs.

## Optional monetization track

Continue with [the monetization workshop](../documentation/modules/ROOT/pages/05-monetization.adoc) and the runnable examples under `workshop/monetization/`. It covers ConfigMap and Grafana usage estimates, Lago usage events, Platform Billing Operator for AI inference, and Moesif API analytics.

## Troubleshooting checklist

- `GatewayClass`: exists and is accepted by the intended provider.
- `Gateway`: `Accepted=True`, `Programmed=True`; check its addresses and generated Service.
- `HTTPRoute`: `Accepted=True`, `ResolvedRefs=True`; verify hostname, parentRef, and backend Service port.
- `AuthPolicy` / `RateLimitPolicy`: inspect conditions and events; verify target kind/name/namespace and policy CRD version.
- Authentication: the Secret must match the policy's label selector, contain `api_key`, and carry the identity annotation.
- Rate limit: authenticated identity must be present in the successful AuthPolicy response and match the expression in the RateLimitPolicy.
- Allow a short reconciliation delay after applying policy resources. Check controller logs only with appropriate access.

## References

- [RHCL product documentation](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/)
- [Kuadrant AuthPolicy overview](https://docs.kuadrant.io/1.2.x/kuadrant-operator/doc/overviews/auth/)
- [Kuadrant RateLimitPolicy overview](https://docs.kuadrant.io/1.2.x/kuadrant-operator/doc/overviews/rate-limiting/)
- [AuthPolicy tutorial](https://docs.kuadrant.io/1.2.x/kuadrant-operator/doc/user-guides/auth/auth-for-app-devs-and-platform-engineers/)
- [Authenticated rate limiting tutorial](https://docs.kuadrant.io/1.2.x/kuadrant-operator/doc/user-guides/ratelimiting/authenticated-rl-for-app-developers/)
