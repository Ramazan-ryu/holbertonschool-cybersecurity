# Cluster quiz answers

No separate quiz questions were included with the lab handover. These are the core answers derived from the supplied export:

1. RBAC is additive: effective permissions are the union of every RoleBinding and ClusterRoleBinding that names the subject.
2. A RoleBinding is namespaced. Binding a ClusterRole through a RoleBinding grants that ClusterRole's namespaced permissions only in the binding namespace. A ClusterRoleBinding to a ClusterRole grants cluster-wide.
3. `build/ci-runner` has grants in `build`, `platform`, and `legacy-billing-migration`, plus cluster-wide Node get/list from `ci-runner-nodes`.
4. `platform/controller-admin` is cluster-superuser because ClusterRoleBinding `platform-controller-admin` binds ClusterRole `cluster-superuser` (wildcard API groups, resources, and verbs).
5. The highest-risk path is `build/ci-runner` → create Pod in `platform` and select `controller-admin` → token backed by `platform-controller-admin` → cluster-wide superuser.
6. `media-processing/transcoder` runs with privileged, SYS_ADMIN, hostNetwork, and hostPath `/`; its `media-worker` token has no exported RBAC binding.
7. The privileged admission policy is bound with `Audit`, so it reports but does not deny. The payments policy's `app: payments-api` selector matches none of the exported payments Deployments.
8. The audit signal is ci-runner doing a platform Pod create and controller-admin ServiceAccount lookup outside its repetitive build-namespace activity (audit log lines 826 and 828), before controller-admin lists/gets Secrets (829–830).
