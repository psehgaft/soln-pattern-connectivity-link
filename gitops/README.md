# GitOps playbook: Connectivity Link workshop

This playbook installs the workshop application resources with OpenShift GitOps (Argo CD). It keeps the lab configuration in Git and lets Argo CD reconcile it into the cluster.

> **Scope:** this configures the workshop namespace and sample API, Gateway API objects, and Kuadrant policies. It does not install cluster operators, Gateway API CRDs, or an Istio/Gateway controller. Install and validate those platform components using the supported product versions before importing the Applications below.

## Prerequisites

- OpenShift cluster with **Red Hat Connectivity Link** installed and its Kuadrant components healthy.
- A Gateway API provider installed and a ready <code>GatewayClass</code> named <code>istio</code>. If your provider uses another name, change <code>gatewayClassName</code> in <code>workshop/manifests/20-gateway-route.yaml</code>.
- OpenShift GitOps installed, with its Argo CD instance available in the <code>openshift-gitops</code> namespace.
- Cluster permissions for the GitOps controller to create the workshop namespace and its namespaced resources.
- This repository reachable from the cluster. The sample Application uses the public GitHub repository and the <code>main</code> branch.

Install Connectivity Link and the platform operators using the current [Red Hat Connectivity Link installation guide](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.4/html/install_connectivity_link_on_openshift/). For OpenShift GitOps, follow the [Red Hat OpenShift GitOps documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops/1.20/html-single/).

Check readiness:

~~~sh
oc get clusterversion
oc get gatewayclass istio
oc get pods -A | grep -E 'kuadrant|authorino|limitador|istio'
oc get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
oc get crd authpolicies.kuadrant.io ratelimitpolicies.kuadrant.io
oc get pods -n openshift-gitops
~~~

Do not continue until the GatewayClass is accepted and the relevant controllers are ready. Product/operator installation is deliberately separate because it is cluster scoped and release-specific.

## Install the workshop application

From a clone of this repository, create the Argo CD Application:

~~~sh
oc apply -f gitops/bootstrap/application.yaml
oc get application connectivity-link-workshop -n openshift-gitops -w
~~~

The Application points to <code>workshop</code>. Its Kustomize entrypoint, <code>workshop/kustomization.yaml</code>, applies the manifests in <code>workshop/manifests/</code>, so the workshop YAML has one source of truth. Argo CD creates the <code>connectivity-link-workshop</code> namespace, labels it for the default OpenShift GitOps instance, and continuously reconciles the resources.

The Application enables automated sync, pruning, and self-healing:

- A committed Git change is applied to the cluster.
- A live change made outside Git is reverted to the Git version.
- A resource removed from the Kustomize resources is pruned from the workshop namespace.
- Deleting the Application cascades to resources it manages. The namespace may remain; remove it explicitly after cleanup.

> **Training credentials:** <code>workshop/manifests/31-demo-api-keys.yaml</code> contains public fake values for this exercise. Never put real API keys or customer secrets in Git. For a real environment, replace the demo Secret resources with an approved secret manager integration such as External Secrets Operator or Sealed Secrets.

## Validate deployment

Wait until the app is synced, then verify the Kubernetes and Connectivity Link conditions:

~~~sh
oc get application connectivity-link-workshop -n openshift-gitops
oc get deployment,service,gateway,httproute,authpolicy,ratelimitpolicy -n connectivity-link-workshop
oc get gateway workshop -n connectivity-link-workshop -o yaml
oc get httproute toystore -n connectivity-link-workshop -o yaml
oc get authpolicy,ratelimitpolicy -n connectivity-link-workshop -o yaml
~~~

Expected conditions:

- <code>Deployment/toystore</code> is available.
- <code>Gateway/workshop</code> reports <code>Accepted=True</code> and <code>Programmed=True</code>.
- Each <code>HTTPRoute</code> reports <code>Accepted=True</code> and <code>ResolvedRefs=True</code>.
- AuthPolicy and RateLimitPolicy resources report <code>Accepted=True</code>.

Allow time for controller reconciliation. Argo CD sync waves order resource submission; they do not replace checking the Gateway API and policy status conditions.

The verification script expects a route to return HTTP 200, missing API keys to return 401, valid keys to work, and configured rate limits to return 429:

~~~sh
NS=connectivity-link-workshop bash workshop/scripts/verify.sh all
~~~

For port-forward-based checks, run the script from a local clone with <code>oc</code>/<code>kubectl</code> access to the cluster. See [the workshop guide](../workshop/README.md) for lab steps and troubleshooting.

## Optional: publish the basic Grafana metering ConfigMap

The Grafana example is an estimate based on Prometheus metrics, not a billing ledger. It assumes user-workload metrics are available and Grafana watches labeled ConfigMaps in the workshop namespace.

After the core Application is healthy, apply the optional Application:

~~~sh
oc apply -f gitops/bootstrap/grafana-application.yaml
oc get application connectivity-link-grafana-metering -n openshift-gitops -w
~~~

It applies the sample <code>connectivity-link-metering</code> ConfigMap. Follow [the Grafana metering lab](../workshop/monetization/README.md) to render/import the dashboard and validate request metrics. Do not treat estimated dashboard values as invoice data.

## Other monetization options

Lago and Moesif require external tenant/API credentials; keep those credentials in an approved secret manager and use the supplied demo scripts from a trusted runner. The Platform Billing Operator example is an upstream preview/experimental path and should be reviewed for compatibility and support before installing its cluster-scoped operator. These are optional integrations and are not part of the core Application.

## Uninstall the lab

Remove the Applications from the GitOps control namespace. The finalizer deletes the namespaced resources each Application manages:

~~~sh
oc delete -f gitops/bootstrap/grafana-application.yaml --ignore-not-found
oc delete -f gitops/bootstrap/application.yaml --ignore-not-found
oc delete namespace connectivity-link-workshop --ignore-not-found
~~~

This removes only workshop resources; it does not uninstall Connectivity Link, the Gateway provider, GitOps, CRDs, or other cluster services.
