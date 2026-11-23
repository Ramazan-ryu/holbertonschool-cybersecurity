# Trellis Software — RBAC escalation edges

## 1. Method

**What an edge is.** An edge is a becoming: a starting subject uses a permission it holds and ends up running as an identity with more authority.

**Step types.** Every step in every edge carries one of two tags:
- **[E] Export-established.** The step is shown by a specific object or line in the export: a binding, a Role rule, a workload field, or a ServiceAccount name. The citation is given.
- **[K] Kubernetes-behavior.** The step depends on how the Kubernetes API or a controller behaves, not on the export. Examples: a pod that names a ServiceAccount receives that account's token; a Job controller creates pods from its template; an image update on a running pod is accepted. The export cannot prove these. They are stated as conditions and must be confirmed on a live cluster.

**Edge status.**
- **Established** means every step is [E]. No edge in this file is fully established, because each one contains at least one [K] step.
- **Conditional** means at least one [K] step remains. The edge is a finding only after its [K] steps are confirmed.

**Delegation rule.** Writing a RoleBinding requires `create`, `update`, or `patch` on `rolebindings`. The export grants that verb to no subject except through `cluster-superuser`, held only by `platform/controller-admin` (`roles.yaml` line 38 lists `rolebindings` with `get,list` only).

**Admission and Pod Security** (verified from files, see `1-effective_privilege.md` Section 1). `disallow-privileged` runs in Audit mode and checks only Deployments. `media-processing`, `kube-system`, and `kube-addons-old` carry no PSA labels. No policy in `admission/` restricts `serviceAccountName`, pod image changes, or hostPath use.

**Not analyzed.** The image source (registry and pull policy), `6-audit_trail.md`, and bootstrap bindings (`system:` groups, absent from the export).

## 2. Summary

| ID | Starting subject | Enabling permission [E] | Becomes | Reach | Status |
|---|---|---|---|---|---|
| E1 | `build/ci-runner` | Pod create in `platform` | `platform/controller-admin` | Cluster-wide, all verbs | Conditional (2 [K] steps) |
| E2 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/billing-reconciler` | Legacy `billing-secrets` read; Job create in `prod` | Conditional (1 [K] step) |
| E3 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/orders-api-sa` | `prod` ConfigMaps and Secrets read | Conditional (1 [K] step) |
| E4 | `prod/billing-reconciler` | Job create in `prod` | `prod/orders-api-sa` | `prod` ConfigMaps and Secrets read | Conditional (1 [K] step) |
| E5 | `media-processing/mediaproce-svc-01`, `-02`, `-03` | Pod update/patch in `media-processing` | Running pod `transcoder` (identity `media-worker`) | Node-level: privileged, host network, host root | Conditional (2 [K] steps) |
| E6 | `maya.chen` | Impersonate ServiceAccounts in `legacy-billing-migration` | `legacybill-svc-*` identities | ConfigMap and Service write in `legacy-billing-migration`; no Secrets | Conditional (1 [K] step) |
| N1 | `prod/deploy-bot` | `bind`, `escalate`, `create` on roles/clusterroles | None active | Inert: no subject holds RoleBinding write | Dead end |
| N2 | `maya.chen` | Pod and Deployment write in `dev` | Any `dev` ServiceAccount | No Secrets, no cluster scope | Dead end |
| N3 | Seven ServiceAccounts with cluster-wide `view` | Cluster-wide `view` | None | Read of pods, services, endpoints, ConfigMaps | No escalation; data exposure |

---

## 3. Edges

### E1. `build/ci-runner` becomes `platform/controller-admin`, then cluster superuser

**Step 1 [E]: enabling grant.** RoleBinding `ci-runner-platform-deploy` (namespace `platform`) binds ServiceAccount `build/ci-runner` to Role `platform-deployer`. Role R1: core `pods`, verbs `get,list,watch,create`. Scope: `platform` only.

**Step 2 [E]: target identity exists.** ServiceAccount `controller-admin` is in `platform` (`0-rbac_map.md` Section 3, platform ServiceAccounts). ClusterRoleBinding `platform-controller-admin` binds it to ClusterRole `cluster-superuser`.

**Step 3 [E]: the identity is a live, token-bearing identity.** `workloads/platform/daemonsets.yaml` lines 16–17: a Deployment `platform-controller` in `platform` sets `serviceAccountName: controller-admin` and `automountServiceAccountToken: true`. The file name says DaemonSet, but the object is a Deployment with `replicas: 1`.

**Step 4 [E]: no export control restricts the choice.** The only admission policy (`admission/policies.yaml`) checks Deployments for `privileged` and runs in Audit mode. No policy checks `serviceAccountName`.

**Step 5 [K]: a Pod created by `ci-runner` with `serviceAccountName: controller-admin` receives that ServiceAccount's token.** The export shows the name; the Kubernetes behavior that binds the token to the pod is not in the export. Confirm with a server-side dry run as `system:serviceaccount:build:ci-runner`.

**Step 6 [K]: the pod's token can be used against the API by code in the container.** Standard behavior of a mounted token, not shown by the export. Confirm with a dry run of an API request using that token.

**Step 7 [E]: resulting identity and its privileges.** ClusterRole `cluster-superuser` (`clusterroles.yaml`, wildcard rule): wildcard API groups, resources, and verbs. Via ClusterRoleBinding `platform-controller-admin`. Cluster-wide. Includes RBAC writes.

**Status.** Conditional on Steps 5 and 6. If both hold, the holder of `build/ci-runner` runs code as cluster superuser. The image must be pullable by the nodes; that is an external condition.

---

### E2. `prod/deploy-bot` becomes `prod/billing-reconciler` and reads legacy Secrets

**Step 1 [E]: enabling grant.** RoleBinding `deploy-bot-deployer` (namespace `prod`) binds `prod/deploy-bot` to Role `deployer`. Role R1: apiGroup `apps`, resources `deployments`, `replicasets`, verbs `get,list,watch,create,update,patch`. Scope: `prod`.

**Step 2 [E]: target identity is used by a workload in `prod`.** `workloads/prod/deployments.yaml` line 39 `serviceAccountName: billing-reconciler`; line 40 `automountServiceAccountToken: true`. The workload's Deployment name is not extracted from the file.

**Step 3 [K]: a Deployment created by `deploy-bot` with `serviceAccountName: billing-reconciler` runs pods that receive that ServiceAccount's token.** The same pattern as E1 Step 5. Confirm with a server-side dry run as `system:serviceaccount:prod:deploy-bot`.

**Step 4 [E]: resulting identity and its privileges.**
- RoleBinding `billing-reconciler-prod` (`prod`) → Role `reconciler`: R1 core `configmaps` `get,list,watch`; R2 `batch/jobs` `get,list,create`.
- RoleBinding `billing-reconciler-secrets` (`legacy-billing-migration`) → Role `billing-secrets` (`roles.yaml` lines 204 and 210): R1 core `secrets` `get,list`; R2 core `configmaps` `get,list`.
- No ClusterRoleBinding names `billing-reconciler`.

**Status.** Conditional on Step 3. If it holds, `deploy-bot` reads Secrets in `legacy-billing-migration` through this identity. Reach is that namespace and `prod` (through the Job path in E4). It is not cluster-wide Secret access.

---

### E3. `prod/deploy-bot` becomes `prod/orders-api-sa` and reads `prod` Secrets

**Step 1 [E]: enabling grant.** Same as E2, Step 1.

**Step 2 [E]: target identity is used by a workload in `prod`.** `workloads/prod/deployments.yaml` line 16 `serviceAccountName: orders-api-sa`; line 17 `automountServiceAccountToken: true`.

**Step 3 [K]: as in E2, Step 3.** Confirm with a server-side dry run as `system:serviceaccount:prod:deploy-bot`, naming `orders-api-sa`.

**Step 4 [E]: resulting identity and its privileges.** RoleBinding `orders-api-config` (`prod`) → Role `orders-api-config`: core `configmaps, secrets` `get,list,watch` (`roles.yaml` line 232). No other binding names `orders-api-sa`.

**Status.** Conditional on Step 3. If it holds, `deploy-bot` reads `prod` Secrets through this identity.

---

### E4. `prod/billing-reconciler` becomes `prod/orders-api-sa` through a Job and reads `prod` Secrets

**Step 1 [E]: enabling grant.** RoleBinding `billing-reconciler-prod` (`prod`) → Role `reconciler` R2: `batch/jobs` `get,list,create`. Scope: `prod`.

**Step 2 [E]: target identity is used in `prod`.** `workloads/prod/deployments.yaml` line 16 `serviceAccountName: orders-api-sa`.

**Step 3 [K]: a Job created with a pod template naming `orders-api-sa` runs its pod under that ServiceAccount's token.** The Job controller creates the pod from the template. That controller behavior is not in the export. Confirm with a server-side dry run of a Job as `system:serviceaccount:prod:billing-reconciler`.

**Step 4 [E]: resulting identity and its privileges.** As in E3, Step 4.

**Status.** Conditional on Step 3. It extends `billing-reconciler`, which already reaches legacy Secrets through E2, and adds `prod` Secrets through `orders-api-sa`.

---

### E5. `media-processing/mediaproce-svc-01`, `-02`, `-03` patch the running `transcoder` pod

**Step 1 [E]: enabling grant.** RoleBindings `mediaproce-svc-01-mediaproce-role-01`, `mediaproce-svc-02-mediaproce-role-01`, and `mediaproce-svc-03-mediaproce-role-01` (namespace `media-processing`) bind these ServiceAccounts to Role `mediaproce-role-01`. R1: core `configmaps, pods, endpoints` with `get,list,watch,update,patch`.

**Step 2 [E]: the privileged workload exists.** `workloads/media-processing/deployments.yaml`, Deployment `transcoder`:
- line 16 `serviceAccountName: media-worker`; line 17 `automountServiceAccountToken: true`
- line 22 `privileged: true`; `capabilities.add: [SYS_ADMIN]` at lines 23–25
- line 30 `hostNetwork: true`
- line 33 `hostPath: /`, mounted read-write at `/host`

**Step 3 [K]: patching a running pod's container `image` changes the code that runs in that container, while the pod's privileges stay as they were.** The export shows that `update`/`patch` on pods is granted. It does not show that the API accepts an image change on a running pod, nor that the replacement container keeps the same `securityContext`, host namespaces, and hostPath. Confirm with a server-side dry run of the patch.

**Step 4 [E]: resulting identity and its privileges.** The pod runs as `media-worker`, which has no RoleBinding (`1-effective_privilege.md`, unbound list). Its effective privilege is the pod's privilege: privileged, `SYS_ADMIN`, host network, read-write host root.

**Status.** Conditional on Step 3. If it holds, the holder gains node-level access on the node running `transcoder`. Cluster-wide reach depends on what else runs on that node, which the export does not show.

---

### E6. `maya.chen` impersonates `legacy-billing-migration` ServiceAccounts

**Step 1 [E]: enabling grant.** RoleBinding `maya-billing-migrator` (namespace `legacy-billing-migration`) → Role `billing-migrator` R2: core `serviceaccounts`, `users`, `groups` with `impersonate` (`roles.yaml` line 105).

**Step 2 [K]: the impersonation check for a ServiceAccount is evaluated in that ServiceAccount's namespace, so a RoleBinding in `legacy-billing-migration` covers `legacybill-svc-01` to `-07` and not ServiceAccounts elsewhere.** This scoping is Kubernetes authorization behavior, not shown by the export. Confirm with `kubectl auth can-i impersonate serviceaccounts -n legacy-billing-migration --as=maya.chen` and with `-n prod`.

**Step 3 [E]: resulting identity and its privileges.** For `legacybill-svc-06`, from its RoleBindings: `legacybill-role-03` (ConfigMaps and Services `get,list,watch,update,patch`; deployments and statefulsets `get,list,watch`) and `legacybill-role-01` (pods `get,list,watch`; replicasets and deployments `get,list,watch`). No Secrets. `reconcile-job` has no RoleBinding, so impersonating it grants nothing.

**Step 4 [E]: users and groups.** Impersonation of `users` and `groups` is a cluster-level check. The export contains no ClusterRoleBinding for `maya.chen`, so this grant does not apply to them. Stated as derived from the export; confirm with `kubectl auth can-i impersonate users --as=maya.chen`.

**Status.** Conditional on Step 2. If it holds, reach is ConfigMap and Service writes in one namespace, with no Secrets.

---

## 4. Dead ends (checked and cleared)

### N1. `prod/deploy-bot` through `migration-operator`

Role `migration-operator` (`legacy-billing-migration`): R1 `rbac/roles, rolebindings` `get,list` (`roles.yaml` line 38); R2 `rbac/roles, clusterroles` `bind, escalate, create` (lines 48–49).

- Creating a RoleBinding requires write access to `rolebindings`. The only grant on that resource is R1 (`get,list`). No subject can create a RoleBinding through this grant.
- `deploy-bot` can create Roles in `legacy-billing-migration` and could use `escalate` to create a Role with permissions it does not hold. Neither is bound to any subject, so neither grants anything.
- `deploy-bot` has no `update` on `roles`, so it cannot change a bound Role.

**Latent risk.** If `create` on `rolebindings` were added for `deploy-bot`, `bind` on `cluster-superuser` would let it create a RoleBinding to `cluster-superuser` in `legacy-billing-migration`. That is control of the namespace, Secrets included. It is not cluster-wide reach, which would need `create` on `clusterrolebindings`, held only by `platform/controller-admin` through `cluster-superuser`.

### N2. `maya.chen` through `dev-editor`

`dev-editor` (`maya-dev-editor`, namespace `dev`) grants write on pods and deployments in `dev`. The `dev` ServiceAccounts she can name are `dev-svc-01` to `dev-svc-04`. Their RoleBindings grant ConfigMaps, pods, endpoints, services, and replicasets. None grants Secrets. None has a ClusterRoleBinding. A grep for `privileged` across the workloads found only `media-processing`, so no `dev` workload is privileged. Result: no becoming.

### N3. Cluster-wide `view` and `configmap-reader`

Seven ServiceAccounts hold cluster-wide `view`: `kubesystem-svc-04`, `prod-svc-01` (two bindings), `build-svc-04`, `build-svc-05`, `staging-svc-01`, `mediaproce-svc-02`, `monitoring-svc-04`. `view` R1 covers pods, services, endpoints, and ConfigMaps for read. It does not cover Secrets. `deploy-bot` reads ConfigMaps cluster-wide through `configmap-reader`. None of these changes identity. The exposure is data; ConfigMap contents are not in the export.

---

## 5. Permissions that look harmless

| Permission | Where it appears | Edge |
|---|---|---|
| Pod `update`/`patch` | `mediaproce-role-01` in `media-processing` | E5 (conditional) |
| Job `create` | `reconciler` in `prod` | E4 (conditional) |
| Deployment `create`/`update` | `deployer` in `prod`; `dev-editor` in `dev` | E2, E3 (conditional); N2 (dead end) |
| Pod `create` | `platform-deployer` in `platform` | E1 (conditional) |
| `impersonate` on ServiceAccounts | `billing-migrator` in `legacy-billing-migration` | E6 (conditional) |
| `bind`, `escalate` | `migration-operator` in `legacy-billing-migration` | N1 (inert) |

---

## 6. Verification needed

Each check resolves the [K] step(s) named. Without them, the edge stays conditional.

| Check | Command | Resolves |
|---|---|---|
| E1 Steps 5–6: pod token and API use | Server-side dry run of a Pod in `platform` with `serviceAccountName: controller-admin`, as `system:serviceaccount:build:ci-runner`; then a live `kubectl auth can-i --list` with the resulting token | E1 |
| E2, E3 Step 3: Deployment identity | Server-side dry run of a Deployment in `prod` with `serviceAccountName: billing-reconciler`, then `orders-api-sa`, as `system:serviceaccount:prod:deploy-bot` | E2, E3 |
| E4 Step 3: Job identity | Server-side dry run of a Job in `prod` with `serviceAccountName: orders-api-sa`, as `system:serviceaccount:prod:billing-reconciler` | E4 |
| E5 Step 3: image patch | As `mediaproce-svc-01`: `kubectl patch pod <transcoder-pod> -n media-processing --dry-run=server -p '{"spec":{"containers":[{"name":"app","image":"busybox"}]}}'`, then confirm the replacement container keeps `privileged` and `hostPath` | E5 |
| E5 node placement | `kubectl get pods -A -o wide` | Whether other workloads share the node with `transcoder` |
| E6 Step 2: impersonation scope | `kubectl auth can-i impersonate serviceaccounts -n legacy-billing-migration --as=maya.chen`; same with `-n prod`; `users` and `groups` as well | E6 |
| N1 binding creation | `kubectl auth can-i create rolebindings -n legacy-billing-migration --as=system:serviceaccount:prod:deploy-bot` | N1 stays inert |
| Image source | Registry allowlist and node pull policy | Whether any attacker-chosen image can run in E1 to E5 |
| Bootstrap bindings | `kubectl get clusterrolebindings,rolebindings -A -o yaml` on a live cluster | Any `system:` grant missing from the export. The main open limit. |

These checks need a caller with impersonation rights. Without them, the commands return `forbidden` and prove nothing.
