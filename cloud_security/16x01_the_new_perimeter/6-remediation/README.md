# 6. Remediation: Remove the Batch Role Handoff

## Why this is the highest-leverage cut in this chain

The selected element is the single `iam:PassRole` grant for `ashford-batch-exec`, not the final Lambda action. The role carries reusable `Action:"*"` / `Resource:"*"` permissions. Removing the scoped handoff prevents this principal from attaching that authority to a new service workload, so the powerful role remains available to its Platform-owned batch workflow without remaining delegable by Finance's reporting identity.

Other plausible cuts have worse scope or leave the reusable edge intact. Removing `lambda:CreateFunction` blocks only this compute API; the PassRole grant remains available if another permitted service path is added later. Removing `lambda:InvokeFunction` blocks invocation of functions but does not remove the ability to configure a new function with the admin role. Weakening `AshfordBatchExecAdmin` itself would reduce the authority of the nightly batch execution role for every legitimate consumer. The chosen cut scopes the change to one principal-to-role handoff. The named legitimate use of `ashford-batch-exec` is nightly batch execution; the provided records do not establish that the reporting analyst needs to assign this role to functions.

## Change

The single risky edge chosen was `iam:PassRole` on the administrator execution role. Through the already-proven admin session, I created a new default version of `ReportingAnalystAccess` with only the `ChainA_PassAndRun` statement removed. The policy still contains `ChainA_Compute` and the reporting bucket read permissions. The boundary continues to cap the user. The exact policy before/after was derived from `get-policy-version`; the remediation version was v2 in the first run and v2 in the fresh post-prediction replay.

Before change, the relevant statement was:

```json
{"Sid":"ChainA_PassAndRun","Effect":"Allow","Action":["iam:PassRole"],"Resource":"arn:aws:iam::418274630117:role/ashford-batch-exec"}
```

The revised document removes that statement. In the fresh replay, CloudTrail records the policy change and the later refusal in `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0642Z_afefc4A7d1d4Bc5b.json.gz`. The `CreatePolicyVersion` event was `73ecacbf-9fad-40dd-aa40-4f0dfc2b2f98`; the `SetDefaultPolicyVersion` event restoring the reader policy after proof was `ebba19b3-3df7-48fb-82e5-e2e24d7bead5`. The reporting caller identity was checked before and after policy change and remained the user ARN.

The after-state retains `ChainA_Compute` (`Effect:Allow`, `Action:["lambda:CreateFunction","lambda:InvokeFunction","lambda:DeleteFunction"]`, `Resource:"*"`) and the reporting bucket read statements. The only permission statement removed from this identity policy version is `ChainA_PassAndRun`; no boundary, SCP, role trust, or role permission was changed as part of this cut.

## Refused chain

Before remediation, a valid zip and `ashford-batch-exec` role caused `CreateFunction` to succeed (event `88c062e5-36e4-4058-8192-90e750cc7341`). After remediation, I checked `aws sts get-caller-identity` (still `reporting-analyst`) and repeated `aws lambda create-function --function-name ashford-boundary-after-fix --runtime python3.12 --role arn:aws:iam::418274630117:role/ashford-batch-exec --handler handler.handler --zip-file fileb:///tmp/probe.zip`. The service returned HTTP 403 `AccessDenied`, naming `lambda:CreateFunction`, at `2026-11-19T06:41:25Z`; event ID `3e317ddd-b30d-452c-aae7-497672061f69`, request ID `XpxjjFFTmP7KtjodsutsgVv9uPeGvbVIQUDIOgjOGpc5BUj9raXu`. It is in the object above. The request requires both Lambda creation and permission to pass the requested role; the handoff permission has been removed.

## Legitimate operation and cost

After the remediation, the same reporting user ran `aws s3 ls s3://ashford-reporting-ap7f3a/`; it returned `PRE reports/` at `2026-11-19T06:41:28Z`, CloudTrail event ID `67fb6f4e-dc02-441e-a93c-6dc1d2a7adb9`, request ID `Yc8ZdwgIfoczh50eslyOmKWujHsRPTe9F0KdkQmUYy2CYTv7vBWq`. Finance Ops retains the reporting read workflow. Ashford gives up the ability of this reporting analyst to assign `ashford-batch-exec` to newly created functions. Existing batch jobs should use a dedicated scheduler identity or deployment workflow with a narrowly scoped PassRole grant.

The independent policy-version chain remains a separate finding; this task cuts and proves one chain, not the whole estate. In the latest replay the temporary `AshfordCrossAcctReaderAccess` v3 test policy was restored to v1 and v3 deleted, recorded in the same CloudTrail object. Lambda invocation was denied as `lambda:Invoke` although the policy grants `lambda:InvokeFunction`; thus runtime execution was not demonstrated. The signed replay export preserves the remediation evidence. After export, `sudo ashford-reset` reported that the account was restored to its handover state and trail activity cleared.
