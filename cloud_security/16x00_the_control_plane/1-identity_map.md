# 1 — Identity Map

## Principal and credential state

`aws sts get-caller-identity` returned user `arn:aws:iam::418274639051:user/svc-audit-intake`, account `418274639051`, user ID `AIDA59C2ACB2A2DB59159`. `aws iam get-user` returned the same ARN and ID (`CreateDate: 2026-11-12T18:51:23.955462+00:00`). The current-session `aws iam list-access-keys --user-name svc-audit-intake` response shows one key metadata record with `Status: Active`; the secret key material was not returned or requested. See `evidence/current-session-api-results.json`.

## Direct user attachments

The user has one attached managed policy and one inline policy:

- **Attached managed policy — `CopperlineOpsLogsReadOnly`.** `list-attached-user-policies` returned ARN `arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly`. The original v1 document in `evidence/iam-get-policy-version.json` had `ReadOpsLogs` scoped to the operations-log bucket plus a broad `IntakeSupport` statement granting `s3:Get*` and `s3:List*` on `Resource: "*"`. The operator created v2 and set it as default; the returned document retains only the scoped `ReadOpsLogs` statement. `evidence/remediation-v2-session.txt` records the successful update and post-change checks. Listing the ops logs bucket succeeded after the change; listing the previously accessible scratch bucket returned `AccessDenied`.
- **Inline user policy — `intake-ops-access`.** `list-user-policies` returned this name, and `get-user-policy` returned its full JSON in `evidence/iam-get-user-policy.json`. `SelfIntrospection` grants calls to inspect this user and its keys. `DirectoryRead` grants `iam:ListUsers`, `iam:ListGroups`, `iam:ListPolicies`, and `iam:ListAccountAliases` on `*`. `PolicyRead` grants `iam:GetPolicy`, `iam:GetPolicyVersion`, and `iam:ListPolicyVersions` for policies in this account. `GroupRead` grants group inspection calls on `migration-readers`. `ServiceInventory` grants `sqs:ListQueues`, `secretsmanager:ListSecrets`, `kms:ListKeys`, and `kms:ListAliases`. `AuditTrailRead` grants `s3:GetObject` and `s3:ListBucket` on the CloudTrail bucket. `MaintainIntakePolicy` grants `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, and `iam:DeletePolicyVersion` on `CopperlineOpsLogsReadOnly`. The read actions listed above were exercised successfully. `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` were exercised successfully during remediation. The delete action was not attempted because deleting a policy version is destructive.

## Inherited group permissions

`list-groups-for-user` returned one group, `migration-readers`. `list-attached-group-policies` returned managed policy `MigrationReadOnly`; `list-group-policies` returned an empty list. The actual managed policy document is in `evidence/migration-readonly-policy.json`. Its `MigrationDescribe` statement grants `secretsmanager:DescribeSecret`, `kms:DescribeKey`, `kms:GetKeyPolicy`, `sqs:GetQueueAttributes`, and `sqs:GetQueueUrl` on `Resource: "*"`. Calls to describe the carrier secret, describe the migration key, retrieve that key's policy, retrieve the dispatch queue URL, and read queue attributes all succeeded. Secret values were not requested.

## Other visible controls and limits

`get-user` returned no `PermissionsBoundary` field. The available calls did not establish organization-level service control policies, so this map is bounded by the identity and account APIs observed. The account's response to `aws ec2 describe-instances --region eu-west-1` was `AccessDenied`; that is an observed boundary, not evidence that the account has no EC2 resources. No inline group policy, second user attachment, or second membership was returned by the calls above.
