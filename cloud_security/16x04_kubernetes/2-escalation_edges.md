# Trellis Software — RBAC escalation edges

## 1. Method

**What an edge is.** An edge is a becoming: a starting subject uses a permission it holds and ends up running as an identity with more authority.

**Step types.** Every step in every edge carries one of two tags:
- **[E] Export-established.** The step is shown by a specific object or line in the export: a binding, a Role rule, a workload field, or a ServiceAccount name. The citation is given.
- **[K] Kubernetes-behavior.** The step follows Kubernetes API/controller behavior rather than an exported field. Examples: a pod template's ServiceAccount determines its API identity; a Job controller creates pods from its template; an accepted workload change is reconciled into pods. I state these separately from export facts. The supplied exercise is offline and has no cluster/API endpoint, so no live execution is claimed or required here.

**Edge status.**
- **Export-established** describes a step directly visible in the files.
- **Behavior-derived** describes the transition that follows when the exported permissions are exercised under the stated Kubernetes behavior. It is not reported as a live test result.

**Delegation rule.** `bind` and `escalate` do not create a grant by themselves. A subject also needs `create`, `update`, or `patch` on `rolebindings` to attach a Role to a subject. In this export, `migration-operator` has only `get,list` on `rolebindings`; its `create`, `bind`, and `escalate` rules are scoped through a RoleBinding in `legacy-billing-migration`. That RoleBinding does not give it cluster-scoped authority over ClusterRoles.

**Admission and Pod Security** (verified from files, see `1-effective_privilege.md` Section 1). `disallow-privileged` checks only Deployments and its binding uses Audit, so it does not reject a matching request. PSA `enforce: baseline` is set in namespaces including `platform` and `prod`; `media-processing`, `kube-system`, and `kube-addons-old` have no PSA labels. The export contains no admission rule that restricts `serviceAccountName`; hostPath must still be assessed against the namespace's PSA setting.

**Not analyzed.** The image source (registry and pull policy), `6-audit_trail.md`, and bootstrap bindings (`system:` groups, absent from the export).

## 2. Summary

| ID | Starting subject | Enabling permission [E] | Becomes | Reach | Status |
|---|---|---|---|---|---|
| E1 | `build/ci-runner` | Pod create in `platform` | `platform/controller-admin`, then the rights granted by `platform-controller-admin` | ClusterRole `cluster-superuser`, cluster-wide wildcard rules | Conditional, behavior-derived |
| E2 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/billing-reconciler` | Legacy `billing-secrets` read; Job create in `prod` | Behavior-derived (1 [K] step) |
| E3 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/orders-api-sa` | `prod` ConfigMaps and Secrets read | Behavior-derived (1 [K] step) |
| E4 | `prod/billing-reconciler` | `create` on Jobs in `prod` | Pod created from a Job template selecting `prod/orders-api-sa` | `orders-api-config`: read/watch Secrets and ConfigMaps in `prod` | Conditional, behavior-derived |
| E5 | `media-processing/mediaproce-svc-01`, `-02`, `-03` | Pod update/patch in `media-processing` | Existing `transcoder` Pod with its configured `media-worker` identity | Its declared privileged container context and read-write `/` hostPath mount | Conditional on accepted image change and successful pull |
| E6 | `maya.chen` | `impersonate` on ServiceAccounts through RoleBinding `maya-billing-migrator` → Role `billing-migrator` R2 | `reconcile-job` and `legacybill-svc-01` through `legacybill-svc-07` in `legacy-billing-migration` | Per-target grants enumerated below; `reconcile-job` has none, others have namespace-scoped grants, none has Secret access | Behavior-derived (2 [K] scope steps) |
| N1 | `prod/deploy-bot` | `bind`, `escalate`, `create` on roles/clusterroles | None active | Inert: no subject holds RoleBinding write | Dead end |

---

## 3. Edges

### E1. `build/ci-runner` can run a Pod as `platform/controller-admin`

**Step 1 [E]: enabling grant.** RoleBinding `ci-runner-platform-deploy` in namespace `platform` names ServiceAccount `ci-runner` in namespace `build` and Role `platform-deployer`. That Role grants `create` on core Pods (and get/list/watch) in `platform` only (`roles.yaml`, Role `platform-deployer`).

**Step 2 [E]: target identity and its own grant.** ServiceAccount `controller-admin` exists in `platform` (`serviceaccounts.yaml`). ClusterRoleBinding `platform-controller-admin` binds that exact ServiceAccount to ClusterRole `cluster-superuser`; the ClusterRole's rule is wildcard API groups, resources, and verbs (`clusterrolebindings.yaml`; `clusterroles.yaml`).

**Step 3 [E]: no listed admission control blocks this choice.** The `disallow-privileged` ValidatingAdmissionPolicy applies to Deployments and its binding is Audit-only (`admission/policies.yaml`; `admission/bindings.yaml`). It does not validate `serviceAccountName`. Namespace `platform` has PSA `enforce: baseline`; a Pod still must meet that baseline, but that label does not forbid selecting `controller-admin`.

**Step 4 [K]: same-namespace ServiceAccount selection.** Using the Pod-create grant in `platform`, `build/ci-runner` can request a Pod whose spec sets `serviceAccountName: controller-admin` and `automountServiceAccountToken: true`. Kubernetes runs that Pod as the selected `platform/controller-admin` ServiceAccount and supplies its token. This uses a ServiceAccount in the Pod's own namespace; no cross-namespace selection is claimed. The existing `platform-controller` Deployment also selects this ServiceAccount and enables token automount (`workloads/platform/daemonsets.yaml`, lines 16–17).

**Result.** Pod creation alone does not grant cluster-wide authority. If a Pod is admitted and its image is available, the path is: `build/ci-runner` creates a Pod in `platform` → the Pod selects `platform/controller-admin` → ClusterRoleBinding `platform-controller-admin` gives that identity the wildcard `cluster-superuser` rules cluster-wide. This is a conditional Kubernetes-behavior path from the exported grant, not an executed Pod or API request.

---

### E2. `prod/deploy-bot` becomes `prod/billing-reconciler` and reads legacy Secrets

**Step 1 [E]: enabling grant.** RoleBinding `deploy-bot-deployer` (namespace `prod`) binds `prod/deploy-bot` to Role `deployer`. Role R1: apiGroup `apps`, resources `deployments`, `replicasets`, verbs `get,list,watch,create,update,patch`. Scope: `prod`.

**Step 2 [E]: target identity is used by a workload in `prod`.** Deployment `billing-worker` in `workloads/prod/deployments.yaml` sets `serviceAccountName: billing-reconciler` and `automountServiceAccountToken: true` (lines 39–40).

**Step 3 [K]: workload identity transition.** In a Deployment Pod template in `prod`, `prod/deploy-bot` can set `serviceAccountName: billing-reconciler` and `automountServiceAccountToken: true`; the controller then creates Pods using that same-namespace ServiceAccount. The resulting API identity is `system:serviceaccount:prod:billing-reconciler`. The existing `billing-worker` template also sets both fields (`workloads/prod/deployments.yaml`, lines 39–40). This remains conditional on the Deployment being admitted and reconciled. The `prod` PSA baseline applies, but the supplied admission policy does not restrict ServiceAccount selection.

**Step 4 [E]: resulting identity and its privileges.**
- RoleBinding `billing-reconciler-prod` (`prod`) → Role `reconciler`: R1 core `configmaps` `get,list,watch`; R2 `batch/jobs` `get,list,create`.
- RoleBinding `billing-reconciler-secrets` (`legacy-billing-migration`) → Role `billing-secrets` (`roles.yaml` lines 204 and 210): R1 core `secrets` `get,list`; R2 core `configmaps` `get,list`.
- No ClusterRoleBinding names `billing-reconciler`.

**Result.** In `prod`, `deploy-bot` can change a Deployment's Pod template to select `prod/billing-reconciler`; the resulting ServiceAccount has `create` on Jobs in `prod` and `get,list` on Secrets only in `legacy-billing-migration`. Each namespace limit comes from the binding that grants the Role. This is conditional Kubernetes behavior, not an executed deployment.

**Token-secret limit [E + K].** The export proves that `billing-reconciler` can read Secret objects in `legacy-billing-migration`. It contains no Secret objects, types, or values, so it does not identify a Secret holding another ServiceAccount's token or establish a target identity that could be assumed from its contents. Treat “read a token-holding Secret, then use its token as another identity” as conditional on finding such a live credential; the present export cannot complete that identity transition. The confirmed path from `billing-reconciler` to `orders-api-sa` is E4 through Job creation.

---

### E3. `prod/deploy-bot` becomes `prod/orders-api-sa` and reads `prod` Secrets

**Step 1 [E]: enabling grant.** RoleBinding `deploy-bot-deployer` in `prod` binds `prod/deploy-bot` to Role `deployer`. Its R1 grants `get,list,watch,create,update,patch` on Apps Deployments and ReplicaSets in `prod`; R2 grants `get,list` on core Pods and ConfigMaps in `prod` (`roles.yaml`, Role `deployer`).

**Step 2 [E]: target identity is used by a workload in `prod`.** `workloads/prod/deployments.yaml` line 16 `serviceAccountName: orders-api-sa`; line 17 `automountServiceAccountToken: true`.

**Step 3 [K]: workload identity transition.** In a Deployment Pod template in `prod`, `prod/deploy-bot` can set `serviceAccountName: orders-api-sa` and `automountServiceAccountToken: true`; its controller then creates Pods running as that same-namespace ServiceAccount. The existing `orders-api` template sets both fields (lines 16–17). This remains conditional on the Deployment being admitted and reconciled. The `prod` PSA baseline applies, but the supplied admission policy does not restrict ServiceAccount selection. Reconciliation and token projection are Kubernetes behavior, not a live result claimed here.

**Step 4 [E]: resulting identity and its privileges.** RoleBinding `orders-api-config` in `prod` binds ServiceAccount `prod/orders-api-sa` to Role `orders-api-config`. Its only rule grants core ConfigMaps and Secrets `get,list,watch` in `prod` (`roles.yaml`, Role `orders-api-config`). No other RoleBinding or ClusterRoleBinding names this ServiceAccount in the export.

**Result.** `deploy-bot` can cause code to run as `prod/orders-api-sa`, whose Role grants `get,list,watch` on Secrets and ConfigMaps in `prod`. This is an offline path analysis, not an executed deployment.

---

### E4. `prod/billing-reconciler` can create a Job running as `prod/orders-api-sa`

**Step 1 [E]: exact Job-create grant.** RoleBinding `billing-reconciler-prod` in namespace `prod` binds ServiceAccount `prod/billing-reconciler` to Role `reconciler`. In `roles.yaml`, that Role's R2 grants `get,list,create` on `batch/jobs`; because it is a namespaced RoleBinding, the grant applies to Jobs in `prod`.

**Step 2 [E]: target ServiceAccount and resulting RBAC grant.** ServiceAccount `orders-api-sa` exists in `prod` (`serviceaccounts.yaml`). RoleBinding `orders-api-config` in `prod` binds it to Role `orders-api-config`, whose rule grants `get,list,watch` on core Secrets and ConfigMaps in `prod` (`rolebindings.yaml`; `roles.yaml`). No cross-namespace ServiceAccount is involved.

**Step 3 [K]: Job template selects the identity.** A Job creator in `prod` can set `spec.template.spec.serviceAccountName: orders-api-sa` and `automountServiceAccountToken: true`. The Job controller creates a Pod from that template; Kubernetes runs it as `prod/orders-api-sa` and projects that identity's token. The existing `orders-api` Deployment also selects `orders-api-sa` and enables token automount (`workloads/prod/deployments.yaml`, lines 16–17). A Job in `prod` cannot select a ServiceAccount from another namespace. This is Kubernetes behavior, not a live Job result; the Pod still has to satisfy applicable admission controls, which do not restrict this ServiceAccount selection in the supplied export.

**Result.** The full path is `prod/billing-reconciler` → `billing-reconciler-prod` / Role `reconciler` (`batch/jobs create` in `prod`) → a Job template selecting `prod/orders-api-sa` → RoleBinding `orders-api-config` → `get,list,watch` on Secrets and ConfigMaps in `prod`. The transition is conditional on the Job being admitted and scheduled; no live Job is claimed.

---

### E5. The media-processing ServiceAccounts can change the `transcoder` Pod image

**Step 1 [E]: exact Pod-update grant.** RoleBindings `mediaproce-svc-01-mediaproce-role-01`, `mediaproce-svc-02-mediaproce-role-01`, and `mediaproce-svc-03-mediaproce-role-01` in namespace `media-processing` bind those ServiceAccounts to Role `mediaproce-role-01`. Its R1 grants `update,patch` on core Pods in `media-processing` (`rolebindings.yaml`; `roles.yaml`).

**Step 2 [E]: existing Pod configuration.** Deployment `transcoder` in `workloads/media-processing/deployments.yaml` selects `media-worker` and enables token automount (lines 16–17). Its container is `privileged: true`, adds `SYS_ADMIN`, uses host networking, and mounts host path `/` read-write at `/host` (lines 22–33). The corresponding ServiceAccount `media-worker` is in `media-processing` (`serviceaccounts.yaml`).

**Step 3 [K]: conditional image replacement.** If one of these ServiceAccounts submits an accepted update/patch changing the container image on an existing `transcoder` Pod, and the node can pull that image, Kubernetes runs the replacement image in that Pod. The update targets the Pod's image; it does not select a different ServiceAccount or alter the other listed Pod settings. The exported `disallow-privileged` policy targets Deployments, not direct Pod updates, and its binding is Audit-only; namespace `media-processing` has no PSA labels (`admission/`; `podsecurity-labels.yaml`). No such patch or image pull is recorded in this offline export.

**Step 4 [E]: inherited context.** The changed container remains in the existing Pod, whose ServiceAccount is `media-worker` with token automount enabled. It also retains the declared privileged setting, `SYS_ADMIN`, host networking, and read-write mount of host `/` at `/host`. These are the target Pod's exported settings, not extra RBAC permissions granted to the three starting ServiceAccounts.

**Result.** Conditional on an accepted image update and successful image pull, code in the replacement image would run in the existing `transcoder` Pod as `media-processing/media-worker`, with that Pod's declared privileged/`SYS_ADMIN` context and read-write host-root mount. This is behavior-derived from the Pod update grant and manifest, not a claim that code ran. The export does not establish node placement or impact on other workloads, so no cluster-wide or multi-node effect is claimed.

---

### E6. `maya.chen` becomes each impersonated ServiceAccount in `legacy-billing-migration`

**Step 1 [E]: starting identity and enabling grant.** RoleBinding `maya-billing-migrator` in `legacy-billing-migration` binds User `maya.chen` to Role `billing-migrator`. Rule R2 in `roles.yaml` grants `impersonate` on core `serviceaccounts`, `users`, and `groups`. Its R1 additionally grants core Pod and ConfigMap `get,list` in that namespace.

**Step 2 [K]: namespace-scoped impersonation.** Kubernetes authorizes impersonation of a ServiceAccount in that ServiceAccount's namespace. The namespaced RoleBinding therefore lets `maya.chen` make API requests as ServiceAccounts in `legacy-billing-migration`, but not ServiceAccounts in other namespaces. This is API impersonation authority; it does not give Maya a ServiceAccount token. The exercise provides exported state and no live API.

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

## 4. Dead ends (checked and cleared)

### N1. `prod/deploy-bot` through `migration-operator`

RoleBinding `legacy-migration-admin` in `legacy-billing-migration` binds `prod/deploy-bot` to namespaced Role `migration-operator`.

- Role `migration-operator`, bound by `legacy-migration-admin` in `legacy-billing-migration`, grants `get,list` on `roles,rolebindings` and `create,bind,escalate` on `roles,clusterroles` (`roles.yaml`; `rolebindings.yaml`). `deploy-bot` therefore lacks `create`, `update`, or `patch` on `rolebindings`; it cannot attach a newly created Role to any subject.
- `escalate` can permit creation of a namespaced Role with rules beyond the creator's own grants, but that Role remains unbound. The `clusterroles` entries in a namespaced Role do not create cluster-scoped authority. No active path from these rules to an additional subject grant is established.

**Result.** `bind` and `escalate` do not make `deploy-bot` an administrator here. The missing RoleBinding write permission stops the escalation; the export supports a dead end, not current namespace takeover or cluster-wide reach.

## 5. Evidence boundary

This assessment is derived from the supplied export; no Kubernetes cluster or API server is in scope. [E] steps are directly reproducible from the cited YAML objects. [K] steps describe the Kubernetes behavior that connects those permissions and objects into an identity transition; they are not represented as executed requests or observed live state. Runtime facts absent from the export—such as node placement, image pull success, or whether a particular patch was applied—are not asserted. In particular, E5 establishes the configured privileged execution context but not which other workloads share its node.
