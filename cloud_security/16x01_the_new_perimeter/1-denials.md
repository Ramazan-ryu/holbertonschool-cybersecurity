# 1. Who Said No

This document attributes every authorization refusal encountered in the baseline Ashford estate to the exact governance layer, policy document, and statement that produced it. Because AWS IAM returns generic `AccessDenied` or `AccessDeniedException` responses across distinct evaluation mechanisms, each refusal below is derived strictly from the governing policy documents rather than inferred from error text.

---

## Summary of Governing Refusal Mechanisms

| # | Attempted Action & Target | Principal at Request Time | Governing Mechanism | Controlling Policy & Statement (`Sid`) |
|---|---|---|---|---|
| **1** | `kms:Decrypt` on `alias/ashford-reporting` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Direct / Explicit Policy Removal** (Identity Policy `Deny`) | `ReportingAnalystAccess` — `Sid: NoDecrypt` |
| **2** | `iam:CreateAccessKey` for `user/reporting-analyst` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Organization-Level Control Overriding a Lower-Level Grant** (SCP `Deny` > Identity `Allow`) | `AshfordGuardrails` (SCP) — `Sid: NoLongLivedKeys` |
| **3** | `s3:PutObject` on `ashford-reporting-ap7f3a/evidence/probe.txt` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Permissions Boundary Cap Granting Nothing by Itself** (Subtractive Intersection Cap) | `ReportingAnalystBoundary` — `Sid: CapRead` |
| **4** | `sqs:ReceiveMessage` on `ashford-dispatch-events` in `us-east-1` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Request-Condition Failure** (Context Key `aws:RequestedRegion` Mismatch) | `ReportingAnalystAccess` — `Sid: DispatchQueueHomeRegionOnly` |
| **5** | `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Caller Identity-Policy Resource Scope Restriction** (Missing Cross-Account Caller Grant) | `ReportingAnalystAccess` — `Sid: ChainB_AssumeReader` |
| **6** | `iam:CreateUser` for `user/proof` (unexported CLI session) | `arn:aws:iam::418274630117:user/reporting-analyst` | **Caller Identity-Policy Action Scope Restriction** (Request Signed by Unprivileged User Session) | `ReportingAnalystAccess` (All Statements) & `ReportingAnalystBoundary` (`Sid: CapRead`) |

---

## Refusal Attributions and Governing Policy Citations

### 1. `kms:Decrypt` — Direct / Explicit Policy Removal (Identity Policy Explicit Deny)

- **Attempted Request & Context:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `kms:Decrypt`
  - **Resource:** `alias/ashford-reporting` (KMS key in account `418274630117`, region `eu-west-1`)
  - **Reproducible Call:** `aws kms decrypt --ciphertext-blob fileb:///dev/null --key-id alias/ashford-reporting`
  - **Executed Outcome:** Refused (`AccessDeniedException`; CloudTrail `Decrypt` logged at `2026-11-19T03:26:46Z` and `2026-11-19T03:44:48Z`).
- **Governing Layer:** **Customer-Managed Identity Policy** (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess`).
- **Controlling Statement:**
  - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Locator (`Sid`):** `NoDecrypt`
  - **Effect:** `Deny`
  - **Action:** `"kms:Decrypt"`
  - **Resource:** `"*"`
  - **Condition:** None
- **Document-Based Evaluation:** Statement `NoDecrypt` matches every `kms:Decrypt` request across all KMS resources (`"*"`) with an unconditional `Effect: "Deny"`. Under IAM policy evaluation rules, an explicit `Deny` in an identity-based policy immediately terminates evaluation and overrides any `Allow` present in the same policy, the attached permissions boundary, or the account SCP.

---

### 2. `iam:CreateAccessKey` — Organization-Level Control Overriding a Lower-Level Grant (SCP Explicit Deny)

- **Attempted Request & Context:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `iam:CreateAccessKey`
  - **Resource:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Reproducible Call:** `aws iam create-access-key --user-name reporting-analyst`
  - **Executed Outcome:** Refused (`AccessDenied`; CloudTrail `CreateAccessKey` logged at `2026-11-19T03:27:32Z` and `2026-11-19T03:44:49Z`).
- **Governing Layer:** **AWS Organizations Service Control Policy (SCP)** (`AshfordGuardrails`, attached to account `418274630117`).
- **Relevant Statements Across Layers:**
  - **Lower-Level Identity Grant (Overridden):**
    - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
    - **Locator (`Sid`):** `SelfKeyManagement`
    - **Effect:** `Allow`
    - **Action:** `["iam:CreateAccessKey", "iam:ListAccessKeys"]`
    - **Resource:** `"arn:aws:iam::418274630117:user/reporting-analyst"`
    - **Condition:** None
  - **Permissions Boundary Ceiling (Does Not Block):**
    - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary`
    - **Locator (`Sid`):** `CapRead`
    - **Effect:** `Allow`
    - **Action:** Includes `"iam:*"`
    - **Resource:** `"*"`
  - **Controlling Organization-Level Statement:**
    - **Control:** Service Control Policy `AshfordGuardrails` (Account `418274630117`)
    - **Locator (`Sid`):** `NoLongLivedKeys`
    - **Effect:** `Deny`
    - **Action:** `["iam:CreateAccessKey", "iam:CreateLoginProfile"]`
    - **Resource:** `"*"`
    - **Condition:** None
- **Document-Based Evaluation:** Evaluating only the user's identity policy (`SelfKeyManagement`) and permissions boundary (`CapRead`) permits `iam:CreateAccessKey` on `user/reporting-analyst`. However, because account `418274630117` is governed by the organizational SCP `AshfordGuardrails`, statement `NoLongLivedKeys` applies an unconditional `Effect: "Deny"` to `iam:CreateAccessKey` on `Resource: "*"`. An SCP explicit `Deny` supersedes all account-level `Allow` grants, producing the refusal.

---

### 3. `s3:PutObject` — Permissions Boundary Cap Granting Nothing by Itself

- **Attempted Request & Context:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `s3:PutObject`
  - **Resource:** `arn:aws:s3:::ashford-reporting-ap7f3a/evidence/probe.txt`
  - **Reproducible Call:** `aws s3api put-object --bucket ashford-reporting-ap7f3a --key evidence/probe.txt --body /tmp/ashford-probe.txt`
  - **Executed Outcome:** Refused (`AccessDenied`; CloudTrail `PutObject` logged at `2026-11-19T05:31:31Z`).
- **Governing Layer:** **IAM Permissions Boundary** (`arn:aws:iam::418274630117:policy/ReportingAnalystBoundary`, attached as permissions boundary to `user/reporting-analyst`).
- **Relevant Statements Across Layers:**
  - **Identity Policy Grant (Capped):**
    - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
    - **Locator (`Sid`):** `ReportingReadWrite`
    - **Effect:** `Allow`
    - **Action:** `"s3:*"`
    - **Resource:** `["arn:aws:s3:::ashford-reporting-ap7f3a", "arn:aws:s3:::ashford-reporting-ap7f3a/*"]`
    - **Condition:** None
  - **Controlling Permissions Boundary Statement:**
    - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary`
    - **Locator (`Sid`):** `CapRead`
    - **Effect:** `Allow`
    - **Action:** `["s3:Get*", "s3:List*", "iam:*", "lambda:*", "sqs:*", "sts:AssumeRole"]` (permits only `s3:Get*` and `s3:List*` for S3)
    - **Resource:** `"*"`
    - **Condition:** None
- **Document-Based Evaluation:** A permissions boundary grants zero permissions by itself; it defines the maximum permission ceiling via set intersection (`Identity Policy ∩ Permissions Boundary`). While `ReportingReadWrite` grants `s3:*` on `arn:aws:s3:::ashford-reporting-ap7f3a/*`, `CapRead` limits S3 actions exclusively to `s3:Get*` and `s3:List*`. Because `s3:PutObject` does not match `s3:Get*` or `s3:List*`, the intersection omits `s3:PutObject` and refuses the write operation.

---

### 4. `sqs:ReceiveMessage` in `us-east-1` — Request-Condition Failure

- **Attempted Request & Context:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `sqs:ReceiveMessage`
  - **Resource:** `arn:aws:sqs:us-east-1:418274630117:ashford-dispatch-events`
  - **Request Context:** `aws:RequestedRegion = "us-east-1"`
  - **Reproducible Call:** `aws --region us-east-1 sqs receive-message --queue-url http://127.0.0.1:4566/418274630117/ashford-dispatch-events --max-number-of-messages 1`
  - **Executed Outcome:** Refused (`AccessDeniedException`; CloudTrail `ReceiveMessage` logged at `2026-11-19T03:26:14Z` and `2026-11-19T03:28:40Z`). By contrast, the identical call executed with `--region eu-west-1` (`aws:RequestedRegion = "eu-west-1"`) succeeded at `2026-11-19T06:13:56Z` (event ID `105611ba-fb7d-4f2a-94e9-04830ff1328b`).
- **Governing Layer:** **Identity Policy Condition Block** (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess`).
- **Controlling Statement:**
  - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Locator (`Sid`):** `DispatchQueueHomeRegionOnly`
  - **Effect:** `Allow`
  - **Action:** `["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]`
  - **Resource:** `"*"`
  - **Condition:** `{"StringEquals": {"aws:RequestedRegion": "eu-west-1"}}`
- **Document-Based Evaluation:** Statement `DispatchQueueHomeRegionOnly` matches `sqs:ReceiveMessage` on `Resource: "*"` only when the request context satisfies `StringEquals: {"aws:RequestedRegion": "eu-west-1"}`. When the request targets `us-east-1`, `aws:RequestedRegion` evaluates to `"us-east-1"`, failing the `StringEquals` check (`"us-east-1" != "eu-west-1"`). Because the condition fails, `DispatchQueueHomeRegionOnly` does not activate; no other statement in `ReportingAnalystAccess` grants SQS permissions, and `CapRead` (`sqs:*`) cannot supply a grant on its own.

---

### 5. Direct `sts:AssumeRole` into Dev Account — Caller Identity-Policy Resource Scope Restriction

- **Attempted Request & Context:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `sts:AssumeRole`
  - **Resource:** `arn:aws:iam::418274630228:role/ashford-dev-maintenance`
  - **Reproducible Call:** `aws sts assume-role --role-arn arn:aws:iam::418274630228:role/ashford-dev-maintenance --role-session-name boundary-review`
  - **Executed Outcome:** Refused (`AccessDenied`; CloudTrail `AssumeRole` logged at `2026-11-19T05:29:41Z`, event ID `4334331f-68e0-47f7-8cf1-ee37a287de94`).
- **Governing Layer:** **Caller Identity Policy Resource Scope** (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess` in account `418274630117`).
- **Relevant Statements Across Accounts:**
  - **Target Role Trust Policy (Account `418274630228` — Permits Account `418274630117`):**
    - **Resource Policy:** Trust policy on `arn:aws:iam::418274630228:role/ashford-dev-maintenance`
    - **Effect:** `Allow`
    - **Principal:** `{"AWS": "arn:aws:iam::418274630117:root"}`
    - **Action:** `"sts:AssumeRole"`
    - **Condition:** None
  - **Permissions Boundary Ceiling (Account `418274630117` — Does Not Block):**
    - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary` (`Sid: CapRead`)
    - **Effect:** `Allow`
    - **Action:** Includes `"sts:AssumeRole"`
    - **Resource:** `"*"`
  - **Controlling Caller Identity Statement (Account `418274630117` — Scoped Away from Dev Role):**
    - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
    - **Locator (`Sid`):** `ChainB_AssumeReader`
    - **Effect:** `Allow`
    - **Action:** `"sts:AssumeRole"`
    - **Resource:** `"arn:aws:iam::418274630117:role/ashford-crossacct-reader"`
    - **Condition:** None
- **Document-Based Evaluation:** Cross-account `sts:AssumeRole` requires an explicit `Allow` from **both** the target role's trust policy in account `418274630228` and the caller's identity policy in account `418274630117`. Although `ashford-dev-maintenance` trusts `arn:aws:iam::418274630117:root`, `ReportingAnalystAccess` contains only one `sts:AssumeRole` statement (`ChainB_AssumeReader`), whose `Resource` is pinned strictly to `arn:aws:iam::418274630117:role/ashford-crossacct-reader`. Because `arn:aws:iam::418274630228:role/ashford-dev-maintenance` is outside that resource scope and `CapRead` cannot grant permissions independently, the caller account refuses the request.

---

### 6. `iam:CreateUser` in the Unexported CLI Shell — Caller Identity-Policy Action Scope Restriction

- **Attempted Request & Context:**
  - **Signing Principal at Request Time:** `arn:aws:iam::418274630117:user/reporting-analyst` (executed after `aws sts assume-role` printed temporary credentials to stdout, before `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` were exported into the shell environment)
  - **Action:** `iam:CreateUser`
  - **Resource:** `arn:aws:iam::418274630117:user/proof`
  - **Reproducible Call:** `aws iam create-user --user-name proof`
  - **Executed Outcome:** Refused (`AccessDenied`; CloudTrail `CreateUser` logged at `2026-11-19T03:45:29Z` and `2026-11-19T06:15:05Z`, event ID `09d135bf-0589-419d-b20e-351f33ecea64`).
- **Governing Layer:** **Caller Identity Policy Action Scope** (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess`).
- **Controlling Policy Enumeration:**
  - **Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Complete Statement Set Attached to `user/reporting-analyst`:**
    - `Sid: DispatchQueueHomeRegionOnly` — `Allow` `sqs:GetQueueAttributes`, `sqs:GetQueueUrl`, `sqs:ReceiveMessage` on `*` (conditioned on `aws:RequestedRegion = "eu-west-1"`)
    - `Sid: NoDecrypt` — `Deny` `kms:Decrypt` on `*`
    - `Sid: SelfKeyManagement` — `Allow` `iam:CreateAccessKey`, `iam:ListAccessKeys` on `arn:aws:iam::418274630117:user/reporting-analyst`
    - `Sid: ReportingReadWrite` — `Allow` `s3:*` on `arn:aws:s3:::ashford-reporting-ap7f3a` and `arn:aws:s3:::ashford-reporting-ap7f3a/*`
    - `Sid: ChainA_Compute` — `Allow` `lambda:CreateFunction`, `lambda:InvokeFunction` on `*`
    - `Sid: ChainA_PassAndRun` — `Allow` `iam:PassRole` on `arn:aws:iam::418274630117:role/ashford-batch-exec`
    - `Sid: ChainB_AmendReaderPolicy` — `Allow` `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, `iam:DeletePolicyVersion` on `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess`
    - `Sid: ChainB_AssumeReader` — `Allow` `sts:AssumeRole` on `arn:aws:iam::418274630117:role/ashford-crossacct-reader`
- **Document-Based Evaluation:** Because temporary STS credentials had not been loaded into the CLI credential provider, the request was signed by `arn:aws:iam::418274630117:user/reporting-analyst`. None of the eight statements in `ReportingAnalystAccess` grants `iam:CreateUser` (the only user-management actions are `iam:CreateAccessKey` and `iam:ListAccessKeys` in `SelfKeyManagement` on `user/reporting-analyst`), and `ReportingAnalystBoundary` (`Sid: CapRead`, `iam:*`) acts only as a ceiling. Consequently, the request fails with an implicit identity-policy deny.

---

## What the Layering Reveals About Ashford's Governance Priorities

Examining which controls sit at which layer—and the exact actions, resources, and request contexts they constrain—reveals a deliberate, risk-differentiated governance design rather than random administration:

1. **Account-Wide Elimination of Static Long-Lived Credentials (`AshfordGuardrails` SCP — `Sid: NoLongLivedKeys`):**
   - **What is constrained:** `iam:CreateAccessKey` and `iam:CreateLoginProfile` across `Resource: "*"` for the entire AWS account `418274630117`.
   - **Risk reduced:** Prevents the creation or persistence of static IAM user access keys and console passwords anywhere in the account, even where individual user policies (such as `SelfKeyManagement` in `ReportingAnalystAccess`) explicitly grant self-service key rotation. Placing this at the SCP layer enforces an organization-wide invariant that cannot be bypassed by local identity policies.

2. **Separation of Bucket Ownership from Analyst Write Capability (`ReportingAnalystBoundary` — `Sid: CapRead` vs. `ReportingReadWrite`):**
   - **What is constrained:** S3 actions on `arn:aws:s3:::ashford-reporting-ap7f3a/*` are capped at `s3:Get*` and `s3:List*` by the permissions boundary, neutralizing the `s3:*` grant in `ReportingReadWrite`.
   - **Risk reduced:** Protects the integrity of reporting artifacts in `ashford-reporting-ap7f3a` against modification, tampering, or unauthorized staging (`s3:PutObject`, `s3:DeleteObject`) by the reporting analyst user, even when a team-level identity policy (`ReportingReadWrite`) is written overly broadly with `s3:*`.

3. **Protection of Encrypted Payloads from Reporting Identities (`ReportingAnalystAccess` — `Sid: NoDecrypt`):**
   - **What is constrained:** `kms:Decrypt` across `Resource: "*"`.
   - **Risk reduced:** Ensures `user/reporting-analyst` can inspect bucket metadata, list objects, and read unencrypted reporting outputs without being able to decrypt KMS-protected sensitive datasets in the same account.

4. **Data Residency and Blast-Radius Containment to Home Region (`ReportingAnalystAccess` — `Sid: DispatchQueueHomeRegionOnly`):**
   - **What is constrained:** SQS queue inspection and message consumption (`sqs:GetQueueAttributes`, `sqs:GetQueueUrl`, `sqs:ReceiveMessage`) outside `aws:RequestedRegion = "eu-west-1"`.
   - **Risk reduced:** Confines queue operations to Ashford's primary operating region (`eu-west-1`), preventing cross-region API usage or interaction with queues outside the home region boundary.

5. **Controlled Cross-Account Entry Point (`ChainB_AssumeReader` vs. `ashford-dev-maintenance` Trust Policy):**
   - **What is constrained:** Direct cross-account `sts:AssumeRole` from `user/reporting-analyst` into account `418274630228` (`ashford-dev-maintenance`), forcing cross-account access through a dedicated intermediary role (`arn:aws:iam::418274630117:role/ashford-crossacct-reader`).
   - **Risk reduced:** Centralizes cross-account access auditing and session chaining onto a single auditable role (`ashford-crossacct-reader`) rather than allowing individual IAM users to assume cross-account maintenance roles directly.

6. **Where Ashford's Governance Leaves Gaps (Privilege Escalation Blind Spots):**
   - While Ashford's layering tightly constrains **operational data and credential hygiene** (blocking S3 writes, KMS decryption, static IAM keys, cross-region SQS calls, and direct cross-account user assumption), its IAM administration boundaries contain two critical gaps: `ReportingAnalystBoundary` (`CapRead`) grants unconstrained `iam:*` and `lambda:*`, while `ReportingAnalystAccess` grants `iam:PassRole` on `ashford-batch-exec` (`ChainA_PassAndRun`) and `iam:CreatePolicyVersion` on `AshfordCrossAcctReaderAccess` (`ChainB_AmendReaderPolicy`). Ashford built strong guardrails against direct data tampering and static credential creation, but failed to cap IAM policy-version mutation and service-role handoff primitives.
