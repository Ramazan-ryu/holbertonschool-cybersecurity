# Trellis Software: controls in the exported state

## 1. Summary

| Control | Defined | Enforced in the export | What it protects today | Prevention value |
|---|---|---|---|---|
| Pod Security Standards (namespace labels) | Yes: 11 of 14 namespaces labelled `enforce: baseline` | Enforcement needs the PodSecurity admission plugin on the API server, which the export does not show | Labelled namespaces, against privileged pods, host namespaces, hostPath, and added capabilities | Conditional. Zero for `media-processing`, `kube-system`, and `kube-addons-old`, which carry no enforce label. |
| ValidatingAdmissionPolicy `disallow-privileged` | Yes | No. Its only binding sets `validationActions: [Audit]` | Nothing. Violations are recorded, not rejected. | Zero. |
| NetworkPolicy | Two objects in the export | Enforcement needs a CNI plugin that implements NetworkPolicy, which the export does not show | Ingress to the `orders-api` pods in `prod` is restricted to pods labelled `app: billing-worker`. Nothing else is restricted. `payments-api-isolation` selects no workload. | Narrow. Every other pod is non-isolated. |

## 2. Method and tags

- **[E]** Export-established. The step is shown by a specific object or line in the export.
- **[K]** Kubernetes or CNI behavior. The export does not show it. It must be confirmed on a live cluster.
- **[V]** Verification pending. The conclusion depends on a command in Section 7.

**Sources.** `podsecurity-labels.yaml`, `admission/policies.yaml`, `admission/bindings.yaml`, `networkpolicies.yaml`, `workloads/*`. Binding and Role data come from `0-rbac_map.md` and `1-effective_privilege.md`.

**Scope of "absent from the export."** Where this file says a mechanism is absent, it means the exported state contains no object of that kind. It does not establish that the live cluster lacks it. Section 4.2 lists each mechanism checked and the result.

## 3. Control 1: Pod Security Standards

### 3.1 Label inventory [E]

| Namespace | Label in `podsecurity-labels.yaml` | Level applied to pods |
|---|---|---|
| default | enforce baseline, warn restricted | baseline |
| prod | enforce baseline, warn restricted | baseline |
| build | enforce baseline, warn restricted | baseline |
| platform | enforce baseline, warn restricted | baseline |
| dev | enforce baseline, warn restricted | baseline |
| staging | enforce baseline, warn restricted | baseline |
| analytics | enforce baseline, warn restricted | baseline |
| payments | enforce baseline, warn restricted | baseline |
| monitoring | enforce baseline, warn restricted | baseline |
| data | enforce baseline, warn restricted | baseline |
| legacy-billing-migration | enforce baseline, warn restricted | baseline |
| kube-system | `labels: {}` | no enforce label (see 3.3) |
| media-processing | `labels: {}` | no enforce label (see 3.2) |
| kube-addons-old | `labels: {}` | no enforce label (see 3.3) |

Eleven namespaces are labelled. Three are not.

**What `warn: restricted` does.** It returns a warning to the client on a violating request and does not block it [K]. It is a signal, not a control.

### 3.2 The exempt namespace: `media-processing` [E]

**Mechanism.** The exemption comes from the missing label, not from an exemption list. Pod Security Admission reads a namespace's `pod-security.kubernetes.io/enforce` label. With no label, the namespace uses the cluster-wide default. The Kubernetes default is `privileged`, which imposes no restriction [K]. The export contains no AdmissionConfiguration that changes that default (Section 4.2), so the unlabelled namespace is unrestricted unless a live cluster sets a different default.

**Workload that uses it.** Deployment `transcoder` (`workloads/media-processing/deployments.yaml`, lines 1 to 34). Its container sets `privileged: true` (line 22), adds `SYS_ADMIN` (lines 23 to 25), sets `runAsNonRoot: false` (line 26), and mounts host path `/` read-write at `/host` (lines 27 to 34). The pod sets `hostNetwork: true` (line 30).

**What `baseline` would forbid for that pod [K, from the Pod Security Standards definition].**

| Setting in `transcoder` | Line | Baseline | Restricted |
|---|---|---|---|
| `privileged: true` | 22 | Forbidden | Forbidden |
| `capabilities.add: [SYS_ADMIN]` | 23 to 25 | Forbidden (outside the default set) | Forbidden |
| `hostNetwork: true` | 30 | Forbidden | Forbidden |
| `hostPath` volume `/` | 32 to 34 | Forbidden | Forbidden |
| `runAsNonRoot: false` | 26 | Not restricted | Forbidden |

Under an enforced baseline level, the pod would be rejected when its ReplicaSet tries to create it. Under the exemption, it runs.

**Neighbouring workloads [E].** A grep over `workloads/` for `privileged`, `hostPath`, and `hostNetwork` returns matches only in `media-processing`. The baseline-labelled namespaces contain none of these settings. This shows that the labelled namespaces are compliant in the export, not that the standard is enforced.

**Same namespace, different posture [E].** Deployment `mediaproce-app-1` in the same unlabelled namespace sets `allowPrivilegeEscalation: false` (lines 51 to 54). The exemption covers the whole namespace, including workloads that would comply.

**What the exemption permits, compared with protected workloads.**
- A pod in a labelled namespace such as `prod` cannot be privileged, cannot mount the host filesystem, and cannot use the host network namespace.
- The `transcoder` pod can do all three. These node-level capabilities are the difference between the two groups, and Section 4 of `3-pod_foothold.md` uses them for reach.

### 3.3 `kube-system` and `kube-addons-old` [E]

Both are unlabelled. `kube-system` holds only ServiceAccounts, Roles, and workloads. Its lack of a label is common practice in many clusters, so it is not a finding by itself. `kube-addons-old` holds one ServiceAccount, `addons-legacy`, with no RoleBinding and no workload in the export. It is an uncovered namespace with no running workload in this export.

### 3.4 Enforcement status [K + V]

A namespace label is configuration data. It takes effect only when the kube-apiserver runs the PodSecurity admission plugin, which is on by default in current Kubernetes [K]. The export does not include the apiserver configuration. Enforcement for the eleven labelled namespaces is therefore conditional on the plugin. Section 7 contains the test that settles it.

## 4. Control 2: ValidatingAdmissionPolicy `disallow-privileged`

### 4.1 Defined [E]

`admission/policies.yaml`, verbatim in its load-bearing parts:

```yaml
kind: ValidatingAdmissionPolicy
metadata:
  name: disallow-privileged
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [apps]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [deployments]
  validations:
  - expression: '!object.spec.template.spec.containers.exists(c, has(c.securityContext)
      && has(c.securityContext.privileged) && c.securityContext.privileged)'
    message: privileged containers are not permitted
```

### 4.2 Bound, in Audit mode [E]

`admission/bindings.yaml`:

```yaml
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-privileged-binding
spec:
  policyName: disallow-privileged
  validationActions:
  - Audit
  matchResources: {}
```

`yq '.spec.validationActions' admission/bindings.yaml` returns `- Audit`.

**Admission inventory: what the export contains.**

| Mechanism | Present in export | Configured action | Effect on a violating request |
|---|---|---|---|
| ValidatingAdmissionPolicy `disallow-privileged` | Yes (`admission/policies.yaml`) | n/a | Expression evaluated |
| ValidatingAdmissionPolicyBinding `disallow-privileged-binding` | Yes (`admission/bindings.yaml`) | `Audit` only | Violation recorded in the audit annotation. Request admitted. |
| Any binding with `Deny` or `Warn` | No | n/a | None |
| ValidatingWebhookConfiguration | No. `grep -rln "WebhookConfiguration\|MutatingAdmissionPolicy\|AdmissionConfiguration" .` returns no file | n/a | None [E] |
| MutatingWebhookConfiguration | No (same grep) | n/a | None [E] |
| MutatingAdmissionPolicy | No (same grep) | n/a | None [E] |
| PodSecurity enforce labels | Yes, 11 namespaces (Section 3) | `enforce: baseline` | Pod rejected at creation, if the plugin is on [K] |
| AdmissionConfiguration (plugin list, PSA defaults) | No (same grep) | n/a | Cluster defaults apply [K] |

In Kubernetes, `Audit` writes an audit annotation to the audit log. `Deny` rejects the request. `Warn` returns a warning to the client. The `failurePolicy` field decides what happens when the policy itself cannot be evaluated. It does not change the result of an evaluation that completes [K]. So `failurePolicy: Fail` has no effect on a violation that the policy correctly detects in Audit mode.

### 4.3 What happens to a violating workload [E + K]

For a Deployment with `privileged: true` in any namespace:

1. The API server evaluates the expression. It returns false.
2. The binding's only action is `Audit`. No `Deny` action exists in the export, so the request is not rejected.
3. The Deployment is admitted and stored.
4. An audit annotation is written, if the apiserver's audit policy records it [K]. The export contains no apiserver audit policy file (Section 8).
5. The ReplicaSet controller creates pods from the template. Whether a pod is then rejected depends on Pod Security Admission in that namespace, not on this policy.

For `transcoder` in `media-processing`, step 5 is not blocked: the namespace has no enforce label, so PodSecurity does not reject the pod. The pod runs. This is the state the export describes.

For a Deployment in a labelled namespace such as `prod`, the Deployment object is admitted, but PodSecurity rejects the pod at creation (step 5). The Deployment shows no running pods, and the rejection appears in the ReplicaSet's events [K]. The VAP does not block it.

### 4.4 Scope gaps, even if the action were changed to `Deny` [E]

- **Only Deployments are matched.** `resources: [deployments]`. A privileged pod created directly, or a privileged Job, CronJob, DaemonSet, or StatefulSet, is not matched. The Job path matters: `billing-reconciler` can create Jobs in `prod` (`0-rbac_map.md`, Role `reconciler` R2).
- **Only `containers` is checked.** The expression reads `spec.template.spec.containers`. It does not read `initContainers` or `ephemeralContainers`. A privileged init container passes. **No manifest in the export uses either field:** `grep -rn "initContainers\|ephemeralContainers" workloads/ admission/` returns nothing. So this is a gap in the policy, not a current workload exposure.
- **Only `privileged` is checked.** `hostPath`, `hostNetwork`, `SYS_ADMIN`, and `runAsNonRoot: false` are not checked. A Deployment with `hostNetwork: true` and a hostPath, but no privileged container, passes.

Changing the action to `Deny` would therefore block one of the four settings in `transcoder`, not all of them.

### 4.5 Verdict [E]

**The policy prevents zero violating workloads in this export.** It records violations for audit and nothing else. The `transcoder` Deployment is admitted under it. The policy is documentation and audit intent, not preventive protection. Even in Deny mode, Section 4.4 leaves violations unblocked.

## 5. Control 3: NetworkPolicy

### 5.1 Inventory [E]

`networkpolicies.yaml` contains exactly two objects:
- `orders-api-ingress`, namespace `prod`.
- `payments-api-isolation`, namespace `payments`.

No other namespace has a NetworkPolicy in the export, including `media-processing`, `analytics`, `platform`, `kube-system`, `build`, `dev`, `staging`, `monitoring`, `data`, `legacy-billing-migration`, `default`, and `kube-addons-old`.

**Isolation semantics [K].** A pod is isolated for a direction only when a NetworkPolicy that lists that direction in `policyTypes` selects it. A pod that no policy selects is non-isolated in both directions. NetworkPolicy has no effect unless the CNI plugin enforces it.

### 5.2 `prod/orders-api-ingress`: selects a real workload, restricts ingress only [E + K]

- **Namespace:** `prod`.
- **Pod selector:** `app: orders-api`.
- **Policy types:** `Ingress` only. No `Egress` type.
- **Ingress rule:** one `from` entry, a `podSelector` of `app: billing-worker`, with no `namespaceSelector` and no ports. The peer is any pod labelled `app: billing-worker` in `prod`.

**Selection confirmed [E].** `workloads/prod/deployments.yaml` defines the `orders-api` Deployment with `labels: &id001` on its metadata (line 6) and `app: orders-api` (line 7). The pod template at line 14 reads `labels: *id001`, which resolves to `app: orders-api`. So the pods of this Deployment carry the label that the policy selects. The `&id001` anchor is local to each YAML document (each Deployment is separated by `---`), so the anchor name reused in the `billing-worker` Deployment does not conflict.

**Peer not yet confirmed [V].** The `billing-worker` Deployment starts at line 24. Its template labels lie past line 35, which was not printed. The policy allows only pods labelled `app: billing-worker`. If the template does not carry that label, no pod matches the peer, and the policy blocks all ingress to `orders-api`, including from `billing-worker`. Section 7 contains the command that settles this.

**Effect on the `orders-api` pods, if the peer label matches [K].** Ingress is isolated: only `billing-worker` pods in `prod` may connect. Egress is unrestricted in both directions for those pods. Whether the isolation holds depends on CNI enforcement.

**Non-selected workloads in `prod` [E].** No policy selects `deploy-controller` (line 53) or `prod-app-1` (line 76). They are non-isolated in both directions, like the rest of the cluster.

### 5.3 `payments/payments-api-isolation`: selects nothing [E]

- **Namespace:** `payments`.
- **Pod selector:** `app: payments-api`.
- **Policy types:** `Ingress` and `Egress`.
- **Ingress and egress rules:** both empty lists (`ingress: []`, `egress: []`).

**Intended effect.** A policy with both types and empty rule lists denies all ingress and all egress for the pods it selects. It reads as strict isolation.

**Actual effect [E].** `grep -r 'app:' workloads/payments/` returns three labels: `payments-gateway`, `ledger`, and `payments-app-1`. None is `payments-api`. The selector matches no pod in the export. The policy isolates nothing.

**Consequence.** `payments-gateway`, `ledger`, and `payments-app-1` are selected by no NetworkPolicy. They are non-isolated in both directions. Their connectivity is the same as in a namespace with no policy.

This finding is worse than an absent policy. Anyone who reads `payments-api-isolation` will conclude that the payments namespace is isolated.

### 5.4 Non-isolated area: no policy at all [E]

Every namespace without a NetworkPolicy is non-isolated in both directions. This covers `media-processing`, where `transcoder` runs, and every other namespace in 5.1. Pods there accept traffic from any source and send traffic to any destination on the pod network. In `prod`, `deploy-controller` and `prod-app-1` are in the same position.

The difference from 5.3 is that nothing in these namespaces claims isolation. The exposure is visible in the configuration.

### 5.5 Effective connectivity from the `transcoder` foothold [E + K]

For pod-network traffic from a `transcoder` pod in `media-processing`:

| Destination | Ingress restriction on destination | Result |
|---|---|---|
| Pods in `media-processing`, `analytics`, `platform`, `build`, `dev`, `staging`, `monitoring`, `data`, `default`, `kube-system`, `legacy-billing-migration` | None: no policy selects them | Reachable on any port |
| `deploy-controller`, `prod-app-1` in `prod` | None: no policy selects them | Reachable on any port |
| `payments-gateway`, `ledger`, `payments-app-1` in `payments` | None: the policy selects none of them | Reachable on any port |
| `orders-api` pods in `prod` | Ingress isolated: only `billing-worker` pods in `prod` [V: peer labels] | Blocked for `transcoder` [K: CNI enforcement] |
| Any destination, outbound from `transcoder` | No egress policy selects `transcoder` | Unrestricted |

**Host-network caveat [K].** `transcoder` runs with `hostNetwork: true`, so its traffic originates from the node's address. A `podSelector` matches pod addresses. Whether NetworkPolicy applies to host-network traffic depends on the CNI plugin. The export does not show it. Section 7 includes the test. If it does apply, the `orders-api` row holds only for pod-network traffic; a host-network connection from `transcoder` may reach `orders-api` through the node address, depending on the plugin.

**What this means for spread.** Network reach from `transcoder` is broad. Network reach is not access: the connection reaches a service, and that service's own authentication decides the rest. The RBAC of `media-worker` is empty (`3-pod_foothold.md`), so network reach carries no API access by itself. Combined with node-level access (Section 3.2), it lets an attacker reach services on the node and in other namespaces without any policy in the way.

## 6. The two findings, compared

| | Area with no policy (5.4) | Ineffective policy (5.3) |
|---|---|---|
| Example | `media-processing`, `analytics`, `platform`, `prod`'s `deploy-controller`, and the rest | `payments` with `payments-api-isolation` |
| What exists | No NetworkPolicy | A NetworkPolicy declaring full isolation |
| Why it fails | Nothing was written | Its selector matches none of the namespace's workloads |
| Effective ingress and egress for the real pods | Unrestricted | Unrestricted |
| What a reader concludes from the configuration | "This namespace is open" | "This namespace is isolated" (wrong) |
| Failure mode | Missing control, visible | Control that looks present and misleads |

Both leave the affected pods unrestricted in both directions. The second is worse because it hides that fact from anyone who reads the policy set. The `orders-api-ingress` policy in `prod` is a narrow, working control if the peer label is confirmed, and it sits next to unselected `prod` workloads that are unrestricted.

## 7. Verification needed

| Check | Command | Resolves |
|---|---|---|
| Template labels of `billing-worker` (the policy's peer) | `sed -n '36,50p' workloads/prod/deployments.yaml` | 5.2 [V] |
| Live admission bindings, all of them | `kubectl get validatingadmissionpolicybindings -o yaml` and `kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations -o yaml` | 4.2. Confirms no `Deny` or webhook exists live. |
| Live policy binding action | `kubectl get validatingadmissionpolicybinding disallow-privileged-binding -o yaml` | 4.2 |
| PodSecurity behavior, labelled namespace | `kubectl apply --dry-run=server -f privileged-pod.yaml -n prod`, expect rejection | 3.4 |
| PodSecurity behavior, unlabelled namespace | `kubectl apply --dry-run=server -f privileged-pod.yaml -n media-processing`, expect admission | 3.2 |
| Cluster default PodSecurity level | `kubectl get --raw /api/v1/namespaces/media-processing` (labels), and the apiserver `--admission-control-config-file` setting, if readable | 3.2 default |
| Violating Deployment admitted | `kubectl apply --dry-run=server -f privileged-deployment.yaml -n media-processing`, expect the Deployment object to be accepted | 4.3 |
| Audit logging captures violations | Review apiserver audit policy and log destination | 4.3 step 4 |
| CNI enforces NetworkPolicy | `kubectl get pods -n kube-system` and identify the CNI (for example Calico or Cilium); check whether it enforces policy | 5.1 and every network conclusion |
| Enforcement of `orders-api-ingress` in practice | From a `billing-worker` pod, and from a `deploy-controller` pod, `kubectl exec` a connection to an `orders-api` pod | 5.2 effect |
| Host-network traffic under NetworkPolicy | From `transcoder`, `kubectl exec` to an `orders-api` pod and to a `payments-gateway` pod | 5.5 caveat |

These checks need a caller with impersonation rights. Without them, the commands return `forbidden` and prove nothing.

## 8. Limits

- **Resolved from the export:** no init or ephemeral containers in any manifest (4.4); no webhook, MutatingAdmissionPolicy, or AdmissionConfiguration object in the export (4.2); the `orders-api` pod template carries the selected label (5.2).
- **Still open:** the `billing-worker` template labels (5.2); the live state of all of the above.
- **Not in the export:** `ls -la` of the export root shows no apiserver configuration, no audit policy, and no CNI configuration. Those files would be needed to establish enforcement, and they are outside this export.
- Admission and network conclusions combine [E] for configuration with [K] for behavior. Where a conclusion depends on [K] or [V], it is conditional until Section 7 is run.
- `6-audit_trail.md` was not used.
