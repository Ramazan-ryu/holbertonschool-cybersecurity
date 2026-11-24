# Selected Fix: Revoke the Repository-Exposed CI Credential

## Change selected

Disable the access key committed in `.ci/deploy.env` for IAM user `ci-runner`, then replace it with short-lived federation constrained to the intended repository and deployment workflow. Remove the secret from current source and repository history under the credential incident process; history rewriting does not revoke the key.

This cuts the proven first edge. Before the change, the credential returned caller ARN `arn:aws:iam::210000000001:user/ci-runner`; it then successfully assumed `gp-deploy`, assumed `gp-telemetry-reader`, and read the telemetry object. After deactivation, that credential cannot authenticate, so the tested path cannot start. The caller is an IAM **user** according to the live `get-caller-identity` response, while identity exports and the trust policy name a role `arn:aws:iam::210000000001:role/ci-runner`. The account API accepted the assume-role call despite this mismatch. Revoking the exact credential proven to work avoids relying on an unresolved user-versus-role interpretation.

The live change was attempted with `aws iam update-access-key` for that credential and returned `AccessDenied` for `iam:UpdateAccessKey`. No account state changed. The post-fix state below is therefore a proposed, derived state, not an executed remediation. An authorized IAM administrator must apply it.

## Why cut here

Credential revocation removes the exact credential that was executed successfully and is the narrowest immediate cut with direct evidence. Removing `ci-runner` from the `gp-deploy` trust policy is another possible cut, but the policy names a role while the proven key authenticates as a user, and the API allowed the transition; the principal mismatch must be reconciled before relying on that trust edit alone. Removing the node role's data rights would block this data path but would not remove the compromised build identity's production deployment capability. Credential revocation therefore contains the verified entry while preserving the option to restore deployment with controlled federation.

## Operational cost

The existing CI workflow loses this credential and cannot authenticate until a replacement is deployed. Releases may pause; emergency deployment must use an approved platform operator path. The replacement requires CI and IAM owners to agree on the exact repository/workflow identity and test its limited deployment permissions before normal releases resume.

## Validation status

Pre-fix identity and storage path execution succeeded; see `3-chain.md`. The attempted key deactivation was denied by the account API (`AccessDenied` for `iam:UpdateAccessKey`), so no post-change identity failure was available to capture. `4-chain_broken.txt` walks the path from the proposed inactive-key state and is explicitly derived, not a live test. Apply the change through an authorized IAM administrator, then verify that the retired key's `get-caller-identity` call fails and that the replacement can deploy only the approved workload.
