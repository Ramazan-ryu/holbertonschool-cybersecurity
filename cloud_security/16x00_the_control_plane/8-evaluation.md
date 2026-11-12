# 8 — Review: The Label and the Evaluation

`CopperlineOpsLogsReadOnly` suggests read-only access limited to operations logs. But its default **v1** let `svc-audit-intake` list the undocumented `copperline-migration-scratch-cl7f3a` bucket and inspect object metadata there. That is the demonstrated mismatch: the label points to ops logs; the effective access reached a separate migration bucket. The source is a second statement in the managed policy directly attached to this user (`evidence/iam-get-policy-version.json`):

```json
{
  "Sid": "IntakeSupport",
  "Effect": "Allow",
  "Action": ["s3:Get*", "s3:List*"],
  "Resource": "*"
}
```

There is no `Condition`; the permission path is user → attached managed policy → v1 → `IntakeSupport`. `s3:List*` with `Resource: "*"` explains the successful scratch-bucket listing, and `s3:Get*` explains the successful `HeadObject` metadata calls for its objects. The object bodies were not read. The separate `ReadOpsLogs` statement did not restrict this independent allow.

During a four-month freight migration, a reusable intake exception could reasonably seem like a way to find cutover files across changing buckets. Wildcards keep work moving as resources appear, while the policy name and narrower statement can make the overall access look limited. The gap is in the policy and review process, not an individual’s competence: the broad exception shipped without a resource limit or a test against an out-of-scope bucket. For future exceptions, name the resources and test both the intended access and a boundary denial.
