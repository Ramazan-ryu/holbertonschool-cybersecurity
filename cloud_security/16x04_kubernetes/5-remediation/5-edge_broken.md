# Broken escalation path: CI runner to cluster-superuser

## Change

In `5-fixed_manifests.yaml`, Role `platform-deployer` in `platform` keeps its existing Pod `get,list,watch` verbs but removes `create`. Its ConfigMap and ServiceAccount `get,list` rule remains. The `ci-runner-platform-deploy` RoleBinding remains, so this is a targeted reduction rather than deleting the binding.

## Re-derive the route after the change

1. `ci-runner-platform-deploy` still binds `build/ci-runner` to `platform-deployer` in the `platform` namespace.
2. The fixed Role no longer grants `create` on `pods`. `ci-runner-build` grants Pod create only in `build`; a namespaced RoleBinding does not move that grant into `platform`.
3. Therefore the first required step—creating a Pod in `platform` with `serviceAccountName: controller-admin`—has no granting rule for `build/ci-runner` after the change. The remaining `get,list,watch` Pod verbs cannot create a workload.
4. The target `platform/controller-admin` still has `cluster-superuser` through `platform-controller-admin`, but the CI runner cannot reach that identity through the pod-creation path. The broken edge is specifically `ci-runner` → Pod in platform → `controller-admin` → cluster-superuser. The target's direct privilege has not been changed.

The other prod `deploy-bot` → `billing-reconciler` → legacy read path described in `2-escalation_edges.md` is separate and is not broken by this Role change.
