# Trellis Software — RBAC escalation edges

## Findings

### 1. `build/ci-runner` can become `platform/controller-admin`, then cluster superuser

1. `RoleBinding ci-runner-platform-deploy` lives in `platform`; its subject is ServiceAccount `ci-runner` in `build`, and it binds Role `platform-deployer` in `platform` (see `0-rbac_map.md`, binding inventory). The Role's R1 grants `create` on core Pods; R2 grants `get,list` on core ServiceAccounts.
2. As that identity, CI can create a Pod in `platform` and set `spec.serviceAccountName: controller-admin`. `controller-admin` exists in `platform` (`serviceaccounts.yaml`) and is the identity already used by Deployment `platform-controller` (`workloads/platform/deployments.yaml`). No rule in `platform-deployer` prevents choosing it.
3. `platform-controller-admin` is a ClusterRoleBinding from `platform/controller-admin` to ClusterRole `cluster-superuser`. That ClusterRole grants `*` API groups, `*` resources, and `*` verbs (R1 in the map). The created Pod's ServiceAccount token is mounted by default unless disabled; the exported platform Deployment also explicitly has `automountServiceAccountToken: true`.
4. Therefore a holder of `build/ci-runner` can cause a workload to run as `platform/controller-admin` and use the cluster-wide superuser identity. The path is concrete and does not depend on the image contents.

This is the highest-impact edge. The audit record contains a corresponding platform Pod creation by ci-runner (line 826) and the next identity's secret reads (lines 829–830); see `6-audit_trail.md`.

### 2. `prod/deploy-bot` can become `prod/billing-reconciler` and read legacy migration secrets

`RoleBinding deploy-bot-deployer` binds Role `deployer` to `prod/deploy-bot`; `deployer` R1 permits create/update/patch of Deployments in `prod`. `billing-reconciler` is a ServiceAccount in `prod`, and `billing-reconciler-secrets` binds it to Role `billing-secrets` in `legacy-billing-migration` (R1 grants Secret get/list; R2 ConfigMap get/list). A modified Deployment in `prod` can therefore run with `serviceAccountName: billing-reconciler`; its mounted token then has the legacy namespace secret/configmap read grant. This edge is bounded to those legacy namespace resources; it is not cluster-wide secret access.

### Permission-shaped dead end: `migration-operator`

`legacy-migration-admin` is a RoleBinding in `legacy-billing-migration`, even though its subject is `prod/deploy-bot`. Its Role `migration-operator` lists `roles` and `clusterroles` with `create`, `bind`, and `escalate` (R2). The binding's grant remains namespaced. In particular, the Role cannot authorize requests for cluster-scoped ClusterRoles through this namespaced binding. Its R1 is only `get,list` on Roles and RoleBindings; there is no RoleBinding create/update permission to attach an escalated namespaced Role. Do not report this as a path to cluster admin.

`maya.chen` has deployment creation in `dev` (`maya-dev-editor` → `dev-editor` R2), but the exported ServiceAccounts in `dev` have only the read/update rules catalogued in `1-effective_privilege.md`; none supplies a stronger identity. Her separate legacy binding has an impersonate rule; through this namespaced RoleBinding it does not authorize impersonation of cluster-scoped Users/Groups, and no route into the prod or platform bindings is established. No equivalent becoming was established from those grants in this export.
