# 2. The Unremarkable Administrator

## Ordinary principal and result

Starting principal: `arn:aws:iam::418274630117:user/reporting-analyst`, Finance Ops monthly regulatory reporting analyst. `aws sts get-caller-identity` returned this ARN. It is not itself an administrator: its attached `ReportingAnalystAccess` grants selected reporting and inspection actions. The resulting identity is the `ashford-crossacct-reader` role session. After its attached policy was changed to `Action:"*"`, `Resource:"*"`, that session exercised IAM user administration. The organization SCP still limits some actions, including long-lived key creation and leaving the organization.

## Chain, with the capability at each edge

### Edge 1 — reporting user can change one managed policy

- **Current principal:** `arn:aws:iam::418274630117:user/reporting-analyst`.
- **Permission and resource:** `iam:CreatePolicyVersion` on `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess`. `ReportingAnalystAccess`, statement `ChainB_AmendReaderPolicy`, is `Effect:Allow`, `Action:["iam:CreatePolicyVersion","iam:SetDefaultPolicyVersion","iam:DeletePolicyVersion"]`, `Resource` equal to that one policy ARN, with no condition.
- **Other layers:** `ReportingAnalystBoundary`, `CapRead`, allows `iam:*` on `*`; it does not cap these actions. `AshfordGuardrails` denies only CreateAccessKey/CreateLoginProfile and organization exit/closure, not policy-version operations. No permissions boundary is attached to `ashford-crossacct-reader` in its `get-role` response.
- **Call and response:** `aws iam create-policy-version --policy-arn arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}' --set-as-default` returned `VersionId:v2`, `IsDefaultVersion:true`. CloudTrail records it at `2026-11-19T03:45:26Z` in `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0346Z_70fB56CA51C7fe8C.json.gz`, with `userIdentity.arn` equal to the reporting user.
- **Capability created:** This user can replace the default document of this specific managed policy. `get-role --role-name ashford-crossacct-reader` plus `list-attached-role-policies` had shown that exact policy attached to the role. `get-policy-version` then returned the new default v2 with `Allow`, `Action:"*"`, `Resource:"*"`. The role's effective grant changed from `s3:GetObject`, `s3:ListBucket`, and `sts:AssumeRole` to all actions/resources.

### Edge 2 — reporting user can assume the role whose policy it changed

- **Current principal before request:** `reporting-analyst`. A separate boto3 session called `GetCallerIdentity` before assuming and returned this user ARN.
- **Permission and resource:** `sts:AssumeRole` on `arn:aws:iam::418274630117:role/ashford-crossacct-reader`. `ReportingAnalystAccess`, `ChainB_AssumeReader`, is `Effect:Allow`, `Action:"sts:AssumeRole"`, `Resource` equal to that ARN, no condition. The role trust returned by `get-role` is `Effect:Allow`, `Principal:{"AWS":"arn:aws:iam::418274630117:user/reporting-analyst"}`, `Action:"sts:AssumeRole"`. The boundary allows `sts:AssumeRole`; the SCP has no deny for it.
- **Call and response:** `aws sts assume-role --role-arn arn:aws:iam::418274630117:role/ashford-crossacct-reader --role-session-name esc` returned STS credentials (CloudTrail `AssumeRole`, `03:45:28Z`, same object as above). With the returned credentials loaded into a boto3 session, the next `GetCallerIdentity` returned `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/chain-proof`.
- **Capability created:** The caller is now a session of the role with the just-modified `*`/`*` managed policy. This is a policy-content change followed by an STS identity transition; the first edge changes the target role's authority, and the second obtains that authority.

### Edge 3 — use the resulting IAM authority

- **Current principal:** `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/chain-proof`, verified immediately before the test using `GetCallerIdentity`.
- **Permission and resource:** The new role policy allows `iam:CreateUser` and `iam:DeleteUser` on `*` because its only statement allows `Action:"*"`, `Resource:"*"`. The organization SCP does not deny either action.
- **Call and response:** Using that boto3 session, `iam.create_user(UserName="ashford-chain-proof-cleanup")` returned the user ARN; `iam.delete_user(...)` then returned success. CloudTrail contains `CreateUser` and `DeleteUser` at `2026-11-19T05:28:56Z` in `.../2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0529Z_BD35bac2A0d5c77f.json.gz`.
- **Result:** This empirically confirms administrative IAM capability. The `*` role policy remains subject to the SCP's explicit denies, so the session cannot create access keys or leave the organization.

## Why individually reasonable grants compose badly

Managing versions of one reporting policy and assuming one reporting role can each look operationally narrow. Together, the first lets the user change the role's effective permissions, and the second lets that same user receive those changed permissions. The role trust and the identity policy agree, so no trust refusal breaks the path. The escalation is not an administrator granting itself access directly; it is authority to alter a trusted role's policy, followed by a permitted identity transition.
