# Trellis Software — RBAC map

## Scope and method

This inventory was derived from the exported objects in `latchkey/trellis-cluster-export/`; it covers every Namespace, ServiceAccount, Role, ClusterRole, RoleBinding, and ClusterRoleBinding in the snapshot. It records grants only. Kubernetes RBAC is additive; no deny rules are inferred.

The export contains 14 namespaces, 86 ServiceAccounts, 62 Roles, 5 ClusterRoles, 117 RoleBindings, and 11 ClusterRoleBindings.

A RoleBinding is namespaced. A RoleBinding to a Role grants only in the binding namespace. A RoleBinding to a ClusterRole still grants only in the binding namespace. A ClusterRoleBinding to a ClusterRole grants across the cluster. RoleBindings in this export include subjects from another namespace; the subject namespace identifies the ServiceAccount, while the binding namespace is where its Role grant applies.

## Namespace category coverage

The source of truth is `namespaces.yaml`: it contains exactly 14 Namespace objects. These categories make the broad and sparse areas visible; categories can overlap in meaning.

- **System:** `kube-system`.
- **Active application/workload namespaces:** `default`, `prod`, `build`, `platform`, `dev`, `staging`, `analytics`, `payments`, `media-processing`, `monitoring`, and `data`. Their workload directories and/or namespaced access objects appear in the export.
- **Completed-project/legacy-looking:** `legacy-billing-migration`. It is included in full despite the project-like name; the snapshot still contains `reconcile-cron`, ServiceAccounts, Roles, and RoleBindings there, so it is not treated as empty or retired.
- **Abandoned-looking and sparse test/sandbox-like namespace:** `kube-addons-old`. The export shows empty namespace labels and ServiceAccount `addons-legacy`, but no Role, RoleBinding, or workload file in that namespace. The export does **not** contain a Namespace literally named `test`; no additional namespace or 2022 object is inferred beyond the exported objects.

## Namespaces and ServiceAccounts

- **`default`** — `default-svc-01`, `default-svc-02`, `default-svc-03`, `default-svc-04`, `default-svc-05`, `default-svc-06`.
- **`kube-system`** — `kubesystem-svc-01`, `kubesystem-svc-02`, `kubesystem-svc-03`, `kubesystem-svc-04`, `kubesystem-svc-05`, `kubesystem-svc-06`, `kubesystem-svc-07`.
- **`prod`** — `deploy-bot`, `billing-reconciler`, `orders-api-sa`, `prod-svc-01`, `prod-svc-02`, `prod-svc-03`, `prod-svc-04`.
- **`build`** — `ci-runner`, `build-cache`, `build-svc-01`, `build-svc-02`, `build-svc-03`, `build-svc-04`, `build-svc-05`, `build-svc-06`.
- **`platform`** — `controller-admin`, `platform-agent`, `platform-svc-01`, `platform-svc-02`, `platform-svc-03`, `platform-svc-04`, `platform-svc-05`, `platform-svc-06`, `platform-svc-07`.
- **`dev`** — `dev-svc-01`, `dev-svc-02`, `dev-svc-03`, `dev-svc-04`.
- **`staging`** — `staging-svc-01`, `staging-svc-02`, `staging-svc-03`, `staging-svc-04`, `staging-svc-05`.
- **`analytics`** — `analytics-worker`, `analytics-svc-01`, `analytics-svc-02`, `analytics-svc-03`, `analytics-svc-04`, `analytics-svc-05`, `analytics-svc-06`.
- **`payments`** — `payments-gateway-sa`, `ledger-sa`, `payments-svc-01`, `payments-svc-02`, `payments-svc-03`, `payments-svc-04`, `payments-svc-05`.
- **`media-processing`** — `media-worker`, `mediaproce-svc-01`, `mediaproce-svc-02`, `mediaproce-svc-03`, `mediaproce-svc-04`.
- **`monitoring`** — `metrics-agent`, `monitoring-svc-01`, `monitoring-svc-02`, `monitoring-svc-03`, `monitoring-svc-04`, `monitoring-svc-05`, `monitoring-svc-06`, `monitoring-svc-07`.
- **`data`** — `data-svc-01`, `data-svc-02`, `data-svc-03`, `data-svc-04`.
- **`legacy-billing-migration`** — `reconcile-job`, `legacybill-svc-01`, `legacybill-svc-02`, `legacybill-svc-03`, `legacybill-svc-04`, `legacybill-svc-05`, `legacybill-svc-06`, `legacybill-svc-07`.
- **`kube-addons-old`** — `addons-legacy`.

## Role and ClusterRole rule inventory

Rule IDs below are the 1-based rule order in the named object. They preserve API group, resource, and verb scope from the export.

### Role `deployer` in `prod`
- **R1:** `apiGroups=apps; resources=deployments,replicasets; verbs=get,list,watch,create,update,patch`
- **R2:** `apiGroups=''; resources=pods,configmaps; verbs=get,list`

### Role `migration-operator` in `legacy-billing-migration`
- **R1:** `apiGroups=rbac.authorization.k8s.io; resources=roles,rolebindings; verbs=get,list`
- **R2:** `apiGroups=rbac.authorization.k8s.io; resources=roles,clusterroles; verbs=bind,escalate,create`

### Role `dev-editor` in `dev`
- **R1:** `apiGroups=''; resources=pods,configmaps,services; verbs=get,list,watch,create,update,patch,delete`
- **R2:** `apiGroups=apps; resources=deployments; verbs=get,list,watch,create,update,patch`

### Role `billing-migrator` in `legacy-billing-migration`
- **R1:** `apiGroups=''; resources=pods,configmaps; verbs=get,list`
- **R2:** `apiGroups=''; resources=serviceaccounts,users,groups; verbs=impersonate`

### Role `ci-build` in `build`
- **R1:** `apiGroups=''; resources=configmaps; verbs=get,list,watch`
- **R2:** `apiGroups=''; resources=pods; verbs=get,list,create`
- **R3:** `apiGroups=batch; resources=jobs; verbs=get,list`

### Role `platform-deployer` in `platform`
- **R1:** `apiGroups=''; resources=pods; verbs=get,list,watch,create`
- **R2:** `apiGroups=''; resources=configmaps,serviceaccounts; verbs=get,list`

### Role `metrics-viewer` in `monitoring`
- **R1:** `apiGroups=''; resources=pods,services,endpoints; verbs=get,list,watch`

### Role `reconciler` in `prod`
- **R1:** `apiGroups=''; resources=configmaps; verbs=get,list,watch`
- **R2:** `apiGroups=batch; resources=jobs; verbs=get,list,create`

### Role `billing-secrets` in `legacy-billing-migration`
- **R1:** `apiGroups=''; resources=secrets; verbs=get,list`
- **R2:** `apiGroups=''; resources=configmaps; verbs=get,list`

### Role `orders-api-config` in `prod`
- **R1:** `apiGroups=''; resources=configmaps,secrets; verbs=get,list,watch`

### Role `default-role-01` in `default`
- **R1:** `apiGroups=''; resources=services,configmaps,endpoints; verbs=get,list,watch,update,patch`

### Role `default-role-02` in `default`
- **R1:** `apiGroups=''; resources=endpoints,pods,configmaps; verbs=get,list`
- **R2:** `apiGroups=apps; resources=replicasets,deployments; verbs=get,list,watch`

### Role `default-role-03` in `default`
- **R1:** `apiGroups=''; resources=services,configmaps; verbs=get,list`

### Role `default-role-04` in `default`
- **R1:** `apiGroups=''; resources=pods; verbs=get,list`

### Role `default-role-05` in `default`
- **R1:** `apiGroups=''; resources=configmaps; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=replicasets,statefulsets; verbs=get,list,watch`

### Role `kubesystem-role-01` in `kube-system`
- **R1:** `apiGroups=''; resources=configmaps,services; verbs=get,list,watch,update,patch`

### Role `kubesystem-role-02` in `kube-system`
- **R1:** `apiGroups=''; resources=configmaps,services; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=statefulsets,replicasets; verbs=get,list,watch`

### Role `kubesystem-role-03` in `kube-system`
- **R1:** `apiGroups=''; resources=configmaps,services; verbs=get,list`

### Role `prod-role-01` in `prod`
- **R1:** `apiGroups=''; resources=pods,services; verbs=get,list`

### Role `prod-role-02` in `prod`
- **R1:** `apiGroups=''; resources=pods; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=deployments,replicasets; verbs=get,list,watch`

### Role `prod-role-03` in `prod`
- **R1:** `apiGroups=''; resources=configmaps,pods; verbs=get,list,watch`

### Role `prod-role-04` in `prod`
- **R1:** `apiGroups=''; resources=pods,configmaps; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=replicasets,deployments; verbs=get,list,watch`

### Role `prod-role-05` in `prod`
- **R1:** `apiGroups=''; resources=configmaps,pods,services; verbs=get,list`

### Role `build-role-01` in `build`
- **R1:** `apiGroups=''; resources=endpoints; verbs=get,list,watch`

### Role `build-role-02` in `build`
- **R1:** `apiGroups=''; resources=configmaps,services,endpoints; verbs=get,list`
- **R2:** `apiGroups=apps; resources=replicasets,statefulsets; verbs=get,list,watch`

### Role `build-role-03` in `build`
- **R1:** `apiGroups=''; resources=services,configmaps,pods; verbs=get,list`
- **R2:** `apiGroups=apps; resources=statefulsets,replicasets; verbs=get,list,watch`

### Role `build-role-04` in `build`
- **R1:** `apiGroups=''; resources=endpoints,configmaps; verbs=get,list`
- **R2:** `apiGroups=apps; resources=replicasets,deployments; verbs=get,list,watch`

### Role `build-role-05` in `build`
- **R1:** `apiGroups=''; resources=pods,configmaps,services; verbs=get,list,watch`

### Role `platform-role-01` in `platform`
- **R1:** `apiGroups=''; resources=configmaps; verbs=get,list,watch`

### Role `platform-role-02` in `platform`
- **R1:** `apiGroups=''; resources=services,pods; verbs=get,list,watch`

### Role `platform-role-03` in `platform`
- **R1:** `apiGroups=''; resources=services,pods,configmaps; verbs=get,list`

### Role `dev-role-01` in `dev`
- **R1:** `apiGroups=''; resources=pods; verbs=get,list,watch,update,patch`

### Role `dev-role-02` in `dev`
- **R1:** `apiGroups=''; resources=endpoints,services; verbs=get,list`
- **R2:** `apiGroups=apps; resources=replicasets,statefulsets; verbs=get,list,watch`

### Role `dev-role-03` in `dev`
- **R1:** `apiGroups=''; resources=services,configmaps,endpoints; verbs=get,list`
- **R2:** `apiGroups=apps; resources=deployments,replicasets; verbs=get,list,watch`

### Role `dev-role-04` in `dev`
- **R1:** `apiGroups=''; resources=configmaps,pods; verbs=get,list,watch,update,patch`

### Role `dev-role-05` in `dev`
- **R1:** `apiGroups=''; resources=configmaps,endpoints,pods; verbs=get,list,watch`

### Role `staging-role-01` in `staging`
- **R1:** `apiGroups=''; resources=services; verbs=get,list,watch`

### Role `staging-role-02` in `staging`
- **R1:** `apiGroups=''; resources=configmaps; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=statefulsets,replicasets; verbs=get,list,watch`

### Role `staging-role-03` in `staging`
- **R1:** `apiGroups=''; resources=services; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=deployments,statefulsets; verbs=get,list,watch`

### Role `staging-role-04` in `staging`
- **R1:** `apiGroups=''; resources=endpoints,pods; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=replicasets,deployments; verbs=get,list,watch`

### Role `analytics-role-01` in `analytics`
- **R1:** `apiGroups=''; resources=endpoints; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=deployments,replicasets; verbs=get,list,watch`

### Role `analytics-role-02` in `analytics`
- **R1:** `apiGroups=''; resources=pods; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=deployments,replicasets; verbs=get,list,watch`

### Role `analytics-role-03` in `analytics`
- **R1:** `apiGroups=''; resources=pods,endpoints; verbs=get,list`
- **R2:** `apiGroups=apps; resources=statefulsets,replicasets; verbs=get,list,watch`

### Role `payments-role-01` in `payments`
- **R1:** `apiGroups=''; resources=endpoints,services; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=deployments,replicasets; verbs=get,list,watch`

### Role `payments-role-02` in `payments`
- **R1:** `apiGroups=''; resources=endpoints,services; verbs=get,list`
- **R2:** `apiGroups=apps; resources=statefulsets,replicasets; verbs=get,list,watch`

### Role `payments-role-03` in `payments`
- **R1:** `apiGroups=''; resources=configmaps,endpoints; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=statefulsets,deployments; verbs=get,list,watch`

### Role `mediaproce-role-01` in `media-processing`
- **R1:** `apiGroups=''; resources=configmaps,pods,endpoints; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=statefulsets,replicasets; verbs=get,list,watch`

### Role `mediaproce-role-02` in `media-processing`
- **R1:** `apiGroups=''; resources=endpoints,configmaps,services; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=replicasets,deployments; verbs=get,list,watch`

### Role `mediaproce-role-03` in `media-processing`
- **R1:** `apiGroups=''; resources=services; verbs=get,list`
- **R2:** `apiGroups=apps; resources=replicasets,deployments; verbs=get,list,watch`

### Role `monitoring-role-01` in `monitoring`
- **R1:** `apiGroups=''; resources=services,configmaps,pods; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=deployments,replicasets; verbs=get,list,watch`

### Role `monitoring-role-02` in `monitoring`
- **R1:** `apiGroups=''; resources=configmaps,endpoints; verbs=get,list`

### Role `monitoring-role-03` in `monitoring`
- **R1:** `apiGroups=''; resources=configmaps,pods,services; verbs=get,list,watch,update,patch`

### Role `monitoring-role-04` in `monitoring`
- **R1:** `apiGroups=''; resources=configmaps,services,pods; verbs=get,list`

### Role `monitoring-role-05` in `monitoring`
- **R1:** `apiGroups=''; resources=endpoints,configmaps,pods; verbs=get,list`
- **R2:** `apiGroups=apps; resources=replicasets,deployments; verbs=get,list,watch`

### Role `data-role-01` in `data`
- **R1:** `apiGroups=''; resources=pods,configmaps; verbs=get,list`
- **R2:** `apiGroups=apps; resources=statefulsets,replicasets; verbs=get,list,watch`

### Role `data-role-02` in `data`
- **R1:** `apiGroups=''; resources=services,pods; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=statefulsets,replicasets; verbs=get,list,watch`

### Role `data-role-03` in `data`
- **R1:** `apiGroups=''; resources=services,endpoints,configmaps; verbs=get,list`

### Role `data-role-04` in `data`
- **R1:** `apiGroups=''; resources=endpoints; verbs=get,list`

### Role `data-role-05` in `data`
- **R1:** `apiGroups=''; resources=configmaps,pods; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=statefulsets,deployments; verbs=get,list,watch`

### Role `legacybill-role-01` in `legacy-billing-migration`
- **R1:** `apiGroups=''; resources=pods; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=replicasets,deployments; verbs=get,list,watch`

### Role `legacybill-role-02` in `legacy-billing-migration`
- **R1:** `apiGroups=''; resources=pods,configmaps,services; verbs=get,list`

### Role `legacybill-role-03` in `legacy-billing-migration`
- **R1:** `apiGroups=''; resources=configmaps,services; verbs=get,list,watch,update,patch`
- **R2:** `apiGroups=apps; resources=deployments,statefulsets; verbs=get,list,watch`

### ClusterRole `view` (cluster-scoped)
- **R1:** `apiGroups=''; resources=pods,services,endpoints,configmaps; verbs=get,list,watch`
- **R2:** `apiGroups=apps; resources=deployments,replicasets; verbs=get,list,watch`

### ClusterRole `configmap-reader` (cluster-scoped)
- **R1:** `apiGroups=''; resources=configmaps; verbs=get,list`

### ClusterRole `node-reader` (cluster-scoped)
- **R1:** `apiGroups=''; resources=nodes; verbs=get,list`

### ClusterRole `cluster-superuser` (cluster-scoped)
- **R1:** `apiGroups='*'; resources='*'; verbs='*'`

### ClusterRole `secret-reader-cluster` (cluster-scoped)
- **R1:** `apiGroups=''; resources=secrets; verbs=get,list`

## Binding inventory

All 128 exported bindings are listed individually below. Each row contains the binding object, binding scope, every subject (including ServiceAccount namespace), the roleRef kind/name, the role object namespace when applicable, and explicit reference-resolution status. “RESOLVED” means the referenced Role or ClusterRole exists in the export.

- **RoleBinding `deploy-bot-deployer`** at namespace `prod`: ServiceAccount `deploy-bot` in `prod` → Role `deployer` in `prod` — **RESOLVED**.
- **RoleBinding `legacy-migration-admin`** at namespace `legacy-billing-migration`: ServiceAccount `deploy-bot` in `prod` → Role `migration-operator` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `maya-dev-editor`** at namespace `dev`: User `maya.chen` → Role `dev-editor` in `dev` — **RESOLVED**.
- **RoleBinding `maya-billing-migrator`** at namespace `legacy-billing-migration`: User `maya.chen` → Role `billing-migrator` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `ci-runner-build`** at namespace `build`: ServiceAccount `ci-runner` in `build` → Role `ci-build` in `build` — **RESOLVED**.
- **RoleBinding `ci-runner-platform-deploy`** at namespace `platform`: ServiceAccount `ci-runner` in `build` → Role `platform-deployer` in `platform` — **RESOLVED**.
- **RoleBinding `ci-runner-legacy-secrets`** at namespace `legacy-billing-migration`: ServiceAccount `ci-runner` in `build` → Role `billing-secrets` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `sam-metrics-viewer`** at namespace `monitoring`: User `sam.okafor` → Role `metrics-viewer` in `monitoring` — **RESOLVED**.
- **RoleBinding `sam-legacy-view`** at namespace `legacy-billing-migration`: User `sam.okafor` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.
- **RoleBinding `billing-reconciler-prod`** at namespace `prod`: ServiceAccount `billing-reconciler` in `prod` → Role `reconciler` in `prod` — **RESOLVED**.
- **RoleBinding `billing-reconciler-secrets`** at namespace `legacy-billing-migration`: ServiceAccount `billing-reconciler` in `prod` → Role `billing-secrets` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `orders-api-config`** at namespace `prod`: ServiceAccount `orders-api-sa` in `prod` → Role `orders-api-config` in `prod` — **RESOLVED**.
- **RoleBinding `default-svc-01-default-role-04`** at namespace `default`: ServiceAccount `default-svc-01` in `default` → Role `default-role-04` in `default` — **RESOLVED**.
- **RoleBinding `default-svc-01-default-role-01`** at namespace `default`: ServiceAccount `default-svc-01` in `default` → Role `default-role-01` in `default` — **RESOLVED**.
- **RoleBinding `default-svc-02-default-role-05`** at namespace `default`: ServiceAccount `default-svc-02` in `default` → Role `default-role-05` in `default` — **RESOLVED**.
- **RoleBinding `default-svc-03-default-role-02`** at namespace `default`: ServiceAccount `default-svc-03` in `default` → Role `default-role-02` in `default` — **RESOLVED**.
- **RoleBinding `default-svc-04-default-role-04`** at namespace `default`: ServiceAccount `default-svc-04` in `default` → Role `default-role-04` in `default` — **RESOLVED**.
- **RoleBinding `default-svc-05-default-role-04`** at namespace `default`: ServiceAccount `default-svc-05` in `default` → Role `default-role-04` in `default` — **RESOLVED**.
- **RoleBinding `default-svc-06-default-role-03`** at namespace `default`: ServiceAccount `default-svc-06` in `default` → Role `default-role-03` in `default` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-01-kubesystem-role-03`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-01` in `kube-system` → Role `kubesystem-role-03` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-02-kubesystem-role-02`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-02` in `kube-system` → Role `kubesystem-role-02` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-02-kubesystem-role-03`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-02` in `kube-system` → Role `kubesystem-role-03` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-03-kubesystem-role-02`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-03` in `kube-system` → Role `kubesystem-role-02` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-03-kubesystem-role-03`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-03` in `kube-system` → Role `kubesystem-role-03` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-04-kubesystem-role-02`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-04` in `kube-system` → Role `kubesystem-role-02` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-05-kubesystem-role-01`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-05` in `kube-system` → Role `kubesystem-role-01` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-05-kubesystem-role-02`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-05` in `kube-system` → Role `kubesystem-role-02` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-06-kubesystem-role-02`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-06` in `kube-system` → Role `kubesystem-role-02` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-06-kubesystem-role-03`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-06` in `kube-system` → Role `kubesystem-role-03` in `kube-system` — **RESOLVED**.
- **RoleBinding `kubesystem-svc-07-kubesystem-role-03`** at namespace `kube-system`: ServiceAccount `kubesystem-svc-07` in `kube-system` → Role `kubesystem-role-03` in `kube-system` — **RESOLVED**.
- **RoleBinding `prod-svc-01-prod-role-01`** at namespace `prod`: ServiceAccount `prod-svc-01` in `prod` → Role `prod-role-01` in `prod` — **RESOLVED**.
- **RoleBinding `prod-svc-02-prod-role-03`** at namespace `prod`: ServiceAccount `prod-svc-02` in `prod` → Role `prod-role-03` in `prod` — **RESOLVED**.
- **RoleBinding `prod-svc-02-prod-role-01`** at namespace `prod`: ServiceAccount `prod-svc-02` in `prod` → Role `prod-role-01` in `prod` — **RESOLVED**.
- **RoleBinding `prod-svc-03-prod-role-02`** at namespace `prod`: ServiceAccount `prod-svc-03` in `prod` → Role `prod-role-02` in `prod` — **RESOLVED**.
- **RoleBinding `prod-svc-03-prod-role-01`** at namespace `prod`: ServiceAccount `prod-svc-03` in `prod` → Role `prod-role-01` in `prod` — **RESOLVED**.
- **RoleBinding `prod-svc-04-prod-role-03`** at namespace `prod`: ServiceAccount `prod-svc-04` in `prod` → Role `prod-role-03` in `prod` — **RESOLVED**.
- **RoleBinding `prod-svc-04-prod-role-04`** at namespace `prod`: ServiceAccount `prod-svc-04` in `prod` → Role `prod-role-04` in `prod` — **RESOLVED**.
- **RoleBinding `build-svc-01-build-role-02`** at namespace `build`: ServiceAccount `build-svc-01` in `build` → Role `build-role-02` in `build` — **RESOLVED**.
- **RoleBinding `build-svc-01-build-role-03`** at namespace `build`: ServiceAccount `build-svc-01` in `build` → Role `build-role-03` in `build` — **RESOLVED**.
- **RoleBinding `build-svc-02-build-role-05`** at namespace `build`: ServiceAccount `build-svc-02` in `build` → Role `build-role-05` in `build` — **RESOLVED**.
- **RoleBinding `build-svc-03-build-role-03`** at namespace `build`: ServiceAccount `build-svc-03` in `build` → Role `build-role-03` in `build` — **RESOLVED**.
- **RoleBinding `build-svc-04-build-role-01`** at namespace `build`: ServiceAccount `build-svc-04` in `build` → Role `build-role-01` in `build` — **RESOLVED**.
- **RoleBinding `build-svc-05-build-role-01`** at namespace `build`: ServiceAccount `build-svc-05` in `build` → Role `build-role-01` in `build` — **RESOLVED**.
- **RoleBinding `build-svc-05-build-role-03`** at namespace `build`: ServiceAccount `build-svc-05` in `build` → Role `build-role-03` in `build` — **RESOLVED**.
- **RoleBinding `build-svc-06-build-role-03`** at namespace `build`: ServiceAccount `build-svc-06` in `build` → Role `build-role-03` in `build` — **RESOLVED**.
- **RoleBinding `platform-svc-01-platform-role-02`** at namespace `platform`: ServiceAccount `platform-svc-01` in `platform` → Role `platform-role-02` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-01-platform-role-03`** at namespace `platform`: ServiceAccount `platform-svc-01` in `platform` → Role `platform-role-03` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-02-platform-role-03`** at namespace `platform`: ServiceAccount `platform-svc-02` in `platform` → Role `platform-role-03` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-02-platform-role-01`** at namespace `platform`: ServiceAccount `platform-svc-02` in `platform` → Role `platform-role-01` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-03-platform-role-02`** at namespace `platform`: ServiceAccount `platform-svc-03` in `platform` → Role `platform-role-02` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-04-platform-role-02`** at namespace `platform`: ServiceAccount `platform-svc-04` in `platform` → Role `platform-role-02` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-05-platform-role-01`** at namespace `platform`: ServiceAccount `platform-svc-05` in `platform` → Role `platform-role-01` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-05-platform-role-03`** at namespace `platform`: ServiceAccount `platform-svc-05` in `platform` → Role `platform-role-03` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-06-platform-role-02`** at namespace `platform`: ServiceAccount `platform-svc-06` in `platform` → Role `platform-role-02` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-07-platform-role-02`** at namespace `platform`: ServiceAccount `platform-svc-07` in `platform` → Role `platform-role-02` in `platform` — **RESOLVED**.
- **RoleBinding `platform-svc-07-platform-role-01`** at namespace `platform`: ServiceAccount `platform-svc-07` in `platform` → Role `platform-role-01` in `platform` — **RESOLVED**.
- **RoleBinding `dev-svc-01-dev-role-04`** at namespace `dev`: ServiceAccount `dev-svc-01` in `dev` → Role `dev-role-04` in `dev` — **RESOLVED**.
- **RoleBinding `dev-svc-02-dev-role-02`** at namespace `dev`: ServiceAccount `dev-svc-02` in `dev` → Role `dev-role-02` in `dev` — **RESOLVED**.
- **RoleBinding `dev-svc-03-dev-role-04`** at namespace `dev`: ServiceAccount `dev-svc-03` in `dev` → Role `dev-role-04` in `dev` — **RESOLVED**.
- **RoleBinding `dev-svc-04-dev-role-04`** at namespace `dev`: ServiceAccount `dev-svc-04` in `dev` → Role `dev-role-04` in `dev` — **RESOLVED**.
- **RoleBinding `dev-svc-04-dev-role-02`** at namespace `dev`: ServiceAccount `dev-svc-04` in `dev` → Role `dev-role-02` in `dev` — **RESOLVED**.
- **RoleBinding `staging-svc-01-staging-role-04`** at namespace `staging`: ServiceAccount `staging-svc-01` in `staging` → Role `staging-role-04` in `staging` — **RESOLVED**.
- **RoleBinding `staging-svc-02-staging-role-04`** at namespace `staging`: ServiceAccount `staging-svc-02` in `staging` → Role `staging-role-04` in `staging` — **RESOLVED**.
- **RoleBinding `staging-svc-03-staging-role-02`** at namespace `staging`: ServiceAccount `staging-svc-03` in `staging` → Role `staging-role-02` in `staging` — **RESOLVED**.
- **RoleBinding `staging-svc-03-staging-role-04`** at namespace `staging`: ServiceAccount `staging-svc-03` in `staging` → Role `staging-role-04` in `staging` — **RESOLVED**.
- **RoleBinding `staging-svc-04-staging-role-04`** at namespace `staging`: ServiceAccount `staging-svc-04` in `staging` → Role `staging-role-04` in `staging` — **RESOLVED**.
- **RoleBinding `staging-svc-04-staging-role-02`** at namespace `staging`: ServiceAccount `staging-svc-04` in `staging` → Role `staging-role-02` in `staging` — **RESOLVED**.
- **RoleBinding `staging-svc-05-staging-role-04`** at namespace `staging`: ServiceAccount `staging-svc-05` in `staging` → Role `staging-role-04` in `staging` — **RESOLVED**.
- **RoleBinding `staging-svc-05-staging-role-03`** at namespace `staging`: ServiceAccount `staging-svc-05` in `staging` → Role `staging-role-03` in `staging` — **RESOLVED**.
- **RoleBinding `analytics-svc-01-analytics-role-02`** at namespace `analytics`: ServiceAccount `analytics-svc-01` in `analytics` → Role `analytics-role-02` in `analytics` — **RESOLVED**.
- **RoleBinding `analytics-svc-02-analytics-role-03`** at namespace `analytics`: ServiceAccount `analytics-svc-02` in `analytics` → Role `analytics-role-03` in `analytics` — **RESOLVED**.
- **RoleBinding `analytics-svc-03-analytics-role-02`** at namespace `analytics`: ServiceAccount `analytics-svc-03` in `analytics` → Role `analytics-role-02` in `analytics` — **RESOLVED**.
- **RoleBinding `analytics-svc-04-analytics-role-01`** at namespace `analytics`: ServiceAccount `analytics-svc-04` in `analytics` → Role `analytics-role-01` in `analytics` — **RESOLVED**.
- **RoleBinding `analytics-svc-04-analytics-role-02`** at namespace `analytics`: ServiceAccount `analytics-svc-04` in `analytics` → Role `analytics-role-02` in `analytics` — **RESOLVED**.
- **RoleBinding `analytics-svc-05-analytics-role-02`** at namespace `analytics`: ServiceAccount `analytics-svc-05` in `analytics` → Role `analytics-role-02` in `analytics` — **RESOLVED**.
- **RoleBinding `analytics-svc-05-analytics-role-03`** at namespace `analytics`: ServiceAccount `analytics-svc-05` in `analytics` → Role `analytics-role-03` in `analytics` — **RESOLVED**.
- **RoleBinding `analytics-svc-06-analytics-role-02`** at namespace `analytics`: ServiceAccount `analytics-svc-06` in `analytics` → Role `analytics-role-02` in `analytics` — **RESOLVED**.
- **RoleBinding `analytics-svc-06-analytics-role-03`** at namespace `analytics`: ServiceAccount `analytics-svc-06` in `analytics` → Role `analytics-role-03` in `analytics` — **RESOLVED**.
- **RoleBinding `payments-svc-01-payments-role-01`** at namespace `payments`: ServiceAccount `payments-svc-01` in `payments` → Role `payments-role-01` in `payments` — **RESOLVED**.
- **RoleBinding `payments-svc-01-payments-role-02`** at namespace `payments`: ServiceAccount `payments-svc-01` in `payments` → Role `payments-role-02` in `payments` — **RESOLVED**.
- **RoleBinding `payments-svc-02-payments-role-01`** at namespace `payments`: ServiceAccount `payments-svc-02` in `payments` → Role `payments-role-01` in `payments` — **RESOLVED**.
- **RoleBinding `payments-svc-03-payments-role-03`** at namespace `payments`: ServiceAccount `payments-svc-03` in `payments` → Role `payments-role-03` in `payments` — **RESOLVED**.
- **RoleBinding `payments-svc-04-payments-role-02`** at namespace `payments`: ServiceAccount `payments-svc-04` in `payments` → Role `payments-role-02` in `payments` — **RESOLVED**.
- **RoleBinding `payments-svc-04-payments-role-01`** at namespace `payments`: ServiceAccount `payments-svc-04` in `payments` → Role `payments-role-01` in `payments` — **RESOLVED**.
- **RoleBinding `payments-svc-05-payments-role-03`** at namespace `payments`: ServiceAccount `payments-svc-05` in `payments` → Role `payments-role-03` in `payments` — **RESOLVED**.
- **RoleBinding `payments-svc-05-payments-role-01`** at namespace `payments`: ServiceAccount `payments-svc-05` in `payments` → Role `payments-role-01` in `payments` — **RESOLVED**.
- **RoleBinding `mediaproce-svc-01-mediaproce-role-01`** at namespace `media-processing`: ServiceAccount `mediaproce-svc-01` in `media-processing` → Role `mediaproce-role-01` in `media-processing` — **RESOLVED**.
- **RoleBinding `mediaproce-svc-01-mediaproce-role-03`** at namespace `media-processing`: ServiceAccount `mediaproce-svc-01` in `media-processing` → Role `mediaproce-role-03` in `media-processing` — **RESOLVED**.
- **RoleBinding `mediaproce-svc-02-mediaproce-role-01`** at namespace `media-processing`: ServiceAccount `mediaproce-svc-02` in `media-processing` → Role `mediaproce-role-01` in `media-processing` — **RESOLVED**.
- **RoleBinding `mediaproce-svc-02-mediaproce-role-03`** at namespace `media-processing`: ServiceAccount `mediaproce-svc-02` in `media-processing` → Role `mediaproce-role-03` in `media-processing` — **RESOLVED**.
- **RoleBinding `mediaproce-svc-03-mediaproce-role-01`** at namespace `media-processing`: ServiceAccount `mediaproce-svc-03` in `media-processing` → Role `mediaproce-role-01` in `media-processing` — **RESOLVED**.
- **RoleBinding `mediaproce-svc-04-mediaproce-role-02`** at namespace `media-processing`: ServiceAccount `mediaproce-svc-04` in `media-processing` → Role `mediaproce-role-02` in `media-processing` — **RESOLVED**.
- **RoleBinding `monitoring-svc-01-monitoring-role-03`** at namespace `monitoring`: ServiceAccount `monitoring-svc-01` in `monitoring` → Role `monitoring-role-03` in `monitoring` — **RESOLVED**.
- **RoleBinding `monitoring-svc-02-monitoring-role-05`** at namespace `monitoring`: ServiceAccount `monitoring-svc-02` in `monitoring` → Role `monitoring-role-05` in `monitoring` — **RESOLVED**.
- **RoleBinding `monitoring-svc-03-monitoring-role-04`** at namespace `monitoring`: ServiceAccount `monitoring-svc-03` in `monitoring` → Role `monitoring-role-04` in `monitoring` — **RESOLVED**.
- **RoleBinding `monitoring-svc-03-monitoring-role-01`** at namespace `monitoring`: ServiceAccount `monitoring-svc-03` in `monitoring` → Role `monitoring-role-01` in `monitoring` — **RESOLVED**.
- **RoleBinding `monitoring-svc-04-monitoring-role-02`** at namespace `monitoring`: ServiceAccount `monitoring-svc-04` in `monitoring` → Role `monitoring-role-02` in `monitoring` — **RESOLVED**.
- **RoleBinding `monitoring-svc-05-monitoring-role-04`** at namespace `monitoring`: ServiceAccount `monitoring-svc-05` in `monitoring` → Role `monitoring-role-04` in `monitoring` — **RESOLVED**.
- **RoleBinding `monitoring-svc-06-monitoring-role-03`** at namespace `monitoring`: ServiceAccount `monitoring-svc-06` in `monitoring` → Role `monitoring-role-03` in `monitoring` — **RESOLVED**.
- **RoleBinding `monitoring-svc-07-monitoring-role-05`** at namespace `monitoring`: ServiceAccount `monitoring-svc-07` in `monitoring` → Role `monitoring-role-05` in `monitoring` — **RESOLVED**.
- **RoleBinding `data-svc-01-data-role-04`** at namespace `data`: ServiceAccount `data-svc-01` in `data` → Role `data-role-04` in `data` — **RESOLVED**.
- **RoleBinding `data-svc-01-data-role-01`** at namespace `data`: ServiceAccount `data-svc-01` in `data` → Role `data-role-01` in `data` — **RESOLVED**.
- **RoleBinding `data-svc-02-data-role-01`** at namespace `data`: ServiceAccount `data-svc-02` in `data` → Role `data-role-01` in `data` — **RESOLVED**.
- **RoleBinding `data-svc-03-data-role-05`** at namespace `data`: ServiceAccount `data-svc-03` in `data` → Role `data-role-05` in `data` — **RESOLVED**.
- **RoleBinding `data-svc-03-data-role-01`** at namespace `data`: ServiceAccount `data-svc-03` in `data` → Role `data-role-01` in `data` — **RESOLVED**.
- **RoleBinding `data-svc-04-data-role-03`** at namespace `data`: ServiceAccount `data-svc-04` in `data` → Role `data-role-03` in `data` — **RESOLVED**.
- **RoleBinding `data-svc-04-data-role-05`** at namespace `data`: ServiceAccount `data-svc-04` in `data` → Role `data-role-05` in `data` — **RESOLVED**.
- **RoleBinding `legacybill-svc-01-legacybill-role-01`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-01` in `legacy-billing-migration` → Role `legacybill-role-01` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-01-legacybill-role-02`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-01` in `legacy-billing-migration` → Role `legacybill-role-02` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-02-legacybill-role-03`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-02` in `legacy-billing-migration` → Role `legacybill-role-03` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-03-legacybill-role-01`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-03` in `legacy-billing-migration` → Role `legacybill-role-01` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-03-legacybill-role-03`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-03` in `legacy-billing-migration` → Role `legacybill-role-03` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-04-legacybill-role-02`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-04` in `legacy-billing-migration` → Role `legacybill-role-02` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-05-legacybill-role-02`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-05` in `legacy-billing-migration` → Role `legacybill-role-02` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-06-legacybill-role-03`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-06` in `legacy-billing-migration` → Role `legacybill-role-03` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-06-legacybill-role-01`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-06` in `legacy-billing-migration` → Role `legacybill-role-01` in `legacy-billing-migration` — **RESOLVED**.
- **RoleBinding `legacybill-svc-07-legacybill-role-03`** at namespace `legacy-billing-migration`: ServiceAccount `legacybill-svc-07` in `legacy-billing-migration` → Role `legacybill-role-03` in `legacy-billing-migration` — **RESOLVED**.
- **ClusterRoleBinding `platform-controller-admin`** at cluster-wide: ServiceAccount `controller-admin` in `platform` → ClusterRole `cluster-superuser` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `deploy-bot-cm-read`** at cluster-wide: ServiceAccount `deploy-bot` in `prod` → ClusterRole `configmap-reader` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `ci-runner-nodes`** at cluster-wide: ServiceAccount `ci-runner` in `build` → ClusterRole `node-reader` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `kubesystem-svc-04-view-363`** at cluster-wide: ServiceAccount `kubesystem-svc-04` in `kube-system` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `prod-svc-01-view-677`** at cluster-wide: ServiceAccount `prod-svc-01` in `prod` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `build-svc-05-view-692`** at cluster-wide: ServiceAccount `build-svc-05` in `build` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `build-svc-04-view-139`** at cluster-wide: ServiceAccount `build-svc-04` in `build` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `staging-svc-01-view-163`** at cluster-wide: ServiceAccount `staging-svc-01` in `staging` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `mediaproce-svc-02-view-114`** at cluster-wide: ServiceAccount `mediaproce-svc-02` in `media-processing` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `monitoring-svc-04-view-620`** at cluster-wide: ServiceAccount `monitoring-svc-04` in `monitoring` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.
- **ClusterRoleBinding `prod-svc-01-view-509`** at cluster-wide: ServiceAccount `prod-svc-01` in `prod` → ClusterRole `view` (cluster-scoped) — **RESOLVED**.

## Scope caveats visible in the data

- `legacy-migration-admin` is a RoleBinding in `legacy-billing-migration` to the namespaced Role `migration-operator`, and its subject is ServiceAccount `deploy-bot` in `prod`. The RoleBinding does not become cluster-wide because its Role mentions `clusterroles`; the RoleBinding scope remains `legacy-billing-migration`, and a namespaced Role cannot authorize cluster-scoped ClusterRole requests.

- `sam-legacy-view` is a RoleBinding in `legacy-billing-migration` to ClusterRole `view`. Despite the ClusterRole reference, its grant is confined to `legacy-billing-migration`. `view` also appears in ClusterRoleBindings, whose grants are cluster-wide.

- Two separate ClusterRoleBindings, `prod-svc-01-view-677` and `prod-svc-01-view-509`, bind the same `view` ClusterRole to the same ServiceAccount. Both are included; either binding independently grants the same view rules.
