# Trellis Software — workload foothold

## Foothold selected: `media-processing/transcoder`

The Deployment `transcoder` in `workloads/media-processing/deployments.yaml` sets `serviceAccountName: media-worker` and `automountServiceAccountToken: true`. The `media-worker` ServiceAccount exists in `serviceaccounts.yaml`. An exhaustive search of all 117 RoleBindings and 11 ClusterRoleBindings finds no binding whose subject is `media-processing/media-worker`; consequently this mounted token has no permissions granted by the exported RBAC bindings. The other media-processing identities do not transfer their grants to this ServiceAccount. In particular, the cluster-wide `view` ClusterRoleBinding `mediaproce-svc-02-view-114` names `mediaproce-svc-02`, not `media-worker`.

## What the workload is permitted to be

This Deployment is in `media-processing`, whose namespace has no Pod Security enforce/warn labels in `namespaces.yaml` / `podsecurity-labels.yaml`. Its container is configured `privileged: true`, adds `SYS_ADMIN`, permits root (`runAsNonRoot: false`), and mounts host path `/` at `/host`; the Pod also uses `hostNetwork: true`. The exported `disallow-privileged` ValidatingAdmissionPolicy is not presently a deny control because its binding has `validationActions: [Audit]` (`admission/bindings.yaml`). These settings describe the permitted foothold even though the ServiceAccount's RBAC is empty.

The mounted identity alone grants no Kubernetes API permissions in the provided RBAC state. The host path and privileged settings separately permit access to the node's root filesystem and host networking from this workload. They are the important reach from this foothold. The export does not establish which host credentials or other secrets are present on that filesystem, so no such contents are claimed here.

## Reach and boundary evidence

There is no NetworkPolicy selecting or restricting `transcoder`, and there is no NetworkPolicy at all in `media-processing`. Kubernetes NetworkPolicies only constrain traffic when policies select Pods and a supporting network implementation enforces them; the exported state provides no such policy for this Pod. The two policies elsewhere do not select it: `orders-api-ingress` selects `app: orders-api` in `prod`, while `payments-api-isolation` is in `payments` and selects `app: payments-api`.

The RBAC and workload paths are distinct: the `media-worker` token has no exported grant, while the Pod's host-level configuration is a node foothold. From the export alone, we can conclude it can access the mounted host root and use host networking; we cannot assert that host access automatically yields any specific Kubernetes identity or API permission. The manifest correction proposed in `5-fixed_manifests.yaml` removes the privileged, host network, and host root mount paths.
