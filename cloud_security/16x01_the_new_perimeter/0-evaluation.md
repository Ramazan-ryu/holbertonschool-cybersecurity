# 0. Predict, Then Test

## Ordering and method

The supplied terminal history already contained API calls made before I inspected the handover documents. I cannot honestly claim that those historical calls were preceded by a recorded prediction. After reading `ReportingAnalystAccess`, `ReportingAnalystBoundary`, and `AshfordGuardrails`, I wrote down the following predictions before running the corresponding fresh checks. This limitation is part of the result, rather than a prediction reconstructed and presented as contemporaneous.

## Predictions and observed results

Principal: `arn:aws:iam::418274630117:user/reporting-analyst` (confirmed by `aws sts get-caller-identity`).

| Call / condition | Prediction from documents | Observed response | Reconciliation |
|---|---|---|---|
| `aws --region eu-west-1 sqs receive-message --queue-url http://127.0.0.1:4566/418274630117/ashford-dispatch-events` | Allow: `DispatchQueueHomeRegionOnly` requires `aws:RequestedRegion = eu-west-1`. | Message returned; CloudTrail `ReceiveMessage` at `2026-11-19T03:25:36Z`, no error. | Correct. |
| Same `ReceiveMessage` with `--region us-east-1` | Deny: the allow statement's condition will not match. | `AccessDeniedException`; CloudTrail at `03:26:14Z` and `03:28:40Z`. | Correct. The statement is conditional, not inconsistent. The default CLI region is `eu-west-1`. |
| `aws kms decrypt --ciphertext-blob fileb:///dev/null --key-id alias/ashford-reporting` | Deny: `NoDecrypt` explicitly denies `kms:Decrypt`. | `AccessDeniedException`; CloudTrail `Decrypt` at `03:26:46Z` and `03:44:48Z`. | Correct. |
| `aws iam create-access-key --user-name reporting-analyst` | Deny: identity policy allows it, but SCP `NoLongLivedKeys` explicitly denies it. | `AccessDenied`; CloudTrail `CreateAccessKey` at `03:27:32Z`, `03:44:49Z`. | Correct. The identity allow does not override an SCP deny. |
| `aws s3api put-object --bucket ashford-reporting-ap7f3a --key evidence/probe.txt --body /tmp/ashford-probe.txt` | Deny: identity policy says `s3:*`, while the boundary only permits S3 Get/List. | `AccessDenied`; CloudTrail `PutObject` at `05:31:31Z`. | Correct. The earlier supplied attempt had a missing local file and never reached AWS; it was not evidence of a policy decision. |
| Create Lambda using `ashford-batch-exec` before remediation | Allow: `ChainA_PassAndRun` grants PassRole, `ChainA_Compute` grants Lambda operations, and the boundary includes `iam:*` and `lambda:*`. | `CreateFunction` returned ARN `arn:aws:lambda:eu-west-1:418274630117:function:ashford-boundary-probe`; CloudTrail success at `03:47:52Z`. | Correct for creation/role assignment. Invocation was attempted but the endpoint returned `SignatureDoesNotMatch`, so runtime execution was not independently confirmed. |
| Create Lambda with the same role after remediation | Deny: the source policy no longer grants PassRole to `ashford-batch-exec`. | `AccessDenied` on `CreateFunction` at `05:33:11Z`. | Correct. The role handoff edge was removed. |
| Create default version of `AshfordCrossAcctReaderAccess`, then assume that role | Allow: `ChainB_AmendReaderPolicy`, `ChainB_AssumeReader`, and the role trust permit the two requests. | `CreatePolicyVersion` produced default `v2` with `Action:"*"`; `AssumeRole` succeeded. A boto3 session using returned credentials had caller ARN `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/chain-proof` and successfully created then deleted a temporary IAM user. | Correct. The supplied CLI `CreateUser proof` denial at `03:45:29Z` was a credentials-context mistake: `get-caller-identity` still returned the user. A real assumed-role session proved the privilege. |

## The same statement, two answers

`DispatchQueueHomeRegionOnly` in `ReportingAnalystAccess` allows `sqs:ReceiveMessage` only when `aws:RequestedRegion` equals `eu-west-1`. The call without an explicit region used the configured home region and returned the settlement message. The `us-east-1` request did not satisfy the condition and was implicitly denied. CloudTrail locators are `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0326Z_a23AFC0A9cc09a1A.json.gz` (success) and `...T0326Z_a23AFC0A9cc09a1A.json.gz` / `...T0329Z_d5EFd2d98D5ceEf5.json.gz` (denials). The policy behaves consistently; the request context differs.

## Other mismatches in the supplied history

The first Lambda attempt could not load `f.zip`; the client rejected it before the service call. The later `Invoke` response for `rpt` was `SignatureDoesNotMatch`, not an IAM denial. Likewise, the early `CreateUser proof` call used the original user credentials after a successful STS response; the AWS CLI does not replace credentials just because `assume-role` printed them. Both findings came from reading the caller identity and service response, not guessing from the command's intention.
