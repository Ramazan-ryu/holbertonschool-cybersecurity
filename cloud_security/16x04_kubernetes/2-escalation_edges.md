# Trellis Software — RBAC escalation edges

## 1. Method

**What an edge is.** An edge is a becoming: a starting subject uses a permission it holds and ends up running as an identity with more authority.

**Step types.** Every step in every edge carries one of two tags:
- **[E] Export-established.** The step is shown by a specific object or line in the export: a binding, a Role rule, a workload field, or a ServiceAccount name. The citation is given.
- **[K] Kubernetes-behavior.** The step follows Kubernetes API/controller behavior rather than an exported field. Examples: a pod template's ServiceAccount determines its API identity; a Job controller creates pods from its template; an accepted workload change is reconciled into pods. I state these separately from export facts. The supplied exercise is offline and has no cluster/API endpoint, so no live execution is claimed or required here.

**Edge status.**
- **Export-established** describes a step directly visible in the files.
- **Behavior-derived** describes the transition that follows when the exported permissions are exercised under the stated Kubernetes behavior. It is not reported as a live test result.

**Delegation rule.** `bind` and `escalate` do not attach a Role to a subject. Attaching or changing a RoleBinding requires `create`, `update`, or `patch` on `rolebindings`. In this export, `migration-operator` has only `get,list` on `rolebindings`, so it cannot attach a Role to any subject. Its namespaced RoleBinding in `legacy-billing-migration` also does not grant cluster-scoped access to ClusterRoles.

**Admission and Pod Security** (verified from files, see `1-effective_privilege.md` Section 1). `disallow-privileged` checks only Deployments and its binding uses Audit, so it does not reject a matching request. PSA `enforce: baseline` is set in namespaces including `platform` and `prod`; `media-processing`, `kube-system`, and `kube-addons-old` have no PSA labels. The export contains no admission rule that restricts `serviceAccountName`; hostPath must still be assessed against the namespace's PSA setting.

**Not analyzed.** The image source (registry and pull policy), `6-audit_trail.md`, and bootstrap bindings (`system:` groups, absent from the export).

## 2. Summary

| ID | Starting subject | Enabling permission [E] | Becomes | Reach | Status |
|---|---|---|---|---|---|
| E1 | `build/ci-runner` | Pod create in `platform` | `platform/controller-admin`, then the rights granted by `platform-controller-admin` | ClusterRole `cluster-superuser`, cluster-wide wildcard rules | Conditional, behavior-derived |
| E2 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/billing-reconciler` | Legacy `billing-secrets` read; Job create in `prod` | Behavior-derived (1 [K] step) |
| E3 | `prod/deploy-bot` | Deployment create/update in `prod` | `prod/orders-api-sa` | `prod` ConfigMaps and Secrets read | Behavior-derived (1 [K] step) |
| E4 | `prod/billing-reconciler` | `create` on Jobs in `prod` | Pod created from a Job template selecting `prod/orders-api-sa` | `orders-api-config`: read/watch Secrets and ConfigMaps in `prod` | Conditional, behavior-derived |
| E5 | `media-processing/mediaproce-svc-01`, `-02`, `-03` | Pod update/patch in `media-processing` | A Pod created from the `transcoder` Deployment template, if present | `media-worker` identity and the template's declared privileged context | Conditional on Pod existence, accepted image update, and successful pull |
| E6 | `maya.chen` | `impersonate` on ServiceAccounts through RoleBinding `maya-billing-migrator` → Role `billing-migrator` R2 | `reconcile-job` and `legacybill-svc-01` through `legacybill-svc-07` in `legacy-billing-migration` | Per-target grants enumerated below; `reconcile-job` has none, others have namespace-scoped grants, none has Secret access | Behavior-derived (2 [K] scope steps) |
| N1 | `prod/deploy-bot` | `migration-operator` has role creation/delegation verbs but only `get,list` on RoleBindings | No added grant | Cannot create or modify a RoleBinding; namespaced scope only | Dead end |

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

### E5. The media-processing ServiceAccounts can conditionally run a replacement image in a Pod from the `transcoder` template

**Step 1 [E]: exact Pod-update grant.** RoleBindings `mediaproce-svc-01-mediaproce-role-01`, `mediaproce-svc-02-mediaproce-role-01`, and `mediaproce-svc-03-mediaproce-role-01` in namespace `media-processing` bind those ServiceAccounts to Role `mediaproce-role-01`. Its R1 grants `update,patch` on core Pods in `media-processing` (`rolebindings.yaml`; `roles.yaml`).

**Step 2 [E]: exported Deployment template, not a live Pod.** The `transcoder` Deployment template in `workloads/media-processing/deployments.yaml` selects `media-worker` and enables token automount (lines 16–17). The template's container is `privileged: true`, adds `SYS_ADMIN`, uses host networking, and mounts host path `/` read-write at `/host` (lines 22–33). ServiceAccount `media-worker` exists in `media-processing` (`serviceaccounts.yaml`). The export does not prove that a Pod currently exists.

**Step 3 [K]: conditional creation and direct Pod image update.** If the Deployment controller has created a Pod from this template, one of the authorized ServiceAccounts can submit a direct update/patch to that Pod's mutable container `image` field. This is a Pod update, not a Deployment-template update; Kubernetes does not copy a later Deployment change into an already-running Pod. If the direct Pod update is accepted and its node can pull the replacement image, the kubelet starts that image in the Pod. The exported `disallow-privileged` policy targets Deployments, not direct Pod updates, and its binding is Audit-only; namespace `media-processing` has no PSA labels (`admission/`; `podsecurity-labels.yaml`). The export records neither an existing Pod nor an image update or pull.

**Step 4 [K]: conditional inherited context.** A Pod created from the exported template uses `media-processing/media-worker` and the listed Pod settings. If the direct patch changes only the image field, that same Pod keeps its ServiceAccount identity, token-automount setting, privileged setting, `SYS_ADMIN`, host networking, and read-write hostPath mount. Those are template-derived consequences, not facts about a live Pod or an observed patch.

**Result.** The export establishes Pod update/patch rights and a Deployment template. Under the stated conditions—controller-created Pod, accepted direct Pod image update, and successful image pull—the replacement image runs in that Pod as `media-processing/media-worker` with the template-derived privileged and hostPath settings. The export does not establish that any of these runtime steps occurred, nor the node placement or effect on other workloads.

---

### E6. `maya.chen` can conditionally impersonate ServiceAccounts in `legacy-billing-migration`

**Step 1 [E]: starting identity and enabling grant.** RoleBinding `maya-billing-migrator` in `legacy-billing-migration` binds User `maya.chen` to Role `billing-migrator`. Its R2 includes `impersonate` on core ServiceAccounts (`roles.yaml`, Role `billing-migrator`). For this edge, the authorized target set is limited to ServiceAccounts in `legacy-billing-migration`. R1 additionally grants core Pod and ConfigMap `get,list` in the namespace.

**Step 2 [K]: conditional namespace-scoped impersonation.** If this exported RoleBinding is effective, Kubernetes permits `maya.chen` to make API requests with a ServiceAccount identity in `legacy-billing-migration`, the binding's namespace. The grant does not cover ServiceAccounts in other namespaces and does not give Maya their bearer tokens. This is the standard API impersonation behavior derived from the namespaced grant; no live impersonation was performed.

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

**Step 4 [E]: no exported cluster-scoped grant.** The export has no ClusterRoleBinding for `maya.chen`; her only RoleBinding in this namespace is `maya-billing-migrator` (`clusterrolebindings.yaml`; `rolebindings.yaml`).

**Step 5 [K]: scope boundary.** The Role also lists user and group impersonation resources, but those targets require cluster-scoped authorization. This namespaced RoleBinding cannot grant that scope, and the export contains no ClusterRoleBinding for `maya.chen`. Therefore users and groups are not reachable targets; only the eight ServiceAccounts listed above are in scope.

**Result.** The behavior-derived edge is limited to conditional API requests as the seven `legacybill-svc-*` identities or `reconcile-job`, all in `legacy-billing-migration`. The export does not establish a live impersonation request or provide ServiceAccount tokens. No listed target has Secret permissions in the export.

---

## 4. Dead ends (checked and cleared)

### N1. `prod/deploy-bot` through `migration-operator`

RoleBinding `legacy-migration-admin` in `legacy-billing-migration` binds `prod/deploy-bot` to namespaced Role `migration-operator`.

- Role `migration-operator`, bound to `prod/deploy-bot` by `legacy-migration-admin` in `legacy-billing-migration`, grants only `get,list` on `roles,rolebindings` and grants `create,bind,escalate` on `roles,clusterroles` (`rolebindings.yaml`; `roles.yaml`). The decisive blocker is that `get,list` do not include `create`, `update`, or `patch` on `rolebindings`; the subject cannot add or change a binding to attach a Role to itself or another subject.
- Because `legacy-migration-admin` is a namespaced RoleBinding, its `clusterroles` rule does not grant cluster-scoped access to ClusterRole objects. `escalate` may allow creating an elevated namespaced Role, but without RoleBinding write permission that Role remains unattached and grants no new subject access.

**Result.** `bind` and `escalate` do not make `deploy-bot` an administrator here. The export shows only RoleBinding reads, so the subject cannot attach a Role; the namespaced binding also cannot provide cluster-scoped ClusterRole authority. This is a dead end, not a current namespace takeover or cluster-wide reach.

## 5. Evidence boundary

This assessment is derived from the supplied export; no Kubernetes cluster or API server is in scope. [E] steps are directly reproducible from the cited YAML objects. [K] steps describe the Kubernetes behavior that connects those permissions and objects into an identity transition; they are not represented as executed requests or observed live state. Runtime facts absent from the export—such as node placement, image pull success, or whether a particular patch was applied—are not asserted. In particular, E5 establishes the configured privileged execution context but not which other workloads share its node.
