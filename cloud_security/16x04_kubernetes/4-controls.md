# Trellis Software — controls in the exported state

## 1. Pod Security Standards: baseline enforce, with an unlabeled exception

The namespace inventory labels 11 of 14 namespaces `pod-security.kubernetes.io/enforce: baseline` and warns at `restricted`. `kube-system`, `media-processing`, and `kube-addons-old` have empty labels. The materially risky exception is `media-processing`: its `transcoder` Deployment is permitted to run privileged, add `SYS_ADMIN`, run as root, use host networking, and mount host path `/` at `/host`. Those settings would be disallowed by the baseline standard Trellis applies to neighboring labeled namespaces. `kube-addons-old` has an unbound `addons-legacy` ServiceAccount and no workload directory in this export; its lack of labels is still an uncovered namespace, not evidence of a currently running workload.

## 2. ValidatingAdmissionPolicy: defined, but Audit-only

Policy `disallow-privileged` has `failurePolicy: Fail` and validates privileged containers on Deployment CREATE/UPDATE. However, `disallow-privileged-binding` sets `validationActions: [Audit]`. A matching violation is recorded for audit; it is not rejected. The current prevention value is zero for this validation: a privileged Deployment can still be admitted. The policy's `failurePolicy` does not turn an Audit action into a denial.

## 3. NetworkPolicy: one narrow ingress restriction, one selector no-op, broad gaps

- `prod/orders-api-ingress` selects `app: orders-api` and permits ingress only from Pods labeled `app: billing-worker` in the same namespace. It is an ingress control for that workload if the cluster network implementation enforces NetworkPolicy. It declares no egress policy, so it does not restrict the selected Pods' egress.
- `payments/payments-api-isolation` declares empty ingress and egress rule lists and selects `app: payments-api`. No exported payments Deployment has that label: they are `payments-gateway`, `ledger`, and `payments-app-1`. The selector therefore matches none of these workloads, and the policy currently isolates none of them.
- There are only these two NetworkPolicies in the complete export. Every other namespace, including `media-processing`, `analytics`, `platform`, and the old namespaces, has no exported NetworkPolicy. NetworkPolicy is not a cluster-wide default; absent a selecting policy, this export supplies no network segmentation for those Pods.

The three mechanisms have different failure modes: a Pod Security namespace-label gap, a policy whose action is audit rather than denial, and incomplete/mis-targeted network policies. None should be described simply as “the cluster is protected.”
