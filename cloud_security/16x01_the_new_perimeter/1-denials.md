# 1. Who Said No

## Scope and method

This file attributes every authorization refusal in the two signed exports to the governance layer that produced it. Each attribution comes from the policy documents, not from the error text. The interface returns `AccessDenied` or `AccessDeniedException` for every mechanism, so the response alone cannot identify the layer.

The signing principal is `arn:aws:iam::418274630117:user/reporting-analyst` in every refusal. Repeated attempts are listed separately because each is a distinct API event in CloudTrail. Times are UTC.

Successful calls, such as the `eu-west-1` queue receive at `06:13:56Z` (event `105611ba-fb7d-4f2a-94e9-04830ff1328b`), are context only and are not counted.

## Governance mechanisms in Ashford's estate

| Code | Mechanism | How it removes a permission | Where it lives in this estate |
|---|---|---|---|
| M1 | Direct / explicit policy removal | An explicit `Effect: "Deny"` removes the action regardless of any `Allow` elsewhere. | `ReportingAnalystAccess`, `Sid: NoDecrypt` |
| M2 | Organization-level control overriding a lower-level grant | An SCP `Deny` overrides an `Allow` in the identity policy. | SCP `AshfordGuardrails`, `Sid: NoLongLivedKeys`, overriding `ReportingAnalystAccess`, `Sid: SelfKeyManagement` |
| M3 | Permissions boundary cap that grants nothing by itself | Effective permission is `Identity Policy ∩ Permissions Boundary`. The boundary only removes actions outside its ceiling. | `ReportingAnalystBoundary`, `Sid: CapRead`, capping `ReportingAnalystAccess`, `Sid: ReportingReadWrite` |
| M4 | Request-condition or scope-conditioned non-match | The `Allow` exists but its `Condition`, `Action`, or `Resource` does not match the request. | `ReportingAnalystAccess`, `Sid: DispatchQueueHomeRegionOnly` (condition); `Sid: ChainB_AssumeReader` (resource) |

**Note on implicit denies.** Some refusals occur because no statement allows the action at all. AWS treats this as an implicit deny, which is not an explicit `Deny` and not one of the four mechanisms above. This file places those refusals under M4 as "scope non-match" because no `Allow` covers the action. Strictly, they are implicit denies, and they are labelled as such in the ledger.

## Refusal ledger

23 distinct denied API events. Counts by mechanism: M1 = 4, M2 = 4, M3 = 2, M4 = 13 (of which 3 are implicit denies, rows 18–20, and 1 is a probable implicit deny, row 21).

| # | UTC time · CloudTrail event | Attempted request → target | Response | Mechanism | Governing statement |
|---|---|---|---|---|---|
| 1 | 03:26:14 · `b635493b-83d7-4852-9577-18547a88029c` | `sqs:ReceiveMessage` on `ashford-dispatch-events`, `--region us-east-1` | AccessDeniedException | M4 (condition) | `ReportingAnalystAccess` / `DispatchQueueHomeRegionOnly` |
| 2 | 03:28:40 · `f3f0028d-d3f6-4777-b30f-757c7c78ed70` | Same as 1 | AccessDeniedException | M4 (condition) | Same |
| 3 | 03:44:53 · `feaa3f80-4d73-41ea-bcf2-8cbdc85cf01c` | Same as 1 | AccessDeniedException | M4 (condition) | Same |
| 4 | 03:47:02 · `4cdb7c8a-7004-47a0-b2fd-04b7a0566a99` | Same as 1, `--max-number-of-messages 1` | AccessDeniedException | M4 (condition) | Same |
| 5 | 06:13:58 · `ae85da75-39b4-4eb4-b112-15eca50a5b90` | Same as 1 | AccessDeniedException | M4 (condition) | Same |
| 6 | 03:26:46 · `9cfd576b-33c3-421c-b0c7-e866e3f21ff9` | `kms:Decrypt` on `alias/ashford-reporting` | AccessDeniedException | M1 | `ReportingAnalystAccess` / `NoDecrypt` |
| 7 | 03:44:48 · `ba04bad4-ebfe-4d9a-9c0f-7d04c53ed5c2` | Same as 6 | AccessDeniedException | M1 | Same |
| 8 | 03:47:04 · `cdcfd40d-26cb-46d6-8f8e-ca0d0749c201` | Same as 6 | AccessDeniedException | M1 | Same |
| 9 | 06:14:01 · `028d77f5-68ff-4a17-a171-d9065651708d` | Same as 6 | AccessDeniedException | M1 | Same |
| 10 | 03:27:32 · `ddfe4ed2-ec10-4409-918f-28d4b4b520d8` | `iam:CreateAccessKey` on `user/reporting-analyst` | AccessDenied | M2 | SCP `AshfordGuardrails` / `NoLongLivedKeys` |
| 11 | 03:44:49 · `6f2a6985-c2da-4c40-a4a4-a1267385dca0` | Same as 10 | AccessDenied | M2 | Same |
| 12 | 03:47:06 · `5fe6aa05-9079-4cd8-98cb-4a239071b17f` | Same as 10 | AccessDenied | M2 | Same |
| 13 | 06:14:04 · `8f8d27c9-d9fa-4084-90fe-7460ae979aed` | Same as 10 | AccessDenied | M2 | Same |
| 14 | 05:31:31 · `de31c3a7-baa9-4ac7-81e7-885a147341a0` | `s3:PutObject` on `ashford-reporting-ap7f3a/evidence/probe.txt` | AccessDenied | M3 | `ReportingAnalystBoundary` / `CapRead` (cap) against `ReportingAnalystAccess` / `ReportingReadWrite` |
| 15 | 06:15:02 · `c42f764c-a43d-4845-b638-d2728e01ccae` | Same as 14 | AccessDenied | M3 | Same |
| 16 | 05:29:41 · `efbcd6ee-c980-4365-b58c-4f66c2e8ebc0` | `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance` | AccessDenied | M4 (resource scope) | `ReportingAnalystAccess` / `ChainB_AssumeReader` |
| 17 | 06:14:07 · `4334331f-68e0-47f7-8cf1-ee37a287de94` | Same as 16, `--role-session-name task0-replay` | AccessDenied | M4 (resource scope) | Same |
| 18 | 03:45:29 · `ea204ec9-128a-4361-8399-fafd9be61682` | `iam:CreateUser` for `user/proof`, from the original CLI credentials | AccessDenied | M4 (action scope; implicit deny) | No statement in `ReportingAnalystAccess` includes `iam:CreateUser` |
| 19 | 06:15:05 · `09d135bf-0589-419d-b20e-351f33ecea64` | `iam:CreateUser` for `ashford-wrong-session-proof`, from the original CLI credentials | AccessDenied | M4 (action scope; implicit deny) | Same |
| 20 | 06:38:30 · `716e9646-d003-4279-bb5e-f149d84e3ce6` | `iam:CreateUser` for `task0-original-cli-context` | AccessDenied | M4 (action scope; implicit deny) | Same |
| 21 | 06:15:12 · `856cae85-1921-44d5-98e2-7954aa145d8a` | `aws lambda invoke` on `ashford-boundary-probe` (eu-west-1) | HTTP 403 AccessDenied, names `lambda:Invoke` | M4 (probable implicit deny; see open item A) | `ChainA_Compute` allows `lambda:InvokeFunction`, not `lambda:Invoke` |
| 22 | 05:33:11 · `962018c4-25ca-493a-9a9f-e012b6f5bb0e` | `lambda:CreateFunction` with `--role ashford-batch-exec` | AccessDenied | M4 (scope; see open items B and C) | Remediated `ReportingAnalystAccess` without `ChainA_PassAndRun` |
| 23 | 06:41:25 · `3e317ddd-b30d-452c-aae7-497672061f69` | Same as 22 | AccessDenied | M4 (scope; see open items B and C) | Same |

## Governing statements (reproducible citations)

Each statement below is cited with its Effect, Action, Resource, and Condition, so another analyst can reproduce the evaluation.

### S1. `ReportingAnalystAccess` / `NoDecrypt` (M1, rows 6–9)

- Document: `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
- Effect `Deny` · Action `kms:Decrypt` · Resource `*` · Condition none

```json
{ "Sid": "NoDecrypt", "Effect": "Deny", "Action": "kms:Decrypt", "Resource": "*" }
```

An explicit deny removes the action regardless of any allow in another policy layer.

### S2. SCP `AshfordGuardrails` / `NoLongLivedKeys` (M2, rows 10–13)

- Document: Service Control Policy `AshfordGuardrails`, attached to account `418274630117`
- Effect `Deny` · Action `iam:CreateAccessKey`, `iam:CreateLoginProfile` · Resource `*` · Condition none

```json
{ "Sid": "NoLongLivedKeys", "Effect": "Deny",
  "Action": ["iam:CreateAccessKey", "iam:CreateLoginProfile"], "Resource": "*" }
```

This overrides the lower-level allow in S3 below.

### S3. `ReportingAnalystAccess` / `SelfKeyManagement` (overridden by S2)

- Effect `Allow` · Action `iam:CreateAccessKey`, `iam:ListAccessKeys` · Resource `arn:aws:iam::418274630117:user/reporting-analyst` · Condition none

```json
{ "Sid": "SelfKeyManagement", "Effect": "Allow",
  "Action": ["iam:CreateAccessKey", "iam:ListAccessKeys"],
  "Resource": "arn:aws:iam::418274630117:user/reporting-analyst" }
```

The identity allow is present and matches. The SCP deny overrides it.

### S4. `ReportingAnalystBoundary` / `CapRead` (M3, rows 14–15; also present in rows 1–5 and 10–13)

- Document: `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary`, attached as the permissions boundary of `user/reporting-analyst`
- Effect `Allow` (a ceiling only; grants nothing by itself) · Action `s3:Get*`, `s3:List*`, `iam:*`, `lambda:*`, `sqs:*`, `sts:AssumeRole` · Resource `*` · Condition none

```json
{ "Sid": "CapRead", "Effect": "Allow",
  "Action": ["s3:Get*", "s3:List*", "iam:*", "lambda:*", "sqs:*", "sts:AssumeRole"],
  "Resource": "*" }
```

The effective permission is the intersection of the identity policy and this ceiling. `s3:PutObject` matches neither `s3:Get*` nor `s3:List*`, so the intersection removes it.

### S5. `ReportingAnalystAccess` / `ReportingReadWrite` (capped by S4)

- Effect `Allow` · Action `s3:*` · Resource `arn:aws:s3:::ashford-reporting-ap7f3a`, `arn:aws:s3:::ashford-reporting-ap7f3a/*` · Condition none

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

For `us-east-1`, the condition evaluates to `"us-east-1" == "eu-west-1"`, which is false. No other identity statement covers SQS.

### S7. `ReportingAnalystAccess` / `ChainB_AssumeReader` (M4 resource scope, rows 16–17)

- Effect `Allow` · Action `sts:AssumeRole` · Resource `arn:aws:iam::418274630117:role/ashford-crossacct-reader` · Condition none

```json
{ "Sid": "ChainB_AssumeReader", "Effect": "Allow", "Action": "sts:AssumeRole",
  "Resource": "arn:aws:iam::418274630117:role/ashford-crossacct-reader" }
```

The target `arn:aws:iam::418274630228:role/ashford-dev-maintenance` is outside this resource scope, so no caller-side allow matches. The target's trust policy is a separate, necessary but insufficient, condition:

```json
{ "Effect": "Allow", "Principal": { "AWS": "arn:aws:iam::418274630117:root" },
  "Action": "sts:AssumeRole" }
```

Trust permits the caller account to attempt assumption. It does not grant the caller permission to do so.

### S8. Action-scope evidence for rows 18–20 (`iam:CreateUser`)

The eight statements in `ReportingAnalystAccess` at the time of these attempts are:

- `DispatchQueueHomeRegionOnly`: SQS get/receive, `eu-west-1` only (S6)
- `NoDecrypt`: deny `kms:Decrypt` (S1)
- `SelfKeyManagement`: key create/list on own user (S3)
- `ReportingReadWrite`: `s3:*` on the reporting bucket (S5)
- `ChainA_Compute`: `lambda:CreateFunction`, `lambda:InvokeFunction` on `*`
- `ChainA_PassAndRun`: `iam:PassRole` on `arn:aws:iam::418274630117:role/ashford-batch-exec`
- `ChainB_AmendReaderPolicy`: `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, `iam:DeletePolicyVersion` on `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess`
- `ChainB_AssumeReader`: S7

None includes `iam:CreateUser`. S4 cannot grant it, so the request is refused with no matching allow.

### S9. Post-remediation change for rows 22–23

Rows 22 and 23 record that `ChainA_PassAndRun` was removed from `ReportingAnalystAccess`. That removal is the cause of the refusal, not the `CreateFunction` statement, which still exists.

## Excluded non-authorization errors

These were not IAM refusals and are not counted in the 23 rows:

- Malformed S3 body: failed CLI validation before any AWS request.
- Missing Lambda ZIP: failed CLI validation before any AWS request.
- One-character role session name: failed parameter validation.
- Lambda signing failures: `SignatureDoesNotMatch`.
- Cleanup of a nonexistent policy version: `NoSuchEntity`.

## What the layering says about Ashford

The following is bounded to what the statements and refusals show. It does not establish intent.

**Classes Ashford constrained:**

1. **Long-lived credentials, account-wide** (S2). The SCP denies `iam:CreateAccessKey` and `iam:CreateLoginProfile` on all resources, even where a user policy grants self-service key creation (S3). The documents show the control reduces the persistence of static credentials and pushes access toward temporary STS credentials.
2. **Writes to the reporting bucket** (S4 over S5). The identity policy grants `s3:*` on the bucket, and the boundary limits the ceiling to read and list. The documents show an effort to block writes to reporting data by this user, despite a broader grant. This is the clearest case in the estate of a cap added on top of an over-broad allow.
3. **KMS decryption** (S1). The reporting user is explicitly denied `kms:Decrypt`. The documents show the control protects encrypted data from this identity, but they do not show what data is encrypted.
4. **Regional scope for queues** (S6). Queue receive is allowed only from `eu-west-1`. The documents suggest this confines consumption to the primary region.
5. **Cross-account entry** (S7). The reporting user can assume only the intermediary reader role. The dev role's trust does not extend to direct assumption by this user. The documents suggest cross-account entry is routed through one role.

**Gaps the same layering leaves open:**

- The boundary `CapRead` leaves `iam:*` and `lambda:*` uncapped (S4).
- `ChainA_PassAndRun` (`iam:PassRole` on the batch execution role) and `ChainB_AmendReaderPolicy` (`iam:CreatePolicyVersion` on the reader policy) are allowed in the pre-remediation state (S8).
- A user who can amend the reader policy or pass a privileged role can reach permissions the individual denials were meant to block. The scoped controls do not close these paths.

**What the documents do not show:** whether the boundary was added deliberately to cap `s3:*` or added to a broader design. Whether the `iam:*` gap is an oversight or an accepted risk. The file records these as open questions rather than conclusions.

## Discrepancies and open items

**A. Row 21 action name.** The refusal names `lambda:Invoke`. IAM's action for `lambda:Invoke` in CLI calls is `lambda:InvokeFunction`, and `ChainA_Compute` allows that action. If the evaluated action really was `lambda:InvokeFunction`, the M4 "implicit deny" attribution is wrong, and the denial came from another layer, such as a resource-based policy on the function. The attribution in the ledger stands only if the evaluated action name is confirmed from the full CloudTrail record. This needs verification before row 21 is treated as settled.

**B. Row 22 and 23 denied action.** The ledger records "AccessDenied for `lambda:CreateFunction`". Passing a role to a function requires `iam:PassRole` on that role, so the missing permission is most likely `iam:PassRole` on `ashford-batch-exec`, not `lambda:CreateFunction`. The error text should be checked to confirm which action was denied.

**C. Timeline conflict for the remediation.** Row 22 (05:33:11) is recorded as post-remediation, but rows 14–19 (05:31–06:15) are recorded against the pre-remediation statement set, which still includes `ChainA_PassAndRun`. Either the 05:33 timestamp is wrong, or the eight-statement set cited in S8 is not the state at 06:15. The remediation time needs to be fixed before the rows can be reconciled.

**D. Event ID mismatches.** The earlier draft cited event `4334331f-68e0-47f7-8cf1-ee37a287de94` at 05:29:41 for the first `AssumeRole`. In the ledger, that event ID belongs to the 06:14:07 attempt (row 17), and the 05:29:41 attempt is `efbcd6ee-c980-4365-b58c-4f66c2e8ebc0` (row 16). Similarly, the earlier draft cited `09d135bf-...` at 03:45:29, but in the ledger that ID belongs to 06:15:05 (row 19), and the 03:45:29 attempt is `ea204ec9-...` (row 18). The ledger's pairings should be used.

**E. Implicit denies counted as M4.** The four-mechanism model has no class for an action with no matching allow. Rows 18–20 and probably 21 are implicit denies. They are placed under M4 for scope reasons, and this placement should be read with that caveat.

**F. Governance statements change.** The eight-statement listing in S8 is the pre-remediation state. The remediated `ReportingAnalystAccess` must be read separately before any analysis of the current state.
