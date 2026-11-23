# Trellis Software: workload foothold

## 1. Scope and assumption

**Foothold.** Arbitrary code execution inside container `app` of Deployment `transcoder` in namespace `media-processing`. The task sets this as the starting point. How the attacker gets it is out of scope.

**Source.** `workloads/media-processing/deployments.yaml`, first document, lines 1 to 34.

**Tags.**
- **[E]** Export-established. The step is shown by a specific object or line in the export.
- **[K]** Kubernetes-behavior. The step depends on how the API, the kubelet, or the network plugin behaves. The export does not show it. It must be confirmed on a live cluster.

**Determination scope.** Every RBAC conclusion in this file is a determination over the exported objects: 117 RoleBindings, 11 ClusterRoleBindings, 62 Roles, 5 ClusterRoles. It is not a determination over a live cluster, whose bootstrap bindings are outside the export. Section 3 states this boundary precisely.

**Not analyzed.** `6-audit_trail.md`. The live cluster. `admission/` and `podsecurity-labels.yaml` were read in `1-effective_privilege.md` and are cited here by result.

## 2. The identity inside the pod

**Step 1 [E]: the pod names its ServiceAccount.** Line 16 sets `serviceAccountName: media-worker` in the pod spec of `transcoder`. The pod runs as `system:serviceaccount:media-processing:media-worker`.

**Step 2 [E]: the token is requested explicitly.** Line 17 sets `automountServiceAccountToken: true` in the pod spec. The pod-level value applies, so the result does not depend on any default.

**Step 3 [E]: the ServiceAccount object has no token setting.** `serviceaccounts.yaml` lines 70 to 71 define `media-worker` in `media-processing` with only a name and namespace. No `automountServiceAccountToken` field appears at the object level.

**Step 4 [E]: the identity is referenced only here.** `grep -rn "media-worker" .` returns two lines: the ServiceAccount definition (`serviceaccounts.yaml:70`) and the pod reference (`workloads/media-processing/deployments.yaml:16`).

**Step 5 [K]: the projected token is present in the container.** With automount enabled, the kubelet mounts a projected token for `media-worker` into the container, by default at `/var/run/secrets/kubernetes.io/serviceaccount`. Confirm with `kubectl get pod -n media-processing -l app=transcoder -o yaml`.

**Not the foothold.** Deployment `mediaproce-app-1` in the same file runs as `mediaproce-svc-02` (line 51). It is a different identity.

## 3. Effective Kubernetes privilege of `media-worker`

**Determination over the export.** The effective API permission set of `media-processing/media-worker` is empty. This is derived as follows.

**Derivation.** Kubernetes RBAC is additive. The effective set is the union of rules reached through every binding that names the subject, directly or through a group. The derivation searches each of the three ways a subject can be named.

1. **Direct subject [E].** `yq '.subjects[]?.name' rolebindings.yaml clusterrolebindings.yaml | sort | uniq -c` lists the name of every subject in all 128 bindings. `media-worker` is not among them. Matching is by name, and no name is shared across namespaces in this export, so the match is unambiguous. (Verified: `grep -rn "media-worker" .` returns no binding.)
2. **Group subject [E].** `grep -c "kind: Group"` returns 0 in both binding files. No group subject exists in the export, so no group path reaches the identity.
3. **Implicit group subject [E].** Kubernetes adds implicit groups to every ServiceAccount's identity, including `system:serviceaccounts` and `system:serviceaccounts:media-processing`. A binding to either would grant `media-worker`. `grep -rn "system:" rolebindings.yaml clusterrolebindings.yaml roles.yaml clusterroles.yaml` returns no match, so no binding in the export names an implicit group.

**Rules reached.** Because no binding in the export reaches the identity, the set of rules reached is empty. Consequently the API groups, resources, verbs, and restrictions granted to `media-worker` are all empty. The export records no `resourceNames` or `nonResourceURLs` anywhere, so no restriction applies. Roles and ClusterRoles that exist but are not bound to this identity (for example `secret-reader-cluster`, unbound) contribute nothing.

**Scope boundary [K].** The determination is over the exported objects. A live cluster can contain bindings absent from the export, for example bootstrap bindings that a cluster installs by default. Any such binding that names `system:serviceaccounts` or `system:serviceaccounts:media-processing` would grant rules to `media-worker`. That can change the result. Section 7 gives the check that closes this boundary on a live cluster.

**Neighbouring identities do not transfer.** The `media-processing` bindings name `mediaproce-svc-01` to `-04`. The cluster-wide `view` binding `mediaproce-svc-02-view-114` names `mediaproce-svc-02`. None of these applies to `media-worker`.

## 4. Node-level settings

These are in the Deployment spec. They are not RBAC. They give the container reach that the ServiceAccount does not have.

| Setting | Line | Effect [E] |
|---|---|---|
| `securityContext.privileged: true` | 22 | All host devices accessible to the container |
| `capabilities.add: [SYS_ADMIN]` | 23 to 25 | Mount and namespace administration |
| `runAsNonRoot: false` | 26 | Container may run as root |
| `volumeMounts` `hostfs` at `/host` | 27 to 29 | Mounted into the container |
| `hostNetwork: true` | 30 | Pod uses the node's network namespace |
| `hostPath: /` | 32 to 34 | Node root filesystem, read-write (no `readOnly`) |

**Admission [E].** `disallow-privileged` is bound with `validationActions: [Audit]`. It checks only `privileged` on Deployments, and in Audit mode it blocks nothing.

**Pod Security [E].** `media-processing` has `labels: {}` in `podsecurity-labels.yaml`. No enforcement applies.

**Placement [E].** `grep -rn "nodeName\|nodeSelector\|affinity\|tolerations" workloads/` returns nothing. No manifest pins a workload to a node. Placement is decided by the scheduler [K].

**What this enables [K].** A privileged container with the node's root filesystem can read files the kubelet keeps on that node, including projected ServiceAccount tokens of other pods scheduled there. Whether such pods share the node is not in the export.

## 5. Reach, step by step

### R1. Through the pod's own token (API reach): none in the export

1. [E] Start: the projected token of `media-processing/media-worker` (Section 2).
2. [E] Action: any API request with it, such as listing pods or reading ConfigMaps.
3. [E] Authorization: no binding in the export names the identity (Section 3).
4. [E] Result: every request is denied by the export's RBAC. A live cluster is checked under Section 7.

### R2. Through the node's filesystem (co-located identities): conditional

1. [E] Start: code execution in container `app`.
2. [E] Action: read or write under `/host`, the node's root filesystem (Section 4).
3. [K] Intermediate: the kubelet stores projected ServiceAccount tokens for pods on the node under the node's root filesystem.
4. [unknown] Intermediate: which pods share the node. The export has no node assignment and no placement constraint. Placement must be checked live.
5. [E, conditional on step 4] If `platform-controller` shares the node, its token is readable. That token belongs to `platform/controller-admin` (`workloads/platform/daemonsets.yaml`, lines 16 and 17), which holds `cluster-superuser` through ClusterRoleBinding `platform-controller-admin` (`1-effective_privilege.md`, E1). Reach would then be cluster-wide.
6. [E, conditional on step 4] For any other co-located pod, reach is the privileges of that pod's identity, listed in `1-effective_privilege.md` Section 4, and no more.
7. [E] Result: node-level reach is established by configuration. Cluster-wide reach is conditional on steps 3 and 4 and is not established by the export.

### R3. Through the host network: conditional

1. [E] Start: code execution in container `app`.
2. [E] Action: connect to addresses in the node's network namespace (`hostNetwork: true`, line 30).
3. [K] Intermediate: services listening on the node, including the kubelet API, become reachable. Which ports are open and how the kubelet authenticates requests come from node configuration, which the export does not contain.
4. [K] Result: reach depends on settings not in the export. No specific access is claimed.

### R4. Through the pod network (NetworkPolicy): evaluated

**Policies in the export [E].** `networkpolicies.yaml` contains exactly two NetworkPolicies:
- `orders-api-ingress` in `prod`: selects `app: orders-api`, `policyTypes: [Ingress]`, allows ingress only from pods labelled `app: billing-worker` in `prod`.
- `payments-api-isolation` in `payments`: selects `app: payments-api`, `policyTypes: [Ingress, Egress]`, with empty `ingress` and `egress` lists, which denies all traffic.

**No policy in `media-processing` [E].** `grep -n "namespace"` shows policies only in `prod` and `payments`. No policy selects `transcoder` (`app: transcoder`), and no policy governs its egress.

**Consequences for the foothold.**
- **Egress from `transcoder` [E + K].** No policy restricts it. By standard NetworkPolicy semantics, a pod with no selecting policy accepts and originates all traffic.
- **Reach to `orders-api` in `prod` [E + K].** Blocked for pod-network traffic. `orders-api-ingress` allows only `app: billing-worker` pods in `prod`. `transcoder` is in `media-processing` with `app: transcoder`, so it is not an allowed source.
- **Reach to `payments-api` in `payments` [E + K].** Blocked for pod-network traffic. `payments-api-isolation` denies all ingress to `app: payments-api`.
- **Host-network caveat [K].** `transcoder` runs with `hostNetwork: true`, so its traffic originates from the node's address, not a pod IP. A `podSelector` rule does not match node-address traffic. Whether such traffic is restricted depends on the network plugin. The export does not establish it.

**Result.** Pod-network reach from `transcoder` to `orders-api` and `payments-api` is blocked by the manifests. Reach to every other pod is not restricted by any policy in the export.

## 6. Namespace boundary evaluation

The namespace name is not treated as a security boundary.

| Boundary | Evaluated | Holds against this pod | Evidence |
|---|---|---|---|
| RoleBinding scope | Yes | Holds: no RoleBinding names `media-worker` | Section 3 [E] |
| ClusterRoleBinding | Yes | Holds: no ClusterRoleBinding names `media-worker` | Section 3 [E] |
| Cross-namespace RBAC | Yes | Holds: no binding in any namespace grants it anything | Section 3 [E] |
| Admission | Yes | Does not hold: Audit mode, Deployments only | Section 4 [E] |
| Pod Security | Yes | Does not hold: `media-processing` has no labels | Section 4 [E] |
| Node isolation | Yes | Does not hold: privileged, `SYS_ADMIN`, host network, host root | Section 4 [E] |
| NetworkPolicy, ingress to `prod/orders-api` and `payments/payments-api` | Yes | Holds for pod-network traffic | Section 5, R4 [E + K] |
| NetworkPolicy, egress from `transcoder` and ingress to other pods | Yes | Does not hold: no policy applies | Section 5, R4 [E] |

**Conclusion.** The namespace is a boundary for RBAC only, and only because this identity holds no RBAC in the export. It is not a boundary for admission, Pod Security, or node isolation. Network isolation applies to two named targets and nowhere else.

## 7. Verification needed to close the scope boundary

| Check | Command | Resolves |
|---|---|---|
| Effective permissions on the live cluster, including implicit groups and bootstrap bindings | `kubectl auth can-i --list --as=system:serviceaccount:media-processing:media-worker` | Section 3. Closes the scope boundary. |
| Live bindings naming the identity or its implicit groups | `kubectl get clusterrolebindings,rolebindings -A -o yaml \| grep -n "media-worker\|system:serviceaccounts"` | Section 3, live |
| Projected token in the running pod | `kubectl get pod -n media-processing -l app=transcoder -o yaml` | Section 2, Step 5 |
| Node placement | `kubectl get pods -A -o wide` | R2 steps 4 to 6 |
| Node kubelet exposure | Review kubelet authentication and read-only port settings on the node | R3 |
| NetworkPolicy with host-network pods | Confirm the CNI plugin's behavior, then test from `transcoder` with `kubectl exec` to `orders-api` and `payments-api` | R4 host-network caveat |
| Admission mode live | `kubectl get validatingadmissionpolicybinding disallow-privileged-binding -o yaml` | Section 6 |
| Namespace enforcement live | `kubectl get ns media-processing --show-labels` | Section 6 |

These checks need a caller with impersonation rights. Without them, the commands return `forbidden` and prove nothing.
