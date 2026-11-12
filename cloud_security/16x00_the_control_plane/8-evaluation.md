# 8 — Review: The Label and the Evaluation

`CopperlineOpsLogsReadOnly` suggests read-only access to operations logs. In default version **v1**, directly attached to `svc-audit-intake`, a separate statement granted broader access (`evidence/iam-get-policy-version.json`):

```json
{
  "Sid": "IntakeSupport",
  "Effect": "Allow",
  "Action": ["s3:Get*", "s3:List*"],
  "Resource": "*"
}
```

There is no `Condition`. The path is user → attached managed policy → v1 → `IntakeSupport`. These action and resource patterns are not limited to the ops-logs bucket. The user listed the undocumented migration-scratch bucket and successfully called `HeadObject` on its objects; the bodies were not read. The separate `ReadOpsLogs` statement did not narrow this grant.

During a four-month freight migration, a reusable intake exception could reasonably seem like a way to find cutover files across changing buckets. Wildcards keep work moving as resources appear, while the policy name and narrower statement can make the overall access look limited. The gap is in the policy and review process, not an individual’s competence: the broad exception shipped without a resource limit or a test against an out-of-scope bucket. For future exceptions, name the resources and test both the intended access and a boundary denial.
