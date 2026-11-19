# 1. Who Said No

## Scope and method

This file attributes every authorization refusal in the two signed exports to the governance layer that produced it. Each attribution comes from the policy documents, not from the error text. The interface returns `AccessDenied` or `AccessDeniedException` for every mechanism, so the response alone cannot identify the layer.

The signing principal is `arn:aws:iam::418274630117:user/reporting-analyst` in every row. Each row is one distinct denied CloudTrail event. Times are UTC. The successful `eu-west-1` queue receive at `06:13:56Z` (event `105611ba-fb7d-4f2a-94e9-04830ff1328b`) is context only and is not counted.

## Mechanisms

| Code | Mechanism | How it removes a permission |
|---|---|---|
| M1 | Direct / explicit policy removal | An explicit `Effect: "Deny"` removes the action regardless of any `Allow` elsewhere. |
| M2 | Organization-level control overriding a lower-level grant | An SCP `Deny` overrides an identity-policy `Allow` that matches the request. |
| M3 | Permissions boundary cap that grants nothing by itself | Effective permission is `Identity Policy ∩ Permissions Boundary`. The boundary removes actions outside its ceiling and cannot add any. |
| M4 | No matching allow: request-condition, resource-scope, or action-scope non-match, including absence of any allow | No `Allow` statement's `Action`, `Resource`, or `Condition` matches the request. |

## Refusal ledger

23 denied events. M1 = 4, M2 = 4, M3 = 2, M4 = 13.

| # | UTC time · CloudTrail event | Principal | Attempted action → target, request context | Response | Mechanism | Governing statement |
|---|---|---|---|---|---|---|
| 1 | 03:26:14 · `b635493b-83d7-4852-9577-18547a88029c` | reporting-analyst | `sqs:ReceiveMessage` on `ashford-dispatch-events`, `aws:RequestedRegion = us-east-1` | AccessDeniedException | M4 (condition) | `ReportingAnalystAccess` / `DispatchQueueHomeRegionOnly` (S6) |
| 2 | 03:28:40 · `f3f0028d-d3f6-4777-b30f-757c7c78ed70` | reporting-analyst | `sqs:ReceiveMessage` on `ashford-dispatch-events`, `aws:RequestedRegion = us-east-1` | AccessDeniedException | M4 (condition) | S6 |
| 3 | 03:44:53 · `feaa3f80-4d73-41ea-bcf2-8cbdc85cf01c` | reporting-analyst | `sqs:ReceiveMessage` on `ashford-dispatch-events`, `aws:RequestedRegion = us-east-1` | AccessDeniedException | M4 (condition) | S6 |
| 4 | 03:47:02 · `4cdb7c8a-7004-47a0-b2fd-04b7a0566a99` | reporting-analyst | `sqs:ReceiveMessage` on `ashford-dispatch-events`, `aws:RequestedRegion = us-east-1`, `--max-number-of-messages 1` | AccessDeniedException | M4 (condition) | S6 |
| 5 | 06:13:58 · `ae85da75-39b4-4eb4-b112-15eca50a5b90` | reporting-analyst | `sqs:ReceiveMessage` on `ashford-dispatch-events`, `aws:RequestedRegion = us-east-1` | AccessDeniedException | M4 (condition) | S6 |
| 6 | 03:26:46 · `9cfd576b-33c3-421c-b0c7-e866e3f21ff9` | reporting-analyst | `kms:Decrypt` on `alias/ashford-reporting` | AccessDeniedException | M1 | `ReportingAnalystAccess` / `NoDecrypt` (S1) |
| 7 | 03:44:48 · `ba04bad4-ebfe-4d9a-9c0f-7d04c53ed5c2` | reporting-analyst | `kms:Decrypt` on `alias/ashford-reporting` | AccessDeniedException | M1 | S1 |
| 8 | 03:47:04 · `cdcfd40d-26cb-46d6-8f8e-ca0d0749c201` | reporting-analyst | `kms:Decrypt` on `alias/ashford-reporting` | AccessDeniedException | M1 | S1 |
| 9 | 06:14:01 · `028d77f5-68ff-4a17-a171-d9065651708d` | reporting-analyst | `kms:Decrypt` on `alias/ashford-reporting` | AccessDeniedException | M1 | S1 |
| 10 | 03:27:32 · `ddfe4ed2-ec10-4409-918f-28d4b4b520d8` | reporting-analyst | `iam:CreateAccessKey` on `user/reporting-analyst` | AccessDenied | M2 | SCP `AshfordGuardrails` / `NoLongLivedKeys` (S2), overriding S3 |
| 11 | 03:44:49 · `6f2a6985-c2da-4c40-a4a4-a1267385dca0` | reporting-analyst | `iam:CreateAccessKey` on `user/reporting-analyst` | AccessDenied | M2 | S2 over S3 |
| 12 | 03:47:06 · `5fe6aa05-9079-4cd8-98cb-4a239071b17f` | reporting-analyst | `iam:CreateAccessKey` on `user/reporting-analyst` | AccessDenied | M2 | S2 over S3 |
| 13 | 06:14:04 · `8f8d27c9-d9fa-4084-90fe-7460ae979aed` | reporting-analyst | `iam:CreateAccessKey` on `user/reporting-analyst` | AccessDenied | M2 | S2 over S3 |
| 14 | 05:31:31 · `de31c3a7-baa9-4ac7-81e7-885a147341a0` | reporting-analyst | `s3:PutObject` on `ashford-reporting-ap7f3a/evidence/probe.txt` | AccessDenied | M3 | `ReportingAnalystBoundary` / `CapRead` (S4), capping `ReportingReadWrite` (S5) |
| 15 | 06:15:02 · `c42f764c-a43d-4845-b638-d2728e01ccae` | reporting-analyst | `s3:PutObject` on `ashford-reporting-ap7f3a/evidence/probe.txt` | AccessDenied | M3 | S4 over S5 |
| 16 | 05:29:41 · `efbcd6ee-c980-4365-b58c-4f66c2e8ebc0` | reporting-analyst | `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance`, `--role-session-name boundary-review` | AccessDenied | M4 (resource scope) | `ReportingAnalystAccess` / `ChainB_AssumeReader` (S7) |
| 17 | 06:14:07 · `4334331f-68e0-47f7-8cf1-ee37a287de94` | reporting-analyst | `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance`, `--role-session-name task0-replay` | AccessDenied | M4 (resource scope) | S7 |
| 18 | 03:45:29 · `ea204ec9-128a-4361-8399-fafd9be61682` | reporting-analyst (original CLI credentials) | `iam:CreateUser` for `user/proof` | AccessDenied | M4 (action scope, no matching allow) | No statement lists `iam:CreateUser` (S8) |
| 19 | 06:15:05 · `09d135bf-0589-419d-b20e-351f33ecea64` | reporting-analyst (original CLI credentials) | `iam:CreateUser` for `ashford-wrong-session-proof` | AccessDenied | M4 (action scope, no matching allow) | S8 |
| 20 | 06:38:30 · `716e9646-d003-4279-bb5e-f149d84e3ce6` | reporting-analyst (original CLI credentials) | `iam:CreateUser` for `task0-original-cli-context` | AccessDenied | M4 (action scope, no matching allow) | S8 |
| 21 | 06:15:12 · `856cae85-1921-44d5-98e2-7954aa145d8a` | reporting-analyst | `lambda:Invoke` on `arn:aws:lambda:eu-west-1:418274630117:function:ashford-boundary-probe` | HTTP 403 AccessDenied | M4 (action scope, no matching allow) | No identity statement lists `lambda:Invoke`; `ChainA_Compute` lists `lambda:InvokeFunction` only (S8) |
| 22 | 05:33:11 · `962018c4-25ca-493a-9a9f-e012b6f5bb0e` | reporting-analyst | `lambda:CreateFunction` on `ashford-boundary-after-fix` with `--role arn:aws:iam::418274630117:role/ashford-batch-exec` | AccessDenied | M4 (action scope: `iam:PassRole` missing) | `ChainA_PassAndRun` absent after remediation (S9) |
| 23 | 06:41:25 · `3e317ddd-b30d-452c-aae7-497672061f69` | reporting-analyst | Same request as row 22 | AccessDenied | M4 (action scope: `iam:PassRole` missing) | S9 |

## Governing statements

Each statement lists its document, Effect, Action, Resource, and Condition so another analyst can reproduce the evaluation.

### S1. `ReportingAnalystAccess` / `NoDecrypt` (M1, rows 6–9)

- Document: `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
- Effect `Deny` · Action `kms:Decrypt` · Resource `*` · Condition none

```json
{ "Sid": "NoDecrypt", "Effect": "Deny", "Action": "kms:Decrypt", "Resource": "*" }
```

### S2. SCP `AshfordGuardrails` / `NoLongLivedKeys` (M2, rows 10–13)

- Document: Service Control Policy `AshfordGuardrails`, attached to account `418274630117`
- Effect `Deny` · Action `iam:CreateAccessKey`, `iam:CreateLoginProfile` · Resource `*` · Condition none

```json
{ "Sid": "NoLongLivedKeys", "Effect": "Deny",
  "Action": ["iam:CreateAccessKey", "iam:CreateLoginProfile"], "Resource": "*" }
```

### S3. `ReportingAnalystAccess` / `SelfKeyManagement` (matched, then overridden by S2)

- Effect `Allow` · Action `iam:CreateAccessKey`, `iam:ListAccessKeys` · Resource `arn:aws:iam::418274630117:user/reporting-analyst` · Condition none

```json
{ "Sid": "SelfKeyManagement", "Effect": "Allow",
  "Action": ["iam:CreateAccessKey", "iam:ListAccessKeys"],
  "Resource": "arn:aws:iam::418274630117:user/reporting-analyst" }
```

The allow matches the request. The SCP explicit deny in S2 overrides it.

### S4. `ReportingAnalystBoundary` / `CapRead` (M3, rows 14–15)

- Document: `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary`, attached as the permissions boundary of `user/reporting-analyst`
- Effect `Allow` as a ceiling only · Action `s3:Get*`, `s3:List*`, `iam:*`, `lambda:*`, `sqs:*`, `sts:AssumeRole` · Resource `*` · Condition none

```json
{ "Sid": "CapRead", "Effect": "Allow",
  "Action": ["s3:Get*", "s3:List*", "iam:*", "lambda:*", "sqs:*", "sts:AssumeRole"],
  "Resource": "*" }
```

Effective permission is the intersection of the identity policy and this ceiling. `s3:PutObject` matches neither `s3:Get*` nor `s3:List*`, so the intersection removes it.

### S5. `ReportingAnalystAccess` / `ReportingReadWrite` (capped by S4)

- Effect `Allow` · Action `s3:*` · Resource `arn:aws:s3:::ashford-reporting-ap7f3a` and `arn:aws:s3:::ashford-reporting-ap7f3a/*` · Condition none

```json
{ "Sid": "ReportingReadWrite", "Effect": "Allow", "Action": "s3:*",
  "Resource": ["arn:aws:s3:::ashford-reporting-ap7f3a",
               "arn:aws:s3:::ashford-reporting-ap7f3a/*"] }
```

### S6. `ReportingAnalystAccess` / `DispatchQueueHomeRegionOnly` (M4 condition, rows 1–5)

- Effect `Allow` · Action `sqs:GetQueueAttributes`, `sqs:GetQueueUrl`, `sqs:ReceiveMessage` · Resource `*` · Condition `StringEquals: {"aws:RequestedRegion": "eu-west-1"}`

```json
{ "Sid": "DispatchQueueHomeRegionOnly", "Effect": "Allow",
  "Action": ["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage"],
  "Resource": "*",
  "Condition": { "StringEquals": { "aws:RequestedRegion": "eu-west-1" } } }
```

For `us-east-1`, the condition evaluates `"us-east-1" == "eu-west-1"`, which is false. No other identity statement allows SQS actions.

### S7. `ReportingAnalystAccess` / `ChainB_AssumeReader` (M4 resource scope, rows 16–17)

- Effect `Allow` · Action `sts:AssumeRole` · Resource `arn:aws:iam::418274630117:role/ashford-crossacct-reader` · Condition none

```json
{ "Sid": "ChainB_AssumeReader", "Effect": "Allow", "Action": "sts:AssumeRole",
  "Resource": "arn:aws:iam::418274630117:role/ashford-crossacct-reader" }
```

The target `arn:aws:iam::418274630228:role/ashford-dev-maintenance` is outside this resource scope, so no caller-side allow matches. The target role's trust policy is necessary but not sufficient:

```json
{ "Effect": "Allow", "Principal": { "AWS": "arn:aws:iam::418274630117:root" },
  "Action": "sts:AssumeRole" }
```

The trust policy lets the caller account attempt assumption. It does not grant the caller permission to do so.

### S8. Identity statements for rows 18–21 (absence of allow)

The identity statements in `ReportingAnalystAccess` that can match any row in this file are:

- `DispatchQueueHomeRegionOnly` (S6)
- `NoDecrypt` (S1)
- `SelfKeyManagement` (S3)
- `ReportingReadWrite` (S5)
- `ChainA_Compute`: `lambda:CreateFunction`, `lambda:InvokeFunction` on `*`
- `ChainA_PassAndRun`: `iam:PassRole` on `arn:aws:iam::418274630117:role/ashford-batch-exec`
- `ChainB_AmendReaderPolicy`: `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, `iam:DeletePolicyVersion` on `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess`
- `ChainB_AssumeReader` (S7)

No statement lists `iam:CreateUser` or `lambda:Invoke`. The boundary (S4) cannot grant either, so rows 18–20 and row 21 have no matching allow at any time. Row 21 is attributed on the action name in the error. The function's resource-based policy was not among the supplied documents, so it was not evaluated.

### S9. Remediation: `ChainA_PassAndRun` removed

`ChainA_PassAndRun` is absent from the policy by the time of row 22 at `05:33:11`. Row 22 requests `lambda:CreateFunction` with `--role ashford-batch-exec`. `ChainA_Compute` allows `lambda:CreateFunction`, so the refused action is the `iam:PassRole` that the request needs on the passed role. No statement allows that action on that role, so the refusal is an action-scope non-match (M4). Rows 23 is the same request at `06:41:25`.

Rows 14–18 and 16 occur before `05:33:11`, but none of them needs `iam:PassRole`, so their attributions do not depend on when the removal happened. Rows 19–21 occur after `05:33:11`, and their attributions do not depend on `ChainA_PassAndRun` either.

## Excluded non-authorization errors

These are not IAM refusals and are not counted above:

- Malformed S3 request body: rejected by CLI validation before any AWS request.
- Missing Lambda ZIP file: rejected by CLI validation before any AWS request.
- One-character role session name: rejected by parameter validation.
- Lambda request signing failures: `SignatureDoesNotMatch`.
- Cleanup of a nonexistent policy version: `NoSuchEntity`.

## What the layering shows about Ashford's governance

This section states only what the statements show. It does not establish intent.

**Constrained classes:**

1. **Long-lived credentials account-wide** (S2). The SCP denies key and login-profile creation on every resource, even where a user policy allows self-service key creation (S3). The controls reduce the persistence of static credentials and push access toward temporary STS credentials.
2. **Writes to the reporting bucket** (S4 over S5). The identity policy grants `s3:*` on the bucket, and the boundary limits the ceiling to read and list. This is the clearest case in the estate of a cap placed over an over-broad allow.
3. **KMS decryption** (S1). The reporting user is explicitly denied `kms:Decrypt`. The documents show the control protects encrypted data from this identity. They do not show what that data is.
4. **Regional scope for queues** (S6). Queue receive is allowed only from `eu-west-1`, which confines consumption to the primary region.
5. **Cross-account entry** (S7). The reporting user can assume only the intermediary reader role, and cannot directly assume the dev maintenance role.

**Paths the same layering leaves open:**

- The boundary `CapRead` leaves `iam:*` and `lambda:*` uncapped (S4).
- `ChainA_PassAndRun` (`iam:PassRole` on the batch role) was allowed until it was removed (S9).
- `ChainB_AmendReaderPolicy` (`iam:CreatePolicyVersion` on the reader policy) remains allowed (S8). Through it, a user could change the policy that governs the reader role, which is the cross-account path the controls in item 5 are meant to narrow.

The documents do not show whether the boundary was added deliberately to cap `s3:*`, or whether the `iam:*` and policy-version paths are an accepted risk.
