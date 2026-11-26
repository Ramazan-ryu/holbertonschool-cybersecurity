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

### 4.1 Build namespace: cluster-wide read through `view`

RoleBinding `ci-runner-build` → Role `ci-build` R2 grants `create` on Pods in `build`. ClusterRoleBindings `build-svc-04-view-139` and `build-svc-05-view-692` bind ServiceAccounts `build-svc-04` and `build-svc-05` to ClusterRole `view`.

A Pod created by `ci-runner` can select either ServiceAccount and set `automountServiceAccountToken: true` in its pod spec. Kubernetes then runs it with the selected identity. The resulting `view` grant is cluster-wide: `get,list,watch` on Pods, Services, Endpoints, ConfigMaps, Deployments, and ReplicaSets. It does not include Secrets. Existing Deployment `build-app-1` selects `build-svc-04` and explicitly enables token automount (`workloads/build/deployments.yaml`, lines 50–66).

### 4.2 Platform namespace: become `controller-admin` and gain cluster-superuser

RoleBinding `ci-runner-platform-deploy` → Role `platform-deployer` R1 grants `create` on Pods in `platform`. ServiceAccount `controller-admin` exists in `platform`; ClusterRoleBinding `platform-controller-admin` binds it to ClusterRole `cluster-superuser`.

A Pod created in `platform` can set `serviceAccountName: controller-admin` and `automountServiceAccountToken: true`. Kubernetes runs the pod under that identity and projects its credential. `cluster-superuser` grants wildcard API groups, resources, and verbs cluster-wide. The existing `platform-controller` Deployment also uses `controller-admin` with token automount enabled (`workloads/platform/daemonsets.yaml`, lines 16–17).

This is the highest-reach path from the foothold: the starting identity's namespaced Pod-create grant becomes code execution as a cluster-wide superuser. The export does not establish control of the worker host or any cloud account; those outcomes are not claimed.

### 4.3 Legacy namespace: direct Secret and ConfigMap reads

RoleBinding `ci-runner-legacy-secrets` binds the cross-namespace subject `build/ci-runner` to Role `billing-secrets` in `legacy-billing-migration`. That Role grants `get,list` on Secrets and ConfigMaps in that namespace. A RoleBinding applies its grant in its own namespace, so the workload need not move out of `build` or assume another ServiceAccount to make an API request in `legacy-billing-migration`.

The export establishes permission to read/list Secret objects in that namespace. It does not include Secret contents or identify which Secret values contain credentials, so no particular credential or downstream access is asserted here.

### 4.4 Cluster-scoped node metadata

ClusterRoleBinding `ci-runner-nodes` binds `build/ci-runner` to ClusterRole `node-reader`, which grants `get,list` on Nodes across the cluster. This exposes node objects and metadata; it does not itself grant node login, host access, or Secret access.

## 5. Network and namespace boundaries

**NetworkPolicy coverage [E].** The export contains two NetworkPolicies, both outside `build`: `orders-api-ingress` in `prod` and `payments-api-isolation` in `payments`. No policy selects the `ci-runner` pod, so the export imposes no NetworkPolicy egress restriction on it. Under NetworkPolicy semantics, a pod not selected by an egress policy is not isolated for egress; enforcement by a particular CNI is not established by these files.

- `orders-api-ingress` selects `app: orders-api` in `prod` and permits ingress only from `app: billing-worker` pods in `prod`. A `build/ci-runner` pod is not an allowed source for pod-network ingress.
- `payments-api-isolation` selects `app: payments-api` and has empty ingress and egress rules, so it denies pod-network traffic to and from those selected pods.
- No NetworkPolicy is exported for the other namespaces. This does not prove application reachability; services, ports, routing, and live CNI behavior are not part of this snapshot.

**Admission and Pod Security [E].** Namespace `build` is labeled `enforce: baseline` in `podsecurity-labels.yaml`; baseline does not prohibit selecting a ServiceAccount or automounting its token. The `disallow-privileged` ValidatingAdmissionPolicy checks privileged Deployments, but its binding uses `validationActions: [Audit]`, which records violations and does not reject them. No exported admission policy blocks the `serviceAccountName` transitions in Sections 4.1 or 4.2.

**Boundary conclusion.** The `build` namespace does not contain the effective permissions: its subject is explicitly bound in `platform` and `legacy-billing-migration`, and also has a ClusterRoleBinding. NetworkPolicy limits only the specific selected targets above; it does not remove Kubernetes API permissions granted by RBAC.

## 6. Evidence limits

This determination covers the supplied offline export: 117 RoleBindings, 11 ClusterRoleBindings, 62 Roles, and 5 ClusterRoles. The foothold assumes code execution in the `ci-runner` container as specified by the task. Token availability follows from the pod template and Kubernetes token-projection behavior; the token itself was not obtained. No live authorization, network path, or CNI enforcement test was performed. Permissions or bindings absent from the export are outside this conclusion.
