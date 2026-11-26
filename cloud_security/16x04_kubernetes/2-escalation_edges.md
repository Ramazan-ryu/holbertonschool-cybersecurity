# Trellis Software — RBAC escalation edges

## 1. Method

**What an edge is.** An edge is a becoming: a starting subject uses a permission it holds and ends up running as an identity with more authority.

**Step types.** Every step in every edge carries one of two tags:
- **[E] Export-established.** The step is shown by a specific object or line in the export: a binding, a Role rule, a workload field, or a ServiceAccount name. The citation is given.
- **[K] Kubernetes-behavior.** The step follows Kubernetes API/controller behavior rather than an exported field. Examples: a pod template's ServiceAccount determines its API identity; a Job controller creates pods from its template; an accepted workload change is reconciled into pods. I state these separately from export facts. The supplied exercise is offline and has no cluster/API endpoint, so no live execution is claimed or required here.

**Edge status.**
- **Export-established** describes a step directly visible in the files.
- **Behavior-derived** describes the transition that follows when the exported permissions are exercised under the stated Kubernetes behavior. It is not reported as a live test result.

**Delegation rule.** Writing a RoleBinding requires `create`, `update`, or `patch` on `rolebindings`. The export grants that verb to no subject except through `cluster-superuser`, held only by `platform/controller-admin` (`roles.yaml` line 38 lists `rolebindings` with `get,list` only).

**Admission and Pod Security** (verified from files, see `1-effective_privilege.md` Section 1). `disallow-privileged` runs in Audit mode and checks only Deployments. `media-processing`, `kube-system`, and `kube-addons-old` carry no PSA labels. No policy in `admission/` restricts `serviceAccountName`, pod image changes, or hostPath use.

**Not analyzed.** The image source (registry and pull policy), `6-audit_trail.md`, and bootstrap bindings (`system:` groups, absent from the export).

## 2. Summary

| ID | Starting subject | Enabling permission [E] | Becomes | Reach | Status |
|---|---|---|---|---|---|
| E1 | `build/ci-runner` | Pod create in `platform` | `platform/controller-admin` | Cluster-wide, all verbs | Behavior-derived (2 [K] steps) |
| E2 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/billing-reconciler` | Legacy `billing-secrets` read; Job create in `prod` | Behavior-derived (1 [K] step) |
| E3 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/orders-api-sa` | `prod` ConfigMaps and Secrets read | Behavior-derived (1 [K] step) |
| E4 | `prod/billing-reconciler` | Job create in `prod` | `prod/orders-api-sa` | `prod` ConfigMaps and Secrets read | Behavior-derived (1 [K] step) |
| E5 | `media-processing/mediaproce-svc-01`, `-02`, `-03` | Pod update/patch in `media-processing` | Code executing in `transcoder` under its configured `media-worker` identity and privileged container context | Node-level: privileged, host network, host root | Behavior-derived (2 [K] steps) |
| E6 | `maya.chen` | `impersonate` on ServiceAccounts through RoleBinding `maya-billing-migrator` → Role `billing-migrator` R2 | `reconcile-job` and `legacybill-svc-01` through `legacybill-svc-07` in `legacy-billing-migration` | Per-target grants enumerated below; `reconcile-job` has none, others have namespace-scoped grants, none has Secret access | Behavior-derived (2 [K] scope steps) |
| E7 | `build/ci-runner` | Pod create in `build` | `build/build-svc-04` or `build/build-svc-05` | Cluster-wide `view`: read/watch pods, services, endpoints, ConfigMaps, Deployments, ReplicaSets | Behavior-derived (1 [K] step) |
| E8 | `prod/deploy-bot` or `prod/billing-reconciler` | Deployment create/update or Job create in `prod` | `prod/prod-svc-01` | Cluster-wide `view` read access | Behavior-derived (1 [K] step per source) |
| N1 | `prod/deploy-bot` | `bind`, `escalate`, `create` on roles/clusterroles | None active | Inert: no subject holds RoleBinding write | Dead end |
| N2 | `maya.chen` | Pod and Deployment write in `dev` | Any `dev` ServiceAccount | No Secrets, no cluster scope | Dead end |
| N3 | Seven ServiceAccounts with cluster-wide `view` | Cluster-wide `view` | None | Read of pods, services, endpoints, ConfigMaps | No escalation; data exposure |

---

## 3. Edges

### E1. `build/ci-runner` becomes `platform/controller-admin`, then cluster superuser

**Step 1 [E]: enabling grant.** RoleBinding `ci-runner-platform-deploy` (namespace `platform`) binds ServiceAccount `build/ci-runner` to Role `platform-deployer`. Role R1: core `pods`, verbs `get,list,watch,create`. Scope: `platform` only.

**Step 2 [E]: target identity exists.** ServiceAccount `controller-admin` is in `platform` (`0-rbac_map.md` Section 3, platform ServiceAccounts). ClusterRoleBinding `platform-controller-admin` binds it to ClusterRole `cluster-superuser`.

**Step 3 [E]: an existing workload selects the identity and requests token automount.** `workloads/platform/daemonsets.yaml` lines 16–17: the Deployment `platform-controller` in `platform` sets `serviceAccountName: controller-admin` and `automountServiceAccountToken: true`. Despite the filename, the exported object is a Deployment with one replica.

**Step 4 [E]: no export control restricts the choice.** The only admission policy (`admission/policies.yaml`) checks Deployments for `privileged` and runs in Audit mode. No policy checks `serviceAccountName`.

**Step 5 [K]: identity and credential selection.** A Pod template created by `ci-runner` can name `serviceAccountName: controller-admin` and set `automountServiceAccountToken: true`. Kubernetes runs the Pod under `platform/controller-admin` and projects its API credential. The existing `platform-controller` template also selects this identity and explicitly enables automount (`workloads/platform/daemonsets.yaml`, lines 16–17); the new Pod's identity/token behavior is Kubernetes semantics.

**Step 6 [K]: API authorization as the selected identity.** Code running in the created pod uses the pod's ServiceAccount credential for Kubernetes API requests. The credential itself is not included in the export and was not collected.

**Step 7 [E]: resulting identity and its privileges.** ClusterRole `cluster-superuser` (`clusterroles.yaml`, wildcard rule): wildcard API groups, resources, and verbs. Via ClusterRoleBinding `platform-controller-admin`. Cluster-wide. Includes RBAC writes.

**Result.** Behavior-derived from the pod-create grant and the configured target identity. If a pod using a pullable image is created with `serviceAccountName: controller-admin`, code in it runs with that ServiceAccount's cluster-superuser permissions. This is an offline path analysis, not an executed pod or API request.

---

### E2. `prod/deploy-bot` becomes `prod/billing-reconciler` and reads legacy Secrets

**Step 1 [E]: enabling grant.** RoleBinding `deploy-bot-deployer` (namespace `prod`) binds `prod/deploy-bot` to Role `deployer`. Role R1: apiGroup `apps`, resources `deployments`, `replicasets`, verbs `get,list,watch,create,update,patch`. Scope: `prod`.

**Step 2 [E]: target identity is used by a workload in `prod`.** Deployment `billing-worker` in `workloads/prod/deployments.yaml` sets `serviceAccountName: billing-reconciler` and `automountServiceAccountToken: true` (lines 39–40).

**Step 3 [K]: workload identity transition.** A Deployment created or changed by `prod/deploy-bot` can set `serviceAccountName: billing-reconciler` and `automountServiceAccountToken: true`; its controller then creates pods using that ServiceAccount identity. The resulting API identity is `system:serviceaccount:prod:billing-reconciler`. The existing `billing-worker` template also sets both fields (`workloads/prod/deployments.yaml`, lines 39–40).

**Step 4 [E]: resulting identity and its privileges.**
- RoleBinding `billing-reconciler-prod` (`prod`) → Role `reconciler`: R1 core `configmaps` `get,list,watch`; R2 `batch/jobs` `get,list,create`.
- RoleBinding `billing-reconciler-secrets` (`legacy-billing-migration`) → Role `billing-secrets` (`roles.yaml` lines 204 and 210): R1 core `secrets` `get,list`; R2 core `configmaps` `get,list`.
- No ClusterRoleBinding names `billing-reconciler`.

**Result.** `deploy-bot` can cause code to run as `prod/billing-reconciler`, whose union includes `get,list` on Secrets only in `legacy-billing-migration`; the identity also has `create` on Jobs in `prod` (E4). This is an offline path analysis, not an executed deployment.

**Token-secret limit [E + K].** The export proves that `billing-reconciler` can read Secret objects in `legacy-billing-migration`. It contains no Secret objects, types, or values, so it does not identify a Secret holding another ServiceAccount's token or establish a target identity that could be assumed from its contents. Treat “read a token-holding Secret, then use its token as another identity” as conditional on finding such a live credential; the present export cannot complete that identity transition. The confirmed path from `billing-reconciler` to `orders-api-sa` is E4 through Job creation.

---

### E3. `prod/deploy-bot` becomes `prod/orders-api-sa` and reads `prod` Secrets

**Step 1 [E]: enabling grant.** RoleBinding `deploy-bot-deployer` in `prod` binds `prod/deploy-bot` to Role `deployer`. Its R1 grants `get,list,watch,create,update,patch` on Apps Deployments and ReplicaSets in `prod`; R2 grants `get,list` on core Pods and ConfigMaps in `prod` (`roles.yaml`, Role `deployer`).

**Step 2 [E]: target identity is used by a workload in `prod`.** `workloads/prod/deployments.yaml` line 16 `serviceAccountName: orders-api-sa`; line 17 `automountServiceAccountToken: true`.

**Step 3 [K]: workload identity transition.** A Deployment created or changed by `prod/deploy-bot` can set `serviceAccountName: orders-api-sa` and `automountServiceAccountToken: true`; its controller then creates pods running as that ServiceAccount. The existing `orders-api` template sets both fields (lines 16–17); reconciliation and token projection are Kubernetes behavior, not a live result claimed here.

**Step 4 [E]: resulting identity and its privileges.** RoleBinding `orders-api-config` in `prod` binds ServiceAccount `prod/orders-api-sa` to Role `orders-api-config`. Its only rule grants core ConfigMaps and Secrets `get,list,watch` in `prod` (`roles.yaml`, Role `orders-api-config`). No other RoleBinding or ClusterRoleBinding names this ServiceAccount in the export.

**Result.** `deploy-bot` can cause code to run as `prod/orders-api-sa`, whose Role grants `get,list,watch` on Secrets and ConfigMaps in `prod`. This is an offline path analysis, not an executed deployment.

---

### E4. `prod/billing-reconciler` becomes `prod/orders-api-sa` through a Job and reads `prod` Secrets

**Step 1 [E]: enabling grant.** RoleBinding `billing-reconciler-prod` (`prod`) → Role `reconciler` R2: `batch/jobs` `get,list,create`. Scope: `prod`.

**Step 2 [E]: target identity exists and is used in `prod`.** Deployment `orders-api` in `workloads/prod/deployments.yaml` sets `serviceAccountName: orders-api-sa` and `automountServiceAccountToken: true` (lines 1–17). A Job can name this existing ServiceAccount in its pod template.

**Step 3 [K]: Job identity transition.** `billing-reconciler` can create a Job whose pod template names `orders-api-sa` and sets `automountServiceAccountToken: true`. The Job controller creates a pod running under that ServiceAccount. The existing `orders-api` template sets both fields (lines 16–17); controller behavior is Kubernetes semantics, not a live result claimed here.

**Step 4 [E]: resulting identity and its privileges.** RoleBinding `orders-api-config` in `prod` binds `prod/orders-api-sa` to Role `orders-api-config`, whose rule grants `get,list,watch` on core ConfigMaps and Secrets in `prod` (`roles.yaml`, Role `orders-api-config`). No other RoleBinding or ClusterRoleBinding names this ServiceAccount in the export.

**Result.** `billing-reconciler` can cause code to run as `prod/orders-api-sa`, adding read/watch access to `prod` Secrets and ConfigMaps to its existing legacy Secret read. This is an offline path analysis, not an executed Job.

---

### E5. `media-processing/mediaproce-svc-01`, `-02`, `-03` become code execution in `transcoder` under its privileged context

**Step 1 [E]: enabling grant.** RoleBindings `mediaproce-svc-01-mediaproce-role-01`, `mediaproce-svc-02-mediaproce-role-01`, and `mediaproce-svc-03-mediaproce-role-01` (namespace `media-processing`) bind these ServiceAccounts to Role `mediaproce-role-01`. R1: core `configmaps, pods, endpoints` with `get,list,watch,update,patch`.

**Step 2 [E]: the privileged workload exists.** `workloads/media-processing/deployments.yaml`, Deployment `transcoder`:
- line 16 `serviceAccountName: media-worker`; line 17 `automountServiceAccountToken: true`
- line 22 `privileged: true`; `capabilities.add: [SYS_ADMIN]` at lines 23–25
- line 30 `hostNetwork: true`
- line 33 `hostPath: /`, mounted read-write at `/host`

**Step 3 [K]: changed execution context.** If a permitted Pod update/patch changes the `transcoder` container image, Kubernetes runs that image in the Pod's configured container and pod security context. The export establishes the grant and current context, but does not record that a patch was applied; this is the path's Kubernetes-behavior step, not a claimed execution result.

**Step 4 [E]: resulting identity and its privileges.** The pod runs as `media-worker`, which has no RoleBinding (`1-effective_privilege.md`, unbound list). Its effective privilege is the pod's privilege: privileged, `SYS_ADMIN`, host network, read-write host root.

**Result.** Applying the permitted pod change to `transcoder` makes attacker-controlled code execute in that pod's existing context: ServiceAccount `media-worker`, privileged container, `SYS_ADMIN`, host network, and read-write host root. This is a behavior-derived path from the export, not a claim that a patch was run. The resulting node access is tied to the node running `transcoder`; cluster-wide reach depends on co-located workloads, which the export does not show.

---

### E6. `maya.chen` becomes each impersonated ServiceAccount in `legacy-billing-migration`

**Step 1 [E]: starting identity and enabling grant.** RoleBinding `maya-billing-migrator` in `legacy-billing-migration` binds User `maya.chen` to Role `billing-migrator`. Rule R2 in `roles.yaml` grants `impersonate` on core `serviceaccounts`, `users`, and `groups`. Its R1 additionally grants core Pod and ConfigMap `get,list` in that namespace.

**Step 2 [K]: namespace-scoped impersonation.** Kubernetes evaluates impersonation of a ServiceAccount in that ServiceAccount's namespace. The namespaced RoleBinding therefore lets `maya.chen` request identities in `legacy-billing-migration`, but not ServiceAccounts in other namespaces. This scope is Kubernetes authorization behavior; the exercise provides exported state and no live API.

**Step 3 [E]: enumerate every target identity and its exported grants.** The identity objects are in `serviceaccounts.yaml`; each binding and Role below is in `rolebindings.yaml` and `roles.yaml`, respectively. These are the full set of ServiceAccounts in the target namespace.

| Target identity after impersonation | Exported RoleBindings → Role rules | Resulting RBAC privilege in `legacy-billing-migration` |
|---|---|---|
| `reconcile-job` | No RoleBinding names this ServiceAccount. | No RBAC grants in the export. Impersonation reaches an identity with no exported Kubernetes API permissions. |
| `legacybill-svc-01` | `legacybill-svc-01-legacybill-role-01` → `legacybill-role-01` R1,R2; `legacybill-svc-01-legacybill-role-02` → `legacybill-role-02` R1 | Core Pods `get,list,watch`; Apps ReplicaSets and Deployments `get,list,watch`; core Pods, ConfigMaps, and Services `get,list`. |
| `legacybill-svc-02` | `legacybill-svc-02-legacybill-role-03` → `legacybill-role-03` R1,R2 | Core ConfigMaps and Services `get,list,watch,update,patch`; Apps Deployments and StatefulSets `get,list,watch`. |
| `legacybill-svc-03` | `legacybill-svc-03-legacybill-role-01` → `legacybill-role-01` R1,R2; `legacybill-svc-03-legacybill-role-03` → `legacybill-role-03` R1,R2 | Union: core Pods `get,list,watch`; Apps ReplicaSets and Deployments `get,list,watch`; core ConfigMaps and Services `get,list,watch,update,patch`; Apps Deployments and StatefulSets `get,list,watch`. |
| `legacybill-svc-04` | `legacybill-svc-04-legacybill-role-02` → `legacybill-role-02` R1 | Core Pods, ConfigMaps, and Services `get,list`. |
| `legacybill-svc-05` | `legacybill-svc-05-legacybill-role-02` → `legacybill-role-02` R1 | Core Pods, ConfigMaps, and Services `get,list`. |
| `legacybill-svc-06` | `legacybill-svc-06-legacybill-role-03` → `legacybill-role-03` R1,R2; `legacybill-svc-06-legacybill-role-01` → `legacybill-role-01` R1,R2 | Union: core Pods `get,list,watch`; Apps ReplicaSets and Deployments `get,list,watch`; core ConfigMaps and Services `get,list,watch,update,patch`; Apps Deployments and StatefulSets `get,list,watch`. |
| `legacybill-svc-07` | `legacybill-svc-07-legacybill-role-03` → `legacybill-role-03` R1,R2 | Core ConfigMaps and Services `get,list,watch,update,patch`; Apps Deployments and StatefulSets `get,list,watch`. |

**Step 4 [E]: exported user/group bindings.** The R2 rule includes core resources `users` and `groups`, but none of the 11 ClusterRoleBindings names `maya.chen`, and the only RoleBinding for that subject in the target namespace is `maya-billing-migrator` [E].

**Step 5 [K]: user/group scope.** Kubernetes evaluates impersonation of users and groups at cluster scope; a namespaced RoleBinding does not supply that cluster-scoped grant. The edge is therefore limited to the enumerated ServiceAccounts in the supplied export.

**Result.** `maya.chen` can act as each of the seven listed `legacybill-svc-*` identities with exactly the per-identity rights above, or as `reconcile-job` with no exported RBAC rights. No target has Secret permissions in the export. The write-capable identities can update/patch ConfigMaps and Services and read/watch Deployments/StatefulSets; `legacybill-svc-01` and `-03`/`-06` also read Pods and ReplicaSets. This is one namespace-scoped identity-transition path with eight explicitly enumerated targets.

---

### E7. `build/ci-runner` becomes a build ServiceAccount with cluster-wide `view`

**Step 1 [E]: starting grant.** RoleBinding `ci-runner-build` in namespace `build` binds `build/ci-runner` to Role `ci-build`. Rule R2 grants `create` on core Pods in `build` (`roles.yaml`, Role `ci-build`).

**Step 2 [E]: target identities and their grants.** `build-svc-04` and `build-svc-05` are ServiceAccounts in `build` (`serviceaccounts.yaml`). ClusterRoleBindings `build-svc-04-view-139` and `build-svc-05-view-692` bind them to ClusterRole `view`.

**Step 3 [K]: pod identity transition.** A Pod created by `build/ci-runner` in `build` can set `serviceAccountName` to either target and `automountServiceAccountToken: true`; it then runs with that ServiceAccount identity and projected credential. This is distinct from E1, which selects `platform/controller-admin` in `platform`.

**Step 4 [E]: resulting privilege.** ClusterRole `view` R1 and R2 grants `get,list,watch` on core Pods, Services, Endpoints, ConfigMaps and Apps Deployments and ReplicaSets cluster-wide. It grants no Secret access.

**Result.** Pod creation lets `build/ci-runner` run code as either `build/build-svc-04` or `build/build-svc-05` and obtain cluster-wide read-only `view`. This is narrower than E1's cluster-superuser path but crosses namespace boundaries.

---

### E8. Production workload creators become `prod/prod-svc-01` with cluster-wide `view`

**Step 1 [E]: `prod/deploy-bot` source grant.** RoleBinding `deploy-bot-deployer` binds `prod/deploy-bot` to Role `deployer`; R1 grants `create,update,patch` on Apps Deployments in `prod`.

**Step 2 [E]: `prod/billing-reconciler` source grant.** RoleBinding `billing-reconciler-prod` binds `prod/billing-reconciler` to Role `reconciler`; R2 grants `create` on Batch Jobs in `prod`.

**Step 3 [E]: target identity and binding.** ServiceAccount `prod-svc-01` is in `prod`. ClusterRoleBindings `prod-svc-01-view-677` and `prod-svc-01-view-509` both bind it to ClusterRole `view`; they duplicate the same grant. Existing Deployment `prod-app-1` in `workloads/prod/deployments.yaml` lines 85–86 also selects this ServiceAccount and sets `automountServiceAccountToken: true`.

**Step 4 [K]: workload identity transition.** A Deployment created or changed by `prod/deploy-bot`, or a Job created by `prod/billing-reconciler`, can set `serviceAccountName: prod-svc-01` and `automountServiceAccountToken: true` in its pod template. The resulting pod runs under that ServiceAccount with its projected credential; no exported admission policy restricts these fields.

**Step 5 [E]: resulting privilege.** Through either ClusterRoleBinding, `prod-svc-01` has `get,list,watch` on Pods, Services, Endpoints, ConfigMaps, Deployments and ReplicaSets cluster-wide. It has no Secret permission through `view`.

**Result.** Each of the two starting identities can cause a workload in `prod` to run as `prod/prod-svc-01`, adding cluster-wide read-only `view`. This does not grant cluster-wide writes or Secret reads.

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

### N3. Direct cluster-wide `view` and `configmap-reader` grants

The ClusterRoleBindings directly grant cluster-wide `view` to `kubesystem-svc-04`, `prod-svc-01` (two duplicate bindings), `build-svc-04`, `build-svc-05`, `staging-svc-01`, `mediaproce-svc-02`, and `monitoring-svc-04`. `view` is read-only and excludes Secrets. `deploy-bot` also has cluster-wide ConfigMap read through `deploy-bot-cm-read` → `configmap-reader`. The identity-selection transitions into three of those `view` identities are separately documented in E7 and E8.

---

## 5. Permissions that look harmless

| Permission | Where it appears | Edge |
|---|---|---|
| Pod `update`/`patch` | `mediaproce-role-01` in `media-processing` | E5 (behavior-derived) |
| Job `create` | `reconciler` in `prod` | E4 (behavior-derived) |
| Deployment `create`/`update` | `deployer` in `prod`; `dev-editor` in `dev` | E2, E3 (behavior-derived); N2 (dead end) |
| Pod `create` | `platform-deployer` in `platform` | E1 (behavior-derived) |
| `impersonate` on ServiceAccounts | `billing-migrator` in `legacy-billing-migration` | E6 (behavior-derived) |
| `bind`, `escalate` | `migration-operator` in `legacy-billing-migration` | N1 (inert) |

---

## 6. Evidence boundary

This assessment is derived from the supplied export; no Kubernetes cluster or API server is in scope. [E] steps are directly reproducible from the cited YAML objects. [K] steps describe the Kubernetes behavior that connects those permissions and objects into an identity transition; they are not represented as executed requests or observed live state. Runtime facts absent from the export—such as node placement, image pull success, or whether a particular patch was applied—are not asserted. In particular, E5 establishes the configured privileged execution context but not which other workloads share its node.
