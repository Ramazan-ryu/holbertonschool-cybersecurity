# 8 — Review: The Label and the Evaluation

`CopperlineOpsLogsReadOnly` promises a reasonable reviewer read-only access to Copperline operations logs. Its `ReadOpsLogs` statement does name only the ops-logs bucket. But default version **v1**, directly attached to IAM user `svc-audit-intake`, also contained this independent statement (`evidence/iam-get-policy-version.json`):

```json
{
  "Sid": "IntakeSupport",
  "Effect": "Allow",
  "Action": ["s3:Get*", "s3:List*"],
  "Resource": "*"
}
```

No `Condition` is present. This is the precise gap: `s3:List*` and `s3:Get*` match S3 list and get actions across resources matched by `Resource: "*"`, rather than only the operations-log bucket. The narrow `ReadOpsLogs` statement does not restrict this separate allow. As `svc-audit-intake`, the reviewer listed `copperline-migration-scratch-cl7f3a` and its keys and successfully called `HeadObject` on its objects. That proves the effective scope reached outside ops logs; the object bodies were not read.

This can happen during a four-month freight migration without anyone acting carelessly. While locating cutover artifacts, an intake/support exception across buckets can appear practical. A separately administered statement with reusable `Get*`/`List*` actions and `Resource: "*"` is faster to add and keeps working as buckets appear. The policy name and narrow `ReadOpsLogs` statement make the result look more limited unless someone evaluates every statement together and tests a bucket outside the stated purpose. The corrective lesson is to scope each exception to named resources and test both an intended allow and an out-of-scope denial.

The operator removed `IntakeSupport` in v2 and verified ops-log access still worked while scratch listing was denied (`evidence/iam-get-policy-version-v2.json`, `evidence/remediation-v2-session.txt`). The inline `MaintainIntakePolicy` permission still lets this identity change the policy version, so Copperline should review that separate capability.
