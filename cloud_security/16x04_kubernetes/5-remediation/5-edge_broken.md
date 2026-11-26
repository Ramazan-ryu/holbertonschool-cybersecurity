# Broken escalation path: CI runner to cluster-superuser

## Change

`5-fixed_manifests.yaml` removes the `ci-runner-platform-deploy` RoleBinding from namespace `platform`. The `platform-deployer` Role remains unchanged; without a binding to it, it grants no permissions to `build/ci-runner`.

## Re-derive the route after the change

1. In the source export, `ci-runner-platform-deploy` was the only binding that gave `build/ci-runner` permissions in `platform`; it referenced Role `platform-deployer`, whose Pod rule included `create`.
2. In `5-fixed_manifests.yaml`, that RoleBinding is absent. No other binding grants `build/ci-runner` Pod creation in `platform`.
3. The remaining `ci-runner-build` binding grants Pod `create` only in `build`; `ci-runner-legacy-secrets` grants Secret and ConfigMap reads only in `legacy-billing-migration`. Neither grants Pod creation in `platform`.
4. Therefore `build/ci-runner` cannot create a Pod in `platform` with `serviceAccountName: controller-admin`. The chain stops before that ServiceAccount identity is selected.
5. `platform/controller-admin` still has `cluster-superuser` through `platform-controller-admin`. The remediation breaks the path from `ci-runner`; it does not change the target's own privilege.

Stopped path: `build/ci-runner` → missing `platform` Pod-create binding → no Pod selecting `platform/controller-admin` → no E1 transition to `cluster-superuser`.
