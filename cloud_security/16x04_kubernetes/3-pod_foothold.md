# Trellis Software: workload foothold and reach

## 1. Scope

The assessed foothold is arbitrary code execution in container `app` of Deployment `ci-runner` in namespace `build`. This is the build workload identified by the Task 3 reference path. The analysis is limited to the supplied export; it does not claim live cluster execution.

## 2. Identity and credential in the foothold

**Workload evidence [E].** `workloads/build/deployments.yaml`, Deployment `ci-runner`, sets `metadata.namespace: build`, `spec.template.spec.serviceAccountName: ci-runner`, and `automountServiceAccountToken: true` (lines 1–24; fields at lines 18–19). The matching object in `serviceaccounts.yaml` is ServiceAccount `ci-runner` in namespace `build` (lines 19–23).

**Identity [E].** The workload's configured Kubernetes username is `system:serviceaccount:build:ci-runner`. The pod-level `automountServiceAccountToken: true` explicitly requests a token for this identity; this does not depend on the ServiceAccount object's default.

**Credential availability [K].** Kubernetes projects the selected ServiceAccount token into the container, normally at `/var/run/secrets/kubernetes.io/serviceaccount`. Thus code running in the assumed foothold has the `ci-runner` API credential available. The export establishes the workload template and token-automount setting; it does not contain a running Pod object or the token bytes, and no token was collected.

## 3. Exhaustive RBAC determination for `build/ci-runner`

RBAC permissions are additive. I checked all 117 RoleBindings and 11 ClusterRoleBindings, resolved each binding that names `build/ci-runner` to its referenced Role or ClusterRole, and applied the binding's scope. The exact subject is `kind: ServiceAccount`, name `ci-runner`, namespace `build`.

| Binding | Referenced role and rules | Effective scope and grant |
|---|---|---|
| RoleBinding `ci-runner-build` (`rolebindings.yaml`) | Role `ci-build` (`roles.yaml`): core ConfigMaps `get,list,watch`; core Pods `get,list,create`; Batch Jobs `get,list` | `build` only |
| RoleBinding `ci-runner-platform-deploy` (`rolebindings.yaml`) | Role `platform-deployer` (`roles.yaml`): core Pods `get,list,watch,create`; core ConfigMaps and ServiceAccounts `get,list` | `platform` only, despite subject being in `build` |
| RoleBinding `ci-runner-legacy-secrets` (`rolebindings.yaml`) | Role `billing-secrets` (`roles.yaml`): core Secrets `get,list`; core ConfigMaps `get,list` | `legacy-billing-migration` only |
| ClusterRoleBinding `ci-runner-nodes` (`clusterrolebindings.yaml`) | ClusterRole `node-reader` (`clusterroles.yaml`): core Nodes `get,list` | Cluster-wide |

The exhaustive sweep found exactly three matching RoleBindings among all 117 and exactly one matching ClusterRoleBinding among all 11; these are the four entries above, and each `roleRef` is resolved to its listed rule set. Every other binding has a different subject. The full export contains no Group subjects and no User subject matching the canonical username `system:serviceaccount:build:ci-runner`; it also contains no `system:` group binding. Therefore no other direct, User, or group-derived grant contributes to the union. Unbound Roles and ClusterRoles contribute no permissions.

**Effective union.** The foothold can read/watch ConfigMaps and read/create Pods in `build`; read/list Jobs in `build`; create/read/watch Pods and read ConfigMaps and ServiceAccounts in `platform`; read/list Secrets and ConfigMaps in `legacy-billing-migration`; and read/list Nodes cluster-wide. It has no direct Secret grant in `build` or cluster-wide. The legacy Secret grant is an actual cross-namespace grant, not an inference from the namespace name.

## 4. Identity transitions and cluster reach

### 4.1 Build namespace: cluster-wide read through `view` (full path per target below)

**Exact path to `build-svc-04` [E + K].** The `ci-runner-build` RoleBinding binds the mounted identity `build/ci-runner` to Role `ci-build`; R2 permits `create` on core Pods in `build`. A proposed Pod `ci-runner-view-04` in namespace `build` sets `serviceAccountName: build-svc-04` and `automountServiceAccountToken: true`. If admitted and scheduled, Kubernetes runs it as `system:serviceaccount:build:build-svc-04` and projects that token [K]. ClusterRoleBinding `build-svc-04-view-139` binds this ServiceAccount to ClusterRole `view`, granting cluster-wide `get,list,watch` on Pods, Services, Endpoints, ConfigMaps, Deployments, and ReplicaSets [E]. The proposed Pod is an explanatory example, not an exported or logged object.

**Exact path to `build-svc-05` [E + K].** The same `ci-runner-build` → `ci-build` R2 grant permits Pod creation in `build`. A proposed Pod `ci-runner-view-05` in `build` sets `serviceAccountName: build-svc-05` and `automountServiceAccountToken: true`. If admitted and scheduled, Kubernetes runs it as `system:serviceaccount:build:build-svc-05` and projects that token [K]. ClusterRoleBinding `build-svc-05-view-692` binds it to ClusterRole `view`, granting the same cluster-wide read set [E]. Neither `view` grant includes Secrets. Both examples require a runnable image and successful Pod admission/scheduling; the export does not show them being created.

**Other selectable build identities [E].** The table below closes the in-namespace target set: these are all eight ServiceAccounts in `build`, and every listed binding and role is in `0-rbac_map.md`, Sections 4, 6, and 7.

| Selectable ServiceAccount | Exported binding(s) | Resulting permissions |
|---|---|---|
| `build/ci-runner` | `ci-runner-build` → `ci-build`; plus Section 3 bindings | Same union as Section 3. |
| `build/build-cache` | None | No exported RBAC grant. |
| `build/build-svc-01` | `build-svc-01-build-role-02` → `build-role-02`; `build-svc-01-build-role-03` → `build-role-03` | In `build`: core ConfigMaps, Services, Endpoints, Pods `get,list`; Apps ReplicaSets and StatefulSets `get,list,watch`. |
| `build/build-svc-02` | `build-svc-02-build-role-05` → `build-role-05` | In `build`: core Pods, ConfigMaps, Services `get,list,watch`. |
| `build/build-svc-03` | `build-svc-03-build-role-03` → `build-role-03` | In `build`: core Services, ConfigMaps, Pods `get,list`; Apps StatefulSets, ReplicaSets `get,list,watch`. |
| `build/build-svc-04` | `build-svc-04-build-role-01` → `build-role-01`; `build-svc-04-view-139` → `view` | In `build`: core Endpoints `get,list,watch`; cluster-wide: core Pods, Services, Endpoints, ConfigMaps and Apps Deployments, ReplicaSets `get,list,watch`. |
| `build/build-svc-05` | `build-svc-05-build-role-01` → `build-role-01`; `build-svc-05-build-role-03` → `build-role-03`; `build-svc-05-view-692` → `view` | In `build`: core Endpoints `get,list,watch`; core Services, ConfigMaps, Pods `get,list`; Apps StatefulSets, ReplicaSets `get,list,watch`; plus cluster-wide view rules as for `build-svc-04`. |
| `build/build-svc-06` | `build-svc-06-build-role-03` → `build-role-03` | In `build`: core Services, ConfigMaps, Pods `get,list`; Apps StatefulSets, ReplicaSets `get,list,watch`. |

### 4.2 Platform namespace: become `controller-admin` and gain cluster-superuser

**Exact identity transition [E + K].** `ci-runner-platform-deploy` (RoleBinding namespace `platform`) names `build/ci-runner` and binds it to Role `platform-deployer`; R1 grants `create` on Pods in `platform` [E]. A proposed Pod `ci-runner-platform-admin` in namespace `platform` sets `serviceAccountName: controller-admin` and `automountServiceAccountToken: true`. If the API admits and schedules it, Kubernetes runs it as `system:serviceaccount:platform:controller-admin` and projects that ServiceAccount token [K]. ClusterRoleBinding `platform-controller-admin` binds that exact identity to `cluster-superuser`, whose wildcard rule permits all API groups, resources, and verbs cluster-wide [E]. This example names a proposed object, not one present in the export; it requires an available image and successful Pod admission/scheduling.


### 4.3 Legacy namespace: direct Secret and ConfigMap reads

**Exact direct-access path [E].** The mounted identity remains `system:serviceaccount:build:ci-runner`; no Pod or identity switch is needed. RoleBinding `ci-runner-legacy-secrets` is in `legacy-billing-migration`, names ServiceAccount `build/ci-runner`, and refers to Role `billing-secrets`. That Role grants core `secrets` and `configmaps` `get,list` only in `legacy-billing-migration`. Therefore an API `get` or `list` request for a Secret in that namespace, authenticated with the mounted `ci-runner` token, is authorized by this binding and rule. The export does not reveal Secret values.


### 4.4 Cluster-scoped node metadata

**Exact direct-access path [E].** ClusterRoleBinding `ci-runner-nodes` names ServiceAccount `build/ci-runner` and refers to ClusterRole `node-reader`; its rule grants core Nodes `get,list` cluster-wide. A `get` or `list` Nodes request using the mounted `ci-runner` credential is authorized by this binding. The result is node API metadata only.


## 5. Network and namespace boundaries

**NetworkPolicy coverage [E].** The export contains two NetworkPolicies, both outside `build`: `orders-api-ingress` in `prod` and `payments-api-isolation` in `payments`. No policy selects the `ci-runner` pod. The export therefore contains no egress isolation rule selecting it; actual NetworkPolicy enforcement depends on the CNI, which is not described in the export.

- `orders-api-ingress` selects `app: orders-api` in `prod` and permits ingress only from `app: billing-worker` pods in `prod`. A `build/ci-runner` pod is not an allowed source for pod-network ingress.
- `payments-api-isolation` selects `app: payments-api`, which matches none of the three exported payments pod templates. It selects no exported workload and does not isolate the real payments workloads.
- No NetworkPolicy is exported for the other namespaces. This does not prove application reachability; services, ports, routing, and live CNI behavior are not part of this snapshot.

**Admission and Pod Security [E].** Namespace `build` is labeled `enforce: baseline` in `podsecurity-labels.yaml`; baseline does not prohibit selecting a ServiceAccount or automounting its token. The `disallow-privileged` ValidatingAdmissionPolicy checks privileged Deployments, but its binding uses `validationActions: [Audit]`, which records violations and does not reject them. No exported admission policy blocks the `serviceAccountName` transitions in Sections 4.1 or 4.2.

**Boundary conclusion.** The `build` namespace does not contain the effective permissions: its subject is explicitly bound in `platform` and `legacy-billing-migration`, and also has a ClusterRoleBinding. NetworkPolicy limits only the specific selected targets above; it does not remove Kubernetes API permissions granted by RBAC.

## 6. Evidence limits

This determination covers the supplied offline export: 117 RoleBindings, 11 ClusterRoleBindings, 62 Roles, and 5 ClusterRoles. The foothold assumes code execution in the `ci-runner` container as specified by the task. Token availability follows from the pod template and Kubernetes token-projection behavior; the token itself was not obtained. No live authorization, network path, or CNI enforcement test was performed. Permissions or bindings absent from the export are outside this conclusion.
