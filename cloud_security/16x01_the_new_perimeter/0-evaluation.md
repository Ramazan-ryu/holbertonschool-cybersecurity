# 0. Predict, Then Test

## Policy reading and predictions

This section records the authorization prediction for each request in the fresh replay. The prediction source is the handover policy documents and the request parameters listed here; the response records follow in the next section. Principal for the user requests: `arn:aws:iam::418274630117:user/reporting-analyst`, confirmed by `sts:GetCallerIdentity` before the replay.

The identity policy is `ReportingAnalystAccess`. The attached permissions boundary is `ReportingAnalystBoundary`, statement `CapRead`. Account `418274630117` has SCP `AshfordGuardrails` alongside `FullAWSAccess`. An identity allow must also survive the boundary and SCP; the boundary is a cap and grants nothing by itself. An explicit deny overrides an allow. For role assumption, the caller-side identity permission and receiver-side trust are separately required.

### 1. SQS receive in the configured home region — ALLOW

Request: `aws sqs receive-message --queue-url http://127.0.0.1:4566/418274630117/ashford-dispatch-events` with configured region `eu-west-1`.

`ReportingAnalystAccess`, `DispatchQueueHomeRegionOnly`:

```json
{"Effect":"Allow","Action":["sqs:GetQueueAttributes","sqs:GetQueueUrl","sqs:ReceiveMessage"],"Resource":"*","Condition":{"StringEquals":{"aws:RequestedRegion":"eu-west-1"}}}
```

The request region matches. `CapRead` allows `sqs:*` on `*`, and neither `NoDecrypt` nor `NoLongLivedKeys` matches SQS. Prediction: **ALLOW**.

### 2. Same SQS receive in `us-east-1` — DENY

The same conditional statement does not match because `aws:RequestedRegion` is `us-east-1`, not `eu-west-1`. No other identity statement allows `sqs:ReceiveMessage`. The boundary's SQS allowance cannot grant it independently, and the SCP has no SQS grant. Prediction: **DENY**, implicit identity-policy deny caused by the failed condition.

### 3. KMS Decrypt — DENY

Request: `kms:Decrypt` on `alias/ashford-reporting`.

`ReportingAnalystAccess`, `NoDecrypt`:

```json
{"Effect":"Deny","Action":"kms:Decrypt","Resource":"*"}
```

This explicit identity-policy deny applies regardless of other allows. Prediction: **DENY**.

### 4. Create an access key for the analyst — DENY

Request: `iam:CreateAccessKey` for `arn:aws:iam::418274630117:user/reporting-analyst`.

Identity statement `SelfKeyManagement` allows `iam:CreateAccessKey` and `iam:ListAccessKeys` on that exact user ARN. Boundary statement `CapRead` includes `iam:*` on `*`, so the boundary does not remove this grant. SCP statement `NoLongLivedKeys` says:

```json
{"Effect":"Deny","Action":["iam:CreateAccessKey","iam:CreateLoginProfile"],"Resource":"*"}
```

Prediction: **DENY**, explicitly by the SCP despite the identity allow.

### 5. Put an object in the reporting bucket — DENY

Request: `s3:PutObject` on `arn:aws:s3:::ashford-reporting-ap7f3a/evidence/probe.txt`.

Identity statement `ReportingReadWrite` allows `s3:*` on the bucket ARN and `arn:aws:s3:::ashford-reporting-ap7f3a/*`. Boundary `CapRead` permits only `s3:Get*` and `s3:List*` on `*`; it does not include `s3:PutObject`. There is no relevant SCP deny, but an SCP allow cannot replace the missing boundary permission. Prediction: **DENY** by the permissions-boundary cap.

### 6. Create a Lambda function passing `ashford-batch-exec` — ALLOW

Request: create a function in `eu-west-1` with role `arn:aws:iam::418274630117:role/ashford-batch-exec`.

`ChainA_Compute` allows `lambda:CreateFunction` on `*`. `ChainA_PassAndRun` allows `iam:PassRole` on the exact role ARN. `CapRead` includes `lambda:*` and `iam:*`; the SCP has no deny for either action. The role trust permits `lambda.amazonaws.com` to assume it, and `AshfordBatchExecAdmin` v1 allows `Action:"*"`, `Resource:"*"`. These documents predict authorization of function creation and role assignment. Prediction: **ALLOW**.

### 7. Invoke the created Lambda function — ALLOW for the IAM action in the policy

The request is Lambda function invocation. `ChainA_Compute` explicitly allows `lambda:InvokeFunction` on `*`. `CapRead` includes `lambda:*` and the SCP has no matching deny. The policy-derived prediction for IAM action `lambda:InvokeFunction` is **ALLOW**. This predicts authorization only, not successful runtime execution.

### 8. Directly assume the dev maintenance role — DENY

Request: `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance` as `reporting-analyst`.

`ChainB_AssumeReader` allows `sts:AssumeRole` only on `arn:aws:iam::418274630117:role/ashford-crossacct-reader`. The user boundary's STS allowance is only a cap. The dev role trust accepts account `418274630117`, but the caller identity policy does not allow this target ARN. Prediction: **DENY** by missing caller-side identity permission.

### 9. Change and assume the reader role — ALLOW

Request: create a default version of `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess` with `Allow`, `Action:"*"`, `Resource:"*"`, then assume `arn:aws:iam::418274630117:role/ashford-crossacct-reader`.

`ChainB_AmendReaderPolicy` allows `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, and `iam:DeletePolicyVersion` on that exact policy ARN. `CapRead` includes `iam:*`, and the SCP has no matching deny. `ChainB_AssumeReader` allows `sts:AssumeRole` on the exact role ARN; its trust names the reporting user. Prediction: both policy change and role assumption **ALLOW**. The resulting role session can perform actions in the new attached policy, except actions explicitly denied by the SCP.

### 10. CreateUser in original CLI context versus STS session

**10a. Original shell:** after `assume-role` prints credentials, call `iam:CreateUser` without configuring a new credential session. The CLI remains the reporting user; no identity statement allows `iam:CreateUser`. Prediction: **DENY**.

**10b. Actual reader-role session:** use the returned STS credentials, then call `iam:CreateUser` and assume the dev role. The reader role's changed default policy allows `*` on `*`; it has no attached boundary. The SCP does not deny CreateUser or AssumeRole, and the dev trust accepts the prod account. Prediction: **ALLOW** for both operations.

## Executed results (recorded after the prediction section)

The identifiers below locate events in the fresh replay's CloudTrail records. Calls made before the fresh replay are historical and are not claimed as having followed this prediction record.

1. **SQS, `eu-west-1`:** message returned. `ReceiveMessage`, `2026-11-19T06:13:56Z`, event `105611ba-fb7d-4f2a-94e9-04830ff1328b`. Prediction confirmed.
2. **SQS, `us-east-1`:** `AccessDeniedException`. `ReceiveMessage`, `06:13:58Z`, event `ae85da75-39b4-4eb4-b112-15eca50a5b90`. Prediction confirmed; only request region changed.
3. **KMS Decrypt:** `AccessDeniedException` for `kms:Decrypt`. `Decrypt`, `06:14:01Z`, event `028d77f5-68ff-4a17-a171-d9065651708d`. Prediction confirmed by explicit `NoDecrypt`.
4. **CreateAccessKey:** `AccessDenied` with explicit SCP-deny response. `CreateAccessKey`, `06:14:04Z`, event `8f8d27c9-d9fa-4084-90fe-7460ae979aed`. Prediction confirmed.
5. **PutObject:** `AccessDenied`, response says no permissions boundary allows `s3:PutObject`. `PutObject`, `06:15:02Z`, event `c42f764c-a43d-4845-b638-d2728e01ccae`. Prediction confirmed. An earlier malformed `--body f` attempt failed local CLI validation and is not authorization evidence.
6. **CreateFunction:** returned `arn:aws:lambda:eu-west-1:418274630117:function:ashford-boundary-probe` with the requested role. `CreateFunction`, `06:15:08Z`, event `88c062e5-36e4-4058-8192-90e750cc7341`. Prediction confirmed for creation and role assignment.
7. **Invoke:** HTTP 403 `AccessDenied`, naming `lambda:Invoke`, event `856cae85-1921-44d5-98e2-7954aa145d8a` at `06:15:12Z`. This differs from the policy-derived prediction for `lambda:InvokeFunction`: the endpoint evaluated the request under the distinct action string `lambda:Invoke`, for which no identity allow exists. This is the prediction divergence; the static policy text alone names `lambda:InvokeFunction`. Function runtime execution was not established.
8. **Direct dev AssumeRole:** `AccessDenied`, event `4334331f-68e0-47f7-8cf1-ee37a287de94` at `06:14:07Z`. Prediction confirmed; the identity permission is scoped to the reader role.
9. **Policy change and reader AssumeRole:** `CreatePolicyVersion` made default v2 with `Allow/*/*` at `06:15:55Z`, event `470c5222-ec60-4d00-9baf-526cee5857aa`; `AssumeRole` succeeded at `06:15:56Z`, event `37c3d6ff-b7af-46bd-a454-462e3b944c7b`. Caller identity changed from the reporting user to `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/task0-prediction-replay`. With those credentials, CreateUser and DeleteUser succeeded (events `3a924e0e-2f16-44d0-a67a-773a36d87b58` and `063cc197-ca58-473e-aee7-f6f1dcd3aba2`). The session then assumed dev; `GetCallerIdentity` confirmed `arn:aws:sts::418274630228:assumed-role/ashford-dev-maintenance/task0-dev-cross`. Prediction confirmed.
10. **CreateUser context check:** the original shell call was denied as `reporting-analyst` (event `09d135bf-0589-419d-b20e-351f33ecea64`, `06:15:05Z`); this confirms the CLI did not adopt printed STS credentials. The STS-backed CreateUser succeeded as described in item 9. Both predictions confirmed.

## The same statement, two outcomes

`DispatchQueueHomeRegionOnly` allowed `ReceiveMessage` in `eu-west-1` and denied it in `us-east-1`. The success and denial are events `105611ba-fb7d-4f2a-94e9-04830ff1328b` and `ae85da75-39b4-4eb4-b112-15eca50a5b90` in `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0614Z_778f22126fbb4fd4.json.gz`. Its `StringEquals` condition tests `aws:RequestedRegion`; the changed context value explains both consistent outcomes.
