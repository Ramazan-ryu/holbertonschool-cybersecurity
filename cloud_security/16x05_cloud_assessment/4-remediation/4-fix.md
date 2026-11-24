# Selected Fix: Remove the Build Role's Production Deployment Trust

## Change selected

Cut the chain at the cross-account trust edge. Remove `arn:aws:iam::210000000001:role/ci-runner` from the trust policy of platform role `gp-deploy`, and revoke the long-lived CI access key found in repository history. Do not restore deployment access until the pipeline has a short-lived, narrowly scoped identity and an approved trust condition. Remove the credential from current source and history using the repository's credential incident process; rewriting history alone does not revoke a credential.

The required state change is in `infrastructure/identity/gp-deploy.tf`: the current `Principal.AWS` value admits the build account CI role. In the immediate containment state that principal is absent, so `ci-runner` cannot assume `gp-deploy`. This is a declarative remediation plan; **it was not applied to the live account**. The supplied workstation transcript shows failed credential setup, and this assessment did not establish a working API session.

## Why cut here

Removing the trust edge prevents the build identity from obtaining the production deployment role through this cross-account path, regardless of downstream cluster or storage configuration. It is a direct boundary and can be validated with an STS assume-role denial. Cutting only the KMS grant would reduce access to plaintext but leave the build identity able to modify production workloads and reach other resources through `eks:*`; fixing only the pod's service account would leave the broad deployment path intact and could be bypassed by another deployment change.

## Operational cost

The existing CI pipeline will no longer deploy to the platform account until a replacement identity and trust are implemented and tested. Releases may be delayed; emergency deployment will require the approved platform operator path. This temporary interruption is preferable to leaving the build-to-production trust path open while investigating credential exposure. Restore the workflow with short-lived federation, a constrained repository/workflow identity, limited deployment actions and resources, and a controlled release process.

## Validation status

Not executed. The terminal evidence shows the interactive prompt received command text instead of the CI key, so the CI credentials were incomplete; later assumed-role profiles were not established. See `4-chain_broken.txt` for the derived result from the proposed fixed trust state; it is not a live test result.
