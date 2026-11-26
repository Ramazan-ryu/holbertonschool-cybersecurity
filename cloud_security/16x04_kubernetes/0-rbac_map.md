# Trellis Software: RBAC Map

## 1. Scope and method

This map inventories every RBAC object in the snapshot `latchkey/trellis-cluster-export/`: Namespaces, ServiceAccounts, Roles, ClusterRoles, RoleBindings, and ClusterRoleBindings. It records grants only. Kubernetes RBAC is additive, so no deny rules exist to infer.

Object counts were verified with `grep -c` against the export files:

| Object | Expected | Verified |
|---|---|---|
| Namespace | 14 | 14 |
| ServiceAccount | 86 | 86 |
| Role | 62 | 62 |
| ClusterRole | 5 | 5 |
| RoleBinding | 117 | 117 |
| ClusterRoleBinding | 11 | 11 |
| **Total bindings** | **128** | **128** |

Verification method: the counts above come from `grep -c '^kind: <Kind>$'` run against each export file. The subjects and roleRefs come from `rolebindings.yaml` and `clusterrolebindings.yaml`. The Role and ClusterRole rule fields are transcribed in Section 6.

**Not verified:** Effective permissions were not checked against a live cluster. No kubeconfig is present on the analysis machine (`kubectl config current-context` is unset, `~/.kube` does not exist, `KUBECONFIG` is empty). Any statement below about effective authorization is derived from manifests, and it is marked as such.

## 2. Scope rules used in this map

- A **RoleBinding** is namespaced. Its grant applies only in the binding's namespace.
- A RoleBinding that references a **Role** grants only that Role's rules, in the binding namespace. The Role must exist in the same namespace as the binding. All RoleBindings in this export satisfy that condition.
- A RoleBinding that references a **ClusterRole** still grants only in the binding's namespace. Example: `sam-legacy-view` binds ClusterRole `view` but applies only in `legacy-billing-migration`.
- A **ClusterRoleBinding** referencing a **ClusterRole** grants across the whole cluster.
- The subject's namespace identifies its ServiceAccount. The binding's namespace is where a RoleBinding's grant applies. Cross-namespace subjects are shown as `SA <subject-namespace>/<name>`.

## 3. Namespace inventory

The namespace names below are copied from `namespaces.yaml`. Counts are object counts in the corresponding RBAC export files; they are not namespace classifications.

| Namespace | ServiceAccounts | Roles | RoleBindings |
|---|---:|---:|---:|
| analytics | 7 | 3 | 9 |
| build | 8 | 6 | 9 |
| data | 4 | 5 | 7 |
| default | 6 | 5 | 7 |
| dev | 4 | 6 | 6 |
| kube-addons-old | 1 | 0 | 0 |
| kube-system | 7 | 3 | 11 |
| legacy-billing-migration | 8 | 6 | 15 |
| media-processing | 5 | 3 | 6 |
| monitoring | 8 | 6 | 9 |
| payments | 7 | 3 | 8 |
| platform | 9 | 4 | 12 |
| prod | 7 | 8 | 10 |
| staging | 5 | 4 | 8 |
| **Total** | **86** | **62** | **117** |

**Brief-to-export discrepancy:** the task brief mentions a test namespace containing three objects. The supplied `namespaces.yaml` contains exactly the 14 namespaces listed above and has no `test` Namespace object. This map records the complete supplied export and does not add an unexported namespace or objects to it.

## 4. ServiceAccount subjects

Every ServiceAccount object from `serviceaccounts.yaml` is listed below with its namespace. Binding relationships for subjects are enumerated individually in Section 7.

| Namespace | ServiceAccount names |
|---|---|
| analytics | `analytics-worker`, `analytics-svc-01`, `analytics-svc-02`, `analytics-svc-03`, `analytics-svc-04`, `analytics-svc-05`, `analytics-svc-06` |
| build | `ci-runner`, `build-cache`, `build-svc-01`, `build-svc-02`, `build-svc-03`, `build-svc-04`, `build-svc-05`, `build-svc-06` |
| data | `data-svc-01`, `data-svc-02`, `data-svc-03`, `data-svc-04` |
| default | `default-svc-01`, `default-svc-02`, `default-svc-03`, `default-svc-04`, `default-svc-05`, `default-svc-06` |
| dev | `dev-svc-01`, `dev-svc-02`, `dev-svc-03`, `dev-svc-04` |
| kube-addons-old | `addons-legacy` |
| kube-system | `kubesystem-svc-01`, `kubesystem-svc-02`, `kubesystem-svc-03`, `kubesystem-svc-04`, `kubesystem-svc-05`, `kubesystem-svc-06`, `kubesystem-svc-07` |
| legacy-billing-migration | `reconcile-job`, `legacybill-svc-01`, `legacybill-svc-02`, `legacybill-svc-03`, `legacybill-svc-04`, `legacybill-svc-05`, `legacybill-svc-06`, `legacybill-svc-07` |
| media-processing | `media-worker`, `mediaproce-svc-01`, `mediaproce-svc-02`, `mediaproce-svc-03`, `mediaproce-svc-04` |
| monitoring | `metrics-agent`, `monitoring-svc-01`, `monitoring-svc-02`, `monitoring-svc-03`, `monitoring-svc-04`, `monitoring-svc-05`, `monitoring-svc-06`, `monitoring-svc-07` |
| payments | `payments-gateway-sa`, `ledger-sa`, `payments-svc-01`, `payments-svc-02`, `payments-svc-03`, `payments-svc-04`, `payments-svc-05` |
| platform | `controller-admin`, `platform-agent`, `platform-svc-01`, `platform-svc-02`, `platform-svc-03`, `platform-svc-04`, `platform-svc-05`, `platform-svc-06`, `platform-svc-07` |
| prod | `deploy-bot`, `billing-reconciler`, `orders-api-sa`, `prod-svc-01`, `prod-svc-02`, `prod-svc-03`, `prod-svc-04` |
| staging | `staging-svc-01`, `staging-svc-02`, `staging-svc-03`, `staging-svc-04`, `staging-svc-05` |

## 5. User and group subjects

| Subject | Kind | Bindings |
|---|---|---|
| maya.chen | User | `maya-dev-editor` (dev), `maya-billing-migrator` (legacy-billing-migration) |
| sam.okafor | User | `sam-metrics-viewer` (monitoring), `sam-legacy-view` (legacy-billing-migration) |

The two User subjects above are the only non-ServiceAccount subjects in the binding exports. No Group subjects appear.

## 6. Role and ClusterRole inventory

Rule IDs are the 1-based order of rules in each object. `resourceNames` restrictions: none are specified in these Role and ClusterRole rules. "Bound by" counts RoleBindings or ClusterRoleBindings that reference the object. Full binding entries are in Section 7.

### 6.1 Roles by namespace

**prod**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| deployer | R1 | apps | deployments, replicasets | get, list, watch, create, update, patch | 1 | bound |
| deployer | R2 | "" (core) | pods, configmaps | get, list | | |
| reconciler | R1 | "" | configmaps | get, list, watch | 1 | bound |
| reconciler | R2 | batch | jobs | get, list, create | | |
| orders-api-config | R1 | "" | configmaps, secrets | get, list, watch | 1 | bound |
| prod-role-01 | R1 | "" | pods, services | get, list | 3 | bound |
| prod-role-02 | R1 | "" | pods | get, list, watch, update, patch | 1 | bound |
| prod-role-02 | R2 | apps | deployments, replicasets | get, list, watch | | |
| prod-role-03 | R1 | "" | configmaps, pods | get, list, watch | 2 | bound |
| prod-role-04 | R1 | "" | pods, configmaps | get, list, watch | 1 | bound |
| prod-role-04 | R2 | apps | replicasets, deployments | get, list, watch | | |
| prod-role-05 | R1 | "" | configmaps, pods, services | get, list | 0 | **UNBOUND** |

**legacy-billing-migration**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| migration-operator | R1 | rbac.authorization.k8s.io | roles, rolebindings | get, list | 1 | bound |
| migration-operator | R2 | rbac.authorization.k8s.io | roles, clusterroles | bind, escalate, create | | |
| billing-migrator | R1 | "" | pods, configmaps | get, list | 1 | bound |
| billing-migrator | R2 | "" | serviceaccounts, users, groups | impersonate | | |
| billing-secrets | R1 | "" | secrets | get, list | 2 | bound |
| billing-secrets | R2 | "" | configmaps | get, list | | |
| legacybill-role-01 | R1 | "" | pods | get, list, watch | 3 | bound |
| legacybill-role-01 | R2 | apps | replicasets, deployments | get, list, watch | | |
| legacybill-role-02 | R1 | "" | pods, configmaps, services | get, list | 3 | bound |
| legacybill-role-03 | R1 | "" | configmaps, services | get, list, watch, update, patch | 4 | bound |
| legacybill-role-03 | R2 | apps | deployments, statefulsets | get, list, watch | | |

**dev**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| dev-editor | R1 | "" | pods, configmaps, services | get, list, watch, create, update, patch, delete | 1 | bound |
| dev-editor | R2 | apps | deployments | get, list, watch, create, update, patch | | |
| dev-role-01 | R1 | "" | pods | get, list, watch, update, patch | 0 | **UNBOUND** |
| dev-role-02 | R1 | "" | endpoints, services | get, list | 2 | bound |
| dev-role-02 | R2 | apps | replicasets, statefulsets | get, list, watch | | |
| dev-role-03 | R1 | "" | services, configmaps, endpoints | get, list | 0 | **UNBOUND** |
| dev-role-03 | R2 | apps | deployments, replicasets | get, list, watch | | |
| dev-role-04 | R1 | "" | configmaps, pods | get, list, watch, update, patch | 3 | bound |
| dev-role-05 | R1 | "" | configmaps, endpoints, pods | get, list, watch | 0 | **UNBOUND** |

**build**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| ci-build | R1 | "" | configmaps | get, list, watch | 1 | bound |
| ci-build | R2 | "" | pods | get, list, create | | |
| ci-build | R3 | batch | jobs | get, list | | |
| build-role-01 | R1 | "" | endpoints | get, list, watch | 2 | bound |
| build-role-02 | R1 | "" | configmaps, services, endpoints | get, list | 1 | bound |
| build-role-02 | R2 | apps | replicasets, statefulsets | get, list, watch | | |
| build-role-03 | R1 | "" | services, configmaps, pods | get, list | 4 | bound |
| build-role-03 | R2 | apps | statefulsets, replicasets | get, list, watch | | |
| build-role-04 | R1 | "" | endpoints, configmaps | get, list | 0 | **UNBOUND** |
| build-role-04 | R2 | apps | replicasets, deployments | get, list, watch | | |
| build-role-05 | R1 | "" | pods, configmaps, services | get, list, watch | 1 | bound |

**platform**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| platform-deployer | R1 | "" | pods | get, list, watch, create | 1 | bound |
| platform-deployer | R2 | "" | configmaps, serviceaccounts | get, list | | |
| platform-role-01 | R1 | "" | configmaps | get, list, watch | 3 | bound |
| platform-role-02 | R1 | "" | services, pods | get, list, watch | 5 | bound |
| platform-role-03 | R1 | "" | services, pods, configmaps | get, list | 3 | bound |

**monitoring**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| metrics-viewer | R1 | "" | pods, services, endpoints | get, list, watch | 1 | bound |
| monitoring-role-01 | R1 | "" | services, configmaps, pods | get, list, watch, update, patch | 1 | bound |
| monitoring-role-01 | R2 | apps | deployments, replicasets | get, list, watch | | |
| monitoring-role-02 | R1 | "" | configmaps, endpoints | get, list | 1 | bound |
| monitoring-role-03 | R1 | "" | configmaps, pods, services | get, list, watch, update, patch | 2 | bound |
| monitoring-role-04 | R1 | "" | configmaps, services, pods | get, list | 2 | bound |
| monitoring-role-05 | R1 | "" | endpoints, configmaps, pods | get, list | 2 | bound |
| monitoring-role-05 | R2 | apps | replicasets, deployments | get, list, watch | | |

**default**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| default-role-01 | R1 | "" | services, configmaps, endpoints | get, list, watch, update, patch | 1 | bound |
| default-role-02 | R1 | "" | endpoints, pods, configmaps | get, list | 1 | bound |
| default-role-02 | R2 | apps | replicasets, deployments | get, list, watch | | |
| default-role-03 | R1 | "" | services, configmaps | get, list | 1 | bound |
| default-role-04 | R1 | "" | pods | get, list | 3 | bound |
| default-role-05 | R1 | "" | configmaps | get, list, watch, update, patch | 1 | bound |
| default-role-05 | R2 | apps | replicasets, statefulsets | get, list, watch | | |

**kube-system**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| kubesystem-role-01 | R1 | "" | configmaps, services | get, list, watch, update, patch | 1 | bound |
| kubesystem-role-02 | R1 | "" | configmaps, services | get, list, watch | 5 | bound |
| kubesystem-role-02 | R2 | apps | statefulsets, replicasets | get, list, watch | | |
| kubesystem-role-03 | R1 | "" | configmaps, services | get, list | 5 | bound |

**staging**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| staging-role-01 | R1 | "" | services | get, list, watch | 0 | **UNBOUND** |
| staging-role-02 | R1 | "" | configmaps | get, list, watch, update, patch | 2 | bound |
| staging-role-02 | R2 | apps | statefulsets, replicasets | get, list, watch | | |
| staging-role-03 | R1 | "" | services | get, list, watch | 1 | bound |
| staging-role-03 | R2 | apps | deployments, statefulsets | get, list, watch | | |
| staging-role-04 | R1 | "" | endpoints, pods | get, list, watch | 5 | bound |
| staging-role-04 | R2 | apps | replicasets, deployments | get, list, watch | | |

**analytics**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| analytics-role-01 | R1 | "" | endpoints | get, list, watch, update, patch | 1 | bound |
| analytics-role-01 | R2 | apps | deployments, replicasets | get, list, watch | | |
| analytics-role-02 | R1 | "" | pods | get, list, watch, update, patch | 5 | bound |
| analytics-role-02 | R2 | apps | deployments, replicasets | get, list, watch | | |
| analytics-role-03 | R1 | "" | pods, endpoints | get, list | 3 | bound |
| analytics-role-03 | R2 | apps | statefulsets, replicasets | get, list, watch | | |

**payments**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| payments-role-01 | R1 | "" | endpoints, services | get, list, watch | 4 | bound |
| payments-role-01 | R2 | apps | deployments, replicasets | get, list, watch | | |
| payments-role-02 | R1 | "" | endpoints, services | get, list | 2 | bound |
| payments-role-02 | R2 | apps | statefulsets, replicasets | get, list, watch | | |
| payments-role-03 | R1 | "" | configmaps, endpoints | get, list, watch | 2 | bound |
| payments-role-03 | R2 | apps | statefulsets, deployments | get, list, watch | | |

**media-processing**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| mediaproce-role-01 | R1 | "" | configmaps, pods, endpoints | get, list, watch, update, patch | 3 | bound |
| mediaproce-role-01 | R2 | apps | statefulsets, replicasets | get, list, watch | | |
| mediaproce-role-02 | R1 | "" | endpoints, configmaps, services | get, list, watch, update, patch | 1 | bound |
| mediaproce-role-02 | R2 | apps | replicasets, deployments | get, list, watch | | |
| mediaproce-role-03 | R1 | "" | services | get, list | 2 | bound |
| mediaproce-role-03 | R2 | apps | replicasets, deployments | get, list, watch | | |

**data**

| Role | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| data-role-01 | R1 | "" | pods, configmaps | get, list | 3 | bound |
| data-role-01 | R2 | apps | statefulsets, replicasets | get, list, watch | | |
| data-role-02 | R1 | "" | services, pods | get, list, watch | 0 | **UNBOUND** |
| data-role-02 | R2 | apps | statefulsets, replicasets | get, list, watch | | |
| data-role-03 | R1 | "" | services, endpoints, configmaps | get, list | 1 | bound |
| data-role-04 | R1 | "" | endpoints | get, list | 1 | bound |
| data-role-05 | R1 | "" | configmaps, pods | get, list, watch, update, patch | 2 | bound |
| data-role-05 | R2 | apps | statefulsets, deployments | get, list, watch | | |

### 6.2 ClusterRoles

| ClusterRole | Rule | apiGroups | Resources | Verbs | Bound by | Status |
|---|---|---|---|---|---|---|
| view | R1 | "" | pods, services, endpoints, configmaps | get, list, watch | 9 (8 ClusterRoleBindings, 1 RoleBinding) | bound |
| view | R2 | apps | deployments, replicasets | get, list, watch | | |
| configmap-reader | R1 | "" | configmaps | get, list | 1 | bound |
| node-reader | R1 | "" | nodes | get, list | 1 | bound |
| cluster-superuser | R1 | * | * | * | 1 | bound (**cluster-admin equivalent**) |
| secret-reader-cluster | R1 | "" | secrets | get, list | 0 | **UNBOUND** |

## 7. Binding inventory

Every binding is listed. Columns: binding name, scope, subjects (kind and namespace), roleRef (kind and name), effective grant scope, and resolution status. "RESOLVED" means the referenced Role or ClusterRole exists in the export and, for Roles, lives in the same namespace as the binding.

### 7.1 RoleBindings (117)

**prod (10 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | deploy-bot-deployer | ServiceAccount prod/deploy-bot | Role deployer | prod | RESOLVED |
| 2 | billing-reconciler-prod | ServiceAccount prod/billing-reconciler | Role reconciler | prod | RESOLVED |
| 3 | orders-api-config | ServiceAccount prod/orders-api-sa | Role orders-api-config | prod | RESOLVED |
| 4 | prod-svc-01-prod-role-01 | ServiceAccount prod/prod-svc-01 | Role prod-role-01 | prod | RESOLVED |
| 5 | prod-svc-02-prod-role-03 | ServiceAccount prod/prod-svc-02 | Role prod-role-03 | prod | RESOLVED |
| 6 | prod-svc-02-prod-role-01 | ServiceAccount prod/prod-svc-02 | Role prod-role-01 | prod | RESOLVED |
| 7 | prod-svc-03-prod-role-02 | ServiceAccount prod/prod-svc-03 | Role prod-role-02 | prod | RESOLVED |
| 8 | prod-svc-03-prod-role-01 | ServiceAccount prod/prod-svc-03 | Role prod-role-01 | prod | RESOLVED |
| 9 | prod-svc-04-prod-role-03 | ServiceAccount prod/prod-svc-04 | Role prod-role-03 | prod | RESOLVED |
| 10 | prod-svc-04-prod-role-04 | ServiceAccount prod/prod-svc-04 | Role prod-role-04 | prod | RESOLVED |

**legacy-billing-migration (15 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | legacy-migration-admin | ServiceAccount prod/deploy-bot (cross-namespace) | Role migration-operator | legacy-billing-migration | RESOLVED |
| 2 | maya-billing-migrator | User maya.chen | Role billing-migrator | legacy-billing-migration | RESOLVED |
| 3 | ci-runner-legacy-secrets | ServiceAccount build/ci-runner (cross-namespace) | Role billing-secrets | legacy-billing-migration | RESOLVED |
| 4 | sam-legacy-view | User sam.okafor | ClusterRole view | legacy-billing-migration only | RESOLVED |
| 5 | billing-reconciler-secrets | ServiceAccount prod/billing-reconciler (cross-namespace) | Role billing-secrets | legacy-billing-migration | RESOLVED |
| 6 | legacybill-svc-01-legacybill-role-01 | ServiceAccount legacy-billing-migration/legacybill-svc-01 | Role legacybill-role-01 | legacy-billing-migration | RESOLVED |
| 7 | legacybill-svc-01-legacybill-role-02 | ServiceAccount legacy-billing-migration/legacybill-svc-01 | Role legacybill-role-02 | legacy-billing-migration | RESOLVED |
| 8 | legacybill-svc-02-legacybill-role-03 | ServiceAccount legacy-billing-migration/legacybill-svc-02 | Role legacybill-role-03 | legacy-billing-migration | RESOLVED |
| 9 | legacybill-svc-03-legacybill-role-01 | ServiceAccount legacy-billing-migration/legacybill-svc-03 | Role legacybill-role-01 | legacy-billing-migration | RESOLVED |
| 10 | legacybill-svc-03-legacybill-role-03 | ServiceAccount legacy-billing-migration/legacybill-svc-03 | Role legacybill-role-03 | legacy-billing-migration | RESOLVED |
| 11 | legacybill-svc-04-legacybill-role-02 | ServiceAccount legacy-billing-migration/legacybill-svc-04 | Role legacybill-role-02 | legacy-billing-migration | RESOLVED |
| 12 | legacybill-svc-05-legacybill-role-02 | ServiceAccount legacy-billing-migration/legacybill-svc-05 | Role legacybill-role-02 | legacy-billing-migration | RESOLVED |
| 13 | legacybill-svc-06-legacybill-role-03 | ServiceAccount legacy-billing-migration/legacybill-svc-06 | Role legacybill-role-03 | legacy-billing-migration | RESOLVED |
| 14 | legacybill-svc-06-legacybill-role-01 | ServiceAccount legacy-billing-migration/legacybill-svc-06 | Role legacybill-role-01 | legacy-billing-migration | RESOLVED |
| 15 | legacybill-svc-07-legacybill-role-03 | ServiceAccount legacy-billing-migration/legacybill-svc-07 | Role legacybill-role-03 | legacy-billing-migration | RESOLVED |

**dev (6 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | maya-dev-editor | User maya.chen | Role dev-editor | dev | RESOLVED |
| 2 | dev-svc-01-dev-role-04 | ServiceAccount dev/dev-svc-01 | Role dev-role-04 | dev | RESOLVED |
| 3 | dev-svc-02-dev-role-02 | ServiceAccount dev/dev-svc-02 | Role dev-role-02 | dev | RESOLVED |
| 4 | dev-svc-03-dev-role-04 | ServiceAccount dev/dev-svc-03 | Role dev-role-04 | dev | RESOLVED |
| 5 | dev-svc-04-dev-role-04 | ServiceAccount dev/dev-svc-04 | Role dev-role-04 | dev | RESOLVED |
| 6 | dev-svc-04-dev-role-02 | ServiceAccount dev/dev-svc-04 | Role dev-role-02 | dev | RESOLVED |

**build (9 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | ci-runner-build | ServiceAccount build/ci-runner | Role ci-build | build | RESOLVED |
| 2 | build-svc-01-build-role-02 | ServiceAccount build/build-svc-01 | Role build-role-02 | build | RESOLVED |
| 3 | build-svc-01-build-role-03 | ServiceAccount build/build-svc-01 | Role build-role-03 | build | RESOLVED |
| 4 | build-svc-02-build-role-05 | ServiceAccount build/build-svc-02 | Role build-role-05 | build | RESOLVED |
| 5 | build-svc-03-build-role-03 | ServiceAccount build/build-svc-03 | Role build-role-03 | build | RESOLVED |
| 6 | build-svc-04-build-role-01 | ServiceAccount build/build-svc-04 | Role build-role-01 | build | RESOLVED |
| 7 | build-svc-05-build-role-01 | ServiceAccount build/build-svc-05 | Role build-role-01 | build | RESOLVED |
| 8 | build-svc-05-build-role-03 | ServiceAccount build/build-svc-05 | Role build-role-03 | build | RESOLVED |
| 9 | build-svc-06-build-role-03 | ServiceAccount build/build-svc-06 | Role build-role-03 | build | RESOLVED |

**platform (12 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | ci-runner-platform-deploy | ServiceAccount build/ci-runner (cross-namespace) | Role platform-deployer | platform | RESOLVED |
| 2 | platform-svc-01-platform-role-02 | ServiceAccount platform/platform-svc-01 | Role platform-role-02 | platform | RESOLVED |
| 3 | platform-svc-01-platform-role-03 | ServiceAccount platform/platform-svc-01 | Role platform-role-03 | platform | RESOLVED |
| 4 | platform-svc-02-platform-role-03 | ServiceAccount platform/platform-svc-02 | Role platform-role-03 | platform | RESOLVED |
| 5 | platform-svc-02-platform-role-01 | ServiceAccount platform/platform-svc-02 | Role platform-role-01 | platform | RESOLVED |
| 6 | platform-svc-03-platform-role-02 | ServiceAccount platform/platform-svc-03 | Role platform-role-02 | platform | RESOLVED |
| 7 | platform-svc-04-platform-role-02 | ServiceAccount platform/platform-svc-04 | Role platform-role-02 | platform | RESOLVED |
| 8 | platform-svc-05-platform-role-01 | ServiceAccount platform/platform-svc-05 | Role platform-role-01 | platform | RESOLVED |
| 9 | platform-svc-05-platform-role-03 | ServiceAccount platform/platform-svc-05 | Role platform-role-03 | platform | RESOLVED |
| 10 | platform-svc-06-platform-role-02 | ServiceAccount platform/platform-svc-06 | Role platform-role-02 | platform | RESOLVED |
| 11 | platform-svc-07-platform-role-02 | ServiceAccount platform/platform-svc-07 | Role platform-role-02 | platform | RESOLVED |
| 12 | platform-svc-07-platform-role-01 | ServiceAccount platform/platform-svc-07 | Role platform-role-01 | platform | RESOLVED |

**monitoring (9 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | sam-metrics-viewer | User sam.okafor | Role metrics-viewer | monitoring | RESOLVED |
| 2 | monitoring-svc-01-monitoring-role-03 | ServiceAccount monitoring/monitoring-svc-01 | Role monitoring-role-03 | monitoring | RESOLVED |
| 3 | monitoring-svc-02-monitoring-role-05 | ServiceAccount monitoring/monitoring-svc-02 | Role monitoring-role-05 | monitoring | RESOLVED |
| 4 | monitoring-svc-03-monitoring-role-04 | ServiceAccount monitoring/monitoring-svc-03 | Role monitoring-role-04 | monitoring | RESOLVED |
| 5 | monitoring-svc-03-monitoring-role-01 | ServiceAccount monitoring/monitoring-svc-03 | Role monitoring-role-01 | monitoring | RESOLVED |
| 6 | monitoring-svc-04-monitoring-role-02 | ServiceAccount monitoring/monitoring-svc-04 | Role monitoring-role-02 | monitoring | RESOLVED |
| 7 | monitoring-svc-05-monitoring-role-04 | ServiceAccount monitoring/monitoring-svc-05 | Role monitoring-role-04 | monitoring | RESOLVED |
| 8 | monitoring-svc-06-monitoring-role-03 | ServiceAccount monitoring/monitoring-svc-06 | Role monitoring-role-03 | monitoring | RESOLVED |
| 9 | monitoring-svc-07-monitoring-role-05 | ServiceAccount monitoring/monitoring-svc-07 | Role monitoring-role-05 | monitoring | RESOLVED |

**default (7 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | default-svc-01-default-role-04 | ServiceAccount default/default-svc-01 | Role default-role-04 | default | RESOLVED |
| 2 | default-svc-01-default-role-01 | ServiceAccount default/default-svc-01 | Role default-role-01 | default | RESOLVED |
| 3 | default-svc-02-default-role-05 | ServiceAccount default/default-svc-02 | Role default-role-05 | default | RESOLVED |
| 4 | default-svc-03-default-role-02 | ServiceAccount default/default-svc-03 | Role default-role-02 | default | RESOLVED |
| 5 | default-svc-04-default-role-04 | ServiceAccount default/default-svc-04 | Role default-role-04 | default | RESOLVED |
| 6 | default-svc-05-default-role-04 | ServiceAccount default/default-svc-05 | Role default-role-04 | default | RESOLVED |
| 7 | default-svc-06-default-role-03 | ServiceAccount default/default-svc-06 | Role default-role-03 | default | RESOLVED |

**kube-system (11 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | kubesystem-svc-01-kubesystem-role-03 | ServiceAccount kube-system/kubesystem-svc-01 | Role kubesystem-role-03 | kube-system | RESOLVED |
| 2 | kubesystem-svc-02-kubesystem-role-02 | ServiceAccount kube-system/kubesystem-svc-02 | Role kubesystem-role-02 | kube-system | RESOLVED |
| 3 | kubesystem-svc-02-kubesystem-role-03 | ServiceAccount kube-system/kubesystem-svc-02 | Role kubesystem-role-03 | kube-system | RESOLVED |
| 4 | kubesystem-svc-03-kubesystem-role-02 | ServiceAccount kube-system/kubesystem-svc-03 | Role kubesystem-role-02 | kube-system | RESOLVED |
| 5 | kubesystem-svc-03-kubesystem-role-03 | ServiceAccount kube-system/kubesystem-svc-03 | Role kubesystem-role-03 | kube-system | RESOLVED |
| 6 | kubesystem-svc-04-kubesystem-role-02 | ServiceAccount kube-system/kubesystem-svc-04 | Role kubesystem-role-02 | kube-system | RESOLVED |
| 7 | kubesystem-svc-05-kubesystem-role-01 | ServiceAccount kube-system/kubesystem-svc-05 | Role kubesystem-role-01 | kube-system | RESOLVED |
| 8 | kubesystem-svc-05-kubesystem-role-02 | ServiceAccount kube-system/kubesystem-svc-05 | Role kubesystem-role-02 | kube-system | RESOLVED |
| 9 | kubesystem-svc-06-kubesystem-role-02 | ServiceAccount kube-system/kubesystem-svc-06 | Role kubesystem-role-02 | kube-system | RESOLVED |
| 10 | kubesystem-svc-06-kubesystem-role-03 | ServiceAccount kube-system/kubesystem-svc-06 | Role kubesystem-role-03 | kube-system | RESOLVED |
| 11 | kubesystem-svc-07-kubesystem-role-03 | ServiceAccount kube-system/kubesystem-svc-07 | Role kubesystem-role-03 | kube-system | RESOLVED |

**staging (8 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | staging-svc-01-staging-role-04 | ServiceAccount staging/staging-svc-01 | Role staging-role-04 | staging | RESOLVED |
| 2 | staging-svc-02-staging-role-04 | ServiceAccount staging/staging-svc-02 | Role staging-role-04 | staging | RESOLVED |
| 3 | staging-svc-03-staging-role-02 | ServiceAccount staging/staging-svc-03 | Role staging-role-02 | staging | RESOLVED |
| 4 | staging-svc-03-staging-role-04 | ServiceAccount staging/staging-svc-03 | Role staging-role-04 | staging | RESOLVED |
| 5 | staging-svc-04-staging-role-04 | ServiceAccount staging/staging-svc-04 | Role staging-role-04 | staging | RESOLVED |
| 6 | staging-svc-04-staging-role-02 | ServiceAccount staging/staging-svc-04 | Role staging-role-02 | staging | RESOLVED |
| 7 | staging-svc-05-staging-role-04 | ServiceAccount staging/staging-svc-05 | Role staging-role-04 | staging | RESOLVED |
| 8 | staging-svc-05-staging-role-03 | ServiceAccount staging/staging-svc-05 | Role staging-role-03 | staging | RESOLVED |

**analytics (9 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | analytics-svc-01-analytics-role-02 | ServiceAccount analytics/analytics-svc-01 | Role analytics-role-02 | analytics | RESOLVED |
| 2 | analytics-svc-02-analytics-role-03 | ServiceAccount analytics/analytics-svc-02 | Role analytics-role-03 | analytics | RESOLVED |
| 3 | analytics-svc-03-analytics-role-02 | ServiceAccount analytics/analytics-svc-03 | Role analytics-role-02 | analytics | RESOLVED |
| 4 | analytics-svc-04-analytics-role-01 | ServiceAccount analytics/analytics-svc-04 | Role analytics-role-01 | analytics | RESOLVED |
| 5 | analytics-svc-04-analytics-role-02 | ServiceAccount analytics/analytics-svc-04 | Role analytics-role-02 | analytics | RESOLVED |
| 6 | analytics-svc-05-analytics-role-02 | ServiceAccount analytics/analytics-svc-05 | Role analytics-role-02 | analytics | RESOLVED |
| 7 | analytics-svc-05-analytics-role-03 | ServiceAccount analytics/analytics-svc-05 | Role analytics-role-03 | analytics | RESOLVED |
| 8 | analytics-svc-06-analytics-role-02 | ServiceAccount analytics/analytics-svc-06 | Role analytics-role-02 | analytics | RESOLVED |
| 9 | analytics-svc-06-analytics-role-03 | ServiceAccount analytics/analytics-svc-06 | Role analytics-role-03 | analytics | RESOLVED |

**payments (8 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | payments-svc-01-payments-role-01 | ServiceAccount payments/payments-svc-01 | Role payments-role-01 | payments | RESOLVED |
| 2 | payments-svc-01-payments-role-02 | ServiceAccount payments/payments-svc-01 | Role payments-role-02 | payments | RESOLVED |
| 3 | payments-svc-02-payments-role-01 | ServiceAccount payments/payments-svc-02 | Role payments-role-01 | payments | RESOLVED |
| 4 | payments-svc-03-payments-role-03 | ServiceAccount payments/payments-svc-03 | Role payments-role-03 | payments | RESOLVED |
| 5 | payments-svc-04-payments-role-02 | ServiceAccount payments/payments-svc-04 | Role payments-role-02 | payments | RESOLVED |
| 6 | payments-svc-04-payments-role-01 | ServiceAccount payments/payments-svc-04 | Role payments-role-01 | payments | RESOLVED |
| 7 | payments-svc-05-payments-role-03 | ServiceAccount payments/payments-svc-05 | Role payments-role-03 | payments | RESOLVED |
| 8 | payments-svc-05-payments-role-01 | ServiceAccount payments/payments-svc-05 | Role payments-role-01 | payments | RESOLVED |

**media-processing (6 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | mediaproce-svc-01-mediaproce-role-01 | ServiceAccount media-processing/mediaproce-svc-01 | Role mediaproce-role-01 | media-processing | RESOLVED |
| 2 | mediaproce-svc-01-mediaproce-role-03 | ServiceAccount media-processing/mediaproce-svc-01 | Role mediaproce-role-03 | media-processing | RESOLVED |
| 3 | mediaproce-svc-02-mediaproce-role-01 | ServiceAccount media-processing/mediaproce-svc-02 | Role mediaproce-role-01 | media-processing | RESOLVED |
| 4 | mediaproce-svc-02-mediaproce-role-03 | ServiceAccount media-processing/mediaproce-svc-02 | Role mediaproce-role-03 | media-processing | RESOLVED |
| 5 | mediaproce-svc-03-mediaproce-role-01 | ServiceAccount media-processing/mediaproce-svc-03 | Role mediaproce-role-01 | media-processing | RESOLVED |
| 6 | mediaproce-svc-04-mediaproce-role-02 | ServiceAccount media-processing/mediaproce-svc-04 | Role mediaproce-role-02 | media-processing | RESOLVED |

**data (7 bindings)**

| # | Binding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | data-svc-01-data-role-04 | ServiceAccount data/data-svc-01 | Role data-role-04 | data | RESOLVED |
| 2 | data-svc-01-data-role-01 | ServiceAccount data/data-svc-01 | Role data-role-01 | data | RESOLVED |
| 3 | data-svc-02-data-role-01 | ServiceAccount data/data-svc-02 | Role data-role-01 | data | RESOLVED |
| 4 | data-svc-03-data-role-05 | ServiceAccount data/data-svc-03 | Role data-role-05 | data | RESOLVED |
| 5 | data-svc-03-data-role-01 | ServiceAccount data/data-svc-03 | Role data-role-01 | data | RESOLVED |
| 6 | data-svc-04-data-role-03 | ServiceAccount data/data-svc-04 | Role data-role-03 | data | RESOLVED |
| 7 | data-svc-04-data-role-05 | ServiceAccount data/data-svc-04 | Role data-role-05 | data | RESOLVED |

### 7.2 ClusterRoleBindings (11)

Every ClusterRoleBinding has cluster-wide effective scope.

| # | ClusterRoleBinding | Subjects | roleRef | Effective scope | Status |
|---|---|---|---|---|---|
| 1 | platform-controller-admin | ServiceAccount platform/controller-admin | ClusterRole cluster-superuser | cluster-wide | RESOLVED |
| 2 | deploy-bot-cm-read | ServiceAccount prod/deploy-bot | ClusterRole configmap-reader | cluster-wide | RESOLVED |
| 3 | ci-runner-nodes | ServiceAccount build/ci-runner | ClusterRole node-reader | cluster-wide | RESOLVED |
| 4 | kubesystem-svc-04-view-363 | ServiceAccount kube-system/kubesystem-svc-04 | ClusterRole view | cluster-wide | RESOLVED |
| 5 | prod-svc-01-view-677 | ServiceAccount prod/prod-svc-01 | ClusterRole view | cluster-wide | RESOLVED |
| 6 | build-svc-05-view-692 | ServiceAccount build/build-svc-05 | ClusterRole view | cluster-wide | RESOLVED |
| 7 | build-svc-04-view-139 | ServiceAccount build/build-svc-04 | ClusterRole view | cluster-wide | RESOLVED |
| 8 | staging-svc-01-view-163 | ServiceAccount staging/staging-svc-01 | ClusterRole view | cluster-wide | RESOLVED |
| 9 | mediaproce-svc-02-view-114 | ServiceAccount media-processing/mediaproce-svc-02 | ClusterRole view | cluster-wide | RESOLVED |
| 10 | monitoring-svc-04-view-620 | ServiceAccount monitoring/monitoring-svc-04 | ClusterRole view | cluster-wide | RESOLVED |
| 11 | prod-svc-01-view-509 | ServiceAccount prod/prod-svc-01 | ClusterRole view | cluster-wide | RESOLVED |

Summary: 117 RoleBindings, all resolve. 11 ClusterRoleBindings, all resolve. Zero dangling references.

## 8. Inventory verification and boundary

Object counts were checked against the six source files with `grep -c '^kind: <Kind>$'`: 14 Namespaces, 86 ServiceAccounts, 62 Roles, 5 ClusterRoles, 117 RoleBindings, and 11 ClusterRoleBindings. The binding entries appear in Section 7; the rule fields shown in Section 6 are `apiGroups`, `resources`, and `verbs` from each Role and ClusterRole object. No effective authorization check was made against a live cluster; this document maps the supplied exported objects only.
