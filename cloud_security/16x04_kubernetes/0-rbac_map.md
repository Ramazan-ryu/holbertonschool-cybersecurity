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

Verification method: the counts above come from `grep -c '^kind: <Kind>$'` run against each export file. The rule contents, subjects, and roleRefs come from the reviewed `yq` output of `rolebindings.yaml` and `clusterrolebindings.yaml`. The Role and ClusterRole rules come from the export objects summarized in Section 5.

**Not verified:** Effective permissions were not checked against a live cluster. No kubeconfig is present on the analysis machine (`kubectl config current-context` is unset, `~/.kube` does not exist, `KUBECONFIG` is empty). Any statement below about effective authorization is derived from manifests, and it is marked as such.

## 2. Scope rules used in this map

- A **RoleBinding** is namespaced. Its grant applies only in the binding's namespace.
- A RoleBinding that references a **Role** grants only that Role's rules, in the binding namespace. The Role must exist in the same namespace as the binding. All RoleBindings in this export satisfy that condition.
- A RoleBinding that references a **ClusterRole** still grants only in the binding's namespace. Example: `sam-legacy-view` binds ClusterRole `view` but applies only in `legacy-billing-migration`.
- A **ClusterRoleBinding** referencing a **ClusterRole** grants across the whole cluster.
- The subject's namespace identifies its ServiceAccount. The binding's namespace is where a RoleBinding's grant applies. Cross-namespace subjects are shown as `SA <subject-namespace>/<name>`.

## 3. Namespace coverage

The export contains exactly 14 Namespace objects. Every one is listed below, including namespaces with few or no RBAC objects. Categories are analyst labels assigned from object names and content. The export itself contains no category field.

| Namespace | Category (analyst label) | ServiceAccounts | Roles | RoleBindings (in namespace) | Workloads dir present | Notes |
|---|---|---|---|---|---|---|
| default | active | 6 | 5 | 7 | yes | |
| kube-system | system | 7 | 3 | 11 | yes | |
| prod | active | 7 | 8 | 10 | yes | |
| build | active | 8 | 6 | 9 | yes | |
| platform | active | 9 | 4 | 12 | yes | Includes `daemonsets.yaml` |
| dev | active | 4 | 6 | 6 | yes | |
| staging | active | 5 | 4 | 8 | yes | |
| analytics | active | 7 | 3 | 9 | yes | |
| payments | active | 7 | 3 | 8 | yes | |
| media-processing | active | 5 | 3 | 6 | yes | |
| monitoring | active | 8 | 6 | 9 | yes | |
| data | active | 4 | 5 | 7 | yes | |
| legacy-billing-migration | completed-project / legacy-looking | 8 | 6 | 15 | yes | Still holds a live `reconcile-cron` workload and active bindings. Not treated as retired. |
| kube-addons-old | abandoned-looking / sparse | 1 | 0 | 0 | **no** | Only ServiceAccount `addons-legacy`. No Role, RoleBinding, or workload directory. |

Totals: 86 ServiceAccounts, 62 Roles, 117 RoleBindings. Each Role-count and RoleBinding-count row sums to the totals in Section 1.

**Test namespace:** The export does not contain a Namespace named `test`. This map does not invent one. If a test or sandbox namespace exists in the live cluster, the export is incomplete and must be regenerated before this map is final.

**Excluded files:** The following export contents are not RBAC objects and are not part of this map: `admission/` (`bindings.yaml`, `policies.yaml`), `networkpolicies.yaml`, `podsecurity-labels.yaml`, and `workloads/` (per-namespace `deployments.yaml`, plus `daemonsets.yaml` in platform). Note that `kube-addons-old` has no `workloads/` directory.

## 4. ServiceAccount inventory

All 86 ServiceAccounts are listed in Section 3 counts. Of these, 9 have **no RoleBinding and no ClusterRoleBinding** in the export. They hold no RBAC grants:

| ServiceAccount | Namespace | RBAC status |
|---|---|---|
| build-cache | build | UNBOUND |
| platform-agent | platform | UNBOUND |
| analytics-worker | analytics | UNBOUND |
| payments-gateway-sa | payments | UNBOUND |
| ledger-sa | payments | UNBOUND |
| media-worker | media-processing | UNBOUND |
| metrics-agent | monitoring | UNBOUND |
| reconcile-job | legacy-billing-migration | UNBOUND |
| addons-legacy | kube-addons-old | UNBOUND |

All other ServiceAccounts appear as subjects in at least one binding listed in Section 6 or 7. Unbound ServiceAccounts still exist and can still be assigned to pods, so the absence of a grant does not mean the pods are harmless. Check them with the workloads manifests.

## 5. User and group subjects

| Subject | Kind | Bindings |
|---|---|---|
| maya.chen | User | `maya-dev-editor` (dev), `maya-billing-migrator` (legacy-billing-migration) |
| sam.okafor | User | `sam-metrics-viewer` (monitoring), `sam-legacy-view` (legacy-billing-migration) |

No Group subjects appear in any binding.

## 6. Role and ClusterRole inventory

Rule IDs are the 1-based order of rules in each object. `resourceNames` restrictions: **none recorded** in the Role and ClusterRole objects inventoried here. "Bound by" counts RoleBindings or ClusterRoleBindings that reference the object. Full binding details are in Section 7.

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

Note: `monitoring-role-01` through `monitoring-role-05` are six Roles in total with `metrics-viewer`. The count in Section 3 includes all six.

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

### 6.3 Unbound Roles and ClusterRoles

These objects exist in the export but are not referenced by any binding:

- Role `prod-role-05` (prod)
- Role `build-role-04` (build)
- Role `dev-role-01`, `dev-role-03`, `dev-role-05` (dev)
- Role `staging-role-01` (staging)
- Role `data-role-02` (data)
- ClusterRole `secret-reader-cluster`

Unbound objects grant nothing today. `secret-reader-cluster` is a latent risk: a single ClusterRoleBinding would grant cluster-wide read of Secrets.

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

## 8. Scope observations

- **Cross-namespace RoleBindings** (subject namespace differs from binding namespace): `legacy-migration-admin`, `ci-runner-legacy-secrets`, `billing-reconciler-secrets` (all bind into `legacy-billing-migration`), and `ci-runner-platform-deploy` (binds into `platform`). In each case the grant applies in the binding namespace only.
- **RoleBinding to ClusterRole:** `sam-legacy-view` binds ClusterRole `view`, but the grant applies only in `legacy-billing-migration`, not cluster-wide. `view` also appears in ClusterRoleBindings, and those grants are cluster-wide. Those are separate objects.
- **Duplicate bindings:** `prod-svc-01-view-677` and `prod-svc-01-view-509` bind the same ClusterRole to the same ServiceAccount. Either one grants the same rules. This is cleanup, not a separate privilege.
- **Namespaced Role cannot authorize cluster-scoped resources.** The `migration-operator` Role names `clusterroles` in its rules, but a namespaced Role applies only inside its namespace. Creating a RoleBinding that references a ClusterRole is still limited to that binding's namespace.

## 9. Risk notes

Ranked by impact. Items marked **(manifest-derived)** have not been confirmed against a live cluster.

1. **Cluster-admin equivalent.** ClusterRoleBinding `platform-controller-admin` binds ServiceAccount `platform/controller-admin` to ClusterRole `cluster-superuser`, which grants `*` on `*` with `*` verbs across the cluster. This is the highest-priority finding. Any compromise of `controller-admin` yields full cluster control.

2. **Namespace-level takeover of legacy-billing-migration.** RoleBinding `legacy-migration-admin` gives ServiceAccount `prod/deploy-bot` the verbs `bind`, `escalate`, and `create` on `roles` and `clusterroles` in `legacy-billing-migration`. With `bind`, the holder can create a RoleBinding that references any ClusterRole, including `cluster-superuser`. With `escalate`, it can create Roles containing permissions it does not itself hold. The resulting grants apply only inside `legacy-billing-migration`. So the risk is full control of that namespace, including its Secrets, not cluster-wide access. No ClusterRoleBinding grants these verbs.

3. **Secret read across namespaces.** RoleBindings `ci-runner-legacy-secrets` (ServiceAccount `build/ci-runner`) and `billing-reconciler-secrets` (ServiceAccount `prod/billing-reconciler`) both bind Role `billing-secrets`, which grants `get` and `list` on `secrets` in `legacy-billing-migration`. Two ServiceAccounts from other namespaces can read that namespace's Secrets.

4. **Impersonation (manifest-derived).** Role `billing-migrator` grants User `maya.chen` the verb `impersonate` on `serviceaccounts`, `users`, and `groups` through RoleBinding `maya-billing-migrator`. Impersonation of `serviceaccounts` is checked against the target ServiceAccount's namespace, so from manifests the grant applies to ServiceAccounts in `legacy-billing-migration` (`reconcile-job`, `legacybill-svc-01` through `07`). Those ServiceAccounts hold the namespace's bindings. Impersonation of `users` and `groups` is a cluster-scoped check, which a namespaced RoleBinding does not satisfy. From manifests, those two grants should have no effect. **Not verified on a live cluster.** Verify with `kubectl auth can-i impersonate users --as=maya.chen` and the equivalent for groups and serviceaccounts, once a kubeconfig is available.

5. **Cluster-wide Secret read exposure (latent).** ClusterRole `secret-reader-cluster` grants `get` and `list` on `secrets` cluster-wide. It is currently unbound, so it grants nothing. Binding it would be cluster-wide Secret read.

6. **Cluster-wide configmap and node read.** ClusterRoleBinding `deploy-bot-cm-read` gives `prod/deploy-bot` cluster-wide `get` and `list` on configmaps. ClusterRoleBinding `ci-runner-nodes` gives `build/ci-runner` cluster-wide `get` and `list` on nodes. These are low-to-medium exposure, but configmaps often hold sensitive settings.

7. **Cluster-wide view for several ServiceAccounts.** Eight ClusterRoleBindings give ClusterRole `view` cluster-wide to six ServiceAccounts. `view` grants `get`, `list`, and `watch` on pods, services, endpoints, configmaps, deployments, and replicasets across all namespaces. It does not include Secrets.

8. **Overlapping grants on `prod/prod-svc-01`.** Two ClusterRoleBindings (`-677` and `-509`) grant the same view rules. Cleanup candidate, not a separate risk.

9. **Unbound ServiceAccounts (9).** `build-cache`, `platform-agent`, `analytics-worker`, `payments-gateway-sa`, `ledger-sa`, `media-worker`, `metrics-agent`, `reconcile-job`, `addons-legacy`. They have no RBAC grants. Their workloads may still run under them. Review the workloads manifests for any that mount tokens and run with those identities.

10. **Stale namespace.** `kube-addons-old` holds one ServiceAccount, no Roles, no RoleBindings, and no workloads directory. Confirm whether it still exists in the live cluster and whether any pod uses `addons-legacy`.

11. **Unbound Roles (7) and one unbound ClusterRole.** Listed in Section 6.3. Unbound grants are no current risk. They are cleanup candidates, and they are latent risk if bound later.

## 10. Verification status

| Check | Method | Status |
|---|---|---|
| Object counts | `grep -c '^kind: <Kind>$'` on each export file | Done. All match. |
| Binding totals (117 + 11 = 128) | Same grep, per file | Done. |
| Dangling roleRefs | Manual cross-check of every roleRef against Section 6 | Done. None found. |
| Role-to-binding namespace match | Manual check of each RoleBinding against its roleRef namespace | Done. All Role references are in the binding's namespace. |
| Unbound Roles and ClusterRoles | Cross-check of roleRefs against all Role and ClusterRole names | Done. 7 Roles and 1 ClusterRole are unbound. |
| Unbound ServiceAccounts | Cross-check of subjects against all ServiceAccount names | Done. 9 are unbound. |
| Effective authorization (live cluster) | `kubectl auth can-i` | **Not done.** No kubeconfig on the analysis machine. |
| Test namespace | Export review | **Not present in export.** Not inferred. |
| Role rules `resourceNames` | Review of Role objects | None recorded. |
