# Trellis Software — audit trail reconstruction

Audit references below are 1-based physical line numbers in `latchkey/trellis-audit.jsonl`. All cited events have response code 200 and authorization decision `allow`.

| Order | Record | Interpretation |
|---|---|---|
| 1 | Line 826, auditID `fc732b41831c35c`, `2026-10-25T14:00:00Z`: `system:serviceaccount:build:ci-runner` creates Pod `platform/debug-shell-x7k2`. | This is the first out-of-pattern action: CI's normal repetitive API use is in `build`, but it creates a Pod in `platform`. `ci-runner-platform-deploy` grants Pod create in platform, and that Role also grants ServiceAccount get/list. |
| 2 | Line 828, auditID `c22c0094a42c174`, `14:02Z`: the same CI identity gets `serviceaccounts/platform/controller-admin`. | This is an unusual identity lookup immediately after the platform Pod creation. `platform-deployer` permits this lookup. |
| 3 | Line 829, auditID `a55c4295ef26154`, `14:05Z`: `system:serviceaccount:platform:controller-admin` lists Secrets cluster-wide (audit objectRef's namespace is `kube-system`, name empty). | The actor has changed to the privileged ServiceAccount. `platform-controller-admin` binds it to `cluster-superuser`. The audit namespace field on a list is not evidence that the resulting RBAC permission is namespace-limited. |
| 4 | Line 830, auditID `50169ea038b7cff`, `14:06Z`: controller-admin gets `prod/orders-api-token`. | Concrete access to a named Secret in a second namespace, allowed by the wildcard ClusterRole grant. |

The most useful distinguishing signal is **identity behavior out of profile**: `build/ci-runner`, whose workload is `workloads/build/deployments.yaml` Deployment `ci-runner`, begins creating a Pod and resolving a ServiceAccount in `platform`. Across the week, 255 of the 257 ci-runner events are in `build` and are overwhelmingly repetitive reads of build ConfigMaps and Pods (with a small number of routine local service/deployment reads). Only the Pod create and ServiceAccount lookup are cross-namespace events. The platform create/get sequence is not a normal build operation. The secret list/get at the end is the obvious high-impact action, but it is late in the path and is a weaker early-warning point.

A detection needs per-ServiceAccount baselines from audit history (namespace, verb, resource, target identity, and rate), then alerts on meaningful deviation such as a build identity creating a Pod or looking up a privileged ServiceAccount in platform. Tune against approved deployment/debug changes and track identity-to-workload ownership. Trellis currently has no such established per-identity normal profile; the supplied week can seed one, but does not by itself establish a two-year baseline.
