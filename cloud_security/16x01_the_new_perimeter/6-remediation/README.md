# 6. Remediation: Remove the Batch Role Handoff

## Change

The single risky edge chosen was `iam:PassRole` on the administrator execution role. Through the already-proven admin session, I created a new default version of `ReportingAnalystAccess` with only the `ChainA_PassAndRun` statement removed. The policy still contains `ChainA_Compute` and the reporting bucket read permissions. The boundary continues to cap the user. The exact policy before/after was derived from `get-policy-version`; the new version is v2 and is the current default.

Before change, the relevant statement was:

```json
{"Sid":"ChainA_PassAndRun","Effect":"Allow","Action":["iam:PassRole"],"Resource":"arn:aws:iam::418274630117:role/ashford-batch-exec"}
```

The revised document removes that statement. CloudTrail records `CreatePolicyVersion` at `2026-11-19T05:32:34Z` and `SetDefaultPolicyVersion` at `05:32:35Z` in `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0533Z_081bECEA9BDEd40D.json.gz`. `GetCallerIdentity` before and after the policy update remained the assumed admin session ARN.

## Refused chain

Before remediation, a valid zip and `ashford-batch-exec` role caused `CreateFunction` to succeed. After remediation, I checked `aws sts get-caller-identity` (still `reporting-analyst`) and repeated `aws lambda create-function --function-name ashford-boundary-after-fix --runtime python3.12 --role arn:aws:iam::418274630117:role/ashford-batch-exec --handler handler.handler --zip-file fileb:///tmp/probe.zip`. The service returned HTTP 403 `AccessDenied`, naming `lambda:CreateFunction`; CloudTrail records the denied event at `2026-11-19T05:33:11Z` in the object above. The request requires both Lambda creation and permission to pass the requested role; the handoff permission has been removed.

## Legitimate operation and cost

`aws s3 ls s3://ashford-reporting-ap7f3a/` still succeeded and returned `PRE reports/` (`ListObjects`, `05:33:14Z`, same CloudTrail object). Finance Ops retains the reporting read workflow. Ashford gives up the ability of this reporting analyst to assign `ashford-batch-exec` to newly created functions. Existing batch jobs should use a dedicated scheduler identity or deployment workflow with a narrowly scoped PassRole grant.

The independent policy-version chain remains a separate finding; this task cuts and proves one chain, not the whole estate. The temporary `AshfordCrossAcctReaderAccess` v2 test policy was restored to v1, and v2 was deleted (`DeletePolicyVersion`, `05:33:06Z`). Lambda `Invoke`/`DeleteFunction` returned `SignatureDoesNotMatch`, so direct cleanup through that emulator endpoint failed. After exporting the signed bundle, `sudo ashford-reset` reported that the account was restored to its handover state and trail activity cleared. The export preserves the pre-reset remediation and its Lambda signing errors; reset left the lab in its clean baseline.
