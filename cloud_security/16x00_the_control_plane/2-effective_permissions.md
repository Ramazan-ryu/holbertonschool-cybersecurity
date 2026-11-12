# 2 — Effective Permissions

Identity confirmed by `aws sts get-caller-identity`: `arn:aws:iam::418274639051:user/svc-audit-intake` (`evidence/0-caller-identity.json`; same ARN in the current-session responses). The following verdicts are based on the user inline policy, both attached managed policy documents, group membership, and actual API replies. Evidence files preserve the response bodies. `ALLOW` means the specified representative call succeeded; wildcard statements may match more actions than the representative call demonstrates.

## Confirmed allowed

| Permission | Verdict | Call made | Account response / evidence |
|---|---|---|---|
| `iam:GetUser` | ALLOW | `aws iam get-user` | Returned `UserName: svc-audit-intake`, matching user ID and ARN; `evidence/current-session-api-results.json`. |
| `iam:ListAttachedUserPolicies` | ALLOW | `aws iam list-attached-user-policies --user-name svc-audit-intake` | Returned `CopperlineOpsLogsReadOnly`; raw response in `evidence/current-session-iam-probes.md`. |
| `iam:ListUserPolicies` | ALLOW | `aws iam list-user-policies --user-name svc-audit-intake` | Returned `intake-ops-access`; raw response in `evidence/current-session-iam-probes.md`. |
| `iam:GetUserPolicy` | ALLOW | `aws iam get-user-policy --user-name svc-audit-intake --policy-name intake-ops-access` | Returned the inline JSON, including `MaintainIntakePolicy`; `evidence/iam-get-user-policy.json`. |
| `iam:ListGroupsForUser` | ALLOW | `aws iam list-groups-for-user --user-name svc-audit-intake` | Returned group `migration-readers`; raw response in `evidence/current-session-iam-probes.md`. |
| `iam:ListAccessKeys` | ALLOW | `aws iam list-access-keys --user-name svc-audit-intake` | Returned one active key metadata record; `evidence/current-session-api-results.json`. |
| `iam:ListUsers` | ALLOW | `aws iam list-users` | Returned five users; `evidence/current-session-api-results.json`. |
| `iam:ListGroups` | ALLOW | `aws iam list-groups` | Returned `migration-readers` and `dispatch-staff`; `evidence/current-session-api-results.json`. |
| `iam:ListPolicies` | ALLOW | `aws iam list-policies` | Returned four managed policies; `evidence/current-session-api-results.json`. |
| `iam:ListAccountAliases` | ALLOW | `aws iam list-account-aliases` | Returned `copperline-logistics`; `evidence/current-session-api-results.json`. |
| `iam:GetPolicy` | ALLOW | `aws iam get-policy --policy-arn arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly` (also called for `MigrationReadOnly`) | Returned policy metadata and default version `v1`; `evidence/iam-get-policy.json` and `evidence/current-session-iam-probes.md`. |
| `iam:GetPolicyVersion` | ALLOW | `aws iam get-policy-version ... --version-id v1` for both attached policies | Returned each JSON document; `evidence/iam-get-policy-version.json` and `evidence/migration-readonly-policy.json`. |
| `iam:ListPolicyVersions` | ALLOW | `aws iam list-policy-versions ...` for both attached policies | Each response contained only default version `v1`; raw response summaries in `evidence/current-session-iam-probes.md`. |
| `iam:GetGroup` | ALLOW | `aws iam get-group --group-name migration-readers` | Returned the group and `svc-audit-intake`; response supplied in the current-session transcript. |
| `iam:ListAttachedGroupPolicies` | ALLOW | `aws iam list-attached-group-policies --group-name migration-readers` | Returned `MigrationReadOnly`; response in `evidence/current-session-iam-probes.md`. |
| `iam:ListGroupPolicies` | ALLOW | `aws iam list-group-policies --group-name migration-readers` | Returned an empty `PolicyNames` array; response in `evidence/current-session-iam-probes.md`. |
| `sqs:ListQueues` | ALLOW | `aws sqs list-queues` | Returned the dispatch queue URL; `evidence/current-session-api-results.json`. |
| `sqs:GetQueueUrl` | ALLOW | `aws sqs get-queue-url --queue-name copperline-dispatch-events` | Returned the queue URL shown in the service inventory. |
| `sqs:GetQueueAttributes` | ALLOW | `aws sqs get-queue-attributes --queue-url http://127.0.0.1:4566/418274639051/copperline-dispatch-events --attribute-names All` | Returned queue attributes, including 3 approximate messages and managed SSE enabled; `evidence/current-session-api-results.json`. |
| `secretsmanager:ListSecrets` | ALLOW | `aws secretsmanager list-secrets` | Returned two secret metadata records; no values requested; `evidence/current-session-api-results.json`. |
| `secretsmanager:DescribeSecret` | ALLOW | `aws secretsmanager describe-secret --secret-id copperline/carrier-api` | Returned carrier secret metadata only; `evidence/current-session-api-results.json`. |
| `kms:ListKeys` | ALLOW | `aws kms list-keys` | Returned key `803db655-9754-4464-8822-eff23a3ba4e7`; `evidence/current-session-api-results.json`. |
| `kms:ListAliases` | ALLOW | `aws kms list-aliases` | Returned `alias/copperline-migration` and AWS-managed aliases; `evidence/current-session-api-results.json`. |
| `kms:DescribeKey` | ALLOW | `aws kms describe-key --key-id 803db655-9754-4464-8822-eff23a3ba4e7` | Returned enabled customer-managed key metadata; `evidence/current-session-api-results.json`. |
| `kms:GetKeyPolicy` | ALLOW | `aws kms get-key-policy --key-id 803db655-9754-4464-8822-eff23a3ba4e7 --policy-name default` | Returned the default policy JSON; `evidence/current-session-api-results.json`. |
| `s3:ListAllMyBuckets` (matched by `s3:List*`) | ALLOW | `aws s3api list-buckets` | Returned four bucket names, including undocumented scratch; `evidence/current-session-s3-results.json`. |
| `s3:ListBucket` (matched by `s3:List*`) | ALLOW | `aws s3api list-objects-v2` on scratch, ops-logs, and CloudTrail buckets | Returned object keys; scratch and CloudTrail response in `evidence/current-session-s3-results.json`, scratch details in `evidence/scratch-objects.json`. |
| `s3:GetObject` (matched by `s3:Get*`; tested through `HeadObject`) | ALLOW | `aws s3api head-object` on scratch keys and ops log `access/2026-08.log` | Returned metadata for these keys; scratch responses in `evidence/scratch-head-notes.json` and `evidence/scratch-head-pre-cutover-dump.json`; ops response is in the operator's current-session transcript. Both scratch and ops returned `ContentLength: 0`. |
| `s3:GetBucketEncryption`, `s3:GetPublicAccessBlock`, `s3:GetBucketPolicy`, `s3:GetBucketPolicyStatus`, `s3:GetBucketAcl` (matched by `s3:Get*`) | ALLOW | Calls against ops-logs, CloudTrail, and scratch | Ops/CloudTrail returned encryption and PAB configurations; scratch returned missing-configuration/no-policy errors and owner-only ACL. These account responses are preserved under `evidence/*encryption*`, `evidence/*public-access*`, and `evidence/scratch-public-access-checks.txt`. |

## Confirmed denied

| Permission | Verdict | Call made | Verbatim account response |
|---|---|---|---|
| `ec2:DescribeInstances` | DENY | `aws ec2 describe-instances --region eu-west-1` | `An error occurred (AccessDenied) when calling the DescribeInstances operation: User: arn:aws:iam::418274639051:user/svc-audit-intake is not authorized to perform: ec2:DescribeInstances` (`evidence/current-session-api-results.json`). |

## Not yet established

The controlled remediation successfully exercised `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion`: `CopperlineOpsLogsReadOnly` v2 is default. Afterward, `ListBucket` for the operations-log bucket succeeded and `ListBucket` for the formerly accessible migration-scratch bucket returned `AccessDenied`; see `evidence/remediation-v2-session.txt`. `iam:DeletePolicyVersion` is also in that inline statement but is intentionally not probed because deleting a policy version is destructive and the lab forbids destructive actions. The direct `s3:GetObject` body read on a CloudTrail object has not been made; `HeadObject` established metadata access only. No organization-level policy or service control policy was inspected, so this is the permission boundary visible to this IAM identity and tested API calls, not an assertion about unseen organization controls.
