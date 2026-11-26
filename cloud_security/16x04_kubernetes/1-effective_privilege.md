# Effective privilege by subject

## 1. Method and limits

**Source.** Every grant below comes from the supplied RBAC exports, cross-referenced with `0-rbac_map.md` (roles in Section 6; bindings in Section 7). The snapshot contains 117 RoleBindings, 11 ClusterRoleBindings, 62 Roles, 5 ClusterRoles, 86 ServiceAccounts, 2 Users, and no Group subjects. Rule IDs (R1, R2, ...) refer to Section 6 of the map. Each named ServiceAccount is determined in Section 4; the two User subjects are determined in Section 5.

**Semantics applied.**
- Kubernetes RBAC is additive. A subject's effective permission set is the union of every rule reached through every binding that names it, directly or through a group. No rule subtracts an allowed action.
- A RoleBinding grants only in its own namespace, even when it references a ClusterRole (`sam-legacy-view`, `legacy-migration-admin`, and the cross-namespace bindings all follow this).
- A ClusterRoleBinding grants cluster-wide.
- A cross-namespace subject (for example `build/ci-runner` in a `platform` RoleBinding) receives the binding's rules in the binding's namespace, under its own identity.
- RBAC has no verb that checks whether a pod creator may use a given ServiceAccount. A subject that can create pods or workloads in a namespace can run them under any ServiceAccount in that namespace. Only admission could block this. Paths of this kind are marked manifest-derived.
- Node access (hostPath, hostNetwork, privileged) is not an RBAC grant. It is a separate class of risk, listed under E8.

**Abbreviations.** `g` get, `l` list, `w` watch, `c` create, `u` update, `p` patch, `d` delete, `b` bind, `e` escalate, `i` impersonate. Core API group has no prefix. Other groups are written `apps/`, `batch/`, `rbac/`. A wildcard is written as the word "wildcard", not as a symbol.

**resourceNames and nonResourceURLs.** None recorded in any Role, ClusterRole, RoleBinding, or ClusterRoleBinding in the export (`grep -rn "resourceNames\|nonResourceURLs"` returned no lines).

**Absence method.** A negative determination is limited to the supplied snapshot and follows a review of all 117 RoleBindings, all 11 ClusterRoleBindings, and the rules of every referenced Role and ClusterRole. Checks run:
- For a ServiceAccount, a direct binding match requires `kind: ServiceAccount` plus the exact `metadata.namespace` and `metadata.name`; a `User` subject would match its canonical username `system:serviceaccount:<namespace>:<name>`; group-derived grants require a matching `Group` subject. I checked all three routes for each ServiceAccount, not only occurrences of its short name.
- `yq '.subjects[]?.name' rolebindings.yaml clusterrolebindings.yaml | sort | uniq -c`: 128 binding documents, one subject each. Every ServiceAccount named in a binding is listed in Section 4. The nine unbound ServiceAccounts do not appear.
- `grep -c "kind: Group"` in both binding files: 0. No Group subjects exist.
- `grep -rn "system:serviceaccount:" rolebindings.yaml clusterrolebindings.yaml`: no User subject matches any ServiceAccount's canonical username. `grep -rn "system:" rolebindings.yaml clusterrolebindings.yaml`: no implicit group subject appears, including `system:serviceaccounts`, `system:serviceaccounts:<namespace>`, and `system:authenticated`.
- `grep -rn "maya.chen\|sam.okafor" .`: 4 matches, all subject lines in `rolebindings.yaml` (two per user).
- `grep -rn "addons-legacy" .`: 1 match, in `serviceaccounts.yaml`.
- `grep -n "secrets\|impersonate\|escalate\|bind\|*" roles.yaml clusterroles.yaml`: `bind` and `escalate` in `migration-operator`; `impersonate` in `billing-migrator`; `secrets` in `billing-secrets` and `orders-api-config` (the map assigns these); the wildcard rule in `cluster-superuser`; `secrets` in `secret-reader-cluster`.
- `grep -rn "system:" rolebindings.yaml clusterrolebindings.yaml roles.yaml clusterroles.yaml`: no matches.

**Admission and Pod Security (checked).**
- `admission/policies.yaml` defines one ValidatingAdmissionPolicy, `disallow-privileged`. It checks only `privileged: true` on Deployments.
- `admission/bindings.yaml` binds it with `validationActions: [Audit]`. Violations are written to the audit log. Nothing is rejected. `failurePolicy` governs evaluation errors, not audit results.
- `podsecurity-labels.yaml`: `media-processing`, `kube-system`, and `kube-addons-old` have no PSA labels, so no Pod Security enforcement applies there. The other namespaces carry `enforce: baseline`, which does not restrict `serviceAccountName` but does forbid privileged containers and host namespaces.
- Conclusion: no admission or PSA control in the export blocks E2, E3, E4, or E8.

**Not verified.**
- **Live cluster.** No kubeconfig exists on the analysis machine (`~/.kube` and `/etc/kubernetes` absent, `KUBECONFIG` empty). No `kubectl auth can-i` or server-side dry run was run. All path findings are manifest-derived.
- **Bootstrap bindings.** The export contains no `system:` bindings, but a live cluster normally has some (for example to `system:authenticated`). If they exist, effective permissions are larger than shown. This is the main open limit of this determination.
- **Node placement.** The export does not say which node each pod runs on.
- **Live admission mode.** The `Audit` binding is assumed to match the live cluster.
- **Workload identity.** Only the `serviceAccountName` lines were extracted from `workloads/`, not the full manifests.

**Unbound role objects.** The seven unbound Roles (`prod/prod-role-05`, `build/build-role-04`, `dev/dev-role-01`, `dev/dev-role-03`, `dev/dev-role-05`, `staging/staging-role-01`, and `data/data-role-02`) and unbound ClusterRole `secret-reader-cluster` are not referenced by any of the 128 bindings. Their rule definitions exist in the export, but they contribute no permissions to any subject's effective union in this snapshot. The binding-reference search in `0-rbac_map.md` Section 6.3 identifies them; the full Role and ClusterRole inventory is in Section 6 of that map.

## 2. Named subjects: summary

| Subject | Kind | Direct effective privilege | Path-based privilege (manifest-derived) | Verdict |
|---|---|---|---|---|
| `platform/controller-admin` | ServiceAccount | Cluster-wide wildcard on API groups, resources, and verbs (`platform-controller-admin` → `cluster-superuser` R1). Used by Deployment `platform-controller`. | Already cluster-admin-equivalent. Its pod is reachable from E2. | Over-privileged. Critical (E1). |
| `build/ci-runner` | ServiceAccount | Union of `ci-runner-build` (build), `ci-runner-platform-deploy` (platform), `ci-runner-legacy-secrets` (legacy), and `ci-runner-nodes` (cluster): build ConfigMap/pod/job reads, build pod create, platform pod create and ConfigMap/ServiceAccount reads, legacy Secret/ConfigMap reads, cluster-wide node reads | Can run as any build or platform ServiceAccount when creating a pod there. This includes `build-svc-04`/`build-svc-05` (cluster-wide `view`) and `platform/controller-admin` (cluster superuser); see E2 and E9. | Over-privileged. Critical. |
| `prod/deploy-bot` | ServiceAccount | Union of `deploy-bot-deployer` (prod), `deploy-bot-cm-read` (cluster), and `legacy-migration-admin` (legacy): Deployment/ReplicaSet write and pod/ConfigMap read in prod; cluster-wide ConfigMap read; legacy role/rolebinding read and namespaced Role create/bind/escalate actions. The binding does not grant cluster-scoped ClusterRole operations or create/update of RoleBindings. | Can deploy under any prod ServiceAccount: `billing-reconciler` or `orders-api-sa` reaches Secrets; `prod-svc-01` reaches cluster-wide `view` (E3, E9). | Over-privileged. High. |
| `prod/billing-reconciler` | ServiceAccount | Union of `billing-reconciler-prod` (prod) and `billing-reconciler-secrets` (legacy): prod ConfigMap read and Job create; legacy Secret/ConfigMap read | Can create a Job under any prod ServiceAccount, including `orders-api-sa` (prod Secrets), `deploy-bot` (its deployment capability), or `prod-svc-01` (cluster-wide `view`); see E4 and E9. | Over-privileged. High. |
| `prod/orders-api-sa` | ServiceAccount | get, list, watch on ConfigMaps and Secrets in `prod`; nothing else | None of its own. Its token is reachable through E3 and E4. | **Cleared (RBAC), with caveats.** See Section 6. |
| `media-processing/media-worker` | ServiceAccount | None. Unbound in RBAC. | Runs privileged `transcoder` with host root filesystem, host network, and SYS_ADMIN (E8) | Over-privileged through the node, not RBAC. Critical. |
| `maya.chen` | User | Write to Pods, ConfigMaps, Services, Deployments in `dev`; read Pods/ConfigMaps in `legacy-billing-migration` | Impersonation of `legacy-billing-migration` ServiceAccounts (E6) | Over-privileged for a dev editor. Medium. No Secret path found. |
| `sam.okafor` | User | Union of `sam-metrics-viewer` (monitoring) and `sam-legacy-view` (legacy namespace only): read/watch permissions on the resources in ClusterRole `view`, restricted by the first RoleBinding to monitoring and by the second RoleBinding to `legacy-billing-migration` | No pod/workload creation or impersonation path; no other subject binding or group path in the export | **Cleared as the correctly scoped read-only subject in this snapshot.** See Section 5.2. |
| Other ServiceAccounts | ServiceAccount | Each of the remaining 80 ServiceAccounts is individually listed in Section 4 with all bindings and the union of its rules, including unbound identities | Workload-creation paths are assessed by namespace in E2–E4 and E9; no path is inferred without an in-namespace create grant | See Section 4 and path analysis. |

## 3. Escalation and node-access paths

**E1 (critical, direct, active). `platform/controller-admin` is cluster-superuser.**
- Binding: ClusterRoleBinding `platform-controller-admin` → ClusterRole `cluster-superuser` R1 (`apiGroups` wildcard, `resources` wildcard, `verbs` wildcard).
- Scope: cluster-wide.
- In use: Deployment `platform-controller` in `platform` (file `workloads/platform/daemonsets.yaml`, which despite its name holds a Deployment, `replicas: 1`) runs with `serviceAccountName: controller-admin` and `automountServiceAccountToken: true`.
- Effect: compromise of `platform-controller` yields cluster-admin.
- Scope note: the rule has no `nonResourceURLs`, so this grant covers resources only.

**E2 (critical, manifest-derived). `build/ci-runner` → pod in `platform` as `controller-admin` → cluster-admin via E1.**
- Source: RoleBinding `ci-runner-platform-deploy` (subject `build/ci-runner`, binding namespace `platform`) → Role `platform-deployer` R1 (core `pods` g,l,w,c).
- Path: `ci-runner` creates a Pod in `platform` with `serviceAccountName: controller-admin`. The pod runs with E1's grant.
- Blocked by: nothing in the export.
- Live check: server-side dry run as `system:serviceaccount:build:ci-runner`, pod naming `controller-admin`. Not performed.

**E3 (high, manifest-derived). `prod/deploy-bot` → a selected prod ServiceAccount → its effective rights.**
- Source: RoleBinding `deploy-bot-deployer` → Role `deployer` R1 (`apps/deployments`, `apps/replicasets` g,l,w,c,u,p) in `prod`.
- The Deployment controller creates pods for the resulting workload. RBAC does not check whether `deploy-bot` may select a ServiceAccount, and no exported admission rule restricts `serviceAccountName`.
- With `serviceAccountName: billing-reconciler`, the pod receives `billing-reconciler` rights, including `legacy-billing-migration` Secret read through `billing-reconciler-secrets` → `billing-secrets` R1.
- With `serviceAccountName: orders-api-sa`, the pod receives `prod` Secret read through `orders-api-config` → `orders-api-config` R1.
- With `serviceAccountName: prod-svc-01`, the pod receives ClusterRole `view` cluster-wide through `prod-svc-01-view-677` and `prod-svc-01-view-509` (same grant duplicated); see E9.
- Also reachable: cluster-wide ConfigMap read (CRB `deploy-bot-cm-read`).
- Blocked by: nothing in the export. Live check not performed.

**E4 (high, manifest-derived). `prod/billing-reconciler` → Job as `orders-api-sa` → `prod` Secrets.**
- Source: RoleBinding `billing-reconciler-prod` → Role `reconciler` R2 (`batch/jobs` g,l,c) in `prod`.
- A Job's pod may use any ServiceAccount in `prod`; RBAC does not separately authorize the `serviceAccountName`, and no exported admission rule restricts it.
- As `orders-api-sa`, the Job's pod reads `prod` Secrets through RoleBinding `orders-api-config` → Role `orders-api-config` R1.
- As `deploy-bot`, the Job's pod can use the E3 deployment capability. As `prod-svc-01`, it receives cluster-wide `view`; see E9.
- Blocked by: nothing in the export. Live check not performed.

**E9 (medium, manifest-derived). Workload creators can select a more privileged ServiceAccount and inherit its grants.**
- `prod-svc-01` is bound to ClusterRole `view` by ClusterRoleBindings `prod-svc-01-view-677` and `prod-svc-01-view-509`. The effective grant is the union of those identical cluster-wide grants and its namespaced `prod-role-01` grant.
- `prod/deploy-bot` can create/update Deployments in `prod` (`deploy-bot-deployer` → `deployer` R1). `prod/billing-reconciler` can create Jobs there (`billing-reconciler-prod` → `reconciler` R2). Either workload can specify `serviceAccountName: prod-svc-01`; the pod then receives cluster-wide `view`.
- `build/ci-runner` can create pods in `build` (`ci-runner-build` → `ci-build` R2) and can select `build-svc-04` or `build-svc-05`; both have cluster-wide `view` ClusterRoleBindings. Its separate platform binding also allows pod creation as `platform/controller-admin` (E2).
- The view rules allow get/list/watch on pods, services, endpoints, ConfigMaps, Deployments, and ReplicaSets in all namespaces. They do not grant Secret access.
- `maya.chen` can create pods and Deployments in `dev`, but no ServiceAccount in `dev` has a binding to a Secret-reading or cluster-wide role in this snapshot. The export's Audit-only admission policy and Pod Security labels do not constrain `serviceAccountName`; these are manifest-derived conclusions, not live authorization tests.

**E5 (medium, direct). Secret read in `legacy-billing-migration` by two cross-namespace subjects.**
- `build/ci-runner` via RoleBinding `ci-runner-legacy-secrets` → Role `billing-secrets` R1.
- `prod/billing-reconciler` via RoleBinding `billing-reconciler-secrets` → Role `billing-secrets` R1.
- These are direct grants, not paths.

**E6 (medium, manifest-derived). `maya.chen` impersonates `legacy-billing-migration` ServiceAccounts.**
- Source: RoleBinding `maya-billing-migrator` → Role `billing-migrator` R2 (core `serviceaccounts`, `users`, `groups` i) in `legacy-billing-migration`.
- Effective for ServiceAccounts in `legacy-billing-migration` (`reconcile-job`, `legacybill-svc-01` to `07`). Those ServiceAccounts give maya ConfigMap and Service update and patch in `legacy-billing-migration` through `legacybill-role-03`. None of them reads Secrets.
- Not effective for `users` and `groups`: those checks are cluster-scoped, and a RoleBinding does not satisfy them (manifest-derived; confirm with `kubectl auth can-i`).

**E7 (low, manifest-derived). ServiceAccounts with no RBAC but mounted tokens.**
- Eight ServiceAccounts without RBAC are used by workloads, and their pods mount tokens (`automountServiceAccountToken: true`): `build-cache`, `platform-agent`, `analytics-worker`, `payments-gateway-sa`, `ledger-sa`, `media-worker`, `metrics-agent`, `reconcile-job`.
- `addons-legacy` has no workload in the export, so no token mount is recorded for it.
- Their API grant is zero. The risk is the token, not RBAC. For `media-worker` the token is secondary to E8.

**E8 (critical, manifest-derived, node-level). `media-processing/media-worker` → privileged pod → node root.**
- Source: Deployment `transcoder` in `media-processing` (`workloads/media-processing/deployments.yaml`, lines 1 to 33).
  - Pod: `serviceAccountName: media-worker`, `automountServiceAccountToken: true`, `hostNetwork: true`.
  - Container `app`: `privileged: true`, `capabilities.add: [SYS_ADMIN]`, `runAsNonRoot: false`.
  - Volume `hostfs`: `hostPath: /`, mounted read-write at `/host`.
- RBAC of `media-worker`: none.
- Effect: the container has root on the node's filesystem and uses the node's network namespace. It can read kubelet-stored tokens and Secret volumes of other pods on the same node.
- Chain to E1: if `platform-controller` runs on the same node, its `controller-admin` token is readable from the host, and E1 follows.
- Admission and PSA: neither blocks it (Section 1).
- Node placement is not in the export. Check with `kubectl get pods -A -o wide`.

**Unused ServiceAccounts.** 54 of the 86 ServiceAccounts run no pod in the export. They have no direct workload risk. They are still targets of E2–E4, because a subject that can create pods can name any of them. Their RBAC is listed in Section 4.

## 4. Per-subject determinations

Notation: `RB` RoleBinding, `CRB` ClusterRoleBinding. "Union" lists the capabilities held in the namespace after combining all bindings. Cluster-wide capabilities are listed separately. Rules are the R-numbers in `0-rbac_map.md`.

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
| kubesystem-svc-03 | RB `kubesystem-svc-03-kubesystem-role-02` → R1, R2; RB `kubesystem-svc-03-kubesystem-role-03` → R1 | `core configmaps, services g,l,w`; `apps/statefulsets, apps/replicasets g,l,w` |
| kubesystem-svc-04 | RB `kubesystem-svc-04-kubesystem-role-02` → R1, R2; CRB `kubesystem-svc-04-view-363` → ClusterRole `view` R1, R2 | Namespace: `core configmaps, services g,l,w`; `apps/statefulsets, apps/replicasets g,l,w`. Cluster-wide: `core pods, services, endpoints, configmaps g,l,w`; `apps/deployments, apps/replicasets g,l,w` |
| kubesystem-svc-05 | RB `kubesystem-svc-05-kubesystem-role-01` → R1; RB `kubesystem-svc-05-kubesystem-role-02` → R1, R2 | `core configmaps, services g,l,w,u,p`; `apps/statefulsets, apps/replicasets g,l,w` |
| kubesystem-svc-06 | RB `kubesystem-svc-06-kubesystem-role-02` → R1, R2; RB `kubesystem-svc-06-kubesystem-role-03` → R1 | `core configmaps, services g,l,w`; `apps/statefulsets, apps/replicasets g,l,w` |
| kubesystem-svc-07 | RB `kubesystem-svc-07-kubesystem-role-03` → R1 | `core configmaps, services g,l` |

### 4.3 Namespace `prod` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| deploy-bot | RB `deploy-bot-deployer` → `deployer` R1, R2 (prod); CRB `deploy-bot-cm-read` → `configmap-reader` R1 (cluster); RB `legacy-migration-admin` → `migration-operator` R1, R2 (legacy) | **prod:** `apps/deployments, apps/replicasets g,l,w,c,u,p`; `core pods, configmaps g,l`. **cluster:** `core configmaps g,l`. **legacy:** `rbac/roles, rbac/rolebindings g,l`; `rbac/roles c,b,e` within the RoleBinding's namespace. It cannot create/update RoleBindings; the `clusterroles` rule entry does not grant cluster-scoped operations through a RoleBinding. See E3. |
| billing-reconciler | RB `billing-reconciler-prod` → `reconciler` R1, R2 (prod); RB `billing-reconciler-secrets` → `billing-secrets` R1, R2 (legacy) | **prod:** `core configmaps g,l,w`; `batch/jobs g,l,c`. **legacy:** `core secrets g,l`; `core configmaps g,l`. See E4, E5. |
| orders-api-sa | RB `orders-api-config` → `orders-api-config` R1 | `core configmaps, secrets g,l,w`. Nothing else. See Section 6. |
| prod-svc-01 | RB `prod-svc-01-prod-role-01` → R1; CRB `prod-svc-01-view-677` → `view` R1, R2; CRB `prod-svc-01-view-509` → `view` R1, R2 | **prod:** `core pods, services g,l`. **cluster:** view rules as in kubesystem-svc-04. The two CRBs grant the same rules (cleanup). |
| prod-svc-02 | RB `prod-svc-02-prod-role-03` → R1; RB `prod-svc-02-prod-role-01` → R1 | `core pods, configmaps g,l,w`; `core pods, services g,l` |
| prod-svc-03 | RB `prod-svc-03-prod-role-02` → R1, R2; RB `prod-svc-03-prod-role-01` → R1 | `core pods g,l,w,u,p`; `core services g,l`; `apps/deployments, apps/replicasets g,l,w` |
| prod-svc-04 | RB `prod-svc-04-prod-role-03` → R1; RB `prod-svc-04-prod-role-04` → R1, R2 | `core configmaps, pods g,l,w`; `apps/replicasets, apps/deployments g,l,w` |

### 4.4 Namespace `build` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| ci-runner | RB `ci-runner-build` → `ci-build` R1, R2, R3 (build); RB `ci-runner-platform-deploy` → `platform-deployer` R1, R2 (platform); RB `ci-runner-legacy-secrets` → `billing-secrets` R1, R2 (legacy); CRB `ci-runner-nodes` → `node-reader` R1 (cluster) | **build:** `core configmaps g,l,w`; `core pods g,l,c`; `batch/jobs g,l`. **platform:** `core pods g,l,w,c`; `core configmaps, serviceaccounts g,l`. **legacy:** `core secrets g,l`; `core configmaps g,l`. **cluster:** `core nodes g,l`. See E2, E5. |
| build-cache | None | No RBAC grant (unbound). Token mounted by its workload. See E7. |
| build-svc-01 | RB `build-svc-01-build-role-02` → R1, R2; RB `build-svc-01-build-role-03` → R1, R2 | `core configmaps, services, endpoints, pods g,l`; `apps/replicasets, apps/statefulsets g,l,w` |
| build-svc-02 | RB `build-svc-02-build-role-05` → R1 | `core pods, configmaps, services g,l,w` |
| build-svc-03 | RB `build-svc-03-build-role-03` → R1, R2 | `core services, configmaps, pods g,l`; `apps/statefulsets, apps/replicasets g,l,w` |
| build-svc-04 | RB `build-svc-04-build-role-01` → R1; CRB `build-svc-04-view-139` → `view` R1, R2 | **build:** `core endpoints g,l,w`. **cluster:** view rules as in kubesystem-svc-04 |
| build-svc-05 | RB `build-svc-05-build-role-01` → R1; RB `build-svc-05-build-role-03` → R1, R2; CRB `build-svc-05-view-692` → `view` R1, R2 | **build:** `core endpoints g,l,w`; `core services, configmaps, pods g,l`; `apps/statefulsets, apps/replicasets g,l,w`. **cluster:** view rules as in kubesystem-svc-04 |
| build-svc-06 | RB `build-svc-06-build-role-03` → R1, R2 | `core services, configmaps, pods g,l`; `apps/statefulsets, apps/replicasets g,l,w` |

### 4.5 Namespace `platform` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| controller-admin | CRB `platform-controller-admin` → `cluster-superuser` R1 | **cluster:** all resources, all API groups, all verbs (wildcards). See E1. Used by `platform-controller`. |
| platform-agent | None | No RBAC grant (unbound). Token mounted by its workload. See E7. |
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
| staging-svc-04 | RB `staging-svc-04-staging-role-04` → R1, R2; RB `staging-svc-04-staging-role-02` → R1, R2 | `core configmaps g,l,w,u,p`; `core endpoints, pods g,l,w`; `apps/replicasets, apps/deployments g,l,w` |
| staging-svc-05 | RB `staging-svc-05-staging-role-04` → R1, R2; RB `staging-svc-05-staging-role-03` → R1, R2 | `core endpoints, pods g,l,w`; `core services g,l,w`; `apps/replicasets, apps/deployments, apps/statefulsets g,l,w` |

### 4.8 Namespace `analytics` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| analytics-worker | None | No RBAC grant (unbound). Token mounted by its workload. See E7. |
| analytics-svc-01 | RB `analytics-svc-01-analytics-role-02` → R1, R2 | `core pods g,l,w,u,p`; `apps/deployments, apps/replicasets g,l,w` |
| analytics-svc-02 | RB `analytics-svc-02-analytics-role-03` → R1, R2 | `core pods, endpoints g,l`; `apps/statefulsets, apps/replicasets g,l,w` |
| analytics-svc-03 | RB `analytics-svc-03-analytics-role-02` → R1, R2 | `core pods g,l,w,u,p`; `apps/deployments, apps/replicasets g,l,w` |
| analytics-svc-04 | RB `analytics-svc-04-analytics-role-01` → R1, R2; RB `analytics-svc-04-analytics-role-02` → R1, R2 | `core endpoints, pods g,l,w,u,p`; `apps/deployments, apps/replicasets g,l,w` |
| analytics-svc-05 | RB `analytics-svc-05-analytics-role-02` → R1, R2; RB `analytics-svc-05-analytics-role-03` → R1, R2 | `core pods g,l,w,u,p`; `core endpoints g,l`; `apps/deployments, apps/replicasets, apps/statefulsets g,l,w` |
| analytics-svc-06 | RB `analytics-svc-06-analytics-role-02` → R1, R2; RB `analytics-svc-06-analytics-role-03` → R1, R2 | `core pods g,l,w,u,p`; `core endpoints g,l`; `apps/deployments, apps/replicasets, apps/statefulsets g,l,w` |

### 4.9 Namespace `payments` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| payments-gateway-sa | None | No RBAC grant (unbound). Token mounted by its workload. See E7. |
| ledger-sa | None | No RBAC grant (unbound). Token mounted by its workload. See E7. |
| payments-svc-01 | RB `payments-svc-01-payments-role-01` → R1, R2; RB `payments-svc-01-payments-role-02` → R1, R2 | `core endpoints, services g,l,w`; `apps/deployments, apps/replicasets, apps/statefulsets g,l,w` |
| payments-svc-02 | RB `payments-svc-02-payments-role-01` → R1, R2 | `core endpoints, services g,l,w`; `apps/deployments, apps/replicasets g,l,w` |
| payments-svc-03 | RB `payments-svc-03-payments-role-03` → R1, R2 | `core configmaps, endpoints g,l,w`; `apps/statefulsets, apps/deployments g,l,w` |
| payments-svc-04 | RB `payments-svc-04-payments-role-02` → R1, R2; RB `payments-svc-04-payments-role-01` → R1, R2 | `core endpoints, services g,l,w`; `apps/deployments, apps/replicasets, apps/statefulsets g,l,w` |
| payments-svc-05 | RB `payments-svc-05-payments-role-03` → R1, R2; RB `payments-svc-05-payments-role-01` → R1, R2 | `core configmaps, endpoints, services g,l,w`; `apps/statefulsets, apps/deployments, apps/replicasets g,l,w` |

### 4.10 Namespace `media-processing` (active; privileged workload)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| media-worker | None | No RBAC grant (unbound). **Runs privileged, host-network, host-root pod `transcoder`. See E8.** Token mounted. |
| mediaproce-svc-01 | RB `mediaproce-svc-01-mediaproce-role-01` → R1, R2; RB `mediaproce-svc-01-mediaproce-role-03` → R1, R2 | `core configmaps, pods, endpoints g,l,w,u,p`; `core services g,l`; `apps/statefulsets, apps/replicasets, apps/deployments g,l,w` |
| mediaproce-svc-02 | RB `mediaproce-svc-02-mediaproce-role-01` → R1, R2; RB `mediaproce-svc-02-mediaproce-role-03` → R1, R2; CRB `mediaproce-svc-02-view-114` → `view` R1, R2 | **media-processing:** `core configmaps, pods, endpoints g,l,w,u,p`; `core services g,l`; `apps/statefulsets, apps/replicasets, apps/deployments g,l,w`. **cluster:** `core pods, services, endpoints, configmaps g,l,w`; `apps/deployments, apps/replicasets g,l,w` |
| mediaproce-svc-03 | RB `mediaproce-svc-03-mediaproce-role-01` → R1, R2 | `core configmaps, pods, endpoints g,l,w,u,p`; `apps/statefulsets, apps/replicasets g,l,w` |
| mediaproce-svc-04 | RB `mediaproce-svc-04-mediaproce-role-02` → R1, R2 | `core endpoints, configmaps, services g,l,w,u,p`; `apps/replicasets, apps/deployments g,l,w` |

### 4.11 Namespace `monitoring` (active)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| metrics-agent | None | No RBAC grant (unbound). Token mounted by its workload. See E7. |
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
| reconcile-job | None | No RBAC grant (unbound). Token mounted by its workload. See E7. |
| legacybill-svc-01 | RB `legacybill-svc-01-legacybill-role-01` → R1, R2; RB `legacybill-svc-01-legacybill-role-02` → R1 | `core pods g,l,w`; `apps/replicasets, apps/deployments g,l,w`; `core pods, configmaps, services g,l` |
| legacybill-svc-02 | RB `legacybill-svc-02-legacybill-role-03` → R1, R2 | `core configmaps, services g,l,w,u,p`; `apps/deployments, apps/statefulsets g,l,w` |
| legacybill-svc-03 | RB `legacybill-svc-03-legacybill-role-01` → R1, R2; RB `legacybill-svc-03-legacybill-role-03` → R1, R2 | `core pods g,l,w`; `apps/replicasets, apps/deployments g,l,w`; `core configmaps, services g,l,w,u,p`; `apps/deployments, apps/statefulsets g,l,w` |
| legacybill-svc-04 | RB `legacybill-svc-04-legacybill-role-02` → R1 | `core pods, configmaps, services g,l` |
| legacybill-svc-05 | RB `legacybill-svc-05-legacybill-role-02` → R1 | `core pods, configmaps, services g,l` |
| legacybill-svc-06 | RB `legacybill-svc-06-legacybill-role-03` → R1, R2; RB `legacybill-svc-06-legacybill-role-01` → R1, R2 | `core pods g,l,w`; `apps/replicasets, apps/deployments g,l,w`; `core configmaps, services g,l,w,u,p`; `apps/deployments, apps/statefulsets g,l,w` |
| legacybill-svc-07 | RB `legacybill-svc-07-legacybill-role-03` → R1, R2 | `core configmaps, services g,l,w,u,p`; `apps/deployments, apps/statefulsets g,l,w` |

None of these ServiceAccounts reads Secrets. They are the targets of E6.

### 4.14 Namespace `kube-addons-old` (abandoned-looking / sparse)

| ServiceAccount | Bindings (Role rules) | Effective union |
|---|---|---|
| addons-legacy | None | No RBAC grant (unbound). No workload in the export uses it, so no token mount is recorded. See E7. |

The namespace has no Role, RoleBinding, or workloads directory in the export.

## 5. User subjects

### 5.1 `maya.chen` (User)

Subject references in the export: 2, both in `rolebindings.yaml` (lines 36 and 50). Absence method: checked against all 117 RoleBindings and 11 ClusterRoleBindings; no other reference exists.

| Source | Binding → Role rules | Scope | Effective capability |
|---|---|---|---|
| Direct | RB `maya-dev-editor` → `dev-editor` R1, R2 | `dev` | `core pods, configmaps, services g,l,w,c,u,p,d`; `apps/deployments g,l,w,c,u,p` |
| Direct | RB `maya-billing-migrator` → `billing-migrator` R1 | `legacy-billing-migration` | `core pods, configmaps g,l` |
| Direct, namespaced | RB `maya-billing-migrator` → `billing-migrator` R2 | `legacy-billing-migration` | `i` on `serviceaccounts` for ServiceAccounts in `legacy-billing-migration` (E6) |
| Direct, not effective (manifest-derived) | RB `maya-billing-migrator` → `billing-migrator` R2 | `legacy-billing-migration` | `i` on `users` and `groups` is cluster-scoped and not satisfied by a RoleBinding |

**Path analysis.**
- Pod creation in `dev` (from `dev-editor`) can run as any `dev` ServiceAccount. None holds Secret access or cluster-wide bindings.
- Impersonation of `legacy-billing-migration` ServiceAccounts gives their grants (Section 4.13). None reads Secrets.
- No Secret path, no cluster-wide path, and no Group path were found, by the absence method in Section 1.

**Determination.** Over-privileged for a dev editor because of the impersonation grant (E6). Not over-privileged for Secrets or cluster scope, per the manifests.

### 5.2 `sam.okafor` (User)

Subject references in the export: 2, both in `rolebindings.yaml` (lines 106 and 120).

| Source | Binding → Role or ClusterRole rules | Scope | Effective capability |
|---|---|---|---|
| Direct | RB `sam-metrics-viewer` → `metrics-viewer` R1 | `monitoring` | `core pods, services, endpoints g,l,w` |
| Direct | RB `sam-legacy-view` → ClusterRole `view` R1, R2 | `legacy-billing-migration` only | `core pods, services, endpoints, configmaps g,l,w`; `apps/deployments, apps/replicasets g,l,w` |

**Path analysis and clearance.** The union of the two bindings is read/watch only: `metrics-viewer` applies in `monitoring`; the ClusterRole `view` rules referenced by `sam-legacy-view` apply only in `legacy-billing-migration`. The full binding export contains no other `sam.okafor` subject, and no Group subjects exist. Neither grant allows creating pods or workloads, changing resources, impersonating identities, or reading Secrets. The user therefore has no workload-selection path to another ServiceAccount in this export. **Determination:** `sam.okafor` is the correctly scoped read-only subject in the supplied snapshot; the extra legacy namespace grant is explicit and remains namespace-limited, not hidden cluster-wide privilege.

**Determination.** Correctly scoped as read-only in this snapshot. The legacy ConfigMap read is broader than the monitoring binding's purpose might suggest, but it is an explicit, namespace-limited `view` binding; it adds no write, Secret, impersonation, or cluster-wide grant. This is the subject cleared as having no hidden privilege beyond its two listed read-only bindings.

## 6. The subject that holds exactly what it appears to hold

`sam.okafor` is the clearest correctly scoped read-only subject: the two bindings and their full read-only union are listed in Section 5.2, and the complete binding export shows no additional or group-derived grant.

**`prod/orders-api-sa`.**
- **Direct grant.** RoleBinding `orders-api-config` (prod) → Role `orders-api-config` R1 (core `configmaps, secrets` g,l,w). Scope: `prod` only.
- **Search for other grants.** The export's RBAC objects were reviewed for this ServiceAccount: no other RoleBinding or ClusterRoleBinding names `prod/orders-api-sa`, and no Group path exists. The `yq` subject count confirms one binding for it. The workload reference is `workloads/prod/deployments.yaml` (line 16).
- **Determination.** Its RBAC privilege is exactly get, list, and watch on ConfigMaps and Secrets in `prod`. Nothing else, nothing cluster-wide.
- **Purpose boundary.** The `orders-api` Deployment in `workloads/prod/deployments.yaml` uses this ServiceAccount and mounts its token. The export proves the single RoleBinding and exact `prod`-only ConfigMap/Secret read grant; it does not establish whether every application permission is required. This is an exact-inventory determination, not a claim that the owner has confirmed the permission need.
- **Caveat about reachability.** E3 and E4 let `deploy-bot` and `billing-reconciler` run pods under this identity and read `prod` Secrets. That is a finding about those subjects, not about this grant.
- **Caveat about the node.** The verdict covers RBAC only. If `orders-api` pods share a node with `transcoder` (E8), the token is readable from the host. Node placement is unverified.

## 7. Verification still needed

| Check | Command or method | Resolves |
|---|---|---|
| Subject references across all bindings | Review all 128 RoleBinding/ClusterRoleBinding documents; one subject each. Every referenced subject appears in Sections 4 and 5; the nine unbound ServiceAccounts have no binding. | Done for the export. Live bootstrap bindings remain outside the snapshot. |
| Bootstrap bindings | `kubectl get clusterrolebindings,rolebindings -A -o yaml` on a live cluster, compared with the export | Any `system:` grants missing from the export. The main open limit. |
| Node placement | `kubectl get pods -A -o wide` | Whether E8 reaches E1, and whether `orders-api` shares a node with `transcoder` |
| Namespace enforcement | `kubectl get ns media-processing --show-labels` | Whether PSA is absent live |
| Admission mode | `kubectl get validatingadmissionpolicybinding disallow-privileged-binding -o yaml` | Confirms `Audit` live |
| E2 | Server dry run of a Pod in `platform` with `serviceAccountName: controller-admin`, as `system:serviceaccount:build:ci-runner` | E2 |
| E3, E4 | Server dry run of a Deployment in `prod` as `deploy-bot`, and of a Job as `billing-reconciler`, naming `billing-reconciler` or `orders-api-sa` | E3, E4 |
| E6 | `kubectl auth can-i impersonate serviceaccounts --as=maya.chen -n legacy-billing-migration`; same for `users` and `groups` | E6 scope |
| Full permission listing | `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<name>` for each named subject | Would compare the manifest-derived determinations with live authorization |

The caller running these checks needs impersonation rights. Without them, the commands return `forbidden` and prove nothing.
