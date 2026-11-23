# Trellis Software — RBAC escalation edges

## 1. Method

**What an edge is.** An edge is a becoming: a starting subject uses a permission it holds and ends up running as an identity with more authority. Each edge is reconstructed in this order:

1. The starting subject and the binding that grants the enabling permission (binding name, namespace, Role or ClusterRole, rule R#, verbs).
2. The workload or controller configuration that carries the identity (file and line).
3. The token path: whether the identity's token is mounted in the new workload, and where that is set.
4. The resulting identity and its effective privileges, cited to the bindings in `1-effective_privilege.md`.

**Delegation rule.** Kubernetes checks `bind` and `escalate` only when a RoleBinding or Role is written. Writing a RoleBinding requires `create` (or `update`/`patch`) on `rolebindings`. The export contains no such grant except through `cluster-superuser`, which is held only by `platform/controller-admin`. So `bind` and `escalate` are present but inert for every other subject.

**Pod identity rule.** RBAC has no verb that checks whether a pod creator may choose a ServiceAccount. The only check is that the ServiceAccount exists in the namespace. A pod sets `automountServiceAccountToken` in its own spec, and that value applies to that pod.

**Admission and Pod Security** (from the export; see `1-effective_privilege.md` Section 1). `disallow-privileged` runs in Audit mode and checks only Deployments. `media-processing`, `kube-system`, and `kube-addons-old` have no PSA labels. Other namespaces are `baseline`, which does not restrict `serviceAccountName` and does not allow privileged pods. Nothing in the export restricts ServiceAccount choice, pod image changes, or image source.

**Naming.** Where a Deployment name is not extracted from the workload file, the edge cites the file and line, and the name is marked as not extracted.

**Not verified.**
- No live cluster. Every edge is manifest-derived. Live checks are in Section 6.
- Image source. The export has no image allowlist. An attacker-chosen image must be pullable by the nodes. This is an external condition.
- Bootstrap bindings (`system:` groups) are absent from the export.
- `6-audit_trail.md` was not analyzed and is not used as evidence here.

## 2. Summary

| ID | Starting subject | Enabling permission | Becomes | Reach | Status |
|---|---|---|---|---|---|
| E1 | `build/ci-runner` | Pod create in `platform` | `platform/controller-admin` | Cluster-wide, all verbs | Critical, manifest-derived |
| E2 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/billing-reconciler` | Legacy Secrets read; Job create in `prod` | High, manifest-derived |
| E3 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/orders-api-sa` | `prod` ConfigMaps and Secrets read | High, manifest-derived |
| E4 | `prod/billing-reconciler` | Job create in `prod` | `prod/orders-api-sa` | `prod` ConfigMaps and Secrets read | High, manifest-derived |
| E5 | `media-processing/mediaproce-svc-01`, `-02`, `-03` | Pod update/patch in `media-processing` | `media-processing/media-worker` (running pod `transcoder`) | Node-level: privileged, host network, host root | Critical, node-level, manifest-derived |
| E6 | `maya.chen` | Impersonate ServiceAccounts in `legacy-billing-migration` | `legacybill-svc-*` identities | ConfigMap and Service write in `legacy-billing-migration`; no Secrets | Medium, manifest-derived |
| N1 | `prod/deploy-bot` | `bind`, `escalate`, `create` on roles/clusterroles | Would be legacy namespace control if RoleBinding create existed | Inert: no subject holds RoleBinding create | Dead end (Section 4) |
| N2 | `maya.chen` | Pod and Deployment create/update in `dev` | Any `dev` ServiceAccount | No Secrets, no cluster scope | Dead end (Section 4) |
| N3 | Seven ServiceAccounts with cluster-wide `view` | Cluster-wide `view` | None | Cluster-wide read of pods, services, endpoints, ConfigMaps; no Secrets | No escalation; data exposure only |

---

## 3. Edges

### E1. `build/ci-runner` becomes `platform/controller-admin`, then cluster superuser (critical)

**Step 1: enabling grant.** RoleBinding `ci-runner-platform-deploy` (namespace `platform`) binds ServiceAccount `build/ci-runner` to Role `platform-deployer`. Role R1: core `pods` with `get,list,watch,create`. The binding is in `platform`, so the grant applies only there.

**Step 2: the pod can name the target identity.** `ci-runner` creates a Pod in `platform` with `spec.serviceAccountName: controller-admin`. ServiceAccount `controller-admin` exists in `platform` (`serviceaccounts.yaml`). No RBAC verb or export admission control restricts this choice. `disallow-privileged` does not apply to Pods.

**Step 3: token path.** The new pod sets `automountServiceAccountToken: true` in its own spec. The token of `platform/controller-admin` is then mounted and readable by any code in the container.

**Step 4: the identity is already in use.** Deployment `platform-controller` in `platform` runs with `serviceAccountName: controller-admin` (`workloads/platform/daemonsets.yaml`, line 16) and `automountServiceAccountToken: true` (line 17). The file name says DaemonSet, but the object is a Deployment with `replicas: 1`. This shows the identity is a live, token-bearing identity. E1 does not depend on it: the attacker's pod creates the same token path itself.

**Step 5: resulting identity and its privileges.** ClusterRoleBinding `platform-controller-admin` binds `platform/controller-admin` to ClusterRole `cluster-superuser`, R1: wildcard API groups, wildcard resources, wildcard verbs. Cluster-wide. This includes RBAC writes, so the holder can also create RoleBindings and ClusterRoleBindings for any subject. `controller-admin` has no other binding.

**Result.** A holder of `build/ci-runner` can run code as cluster superuser. The constraint is an image the nodes can pull. Nothing in the export blocks it.

---

### E2. `prod/deploy-bot` becomes `prod/billing-reconciler` and reads legacy Secrets (high)

**Step 1: enabling grant.** RoleBinding `deploy-bot-deployer` (namespace `prod`) binds `prod/deploy-bot` to Role `deployer`. R1: apiGroup `apps`, resources `deployments`, `replicasets`, verbs `get,list,watch,create,update,patch`. Scope: `prod`.

**Step 2: workload configuration that carries the identity.** `workloads/prod/deployments.yaml` contains a pod spec with `serviceAccountName: billing-reconciler` (line 39) and `automountServiceAccountToken: true` (line 40). The Deployment name is not extracted from the file. The attacker creates or patches a Deployment in `prod` with this ServiceAccount and the token set explicitly.

**Step 3: token path.** The new pod's token belongs to `prod/billing-reconciler`.

**Step 4: resulting identity and its privileges.**
- RoleBinding `billing-reconciler-prod` (`prod`) → Role `reconciler`: R1 core `configmaps` `get,list,watch`; R2 `batch/jobs` `get,list,create`.
- RoleBinding `billing-reconciler-secrets` (`legacy-billing-migration`) → Role `billing-secrets`: R1 core `secrets` `get,list`; R2 core `configmaps` `get,list`.
- No ClusterRoleBinding names `billing-reconciler`.

**Result.** `deploy-bot` reads Secrets in `legacy-billing-migration` through this identity, and it can create Jobs in `prod` (which leads to E4). The reach is limited to the legacy namespace and to `prod`. It is not cluster-wide Secret access.

---

### E3. `prod/deploy-bot` becomes `prod/orders-api-sa` and reads `prod` Secrets (high)

**Step 1: enabling grant.** Same as E2, Step 1.

**Step 2: workload configuration.** `workloads/prod/deployments.yaml` contains a pod spec with `serviceAccountName: orders-api-sa` (line 16) and `automountServiceAccountToken: true` (line 17). The Deployment name is not extracted from the file. The attacker creates or patches a Deployment in `prod` with this ServiceAccount.

**Step 3: token path.** Same pattern as E2. The new pod's token belongs to `prod/orders-api-sa`.

**Step 4: resulting identity and its privileges.** RoleBinding `orders-api-config` (`prod`) → Role `orders-api-config` R1: core `configmaps, secrets` `get,list,watch`. No other binding names `orders-api-sa`.

**Result.** `deploy-bot` reads `prod` ConfigMaps and Secrets through this identity. It is a second route to the same `prod` Secrets. `orders-api-sa` has no escalation of its own (see `1-effective_privilege.md` Section 6).

---

### E4. `prod/billing-reconciler` becomes `prod/orders-api-sa` through a Job and reads `prod` Secrets (high)

**Step 1: enabling grant.** RoleBinding `billing-reconciler-prod` (`prod`) → Role `reconciler` R2: `batch/jobs` `get,list,create`. Scope: `prod`.

**Step 2: controller configuration.** The attacker creates a Job in `prod` whose pod template sets `serviceAccountName: orders-api-sa` and `automountServiceAccountToken: true`. The Job controller creates the pod; the pod runs under the identity named in its template. The creator needs no pod-create permission, because the controller creates the pod.

**Step 3: token path.** The Job pod's token belongs to `prod/orders-api-sa`.

**Step 4: resulting identity and its privileges.** As in E3, Step 4: `prod` ConfigMaps and Secrets `get,list,watch`.

**Result.** This edge extends `billing-reconciler`, which already reaches legacy Secrets through E2. It adds `prod` Secrets through `orders-api-sa`. E3 and E4 reach the same Secrets.

---

### E5. `media-processing/mediaproce-svc-01/02/03` patches the privileged `transcoder` pod and runs as `media-worker` on the node (critical, node-level)

This edge does not depend on a dangerous-looking permission. Pod update looks like label or metadata work, but the container `image` field is mutable.

**Step 1: enabling grant.** Three RoleBindings bind these ServiceAccounts to Role `mediaproce-role-01` (namespace `media-processing`):
- `mediaproce-svc-01-mediaproce-role-01`
- `mediaproce-svc-02-mediaproce-role-01`
- `mediaproce-svc-03-mediaproce-role-01`

Role R1: core `configmaps, pods, endpoints` with `get,list,watch,update,patch`. Each holder can update and patch pods in `media-processing`.

**Step 2: the workload that carries the identity.** Deployment `transcoder` in `media-processing` (`workloads/media-processing/deployments.yaml`):
- line 16 `serviceAccountName: media-worker`; line 17 `automountServiceAccountToken: true`
- line 22 `privileged: true`; lines 23–25 `capabilities.add: [SYS_ADMIN]`
- line 30 `hostNetwork: true`
- lines 31–34 volume `hostfs`, `hostPath: /`, mounted at `/host`

**Step 3: the transition.** A holder patches the running pod's container `image` to an attacker-chosen image. The kubelet restarts the container with the new image. The pod's `securityContext`, `hostNetwork`, `hostPath`, and `serviceAccountName` are not changed by an image patch, so the attacker's code runs with the transcoder pod's privileges, as `media-worker`. The Deployment is not changed, so the change lasts until the pod is replaced.

**Step 4: resulting identity and its privileges.** `media-worker` has no RBAC binding. Its privilege comes from the pod spec: privileged, `SYS_ADMIN`, host network, and read-write access to the host root filesystem. Attacker code can read node-level files and reach services on the host network. The export does not show what else runs on that node, so cluster-wide reach is not established.

**Admission and PSA.** The admission policy checks Deployments only and runs in Audit mode. `media-processing` has no PSA labels. Nothing blocks a pod image patch.

**Result.** Three ServiceAccounts with an ordinary-looking pod `patch` can take over a privileged node-level workload. The highest identity reached is node root on the node that runs `transcoder`. Whether that becomes cluster-wide control depends on what else runs there, which the export does not show.

---

### E6. `maya.chen` impersonates `legacy-billing-migration` ServiceAccounts (medium)

**Step 1: enabling grant.** RoleBinding `maya-billing-migrator` (namespace `legacy-billing-migration`) → Role `billing-migrator` R2: core `serviceaccounts` with `impersonate`. Scope: `legacy-billing-migration`.

**Step 2: target.** A request as `system:serviceaccount:legacy-billing-migration:<name>`, where the name is one of `legacybill-svc-01` to `-07`. The impersonation check runs against the target ServiceAccount's namespace, so this binding applies to `legacy-billing-migration`. Impersonation of a ServiceAccount in another namespace is not granted by this binding. This is a verify item in Section 6.

**Step 3: resulting identity and its privileges.** The impersonated identity keeps its own grants. For `legacybill-svc-06`: RoleBinding to `legacybill-role-03` (R1 ConfigMaps and Services `get,list,watch,update,patch`; R2 deployments and statefulsets `get,list,watch`) and RoleBinding to `legacybill-role-01` (R1 pods `get,list,watch`; R2 replicasets and deployments `get,list,watch`). No Secrets. Impersonating `reconcile-job` yields no grants, because it has no binding.

**Result.** `maya.chen` can update ConfigMaps and Services in `legacy-billing-migration` through an impersonated ServiceAccount. Impersonation of `users` and `groups` is cluster-scoped and is not granted by a RoleBinding (manifest-derived). The reach stays inside one namespace and excludes Secrets.

---

## 4. Dead ends (checked and cleared)

### N1. `prod/deploy-bot` through `migration-operator` (no path)

Role `migration-operator` in `legacy-billing-migration`:
- R1: `rbac` `roles, rolebindings` with `get,list`.
- R2: `rbac` `roles, clusterroles` with `bind, escalate, create`.

**Why it is inert.**
- Creating a RoleBinding requires `create` (or `update`/`patch`) on `rolebindings`. `grep -n "rolebindings" roles.yaml` returns line 38 only, which is in R1 (`get,list`). No subject holds write access to RoleBindings.
- `deploy-bot` can create Roles in `legacy-billing-migration`, and with `escalate` it could create a Role holding permissions it does not hold. Neither is bound to anyone, so neither grants anything.
- `deploy-bot` has no `update` on `roles`, so it cannot change an existing bound Role.

**Latent risk, not active.** If `create` on `rolebindings` were added for `deploy-bot`, `bind` on `cluster-superuser` would let it create a RoleBinding in `legacy-billing-migration` to `cluster-superuser`. That gives full control of the legacy namespace, including its Secrets. It would not give cluster-wide reach, because that requires `create` on `clusterrolebindings`, which only `controller-admin` holds.

**Who can delegate RBAC in this export.** Only `platform/controller-admin`, through `cluster-superuser`. Below that, the highest identity reachable through RBAC delegation is none.

### N2. `maya.chen` through `dev-editor` (no path)

`dev-editor` (`maya-dev-editor`, namespace `dev`) grants create, update, and patch on pods and deployments in `dev`, so she can name any `dev` ServiceAccount. The bound `dev` ServiceAccounts are:
- `dev-svc-01` and `dev-svc-03`: ConfigMaps and pods `get,list,watch,update,patch`.
- `dev-svc-02`: endpoints and services `get,list`; replicasets and statefulsets `get,list,watch`.
- `dev-svc-04`: both sets.

None has Secret access or a ClusterRoleBinding. A grep for `privileged` across the workloads found only `media-processing`, so no `dev` workload is privileged. Result: no becoming.

### N3. Cluster-wide `view` and `configmap-reader` (no escalation; data exposure)

Seven ServiceAccounts hold cluster-wide `view`: `kubesystem-svc-04`, `prod-svc-01` (two bindings), `build-svc-04`, `build-svc-05`, `staging-svc-01`, `mediaproce-svc-02`, `monitoring-svc-04`. `view` R1 covers pods, services, endpoints, and ConfigMaps (read). It does not cover Secrets. `deploy-bot` also reads ConfigMaps cluster-wide (`configmap-reader`). None of these changes identity. The exposure is data: ConfigMaps often hold credentials. Their contents are not in the export.

### N4. `prod/orders-api-sa` (no edge of its own)

Its only grant is read on `prod` ConfigMaps and Secrets. It is the target of E3 and E4 but starts no edge. See `1-effective_privilege.md` Section 6.

---

## 5. Permissions that look harmless

| Permission | Where it appears | What it allows |
|---|---|---|
| Pod `update`/`patch` | `mediaproce-role-01` in `media-processing` | Changes a running pod's image and inherits the pod's privileges (E5) |
| Job `create` | `reconciler` in `prod` | Runs a pod under any ServiceAccount in `prod` (E4) |
| Deployment `create`/`update` | `deployer` in `prod`; `dev-editor` in `dev` | Runs pods under any ServiceAccount in the namespace (E2, E3) |
| Pod `create` | `platform-deployer` in `platform` | Runs pods under `controller-admin` (E1) |
| `impersonate` on ServiceAccounts | `billing-migrator` in `legacy-billing-migration` | Acts as a ServiceAccount in that namespace (E6) |
| `bind`, `escalate` | `migration-operator` in `legacy-billing-migration` | Inert without `create` on RoleBindings (N1) |

---

## 6. Verification still needed

| Check | Command or method | Resolves |
|---|---|---|
| Deployment names in `prod` | Read `workloads/prod/deployments.yaml` in full | Names for the E2 and E3 Deployments (currently cited by line) |
| E1 pod ServiceAccount choice | Server-side dry run of a Pod in `platform` with `serviceAccountName: controller-admin`, as `system:serviceaccount:build:ci-runner` | E1 |
| E2, E3 workload ServiceAccount choice | Server-side dry run of a Deployment in `prod` with `serviceAccountName: billing-reconciler`, then `orders-api-sa`, as `system:serviceaccount:prod:deploy-bot` | E2, E3 |
| E4 Job ServiceAccount choice | Server-side dry run of a Job in `prod` with `serviceAccountName: orders-api-sa`, as `system:serviceaccount:prod:billing-reconciler` | E4 |
| E5 image patch | As `mediaproce-svc-01`: `kubectl patch pod <transcoder-pod> -n media-processing --dry-run=server -p '{"spec":{"containers":[{"name":"app","image":"busybox"}]}}'` | Whether a pod image patch is accepted |
| E5 node placement | `kubectl get pods -A -o wide` | What else runs on the node hosting `transcoder` |
| E6 impersonation scope | `kubectl auth can-i impersonate serviceaccounts -n legacy-billing-migration --as=maya.chen`; same with `-n prod` to confirm no cross-namespace reach | E6 scope |
| N1 binding creation | `kubectl auth can-i create rolebindings -n legacy-billing-migration --as=system:serviceaccount:prod:deploy-bot` | N1 stays inert |
| Image source | Review registry and node image pull policy | Whether an attacker-chosen image can run in E1 to E5 |
| Bootstrap bindings | `kubectl get clusterrolebindings,rolebindings -A -o yaml` on a live cluster | Any `system:` grants missing from the export. The main open limit. |

These checks need a caller with impersonation rights. Without them, the commands return `forbidden` and prove nothing.
