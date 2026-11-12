# 8 — Review: The Label and the Evaluation

## Exact source of the over-grant

`CopperlineOpsLogsReadOnly` version **v1** was directly attached to IAM user `svc-audit-intake`; `list-attached-user-policies` returned that attachment. The actual document is `evidence/iam-get-policy-version.json`. Its `IntakeSupport` statement reads:

```json
{
  "Sid": "IntakeSupport",
  "Effect": "Allow",
  "Action": ["s3:Get*", "s3:List*"],
  "Resource": "*"
}
```

`Condition` is absent. The permission path is IAM user `svc-audit-intake` → directly attached managed policy `CopperlineOpsLogsReadOnly` → default v1 → `IntakeSupport`. The separate `ReadOpsLogs` statement was scoped to one bucket, but did not limit this independent allow: `s3:List*` included bucket listing and `s3:Get*` included object reads on resources matched by `Resource: "*"`. Before remediation, the principal listed the scratch bucket and keys and successfully called `HeadObject` on scratch objects. Those responses demonstrate the statement's reach; their bodies were not read.

## How this could happen in a real migration

During a four-month dispatch migration, an intake/support exception could seem useful for locating cutover artifacts across buckets. Broad action patterns and `Resource: "*"` are quick to write and keep covering new buckets. A reviewer focused on the narrow `ReadOpsLogs` rule or the policy's name could miss that IAM evaluates `IntakeSupport` separately. This is a policy-design and review gap, not individual blame: the exception had no named resource limits or negative test against an out-of-scope bucket.

## Remediation

The operator created v2, removed `IntakeSupport`, and made v2 default. The exact v2 document is in `evidence/iam-get-policy-version-v2.json`. Ops-logs listing and a one-byte `GetObject` read succeeded afterward; scratch listing returned `AccessDenied` (`evidence/remediation-v2-session.txt`, `evidence/ops-logs-get-object-range.json`). The inline `MaintainIntakePolicy` statement still lets this identity create and activate another policy version, so the account owner should review whether that self-modification permission is required.
