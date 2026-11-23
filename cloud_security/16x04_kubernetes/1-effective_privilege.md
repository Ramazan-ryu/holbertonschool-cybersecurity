# Effective privilege by subject

## 1. Method and limits

**Source.** Every grant below comes from `0-rbac_map.md` (Sections 6 and 7). That map was checked against the export: 117 RoleBindings, 11 ClusterRoleBindings, 62 Roles, 5 ClusterRoles, 86 ServiceAccounts, 2 Users, 0 Groups. Rule IDs (R1, R2, ...) refer to the rules listed in `0-rbac_map.md` Section 6.

**Semantics applied.**
- Kubernetes RBAC is additive. A subject's effective permission set is the union of every rule reached through every binding that names it, directly or through a group. No rule subtracts an allowed action.
- A RoleBinding grants only in its own namespace, even when it references a ClusterRole (`sam-legacy-view`, `legacy-migration-admin`, and the cross-namespace bindings all follow this).
- A ClusterRoleBinding grants cluster-wide.
- A cross-namespace subject (for example `build/ci-runner` in a `platform` RoleBinding) receives the binding's rules in the binding's namespace, under its own identity.
- RBAC has no verb that checks whether a pod creator may use a given ServiceAccount. A subject that can create pods or workloads in a namespace can run them under any ServiceAccount in that namespace. Only admission could block this. Paths of this kind are marked manifest-derived.
- Node access (hostPath, hostNetwork, privileged) is not an RBAC grant. It is a separate class of risk and is listed under E8.

**Abbreviations.** `g` get, `l` list, `w` watch, `c` create, `u` update, `p` patch, `d` delete, `b` bind, `e` escalate, `i` impersonate. Core API group has no prefix. Other groups are written `apps/`, `batch/`, `rbac/`.

**resourceNames.** None recorded in any Role or ClusterRole in the export.

**Admission and Pod Security (checked).**
- `admission/policies.yaml` defines one ValidatingAdmissionPolicy, `disallow-privileged`. It checks only `privileged: true` on Deployments.
- `admission/bindings.yaml` binds it with `validationActions: [Audit]`. Violations are recorded in the audit log and nothing is rejected. `failurePolicy: Fail` has no effect in Audit mode.
- `podsecurity-labels.yaml`: `media-processing`, `kube-system`, and `kube-addons-old` have no PSA labels, so no Pod Security enforcement applies there. The other namespaces carry `enforce: baseline`, which does not restrict `serviceAccountName` and does not allow privileged pods.
- Conclusion: no admission or PSA control in the export blocks E2, E3, E4, or E8.

**Not verified.**
- Live cluster. No kubeconfig exists on the analysis machine, so no `kubectl auth can-i` or server-side dry run was run. All path findings are manifest-derived.
- Node placement. The export does not say which node each pod runs on.
- Bootstrap bindings (for example to `system:authenticated`) are absent from the export. If the live cluster has them, effective permissions are larger than shown.
- The live admission mode. The export's `Audit` binding is assumed to match the live cluster.

## 2. Named subjects: summary

| Subject | Kind | Direct effective privilege | Path-based privilege (manifest-derived) | Verdict |
|---|---|---|---|---|
| `platform/controller-admin` | ServiceAccount | Cluster-wide `*` on `*`, all verbs (`platform-controller-admin` → `cluster-superuser` R1). Used by Deployment `platform-controller`. | Already cluster-admin-equivalent. Its pod is reachable from E2. | Over-privileged. Critical (E1). |
| `build/ci-runner` | ServiceAccount | Build pods and ConfigMap/Job access; pod create in `platform`; Secret read in `legacy-billing-migration`; cluster-wide node read | Cluster-admin-equivalent via pod creation in `platform` as `controller-admin` (E2) | Over-privileged. Critical. |
| `prod/deploy-bot` | ServiceAccount | Deployment/ReplicaSet write and Pod/ConfigMap read in `prod`; cluster-wide ConfigMap read; read-only RBAC plus role creation (no `create` on rolebindings) in `legacy-billing-migration` | Secret read in `legacy-billing-migration` (via `billing-reconciler`, E3) and in `prod` (via `orders-api-sa`, E3) | Over-privileged. High. |
| `prod/billing-reconciler` | ServiceAccount | ConfigMap read and Job create in `prod`; Secret and ConfigMap read in `legacy-billing-migration` | Secret read in `prod` (via `orders-api-sa`, E4) | Over-privileged. High. |
| `prod/orders-api-sa` | ServiceAccount | ConfigMap and Secret get/list/watch in `prod`, nothing else | None of its own. Its token is reachable through E3 and E4. | **Cleared (RBAC).** See Section 6. |
| `media-processing/media-worker` | ServiceAccount | None. Unbound in RBAC. | Runs privileged `transcoder` with host root filesystem, host network, and SYS_ADMIN (E8) | Over-privileged through the node, not RBAC. Critical. |
| `maya.chen` | User | Write to Pods, ConfigMaps, Services, Deployments in `dev`; read Pods/ConfigMaps in `legacy-billing-migration` | Impersonation of `legacy-billing-migration` ServiceAccounts (E6) | Over-privileged for a dev editor. Medium. No Secret path found. |
| `sam.okafor` | User | Read-only: Pods/Services/Endpoints in `monitoring`; Pods/Services/Endpoints/ConfigMaps/Deployments/ReplicaSets read in `legacy-billing-migration` | None found | Read-only. Low. |
| Other ServiceAccounts (no finding) | ServiceAccount | Section 4 | Pod creation paths reach them only if they are targets of E2–E4 | See Section 4 |

## 3. Escalation and node-access paths

**E1 (critical, direct, active). `platform/controller-admin` is cluster-superuser.**
- Binding: ClusterRoleBinding `platform-controller-admin` → ClusterRole `cluster-superuser` R1 (`apiGroups='*'`, `resources='*'`, `verbs='*'`).
- Scope: cluster-wide.
- In use: Deployment `platform-controller` in `platform` (file `workloads/platform/daemonsets.yaml`, which despite its name contains a Deployment, `replicas: 1`) runs with `serviceAccountName: controller-admin` and `automountServiceAccountToken: true`.
- Effect: compromise of `platform-controller` yields cluster-admin.
- Scope note: the rule has no `nonResourceURLs` field, so this grant covers resources only.

**E2 (critical, manifest-derived). `build/ci-runner` → pod in `platform` as `controller-admin` → cluster-admin via E1.**
- Source: RoleBinding `ci-runner-platform-deploy` (subject `build/ci-runner`, binding namespace `platform`) → Role `platform-deployer` R1 (core `pods` g,l,w,c).
- Path: `ci-runner` creates a Pod in `platform` with `serviceAccountName: controller-admin`. The pod runs with E1's grant.
- Blocked by: nothing in the export. Admission is in Audit mode, and PSA is not enforced on `platform` against this.
- Live check: server-side dry run as `system:serviceaccount:build:ci-runner`, pod naming `controller-admin`. Not performed.

**E3 (high, manifest-derived). `prod/deploy-bot` → `billing-reconciler` or `orders-api-sa` → Secrets.**
- Source: RoleBinding `deploy-bot-deployer` → Role `deployer` R1 (`apps/deployments`, `apps/replicasets` g,l,w,c,u,p) in `prod`.
- Path A: create or patch a Deployment in `prod` with `serviceAccountName: billing-reconciler`. Its pods read `legacy-billing-migration` Secrets through RoleBinding `billing-reconciler-secrets` → Role `billing-secrets` R1 (core `secrets` g,l).
- Path B: the same with `serviceAccountName: orders-api-sa`. Its pods read `prod` Secrets through Role `orders-api-config` R1 (core `secrets` g,l,w).
- Also reachable: cluster-wide ConfigMap read (CRB `deploy-bot-cm-read`).
- Blocked by: nothing in the export. Live check not performed.

**E4 (high, manifest-derived). `prod/billing-reconciler` → Job as `orders-api-sa` → `prod` Secrets.**
- Source: RoleBinding `billing-reconciler-prod` → Role `reconciler` R2 (`batch/jobs` g,l,c) in `prod`.
- Path: create a Job in `prod` with `serviceAccountName: orders-api-sa`. The Job's pod reads `prod` Secrets through `orders-api-config` R1.
- Also reachable: a Job running as `deploy-bot` (E3).
- Blocked by: nothing in the export. Live check not performed.

**E5 (medium, direct). Secret read in `legacy-billing-migration` by two cross-namespace subjects.**
- `build/ci-runner` via RoleBinding `ci-runner-legacy-secrets` → Role `billing-secrets` R1.
- `prod/billing-reconciler` via RoleBinding `billing-reconciler-secrets` → Role `billing-secrets` R1.
- These are direct grants, not paths.

**E6 (medium, manifest-derived). `maya.chen` impersonates `legacy-billing-migration` ServiceAccounts.**
- Source: RoleBinding `maya-billing-migrator` → Role `billing-migrator` R2 (core `serviceaccounts`, `users`, `groups` i) in `legacy-billing-migration`.
- Effective for ServiceAccounts in `legacy-billing-migration` (`reconcile-job`, `legacybill-svc-01` to `07`). Those ServiceAccounts give maya ConfigMap and Service update and patch in `legacy-billing-migration` through `legacybill-role-03`. None of them reads Secrets.
- Not effective for `users` and `groups`. Those checks are cluster-scoped, and a RoleBinding does not satisfy them (manifest-derived; confirm with `kubectl auth can-i`).

**E7 (low, manifest-derived). Nine ServiceAccounts with tokens but no RBAC.**
- `build-cache`, `platform-agent`, `analytics-worker`, `payments-gateway-sa`, `ledger-sa`, `media-worker`, `metrics-agent`, `reconcile-job`, `addons-legacy`.
- Their API grant is zero. Their workloads still mount tokens, because `automountServiceAccountToken: true` appears in nearly every Deployment. The risk is the token, not RBAC. For `media-worker` the token is secondary to E8.

**E8 (critical, manifest-derived, node-level). `media-processing/media-worker` → privileged pod → node root.**
- Source: Deployment `transcoder` in `media-processing` (`workloads/media-processing/deployments.yaml`, lines 1 to 33).
  - Pod: `serviceAccountName: media-worker`, `automountServiceAccountToken: true`, `hostNetwork: true`.
  - Container `app`: `securityContext.privileged: true`, `capabilities.add: [SYS_ADMIN]`, `runAsNonRoot: false`.
  - Volume `hostfs`: `hostPath: /`, mounted read-write at `/host`.
- RBAC of `media-worker`: none. It is unbound, so no API permissions.
- Effect: the container has root on the node's filesystem and uses the node's network namespace. It can read kubelet-stored tokens and Secret volumes of other pods on the same node.
- Chain to E1: if `platform-controller` runs on the same node, its `controller-admin` token is readable from the host, and E1 follows.
- Admission and PSA: neither blocks it (Section 1).
- Node placement is not in the export. Check with `kubectl get pods -A -o wide`.

## 4. Per-subject determinations

Notation: `RB` RoleBinding, `CRB` ClusterRoleBinding. "Union" lists the capabilities held in the namespace after combining all bindings. Cluster-wide capabilities are listed separately.

### 4.1 Namespace `default`

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| default-svc-01 | RB `default-svc-01-default-role-04` → `default-role-04` R1; RB `default-svc-01-default-role-01` → `default-role-01` R1 | `core pods g,l`; `core services, configmaps, endpoints g,l,w,u,p` |
| default-svc-02 | RB `default-svc-02-default-role-05` → `default-role-05` R1, R2 | `core configmaps g,l,w,u,p`; `apps/replicasets, apps/statefulsets g,l,w` |
| default-svc-03 | RB `default-svc-03-default-role-02` → `default-role-02` R1, R2 | `core endpoints, pods, configmaps g,l`; `apps/replicasets, apps/deployments g,l,w` |
| default-svc-04 | RB `default-svc-04-default-role-04` → R1 | `core pods g,l` |
| default-svc-05 | RB `default-svc-05-default-role-04` → R1 | `core pods g,l` |
| default-svc-06 | RB `default-svc-06-default-role-03` → R1 | `core services, configmaps g,l` |

### 4.2 Namespace `kube-system` (system)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| kubesystem-svc-01 | RB `kubesystem-svc-01-kubesystem-role-03` → R1 | `core configmaps, services g,l` |
| kubesystem-svc-02 | RB `kubesystem-svc-02-kubesystem-role-02` → R1, R2; RB `kubesystem-svc-02-kubesystem-role-03` → R1 | `core configmaps, services g,l,w`; `apps/statefulsets, apps/replicasets g,l,w` |
| kubesystem-svc-03 | RB `kubesystem-svc-03-kubesystem-role-02` → R1, R2; RB `kubesystem-svc-03-kubesystem-role-03` → R1 | Same as kubesystem-svc-02 |
| kubesystem-svc-04 | RB `kubesystem-svc-04-kubesystem-role-02` → R1, R2; **CRB `kubesystem-svc-04-view-363` → ClusterRole `view` R1, R2** | Namespace: `core configmaps, services g,l,w`; `apps/statefulsets, apps/replicasets g,l,w`. **Cluster-wide:** `core pods, services, endpoints, configmaps g,l,w`; `apps/deployments, apps/replicasets g,l,w` |
| kubesystem-svc-05 | RB `kubesystem-svc-05-kubesystem-role-01` → R1; RB `kubesystem-svc-05-kubesystem-role-02` → R1, R2 | `core configmaps, services g,l,w,u,p`; `apps/statefulsets, apps/replicasets g,l,w` |
| kubesystem-svc-06 | RB `kubesystem-svc-06-kubesystem-role-02` → R1, R2; RB `kubesystem-svc-06-kubesystem-role-03` → R1 | Same as kubesystem-svc-02 |
| kubesystem-svc-07 | RB `kubesystem-svc-07-kubesystem-role-03` → R1 | `core configmaps, services g,l` |

### 4.3 Namespace `prod` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| deploy-bot | RB `deploy-bot-deployer` → `deployer` R1, R2 (prod); CRB `deploy-bot-cm-read` → `configmap-reader` R1 (cluster); RB `legacy-migration-admin` → `migration-operator` R1, R2 (legacy) | **prod:** `apps/deployments, apps/replicasets g,l,w,c,u,p`; `core pods, configmaps g,l`. **cluster:** `core configmaps g,l`. **legacy:** `rbac/roles, rbac/rolebindings g,l`; `rbac/roles, rbac/clusterroles b,e,c`. No `create` on rolebindings, so no binding can be created. See E3. |
| billing-reconciler | RB `billing-reconciler-prod` → `reconciler` R1, R2 (prod); RB `billing-reconciler-secrets` → `billing-secrets` R1, R2 (legacy) | **prod:** `core configmaps g,l,w`; `batch/jobs g,l,c`. **legacy:** `core secrets g,l`; `core configmaps g,l`. See E4, E5. |
| orders-api-sa | RB `orders-api-config` → `orders-api-config` R1 | `core configmaps, secrets g,l,w`. Nothing else. See Section 6. |
| prod-svc-01 | RB `prod-svc-01-prod-role-01` → R1; CRB `prod-svc-01-view-677` → `view` R1, R2; CRB `prod-svc-01-view-509` → `view` R1, R2 | **prod:** `core pods, services g,l`. **cluster:** view rules as in kubesystem-svc-04. Two CRBs grant the same rules (cleanup). |
| prod-svc-02 | RB `prod-svc-02-prod-role-03` → R1; RB `prod-svc-02-prod-role-01` → R1 | `core pods, configmaps g,l,w`; `core pods, services g,l` |
| prod-svc-03 | RB `prod-svc-03-prod-role-02` → R1, R2; RB `prod-svc-03-prod-role-01` → R1 | `core pods g,l,w,u,p`; `core services g,l`; `apps/deployments, apps/replicasets g,l,w` |
| prod-svc-04 | RB `prod-svc-04-prod-role-03` → R1; RB `prod-svc-04-prod-role-04` → R1, R2 | `core configmaps, pods g,l,w`; `apps/replicasets, apps/deployments g,l,w` |

### 4.4 Namespace `build` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| ci-runner | RB `ci-runner-build` → `ci-build` R1, R2, R3 (build); RB `ci-runner-platform-deploy` → `platform-deployer` R1, R2 (platform); RB `ci-runner-legacy-secrets` → `billing-secrets` R1, R2 (legacy); CRB `ci-runner-nodes` → `node-reader` R1 (cluster) | **build:** `core configmaps g,l,w`; `core pods g,l,c`; `batch/jobs g,l`. **platform:** `core pods g,l,w,c`; `core configmaps, serviceaccounts g,l`. **legacy:** `core secrets g,l`; `core configmaps g,l`. **cluster:** `core nodes g,l`. See E2, E5. |
| build-cache | None | No grant (unbound). Token mounted. See E7. |
| build-svc-01 | RB `build-svc-01-build-role-02` → R1, R2; RB `build-svc-01-build-role-03` → R1, R2 | `core configmaps, services, endpoints, pods g,l`; `apps/replicasets, apps/statefulsets g,l,w` |
| build-svc-02 | RB `build-svc-02-build-role-05` → R1 | `core pods, configmaps, services g,l,w` |
| build-svc-03 | RB `build-svc-03-build-role-03` → R1, R2 | `core services, configmaps, pods g,l`; `apps/statefulsets, apps/replicasets g,l,w` |
| build-svc-04 | RB `build-svc-04-build-role-01` → R1; CRB `build-svc-04-view-139` → `view` R1, R2 | **build:** `core endpoints g,l,w`. **cluster:** view rules as in kubesystem-svc-04 |
| build-svc-05 | RB `build-svc-05-build-role-01` → R1; RB `build-svc-05-build-role-03` → R1, R2; CRB `build-svc-05-view-692` → `view` R1, R2 | **build:** `core endpoints g,l,w`; `core services, configmaps, pods g,l`; `apps/statefulsets, apps/replicasets g,l,w`. **cluster:** view rules as in kubesystem-svc-04 |
| build-svc-06 | RB `build-svc-06-build-role-03` → R1, R2 | Same as build-svc-03 |

### 4.5 Namespace `platform` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| controller-admin | CRB `platform-controller-admin` → `cluster-superuser` R1 | **cluster:** all resources, all API groups, all verbs. See E1. Used by `platform-controller`. |
| platform-agent | None | No grant (unbound). Token mounted. See E7. |
| platform-svc-01 | RB `platform-svc-01-platform-role-02` → R1; RB `platform-svc-01-platform-role-03` → R1 | `core pods, services g,l,w`; `core configmaps g,l` |
| platform-svc-02 | RB `platform-svc-02-platform-role-03` → R1; RB `platform-svc-02-platform-role-01` → R1 | `core pods, services g,l`; `core configmaps g,l,w` |
| platform-svc-03 | RB `platform-svc-03-platform-role-02` → R1 | `core pods, services g,l,w` |
| platform-svc-04 | RB `platform-svc-04-platform-role-02` → R1 | `core pods, services g,l,w` |
| platform-svc-05 | RB `platform-svc-05-platform-role-01` → R1; RB `platform-svc-05-platform-role-03` → R1 | `core configmaps g,l,w`; `core pods, services g,l` |
| platform-svc-06 | RB `platform-svc-06-platform-role-02` → R1 | `core pods, services g,l,w` |
| platform-svc-07 | RB `platform-svc-07-platform-role-02` → R1; RB `platform-svc-07-platform-role-01` → R1 | `core pods, services g,l,w`; `core configmaps g,l,w` |

### 4.6 Namespace `dev` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| dev-svc-01 | RB `dev-svc-01-dev-role-04` → `dev-role-04` R1 | `core configmaps, pods g,l,w,u,p` |
| dev-svc-02 | RB `dev-svc-02-dev-role-02` → `dev-role-02` R1, R2 | `core endpoints, services g,l`; `apps/replicasets, apps/statefulsets g,l,w` |
| dev-svc-03 | RB `dev-svc-03-dev-role-04` → R1 | `core configmaps, pods g,l,w,u,p` |
| dev-svc-04 | RB `dev-svc-04-dev-role-04` → R1; RB `dev-svc-04-dev-role-02` → R1, R2 | `core configmaps, pods g,l,w,u,p`; `core endpoints, services g,l`; `apps/replicasets, apps/statefulsets g,l,w` |

### 4.7 Namespace `staging` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| staging-svc-01 | RB `staging-svc-01-staging-role-04` → R1, R2; CRB `staging-svc-01-view-163` → `view` R1, R2 | **staging:** `core endpoints, pods g,l,w`; `apps/replicasets, apps/deployments g,l,w`. **cluster:** view rules as in kubesystem-svc-04 |
| staging-svc-02 | RB `staging-svc-02-staging-role-04` → R1, R2 | `core endpoints, pods g,l,w`; `apps/replicasets, apps/deployments g,l,w` |
| staging-svc-03 | RB `staging-svc-03-staging-role-02` → R1, R2; RB `staging-svc-03-staging-role-04` → R1, R2 | `core configmaps g,l,w,u,p`; `core endpoints, pods g,l,w`; `apps/statefulsets, apps/replicasets, apps/deployments g,l,w` |
| staging-svc-04 | RB `staging-svc-04-staging-role-04` → R1, R2; RB `staging-svc-04-staging-role-02` → R1, R2 | Same as staging-svc-03 |
| staging-svc-05 | RB `staging-svc-05-staging-role-04` → R1, R2; RB `staging-svc-05-staging-role-03` → R1, R2 | `core endpoints, pods g,l,w`; `core services g,l,w`; `apps/replicasets, apps/deployments, apps/statefulsets g,l,w` |

### 4.8 Namespace `analytics` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| analytics-worker | None | No grant (unbound). Token mounted. See E7. |
| analytics-svc-01 | RB `analytics-svc-01-analytics-role-02` → R1, R2 | `core pods g,l,w,u,p`; `apps/deployments, apps/replicasets g,l,w` |
| analytics-svc-02 | RB `analytics-svc-02-analytics-role-03` → R1, R2 | `core pods, endpoints g,l`; `apps/statefulsets, apps/replicasets g,l,w` |
| analytics-svc-03 | RB `analytics-svc-03-analytics-role-02` → R1, R2 | Same as analytics-svc-01 |
| analytics-svc-04 | RB `analytics-svc-04-analytics-role-01` → R1, R2; RB `analytics-svc-04-analytics-role-02` → R1, R2 | `core endpoints, pods g,l,w,u,p`; `apps/deployments, apps/replicasets g,l,w` |
| analytics-svc-05 | RB `analytics-svc-05-analytics-role-02` → R1, R2; RB `analytics-svc-05-analytics-role-03` → R1, R2 | `core pods g,l,w,u,p`; `core endpoints g,l`; `apps/deployments, apps/replicasets, apps/statefulsets g,l,w` |
| analytics-svc-06 | RB `analytics-svc-06-analytics-role-02` → R1, R2; RB `analytics-svc-06-analytics-role-03` → R1, R2 | Same as analytics-svc-05 |

### 4.9 Namespace `payments` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| payments-gateway-sa | None | No grant (unbound). Token mounted. See E7. |
| ledger-sa | None | No grant (unbound). Token mounted. See E7. |
| payments-svc-01 | RB `payments-svc-01-payments-role-01` → R1, R2; RB `payments-svc-01-payments-role-02` → R1, R2 | `core endpoints, services g,l,w`; `apps/deployments, apps/replicasets, apps/statefulsets g,l,w` |
| payments-svc-02 | RB `payments-svc-02-payments-role-01` → R1, R2 | `core endpoints, services g,l,w`; `apps/deployments, apps/replicasets g,l,w` |
| payments-svc-03 | RB `payments-svc-03-payments-role-03` → R1, R2 | `core configmaps, endpoints g,l,w`; `apps/statefulsets, apps/deployments g,l,w` |
| payments-svc-04 | RB `payments-svc-04-payments-role-02` → R1, R2; RB `payments-svc-04-payments-role-01` → R1, R2 | `core endpoints, services g,l,w`; `apps/deployments, apps/replicasets, apps/statefulsets g,l,w` |
| payments-svc-05 | RB `payments-svc-05-payments-role-03` → R1, R2; RB `payments-svc-05-payments-role-01` → R1, R2 | `core configmaps, endpoints, services g,l,w`; `apps/statefulsets, apps/deployments, apps/replicasets g,l,w` |

### 4.10 Namespace `media-processing` (active; privileged workloads)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| media-worker | None | No RBAC grant (unbound). **Runs privileged, host-network, host-root pod `transcoder`. See E8.** Token mounted. |
| mediaproce-svc-01 | RB `mediaproce-svc-01-mediaproce-role-01` → R1, R2; RB `mediaproce-svc-01-mediaproce-role-03` → R1, R2 | `core configmaps, pods, endpoints g,l,w,u,p`; `core services g,l`; `apps/statefulsets, apps/replicasets, apps/deployments g,l,w` |
| mediaproce-svc-02 | RB `mediaproce-svc-02-mediaproce-role-01` → R1, R2; RB `mediaproce-svc-02-mediaproce-role-03` → R1, R2; CRB `mediaproce-svc-02-view-114` → `view` R1, R2 | **media-processing:** as mediaproce-svc-01. **cluster:** view rules as in kubesystem-svc-04 |
| mediaproce-svc-03 | RB `mediaproce-svc-03-mediaproce-role-01` → R1, R2 | `core configmaps, pods, endpoints g,l,w,u,p`; `apps/statefulsets, apps/replicasets g,l,w` |
| mediaproce-svc-04 | RB `mediaproce-svc-04-mediaproce-role-02` → R1, R2 | `core endpoints, configmaps, services g,l,w,u,p`; `apps/replicasets, apps/deployments g,l,w` |

### 4.11 Namespace `monitoring` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| metrics-agent | None | No grant (unbound). Token mounted. See E7. |
| monitoring-svc-01 | RB `monitoring-svc-01-monitoring-role-03` → R1 | `core configmaps, pods, services g,l,w,u,p` |
| monitoring-svc-02 | RB `monitoring-svc-02-monitoring-role-05` → R1, R2 | `core endpoints, configmaps, pods g,l`; `apps/replicasets, apps/deployments g,l,w` |
| monitoring-svc-03 | RB `monitoring-svc-03-monitoring-role-04` → R1; RB `monitoring-svc-03-monitoring-role-01` → R1, R2 | `core configmaps, services, pods g,l,w,u,p`; `apps/deployments, apps/replicasets g,l,w` |
| monitoring-svc-04 | RB `monitoring-svc-04-monitoring-role-02` → R1; CRB `monitoring-svc-04-view-620` → `view` R1, R2 | **monitoring:** `core configmaps, endpoints g,l`. **cluster:** view rules as in kubesystem-svc-04 |
| monitoring-svc-05 | RB `monitoring-svc-05-monitoring-role-04` → R1 | `core configmaps, services, pods g,l` |
| monitoring-svc-06 | RB `monitoring-svc-06-monitoring-role-03` → R1 | `core configmaps, pods, services g,l,w,u,p` |
| monitoring-svc-07 | RB `monitoring-svc-07-monitoring-role-05` → R1, R2 | `core endpoints, configmaps, pods g,l`; `apps/replicasets, apps/deployments g,l,w` |

### 4.12 Namespace `data` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| data-svc-01 | RB `data-svc-01-data-role-04` → R1; RB `data-svc-01-data-role-01` → R1, R2 | `core endpoints g,l`; `core pods, configmaps g,l`; `apps/statefulsets, apps/replicasets g,l,w` |
| data-svc-02 | RB `data-svc-02-data-role-01` → R1, R2 | `core pods, configmaps g,l`; `apps/statefulsets, apps/replicasets g,l,w` |
| data-svc-03 | RB `data-svc-03-data-role-05` → R1, R2; RB `data-svc-03-data-role-01` → R1, R2 | `core configmaps, pods g,l,w,u,p`; `apps/statefulsets, apps/deployments, apps/replicasets g,l,w` |
| data-svc-04 | RB `data-svc-04-data-role-03` → R1; RB `data-svc-04-data-role-05` → R1, R2 | `core services, endpoints, configmaps g,l`; `core configmaps, pods g,l,w,u,p`; `apps/statefulsets, apps/deployments g,l,w` |

### 4.13 Namespace `legacy-billing-migration` (completed-project / legacy-looking)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| reconcile-job | None | No grant (unbound). Token mounted. See E7. |
| legacybill-svc-01 | RB `legacybill-svc-01-legacybill-role-01` → R1, R2; RB `legacybill-svc-01-legacybill-role-02` → R1 | `core pods g,l,w`; `apps/replicasets, apps/deployments g,l,w`; `core pods, configmaps, services g,l` |
| legacybill-svc-02 | RB `legacybill-svc-02-legacybill-role-03` → R1, R2 | `core configmaps, services g,l,w,u,p`; `apps/deployments, apps/statefulsets g,l,w` |
| legacybill-svc-03 | RB `legacybill-svc-03-legacybill-role-01` → R1, R2; RB `legacybill-svc-03-legacybill-role-03` → R1, R2 | `core pods g,l,w`; `apps/replicasets, apps/deployments g,l,w`; `core configmaps, services g,l,w,u,p`; `apps/deployments, apps/statefulsets g,l,w` |
| legacybill-svc-04 | RB `legacybill-svc-04-legacybill-role-02` → R1 | `core pods, configmaps, services g,l` |
| legacybill-svc-05 | RB `legacybill-svc-05-legacybill-role-02` → R1 | `core pods, configmaps, services g,l` |
| legacybill-svc-06 | RB `legacybill-svc-06-legacybill-role-03` → R1, R2; RB `legacybill-svc-06-legacybill-role-01` → R1, R2 | Same as legacybill-svc-03 |
| legacybill-svc-07 | RB `legacybill-svc-07-legacybill-role-03` → R1, R2 | Same as legacybill-svc-02 |

None of these ServiceAccounts reads Secrets. They are the targets of E6.

### 4.14 Namespace `kube-addons-old` (abandoned-looking / sparse)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| addons-legacy | None | No grant (unbound). Token mounted per export. See E7. |

The namespace has no Role, RoleBinding, or workloads directory in the export.

## 5. User subjects

### 5.1 `maya.chen` (User)

| Source | Binding → Role rules | Scope | Effective capability |
|---|---|---|---|
| Direct | RB `maya-dev-editor` → `dev-editor` R1, R2 | `dev` | `core pods, configmaps, services g,l,w,c,u,p,d`; `apps/deployments g,l,w,c,u,p` |
| Direct | RB `maya-billing-migrator` → `billing-migrator` R1 | `legacy-billing-migration` | `core pods, configmaps g,l` |
| Direct, namespaced | RB `maya-billing-migrator` → `billing-migrator` R2 | `legacy-billing-migration` | `i` on `serviceaccounts` for ServiceAccounts in `legacy-billing-migration` (E6) |
| Direct, not effective (manifest-derived) | RB `maya-billing-migrator` → `billing-migrator` R2 | `legacy-billing-migration` | `i` on `users` and `groups` is cluster-scoped and not satisfied by a RoleBinding |

**Path analysis.**
- Pod creation in `dev` (from `dev-editor`) can run as any `dev` ServiceAccount. None holds Secret access or cluster-wide bindings, so this adds no Secret access.
- Impersonation of `legacy-billing-migration` ServiceAccounts gives their grants (Section 4.13). No Secret access.
- No cluster-wide or Secret path found.

**Determination.** Over-privileged for a dev editor because of the impersonation grant (E6). Not over-privileged for Secrets or cluster scope, as far as the manifests show.

### 5.2 `sam.okafor` (User)

| Source | Binding → Role or ClusterRole rules | Scope | Effective capability |
|---|---|---|---|
| Direct | RB `sam-metrics-viewer` → `metrics-viewer` R1 | `monitoring` | `core pods, services, endpoints g,l,w` |
| Direct | RB `sam-legacy-view` → ClusterRole `view` R1, R2 | `legacy-billing-migration` only | `core pods, services, endpoints, configmaps g,l,w`; `apps/deployments, apps/replicasets g,l,w` |

**Path analysis.** No create, update, patch, delete, impersonate, or escalate verb anywhere. No cluster-wide binding. No Secret access. No pod-creation path.

**Determination.** Read-only. The ConfigMap read in `legacy-billing-migration` is broader than a monitoring role would need. Confirm the intent of `sam-legacy-view`.

## 6. The subject that holds exactly what it appears to hold

**`prod/orders-api-sa`.**
- **Direct grant.** RoleBinding `orders-api-config` (prod) → Role `orders-api-config` R1 (core `configmaps, secrets` g,l,w). Scope: `prod` only.
- **Search for other grants.** All 117 RoleBindings and all 11 ClusterRoleBindings were checked. No other binding names `prod/orders-api-sa`. No group path exists, because the export has no Group subjects.
- **Determination.** Its RBAC privilege is exactly get, list, and watch on ConfigMaps and Secrets in `prod`. Nothing else, nothing cluster-wide.
- **Caveat about intent.** The name suggests configuration access, and the Role grants Secret access too. Confirm with the owner that Secret read is intended. This is the only reason the verdict is not an unconditional clearance.
- **Caveat about reachability.** E3 and E4 let `deploy-bot` and `billing-reconciler` run pods under this identity and read `prod` Secrets. That is a finding about those subjects, not about this grant.
- **Caveat about the node.** The verdict covers RBAC only. If `orders-api` pods share a node with `transcoder` (E8), the ServiceAccount token is readable from the host. Node placement is unverified.
- **Verification still needed.** `workloads/prod/deployments.yaml` shows `orders-api-sa` in use, but the file was not read in full for this determination.

## 7. Corrections to `0-rbac_map.md`

1. **Section 9, item 2 (`legacy-migration-admin`) is wrong.** `deploy-bot` cannot take over `legacy-billing-migration`. `migration-operator` has no `create` on `rolebindings`, so `deploy-bot` cannot create a binding that applies any Role. `bind` and `escalate` do not substitute for that. `deploy-bot` also has no Secret access there. Its real risk is E3.
2. **Section 9, item 7 miscounts.** The cluster-wide `view` grant reaches **seven** ServiceAccounts: `kubesystem-svc-04`, `prod-svc-01` (two bindings), `build-svc-04`, `build-svc-05`, `staging-svc-01`, `mediaproce-svc-02`, and `monitoring-svc-04`.
3. **E2 is missing from the map.** `ci-runner` → `controller-admin` through pod creation in `platform` should be rank 1 or 2.
4. **E3, E4, E6 are missing from the map.** Workload-creation paths and the impersonation scope belong in the risk section.
5. **E8 is missing from the map.** The privileged, host-network, host-root `transcoder` pod under `media-worker` is among the most serious findings and belongs in the top two.
6. **Admission is misdescribed in earlier versions.** `disallow-privileged` runs in Audit mode and checks only Deployments. It blocks nothing.
7. **E1 is active, not latent.** `platform-controller` runs with `controller-admin` now. The file `workloads/platform/daemonsets.yaml` holds a Deployment.
8. **Section 8 (cross-namespace bindings) is correct.** Each cross-namespace grant applies only in the binding's namespace.

## 8. Verification still needed

| Check | Command or method | Resolves |
|---|---|---|
| Node placement | `kubectl get pods -A -o wide` | Whether E8 reaches E1 and whether `orders-api` shares a node with `transcoder` |
| Namespace enforcement | `kubectl get ns media-processing --show-labels` | Whether PSA is absent live |
| Admission mode | `kubectl get validatingadmissionpolicybinding disallow-privileged-binding -o yaml` | Confirms `Audit` live |
| E2 pod-SA assignment | Server dry run of a Pod in `platform` with `serviceAccountName: controller-admin`, as `system:serviceaccount:build:ci-runner` | E2 |
| E3 and E4 workload creation | Server dry run of a Deployment in `prod` as `deploy-bot`, and of a Job as `billing-reconciler`, naming `billing-reconciler` or `orders-api-sa` | E3, E4 |
| Live impersonation scope | `kubectl auth can-i impersonate serviceaccounts --as=maya.chen -n legacy-billing-migration`; same for `users` and `groups` | E6 |
| Actual pod identities and mounts | Review `workloads/prod/deployments.yaml` in full and the remaining `workloads/*` files | Section 6, E7 |
| Bootstrap bindings | Compare the live cluster's default ClusterRoleBindings with the export | Any group-level grants missing from the export |
| Full permission listing | `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<name>` for each named subject | Confirms Sections 3 to 5 live |

The caller running these checks needs impersonation rights. Without them, the commands return `forbidden` and prove nothing.
