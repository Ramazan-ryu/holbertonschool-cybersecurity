# Effective privilege by subject

## How to read this inventory

Every listed grant comes from a binding in `0-rbac_map.md`. The effective permission set is the union of every binding touching the subject. For each binding, the object name and exact Role or ClusterRole rule IDs are cited; those rules spell out API groups, resources, and verbs in the map. “No exported RBAC binding” means no grant from these exported RBAC objects, not a claim about admission or non-RBAC controls. All namespaces are represented, including `kube-system`, `media-processing`, `legacy-billing-migration`, and `kube-addons-old`.

## Namespace `default`

- **ServiceAccount `default/default-svc-01`:** `RoleBinding default-svc-01-default-role-04` (default) → Role `default-role-04` in `default` [R1]; `RoleBinding default-svc-01-default-role-01` (default) → Role `default-role-01` in `default` [R1].
- **ServiceAccount `default/default-svc-02`:** `RoleBinding default-svc-02-default-role-05` (default) → Role `default-role-05` in `default` [R1, R2].
- **ServiceAccount `default/default-svc-03`:** `RoleBinding default-svc-03-default-role-02` (default) → Role `default-role-02` in `default` [R1, R2].
- **ServiceAccount `default/default-svc-04`:** `RoleBinding default-svc-04-default-role-04` (default) → Role `default-role-04` in `default` [R1].
- **ServiceAccount `default/default-svc-05`:** `RoleBinding default-svc-05-default-role-04` (default) → Role `default-role-04` in `default` [R1].
- **ServiceAccount `default/default-svc-06`:** `RoleBinding default-svc-06-default-role-03` (default) → Role `default-role-03` in `default` [R1].

## Namespace `kube-system`

- **ServiceAccount `kube-system/kubesystem-svc-01`:** `RoleBinding kubesystem-svc-01-kubesystem-role-03` (kube-system) → Role `kubesystem-role-03` in `kube-system` [R1].
- **ServiceAccount `kube-system/kubesystem-svc-02`:** `RoleBinding kubesystem-svc-02-kubesystem-role-02` (kube-system) → Role `kubesystem-role-02` in `kube-system` [R1, R2]; `RoleBinding kubesystem-svc-02-kubesystem-role-03` (kube-system) → Role `kubesystem-role-03` in `kube-system` [R1].
- **ServiceAccount `kube-system/kubesystem-svc-03`:** `RoleBinding kubesystem-svc-03-kubesystem-role-02` (kube-system) → Role `kubesystem-role-02` in `kube-system` [R1, R2]; `RoleBinding kubesystem-svc-03-kubesystem-role-03` (kube-system) → Role `kubesystem-role-03` in `kube-system` [R1].
- **ServiceAccount `kube-system/kubesystem-svc-04`:** `RoleBinding kubesystem-svc-04-kubesystem-role-02` (kube-system) → Role `kubesystem-role-02` in `kube-system` [R1, R2]; `ClusterRoleBinding kubesystem-svc-04-view-363` (cluster-wide) → ClusterRole `view` (cluster-scoped) [R1, R2].
- **ServiceAccount `kube-system/kubesystem-svc-05`:** `RoleBinding kubesystem-svc-05-kubesystem-role-01` (kube-system) → Role `kubesystem-role-01` in `kube-system` [R1]; `RoleBinding kubesystem-svc-05-kubesystem-role-02` (kube-system) → Role `kubesystem-role-02` in `kube-system` [R1, R2].
- **ServiceAccount `kube-system/kubesystem-svc-06`:** `RoleBinding kubesystem-svc-06-kubesystem-role-02` (kube-system) → Role `kubesystem-role-02` in `kube-system` [R1, R2]; `RoleBinding kubesystem-svc-06-kubesystem-role-03` (kube-system) → Role `kubesystem-role-03` in `kube-system` [R1].
- **ServiceAccount `kube-system/kubesystem-svc-07`:** `RoleBinding kubesystem-svc-07-kubesystem-role-03` (kube-system) → Role `kubesystem-role-03` in `kube-system` [R1].

## Namespace `prod`

- **ServiceAccount `prod/deploy-bot`:** `RoleBinding deploy-bot-deployer` (prod) → Role `deployer` in `prod` [R1, R2]; `RoleBinding legacy-migration-admin` (legacy-billing-migration) → Role `migration-operator` in `legacy-billing-migration` [R1, R2]; `ClusterRoleBinding deploy-bot-cm-read` (cluster-wide) → ClusterRole `configmap-reader` (cluster-scoped) [R1].
- **ServiceAccount `prod/billing-reconciler`:** `RoleBinding billing-reconciler-prod` (prod) → Role `reconciler` in `prod` [R1, R2]; `RoleBinding billing-reconciler-secrets` (legacy-billing-migration) → Role `billing-secrets` in `legacy-billing-migration` [R1, R2].
- **ServiceAccount `prod/orders-api-sa`:** `RoleBinding orders-api-config` (prod) → Role `orders-api-config` in `prod` [R1].
- **ServiceAccount `prod/prod-svc-01`:** `RoleBinding prod-svc-01-prod-role-01` (prod) → Role `prod-role-01` in `prod` [R1]; `ClusterRoleBinding prod-svc-01-view-677` (cluster-wide) → ClusterRole `view` (cluster-scoped) [R1, R2]; `ClusterRoleBinding prod-svc-01-view-509` (cluster-wide) → ClusterRole `view` (cluster-scoped) [R1, R2].
- **ServiceAccount `prod/prod-svc-02`:** `RoleBinding prod-svc-02-prod-role-03` (prod) → Role `prod-role-03` in `prod` [R1]; `RoleBinding prod-svc-02-prod-role-01` (prod) → Role `prod-role-01` in `prod` [R1].
- **ServiceAccount `prod/prod-svc-03`:** `RoleBinding prod-svc-03-prod-role-02` (prod) → Role `prod-role-02` in `prod` [R1, R2]; `RoleBinding prod-svc-03-prod-role-01` (prod) → Role `prod-role-01` in `prod` [R1].
- **ServiceAccount `prod/prod-svc-04`:** `RoleBinding prod-svc-04-prod-role-03` (prod) → Role `prod-role-03` in `prod` [R1]; `RoleBinding prod-svc-04-prod-role-04` (prod) → Role `prod-role-04` in `prod` [R1, R2].

## Namespace `build`

- **ServiceAccount `build/ci-runner`:** `RoleBinding ci-runner-build` (build) → Role `ci-build` in `build` [R1, R2, R3]; `RoleBinding ci-runner-platform-deploy` (platform) → Role `platform-deployer` in `platform` [R1, R2]; `RoleBinding ci-runner-legacy-secrets` (legacy-billing-migration) → Role `billing-secrets` in `legacy-billing-migration` [R1, R2]; `ClusterRoleBinding ci-runner-nodes` (cluster-wide) → ClusterRole `node-reader` (cluster-scoped) [R1].
- **ServiceAccount `build/build-cache`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.
- **ServiceAccount `build/build-svc-01`:** `RoleBinding build-svc-01-build-role-02` (build) → Role `build-role-02` in `build` [R1, R2]; `RoleBinding build-svc-01-build-role-03` (build) → Role `build-role-03` in `build` [R1, R2].
- **ServiceAccount `build/build-svc-02`:** `RoleBinding build-svc-02-build-role-05` (build) → Role `build-role-05` in `build` [R1].
- **ServiceAccount `build/build-svc-03`:** `RoleBinding build-svc-03-build-role-03` (build) → Role `build-role-03` in `build` [R1, R2].
- **ServiceAccount `build/build-svc-04`:** `RoleBinding build-svc-04-build-role-01` (build) → Role `build-role-01` in `build` [R1]; `ClusterRoleBinding build-svc-04-view-139` (cluster-wide) → ClusterRole `view` (cluster-scoped) [R1, R2].
- **ServiceAccount `build/build-svc-05`:** `RoleBinding build-svc-05-build-role-01` (build) → Role `build-role-01` in `build` [R1]; `RoleBinding build-svc-05-build-role-03` (build) → Role `build-role-03` in `build` [R1, R2]; `ClusterRoleBinding build-svc-05-view-692` (cluster-wide) → ClusterRole `view` (cluster-scoped) [R1, R2].
- **ServiceAccount `build/build-svc-06`:** `RoleBinding build-svc-06-build-role-03` (build) → Role `build-role-03` in `build` [R1, R2].

## Namespace `platform`

- **ServiceAccount `platform/controller-admin`:** `ClusterRoleBinding platform-controller-admin` (cluster-wide) → ClusterRole `cluster-superuser` (cluster-scoped) [R1].
- **ServiceAccount `platform/platform-agent`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.
- **ServiceAccount `platform/platform-svc-01`:** `RoleBinding platform-svc-01-platform-role-02` (platform) → Role `platform-role-02` in `platform` [R1]; `RoleBinding platform-svc-01-platform-role-03` (platform) → Role `platform-role-03` in `platform` [R1].
- **ServiceAccount `platform/platform-svc-02`:** `RoleBinding platform-svc-02-platform-role-03` (platform) → Role `platform-role-03` in `platform` [R1]; `RoleBinding platform-svc-02-platform-role-01` (platform) → Role `platform-role-01` in `platform` [R1].
- **ServiceAccount `platform/platform-svc-03`:** `RoleBinding platform-svc-03-platform-role-02` (platform) → Role `platform-role-02` in `platform` [R1].
- **ServiceAccount `platform/platform-svc-04`:** `RoleBinding platform-svc-04-platform-role-02` (platform) → Role `platform-role-02` in `platform` [R1].
- **ServiceAccount `platform/platform-svc-05`:** `RoleBinding platform-svc-05-platform-role-01` (platform) → Role `platform-role-01` in `platform` [R1]; `RoleBinding platform-svc-05-platform-role-03` (platform) → Role `platform-role-03` in `platform` [R1].
- **ServiceAccount `platform/platform-svc-06`:** `RoleBinding platform-svc-06-platform-role-02` (platform) → Role `platform-role-02` in `platform` [R1].
- **ServiceAccount `platform/platform-svc-07`:** `RoleBinding platform-svc-07-platform-role-02` (platform) → Role `platform-role-02` in `platform` [R1]; `RoleBinding platform-svc-07-platform-role-01` (platform) → Role `platform-role-01` in `platform` [R1].

## Namespace `dev`

- **ServiceAccount `dev/dev-svc-01`:** `RoleBinding dev-svc-01-dev-role-04` (dev) → Role `dev-role-04` in `dev` [R1].
- **ServiceAccount `dev/dev-svc-02`:** `RoleBinding dev-svc-02-dev-role-02` (dev) → Role `dev-role-02` in `dev` [R1, R2].
- **ServiceAccount `dev/dev-svc-03`:** `RoleBinding dev-svc-03-dev-role-04` (dev) → Role `dev-role-04` in `dev` [R1].
- **ServiceAccount `dev/dev-svc-04`:** `RoleBinding dev-svc-04-dev-role-04` (dev) → Role `dev-role-04` in `dev` [R1]; `RoleBinding dev-svc-04-dev-role-02` (dev) → Role `dev-role-02` in `dev` [R1, R2].

## Namespace `staging`

- **ServiceAccount `staging/staging-svc-01`:** `RoleBinding staging-svc-01-staging-role-04` (staging) → Role `staging-role-04` in `staging` [R1, R2]; `ClusterRoleBinding staging-svc-01-view-163` (cluster-wide) → ClusterRole `view` (cluster-scoped) [R1, R2].
- **ServiceAccount `staging/staging-svc-02`:** `RoleBinding staging-svc-02-staging-role-04` (staging) → Role `staging-role-04` in `staging` [R1, R2].
- **ServiceAccount `staging/staging-svc-03`:** `RoleBinding staging-svc-03-staging-role-02` (staging) → Role `staging-role-02` in `staging` [R1, R2]; `RoleBinding staging-svc-03-staging-role-04` (staging) → Role `staging-role-04` in `staging` [R1, R2].
- **ServiceAccount `staging/staging-svc-04`:** `RoleBinding staging-svc-04-staging-role-04` (staging) → Role `staging-role-04` in `staging` [R1, R2]; `RoleBinding staging-svc-04-staging-role-02` (staging) → Role `staging-role-02` in `staging` [R1, R2].
- **ServiceAccount `staging/staging-svc-05`:** `RoleBinding staging-svc-05-staging-role-04` (staging) → Role `staging-role-04` in `staging` [R1, R2]; `RoleBinding staging-svc-05-staging-role-03` (staging) → Role `staging-role-03` in `staging` [R1, R2].

## Namespace `analytics`

- **ServiceAccount `analytics/analytics-worker`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.
- **ServiceAccount `analytics/analytics-svc-01`:** `RoleBinding analytics-svc-01-analytics-role-02` (analytics) → Role `analytics-role-02` in `analytics` [R1, R2].
- **ServiceAccount `analytics/analytics-svc-02`:** `RoleBinding analytics-svc-02-analytics-role-03` (analytics) → Role `analytics-role-03` in `analytics` [R1, R2].
- **ServiceAccount `analytics/analytics-svc-03`:** `RoleBinding analytics-svc-03-analytics-role-02` (analytics) → Role `analytics-role-02` in `analytics` [R1, R2].
- **ServiceAccount `analytics/analytics-svc-04`:** `RoleBinding analytics-svc-04-analytics-role-01` (analytics) → Role `analytics-role-01` in `analytics` [R1, R2]; `RoleBinding analytics-svc-04-analytics-role-02` (analytics) → Role `analytics-role-02` in `analytics` [R1, R2].
- **ServiceAccount `analytics/analytics-svc-05`:** `RoleBinding analytics-svc-05-analytics-role-02` (analytics) → Role `analytics-role-02` in `analytics` [R1, R2]; `RoleBinding analytics-svc-05-analytics-role-03` (analytics) → Role `analytics-role-03` in `analytics` [R1, R2].
- **ServiceAccount `analytics/analytics-svc-06`:** `RoleBinding analytics-svc-06-analytics-role-02` (analytics) → Role `analytics-role-02` in `analytics` [R1, R2]; `RoleBinding analytics-svc-06-analytics-role-03` (analytics) → Role `analytics-role-03` in `analytics` [R1, R2].

## Namespace `payments`

- **ServiceAccount `payments/payments-gateway-sa`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.
- **ServiceAccount `payments/ledger-sa`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.
- **ServiceAccount `payments/payments-svc-01`:** `RoleBinding payments-svc-01-payments-role-01` (payments) → Role `payments-role-01` in `payments` [R1, R2]; `RoleBinding payments-svc-01-payments-role-02` (payments) → Role `payments-role-02` in `payments` [R1, R2].
- **ServiceAccount `payments/payments-svc-02`:** `RoleBinding payments-svc-02-payments-role-01` (payments) → Role `payments-role-01` in `payments` [R1, R2].
- **ServiceAccount `payments/payments-svc-03`:** `RoleBinding payments-svc-03-payments-role-03` (payments) → Role `payments-role-03` in `payments` [R1, R2].
- **ServiceAccount `payments/payments-svc-04`:** `RoleBinding payments-svc-04-payments-role-02` (payments) → Role `payments-role-02` in `payments` [R1, R2]; `RoleBinding payments-svc-04-payments-role-01` (payments) → Role `payments-role-01` in `payments` [R1, R2].
- **ServiceAccount `payments/payments-svc-05`:** `RoleBinding payments-svc-05-payments-role-03` (payments) → Role `payments-role-03` in `payments` [R1, R2]; `RoleBinding payments-svc-05-payments-role-01` (payments) → Role `payments-role-01` in `payments` [R1, R2].

## Namespace `media-processing`

- **ServiceAccount `media-processing/media-worker`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.
- **ServiceAccount `media-processing/mediaproce-svc-01`:** `RoleBinding mediaproce-svc-01-mediaproce-role-01` (media-processing) → Role `mediaproce-role-01` in `media-processing` [R1, R2]; `RoleBinding mediaproce-svc-01-mediaproce-role-03` (media-processing) → Role `mediaproce-role-03` in `media-processing` [R1, R2].
- **ServiceAccount `media-processing/mediaproce-svc-02`:** `RoleBinding mediaproce-svc-02-mediaproce-role-01` (media-processing) → Role `mediaproce-role-01` in `media-processing` [R1, R2]; `RoleBinding mediaproce-svc-02-mediaproce-role-03` (media-processing) → Role `mediaproce-role-03` in `media-processing` [R1, R2]; `ClusterRoleBinding mediaproce-svc-02-view-114` (cluster-wide) → ClusterRole `view` (cluster-scoped) [R1, R2].
- **ServiceAccount `media-processing/mediaproce-svc-03`:** `RoleBinding mediaproce-svc-03-mediaproce-role-01` (media-processing) → Role `mediaproce-role-01` in `media-processing` [R1, R2].
- **ServiceAccount `media-processing/mediaproce-svc-04`:** `RoleBinding mediaproce-svc-04-mediaproce-role-02` (media-processing) → Role `mediaproce-role-02` in `media-processing` [R1, R2].

## Namespace `monitoring`

- **ServiceAccount `monitoring/metrics-agent`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.
- **ServiceAccount `monitoring/monitoring-svc-01`:** `RoleBinding monitoring-svc-01-monitoring-role-03` (monitoring) → Role `monitoring-role-03` in `monitoring` [R1].
- **ServiceAccount `monitoring/monitoring-svc-02`:** `RoleBinding monitoring-svc-02-monitoring-role-05` (monitoring) → Role `monitoring-role-05` in `monitoring` [R1, R2].
- **ServiceAccount `monitoring/monitoring-svc-03`:** `RoleBinding monitoring-svc-03-monitoring-role-04` (monitoring) → Role `monitoring-role-04` in `monitoring` [R1]; `RoleBinding monitoring-svc-03-monitoring-role-01` (monitoring) → Role `monitoring-role-01` in `monitoring` [R1, R2].
- **ServiceAccount `monitoring/monitoring-svc-04`:** `RoleBinding monitoring-svc-04-monitoring-role-02` (monitoring) → Role `monitoring-role-02` in `monitoring` [R1]; `ClusterRoleBinding monitoring-svc-04-view-620` (cluster-wide) → ClusterRole `view` (cluster-scoped) [R1, R2].
- **ServiceAccount `monitoring/monitoring-svc-05`:** `RoleBinding monitoring-svc-05-monitoring-role-04` (monitoring) → Role `monitoring-role-04` in `monitoring` [R1].
- **ServiceAccount `monitoring/monitoring-svc-06`:** `RoleBinding monitoring-svc-06-monitoring-role-03` (monitoring) → Role `monitoring-role-03` in `monitoring` [R1].
- **ServiceAccount `monitoring/monitoring-svc-07`:** `RoleBinding monitoring-svc-07-monitoring-role-05` (monitoring) → Role `monitoring-role-05` in `monitoring` [R1, R2].

## Namespace `data`

- **ServiceAccount `data/data-svc-01`:** `RoleBinding data-svc-01-data-role-04` (data) → Role `data-role-04` in `data` [R1]; `RoleBinding data-svc-01-data-role-01` (data) → Role `data-role-01` in `data` [R1, R2].
- **ServiceAccount `data/data-svc-02`:** `RoleBinding data-svc-02-data-role-01` (data) → Role `data-role-01` in `data` [R1, R2].
- **ServiceAccount `data/data-svc-03`:** `RoleBinding data-svc-03-data-role-05` (data) → Role `data-role-05` in `data` [R1, R2]; `RoleBinding data-svc-03-data-role-01` (data) → Role `data-role-01` in `data` [R1, R2].
- **ServiceAccount `data/data-svc-04`:** `RoleBinding data-svc-04-data-role-03` (data) → Role `data-role-03` in `data` [R1]; `RoleBinding data-svc-04-data-role-05` (data) → Role `data-role-05` in `data` [R1, R2].

## Namespace `legacy-billing-migration`

- **ServiceAccount `legacy-billing-migration/reconcile-job`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.
- **ServiceAccount `legacy-billing-migration/legacybill-svc-01`:** `RoleBinding legacybill-svc-01-legacybill-role-01` (legacy-billing-migration) → Role `legacybill-role-01` in `legacy-billing-migration` [R1, R2]; `RoleBinding legacybill-svc-01-legacybill-role-02` (legacy-billing-migration) → Role `legacybill-role-02` in `legacy-billing-migration` [R1].
- **ServiceAccount `legacy-billing-migration/legacybill-svc-02`:** `RoleBinding legacybill-svc-02-legacybill-role-03` (legacy-billing-migration) → Role `legacybill-role-03` in `legacy-billing-migration` [R1, R2].
- **ServiceAccount `legacy-billing-migration/legacybill-svc-03`:** `RoleBinding legacybill-svc-03-legacybill-role-01` (legacy-billing-migration) → Role `legacybill-role-01` in `legacy-billing-migration` [R1, R2]; `RoleBinding legacybill-svc-03-legacybill-role-03` (legacy-billing-migration) → Role `legacybill-role-03` in `legacy-billing-migration` [R1, R2].
- **ServiceAccount `legacy-billing-migration/legacybill-svc-04`:** `RoleBinding legacybill-svc-04-legacybill-role-02` (legacy-billing-migration) → Role `legacybill-role-02` in `legacy-billing-migration` [R1].
- **ServiceAccount `legacy-billing-migration/legacybill-svc-05`:** `RoleBinding legacybill-svc-05-legacybill-role-02` (legacy-billing-migration) → Role `legacybill-role-02` in `legacy-billing-migration` [R1].
- **ServiceAccount `legacy-billing-migration/legacybill-svc-06`:** `RoleBinding legacybill-svc-06-legacybill-role-03` (legacy-billing-migration) → Role `legacybill-role-03` in `legacy-billing-migration` [R1, R2]; `RoleBinding legacybill-svc-06-legacybill-role-01` (legacy-billing-migration) → Role `legacybill-role-01` in `legacy-billing-migration` [R1, R2].
- **ServiceAccount `legacy-billing-migration/legacybill-svc-07`:** `RoleBinding legacybill-svc-07-legacybill-role-03` (legacy-billing-migration) → Role `legacybill-role-03` in `legacy-billing-migration` [R1, R2].

## Namespace `kube-addons-old`

- **ServiceAccount `kube-addons-old/addons-legacy`:** no exported RBAC binding; no permissions are granted by the Role/ClusterRole bindings in this export.

## Human User subjects

- **User `maya.chen`:** `RoleBinding maya-dev-editor` in `dev` → Role `dev-editor` in `dev` [R1, R2]; `RoleBinding maya-billing-migrator` in `legacy-billing-migration` → Role `billing-migrator` in `legacy-billing-migration` [R1, R2].
- **User `sam.okafor`:** `RoleBinding sam-metrics-viewer` in `monitoring` → Role `metrics-viewer` in `monitoring` [R1]; `RoleBinding sam-legacy-view` in `legacy-billing-migration` → ClusterRole `view` (cluster-scoped) [R1, R2].

## Named identities with cross-scope or broad grants

- **`prod/deploy-bot`:** its prod `deployer` grant and cluster-wide ConfigMap reader are additive to its legacy migration Role grant. It can read/list ConfigMaps cluster-wide (`deploy-bot-cm-read` → ClusterRole `configmap-reader` R1); in `prod` it can manage Deployments/ReplicaSets (R1) and read/list Pods/ConfigMaps (R2); in `legacy-billing-migration` it gets the migration-operator rules via `legacy-migration-admin`. That namespaced Role lists `clusterroles` with `create`/`bind`/`escalate`, but these do not authorize cluster-scoped requests through a RoleBinding. The `roles` rules and verbs must be read in the RoleBinding scope; no create rolebindings rule is present.

- **`build/ci-runner`:** four distinct bindings contribute. `ci-runner-build` grants ConfigMap read/list/watch, Pod get/list/create, Job get/list in `build`; `ci-runner-platform-deploy` grants Pod get/list/watch/create and ConfigMap/ServiceAccount get/list in `platform`; `ci-runner-legacy-secrets` grants Secret and ConfigMap get/list in `legacy-billing-migration`; `ci-runner-nodes` grants Node get/list cluster-wide. These scopes are independent and are not collapsed into the CI runner’s home namespace.

- **`platform/controller-admin`:** `platform-controller-admin` binds ClusterRole `cluster-superuser` R1; `*` API groups, resources, and verbs cluster-wide.

- **`prod/billing-reconciler`:** `billing-reconciler-prod` grants ConfigMap get/list/watch and Job get/list/create in `prod`; `billing-reconciler-secrets` grants Secret and ConfigMap get/list in `legacy-billing-migration`.

- **`maya.chen`:** `maya-dev-editor` grants CRUD-like access to Pods, ConfigMaps, Services, and Deployments in `dev`; `maya-billing-migrator` grants Pod/ConfigMap get/list in `legacy-billing-migration` and contains an impersonate rule for ServiceAccounts, Users, and Groups. Because it is a namespaced RoleBinding, only impersonation of ServiceAccounts within that namespace is established; it does not establish cluster-wide User/Group impersonation.

- **`sam.okafor`:** `sam-metrics-viewer` grants read/watch on Pods, Services, Endpoints in `monitoring`; `sam-legacy-view` grants ClusterRole `view` rules only in `legacy-billing-migration`.

- **Sound determination:** `prod/orders-api-sa` is bound only by `orders-api-config` to `Role orders-api-config` in `prod`, whose sole rule is get/list/watch on ConfigMaps and Secrets. The `orders-api` Deployment mounts this identity. No other exported binding touches this ServiceAccount, so its grant is exactly that narrow read-only application configuration access.
