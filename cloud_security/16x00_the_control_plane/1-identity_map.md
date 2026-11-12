# 1 — Identity Map

Principal: `arn:aws:iam::418274639051:user/svc-audit-intake` (account `418274639051`, user ID `AIDA59C2ACB2A2DB59159`). `sts get-caller-identity` and `iam get-user` responses are in `evidence/0-caller-identity.json` and `evidence/current-session-api-results.json`.

This map distinguishes the original policy document inspected during discovery from the live default after remediation. JSON policy fields below are transcribed from the cited documents. Unless a statement says otherwise, it has `Effect: Allow`; none of the documents below contains `NotAction`, `NotResource`, or a `Condition` field.

## Directly attached managed policy: `CopperlineOpsLogsReadOnly`

`list-attached-user-policies` returned `arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly` (raw response in `evidence/current-session-iam-probes.md`). The original default document was fetched as **version v1**, `IsDefaultVersion: true`, in `evidence/iam-get-policy-version.json`:

| Sid in v1 | Effect | Action | Resource | Condition | Contribution in v1 |
|---|---|---|---|---|---|
| `ReadOpsLogs` | `Allow` | `s3:GetObject`, `s3:ListBucket` | `arn:aws:s3:::copperline-ops-logs-cl7f3a`; `arn:aws:s3:::copperline-ops-logs-cl7f3a/*` | absent | Read/list the named operations-log bucket and get its objects. |
| `IntakeSupport` | `Allow` | `s3:Get*`, `s3:List*` | `*` | absent | Broad S3 get/list action patterns on all matching resources. This is the unintended grant that made the migration-scratch bucket listable before remediation. |

The operator then created **version v2** and set it as default. The API's returned `PolicyVersion` document is preserved as `evidence/iam-get-policy-version-v2.json`; the CLI transcript is also recorded in `evidence/remediation-v2-session.txt`; the source file is `5-remediation/narrowed-policy.json`. Its sole statement is `Sid: ReadOpsLogs`, `Effect: Allow`, `Action: [s3:GetObject, s3:ListBucket]`, `Resource: [arn:aws:s3:::copperline-ops-logs-cl7f3a, arn:aws:s3:::copperline-ops-logs-cl7f3a/*]`; it has no `Condition`, `NotAction`, or `NotResource`. The version check returned `v2`. The v1 evidence remains the document observed during initial discovery; v2 is the live default at remediation verification. Post-change ops-log listing succeeded and scratch listing returned `AccessDenied` (see `evidence/remediation-v2-session.txt`).

## Directly attached inline user policy: `intake-ops-access`

`list-user-policies` returned this policy name. The complete document returned by `get-user-policy` is preserved in `evidence/iam-get-user-policy.json`. Each statement has `Effect: Allow`, no `Condition`, and no `NotAction` or `NotResource`:

| Sid | Action | Resource | What this JSON statement contributes |
|---|---|---|---|
| `SelfIntrospection` | `iam:GetUser`, `iam:ListAttachedUserPolicies`, `iam:ListUserPolicies`, `iam:GetUserPolicy`, `iam:ListGroupsForUser`, `iam:ListAccessKeys` | `arn:aws:iam::418274639051:user/svc-audit-intake` | Inspect this user, its attached/inline policies, groups, and key metadata. |
| `DirectoryRead` | `iam:ListUsers`, `iam:ListGroups`, `iam:ListPolicies`, `iam:ListAccountAliases` | `*` | Enumerate those account-level directory collections. |
| `PolicyRead` | `iam:GetPolicy`, `iam:GetPolicyVersion`, `iam:ListPolicyVersions` | `arn:aws:iam::418274639051:policy/*` | Read managed policy metadata, versions, and documents for policies in this account. |
| `GroupRead` | `iam:GetGroup`, `iam:ListAttachedGroupPolicies`, `iam:ListGroupPolicies` | `arn:aws:iam::418274639051:group/migration-readers` | Inspect the named group and its policy attachments. |
| `ServiceInventory` | `sqs:ListQueues`, `secretsmanager:ListSecrets`, `kms:ListKeys`, `kms:ListAliases` | `*` | Enumerate queues, secret metadata, KMS keys, and aliases. |
| `AuditTrailRead` | `s3:GetObject`, `s3:ListBucket` | `arn:aws:s3:::copperline-cloudtrail-cl7f3a`; `arn:aws:s3:::copperline-cloudtrail-cl7f3a/*` | List the CloudTrail bucket and get its objects. |
| `MaintainIntakePolicy` | `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, `iam:DeletePolicyVersion` | `arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly` | Create, activate, or delete versions of the attached managed policy. Create and set-default were exercised successfully during remediation; deletion was not attempted. This means this identity can change the policy that limits its own S3 access. |

## Inherited group managed policy: `MigrationReadOnly`

`list-groups-for-user` returned group `migration-readers`. `list-attached-group-policies` returned `arn:aws:iam::418274639051:policy/MigrationReadOnly`; `list-group-policies` returned an empty array. The attached managed policy's actual **v1** document (`IsDefaultVersion: true`) is preserved in `evidence/migration-readonly-policy.json`. Its single statement is `Sid: MigrationDescribe`, `Effect: Allow`, `Action: [secretsmanager:DescribeSecret, kms:DescribeKey, kms:GetKeyPolicy, sqs:GetQueueAttributes, sqs:GetQueueUrl]`, `Resource: "*"`; `Condition`, `NotAction`, and `NotResource` are absent. It contributes those metadata/description/key-policy/queue-inspection actions on any matching resource, subject to other applicable controls.

## Sources checked and found empty or absent

- `list-group-policies --group-name migration-readers` returned `PolicyNames: []`: the group has no inline policy.
- `get-user` returned no `PermissionsBoundary` field: no user permissions boundary was attached in that response.
- `list-attached-user-policies` returned only `CopperlineOpsLogsReadOnly`; `list-user-policies` returned only `intake-ops-access`; `list-groups-for-user` returned only `migration-readers`. No second direct attachment or group membership was returned.
- No session policy was supplied or inspected in the available session evidence. Organization/SCP policy state could not be inspected: `organizations:ListPoliciesForTarget` and `organizations:ListParents` both returned `AccessDeniedException`; see `evidence/organizations-scp-access-denied.txt`. SCP presence or absence is unknown, not established absent. These are visibility limits, not grants.

## Composition note

These are identity and group policy sources. Their `Allow` statements contribute candidate permissions, but an applicable explicit deny or limiting control can still prevent access. The account's observed replies are evaluated separately in `2-effective_permissions.md`; the current v2 default supersedes v1 for live use, while v1 is retained as historical evidence of the original exposure.
