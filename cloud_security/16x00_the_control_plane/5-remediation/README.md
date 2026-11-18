# 5 — Close It, and Prove It Is Closed

## Identity and Remediation Context

All discovery, policy modification, and post-remediation verification calls were executed in account `418274639051` (`eu-west-1`) using the same Copperline IAM principal:

- **ARN:** `arn:aws:iam::418274639051:user/svc-audit-intake`
- **UserId:** `AIDA59C2ACB2A2DB59159`
- **Account:** `418274639051`

Caller identity confirmation is preserved in `5-remediation/evidence/0-caller-identity.json`.

---

## 1. The Over-Grant Removed and the Narrowed Policy

### Policy Source and Statement Removed

During baseline analysis (Task 1 and Task 2), the customer-managed policy `arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly` (default version `v1`, preserved in `5-remediation/evidence/iam-get-policy-version-v1.json`) was attached directly to `svc-audit-intake`. Version `v1` contained two statements:

1. `Sid: ReadOpsLogs` — `Effect: Allow` for `["s3:GetObject", "s3:ListBucket"]` scoped specifically to `["arn:aws:s3:::copperline-ops-logs-cl7f3a", "arn:aws:s3:::copperline-ops-logs-cl7f3a/*"]`.
2. `Sid: IntakeSupport` — `Effect: Allow` for action patterns `["s3:Get*", "s3:List*"]` on resource `"*"`.

The `IntakeSupport` statement was the unintended over-grant. Because it granted `s3:Get*` and `s3:List*` across `*`, it allowed `svc-audit-intake` to list and inspect objects inside the undocumented migration scratch bucket (`arn:aws:s3:::copperline-migration-scratch-cl7f3a` and `arn:aws:s3:::copperline-migration-scratch-cl7f3a/*`), as well as enumerate bucket settings across the account.

Neither the user's inline policy (`intake-ops-access`, which grants S3 access only to `arn:aws:s3:::copperline-cloudtrail-cl7f3a` and `arn:aws:s3:::copperline-cloudtrail-cl7f3a/*` via `AuditTrailRead`) nor the inherited group policy (`MigrationReadOnly` on group `migration-readers`, which grants only `secretsmanager:DescribeSecret`, `kms:DescribeKey`, `kms:GetKeyPolicy`, `sqs:GetQueueAttributes`, and `sqs:GetQueueUrl`) contains any wildcard or inheritance path granting `s3:ListBucket` or `s3:GetObject` on `copperline-migration-scratch-cl7f3a`.

### Narrowed Policy Document (`v2`)

To remove the unintended `s3:Get*` and `s3:List*` grant on `"*"` while preserving `svc-audit-intake`'s legitimate operational role (reading and listing the operations logs bucket `copperline-ops-logs-cl7f3a`), the `IntakeSupport` statement was removed in its entirety.

The complete narrowed policy document (`5-remediation/narrowed-policy.json`, applied as default version `v2` of `arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly`) is:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOpsLogs",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::copperline-ops-logs-cl7f3a",
        "arn:aws:s3:::copperline-ops-logs-cl7f3a/*"
      ]
    }
  ]
}
