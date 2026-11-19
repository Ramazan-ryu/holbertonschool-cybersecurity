# 3. A Different Shape

## Chain: hand an administrator role to a service

The initial caller was `arn:aws:iam::418274630117:user/reporting-analyst`, confirmed by `aws sts get-caller-identity` before the call.

1. `ReportingAnalystAccess`, statement `ChainA_PassAndRun`, allows `iam:PassRole` on `arn:aws:iam::418274630117:role/ashford-batch-exec`. `ChainA_Compute` allows Lambda `CreateFunction`, `InvokeFunction`, and `DeleteFunction` on `*`.
2. `aws iam get-role --role-name ashford-batch-exec` returned trust for `lambda.amazonaws.com` to call `sts:AssumeRole`. `list-attached-role-policies` returned `AshfordBatchExecAdmin`; its v1 document is `Effect:Allow`, `Action:"*"`, `Resource:"*"`. The reporting analyst boundary `CapRead` includes both `iam:*` and `lambda:*`, so it does not remove either edge.
3. `aws lambda create-function --function-name ashford-boundary-probe --runtime python3.12 --role arn:aws:iam::418274630117:role/ashford-batch-exec --handler handler.handler --zip-file fileb:///tmp/probe.zip` returned function ARN `arn:aws:lambda:eu-west-1:418274630117:function:ashford-boundary-probe`. CloudTrail records successful `CreateFunction` at `2026-11-19T03:47:52Z` in `.../2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0348Z_B3feeFebAf1DbD94.json.gz`.
4. An invocation was attempted (`aws lambda invoke --function-name ashford-boundary-probe /tmp/ashford-invoke.json`) but the endpoint returned HTTP 403 `SignatureDoesNotMatch`; delete returned the same signing error. CloudTrail records those errors at `05:31:33Z` and `05:31:36Z` in `...T0532Z_Bf99f6aFFF8B4bC9.json.gz`. These are not permission denials. Thus the assignment of the `*:*` execution role to a function is proven, while this endpoint did not let me independently confirm runtime execution.

This mechanism differs from the policy-version chain: it combines permission to pass a service role with permission to create compute, then relies on the service trust to run under a separate role's rights. The common property is excessive reach created by composing permissions that were reviewed individually. A role or action that looks limited in isolation becomes a path to broader authority when its relationships are followed.
