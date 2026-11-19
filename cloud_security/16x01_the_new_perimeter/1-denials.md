# 1. Who Said No

<<<<<<< HEAD
This document attributes every authorization refusal encountered while evaluating Ashford's baseline estate to the governance layer, policy document, and statement (`Sid`) that produced the decision. Because AWS IAM returns uniform `AccessDenied` or `AccessDeniedException` responses across distinct evaluation mechanisms, every attribution below is derived strictly from the governing policy documents rather than inferred from interface error messages.

---

## Mapping Refusals to Ashford's Four Governance Mechanisms

Ashford's layered governance produces denials through four distinct mechanisms:

1. **Direct / Explicit Policy Removal:** An explicit `Effect: "Deny"` statement in an applicable policy unconditionally removes the permission.
2. **Organization-Level Control Overriding a Lower-Level Grant:** An account-level Service Control Policy (`AshfordGuardrails`) enforces an explicit `Effect: "Deny"` that overrides an `Effect: "Allow"` granted in a lower-level identity policy.
3. **Permissions Boundary Cap That Grants Nothing by Itself:** An attached permissions boundary (`ReportingAnalystBoundary`) defines a maximum ceiling (`Identity Policy ∩ Permissions Boundary`) without granting any permissions independently, blocking actions permitted by the identity policy whenever those actions fall outside the boundary ceiling.
4. **Request-Condition or Scope-Conditioned Statement Non-Match:** A conditional or tightly scoped `Effect: "Allow"` statement fails to match the request's runtime context (`Condition`) or target `Action`/`Resource` scope, leaving no matching `Allow` while the permissions boundary grants nothing by itself.

| # | Attempted Action & Target | Signing Principal | Governing Mechanism | Controlling Document & Statement (`Sid`) |
|---|---|---|---|---|
| **1** | `kms:Decrypt` on `alias/ashford-reporting` | `arn:aws:iam::418274630117:user/reporting-analyst` | **1. Direct / Explicit Policy Removal** | `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (`Sid: "NoDecrypt"`) |
| **2** | `iam:CreateAccessKey` on `user/reporting-analyst` | `arn:aws:iam::418274630117:user/reporting-analyst` | **2. Organization-Level Control Overriding a Lower-Level Grant** | Service Control Policy `AshfordGuardrails` (`Sid: "NoLongLivedKeys"`) |
| **3** | `s3:PutObject` on `ashford-reporting-ap7f3a/evidence/probe.txt` | `arn:aws:iam::418274630117:user/reporting-analyst` | **3. Permissions Boundary Cap That Grants Nothing by Itself** | `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary` (`Sid: "CapRead"`) |
| **4** | `sqs:ReceiveMessage` on `ashford-dispatch-events` (`us-east-1`) | `arn:aws:iam::418274630117:user/reporting-analyst` | **4. Request-Condition Failure** (`aws:RequestedRegion`) | `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (`Sid: "DispatchQueueHomeRegionOnly"`) |
| **5** | `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance` | `arn:aws:iam::418274630117:user/reporting-analyst` | **4. Scope-Conditioned Non-Match** (Caller `Resource` ARN Scope) | `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (`Sid: "ChainB_AssumeReader"`) |
| **6** | `iam:CreateUser` for `user/proof` (unexported CLI shell) | `arn:aws:iam::418274630117:user/reporting-analyst` | **4. Scope-Conditioned Non-Match** (Caller `Action` Scope) | `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (all 8 statements cited below) |

---

## Detailed Refusal Attributions and Reproducible Policy Citations

### 1. `kms:Decrypt` — Mechanism 1: Direct / Explicit Policy Removal

- **Request Context & Execution Record:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `kms:Decrypt`
  - **Resource:** `alias/ashford-reporting` (account `418274630117`, region `eu-west-1`)
  - **Reproducible Command:** `aws kms decrypt --ciphertext-blob fileb:///dev/null --key-id alias/ashford-reporting`
  - **Executed Result:** Refused (`AccessDeniedException`; CloudTrail `Decrypt` recorded at `2026-11-19T03:26:46Z` and `2026-11-19T03:44:48Z`).
- **Governing Layer:** Customer-Managed Identity Policy (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess`).
- **Governing Statement Citation:**
  - **Document:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Statement Locator:** `Sid: "NoDecrypt"`
  - **Effect:** `Deny`
  - **Action:** `"kms:Decrypt"`
  - **Resource:** `"*"`
  - **Condition:** None

        {
          "Sid": "NoDecrypt",
          "Effect": "Deny",
          "Action": "kms:Decrypt",
          "Resource": "*"
        }

- **Reproducible Evaluation:** Statement `NoDecrypt` matches `Action: "kms:Decrypt"` across `Resource: "*"` with an unconditional `Effect: "Deny"`. Under IAM evaluation precedence, an explicit `Deny` directly removes the permission regardless of any `Allow` in any policy layer.

---

### 2. `iam:CreateAccessKey` — Mechanism 2: Organization-Level Control Overriding a Lower-Level Grant

- **Request Context & Execution Record:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `iam:CreateAccessKey`
  - **Resource:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Reproducible Command:** `aws iam create-access-key --user-name reporting-analyst`
  - **Executed Result:** Refused (`AccessDenied`; CloudTrail `CreateAccessKey` recorded at `2026-11-19T03:27:32Z` and `2026-11-19T03:44:49Z`).
- **Governing Layer:** AWS Organizations Service Control Policy (`AshfordGuardrails`, attached to account `418274630117`).
- **Overridden Lower-Level Identity Statement Citation:**
  - **Document:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Statement Locator:** `Sid: "SelfKeyManagement"`
  - **Effect:** `Allow`
  - **Action:** `["iam:CreateAccessKey", "iam:ListAccessKeys"]`
  - **Resource:** `"arn:aws:iam::418274630117:user/reporting-analyst"`
  - **Condition:** None

        {
          "Sid": "SelfKeyManagement",
          "Effect": "Allow",
          "Action": [
            "iam:CreateAccessKey",
            "iam:ListAccessKeys"
          ],
          "Resource": "arn:aws:iam::418274630117:user/reporting-analyst"
        }

- **Permissions Boundary Ceiling Check:** `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary` (`Sid: "CapRead"`) grants nothing by itself; its ceiling specification (`"iam:*"` on `Resource: "*"`) does not subtract `iam:CreateAccessKey` from `SelfKeyManagement`.
- **Controlling Organization-Level Statement Citation:**
  - **Document:** Service Control Policy `AshfordGuardrails` (attached to account `418274630117`)
  - **Statement Locator:** `Sid: "NoLongLivedKeys"`
  - **Effect:** `Deny`
  - **Action:** `["iam:CreateAccessKey", "iam:CreateLoginProfile"]`
  - **Resource:** `"*"`
  - **Condition:** None

        {
          "Sid": "NoLongLivedKeys",
          "Effect": "Deny",
          "Action": [
            "iam:CreateAccessKey",
            "iam:CreateLoginProfile"
          ],
          "Resource": "*"
        }

- **Reproducible Evaluation:** At the user level, `SelfKeyManagement` explicitly grants `iam:CreateAccessKey` on `arn:aws:iam::418274630117:user/reporting-analyst`, and the permissions boundary ceiling does not remove it. However, the organizational SCP `AshfordGuardrails` (`Sid: "NoLongLivedKeys"`) applies an unconditional `Effect: "Deny"` to `iam:CreateAccessKey` on `Resource: "*"`. Because an SCP explicit `Deny` overrides every account-level `Allow`, the organization control produces the refusal.

---

### 3. `s3:PutObject` — Mechanism 3: Permissions Boundary Cap That Grants Nothing by Itself

- **Request Context & Execution Record:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `s3:PutObject`
  - **Resource:** `arn:aws:s3:::ashford-reporting-ap7f3a/evidence/probe.txt`
  - **Reproducible Command:** `aws s3api put-object --bucket ashford-reporting-ap7f3a --key evidence/probe.txt --body /tmp/ashford-probe.txt`
  - **Executed Result:** Refused (`AccessDenied`; CloudTrail `PutObject` recorded at `2026-11-19T05:31:31Z`).
- **Governing Layer:** IAM Permissions Boundary (`arn:aws:iam::418274630117:policy/ReportingAnalystBoundary`, attached as permissions boundary to `user/reporting-analyst`).
- **Capped Identity Policy Statement Citation:**
  - **Document:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Statement Locator:** `Sid: "ReportingReadWrite"`
  - **Effect:** `Allow`
  - **Action:** `"s3:*"`
  - **Resource:** `["arn:aws:s3:::ashford-reporting-ap7f3a", "arn:aws:s3:::ashford-reporting-ap7f3a/*"]`
  - **Condition:** None

        {
          "Sid": "ReportingReadWrite",
          "Effect": "Allow",
          "Action": "s3:*",
          "Resource": [
            "arn:aws:s3:::ashford-reporting-ap7f3a",
            "arn:aws:s3:::ashford-reporting-ap7f3a/*"
          ]
        }

- **Controlling Permissions Boundary Citation:**
  - **Document:** `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary`
  - **Statement Locator:** `Sid: "CapRead"`
  - **Effect:** `Allow` (defines the maximum ceiling only; grants no permissions independently)
  - **Action:** `["s3:Get*", "s3:List*", "iam:*", "lambda:*", "sqs:*", "sts:AssumeRole"]`
  - **Resource:** `"*"`
  - **Condition:** None

        {
          "Sid": "CapRead",
          "Effect": "Allow",
          "Action": [
            "s3:Get*",
            "s3:List*",
            "iam:*",
            "lambda:*",
            "sqs:*",
            "sts:AssumeRole"
          ],
          "Resource": "*"
        }

- **Reproducible Evaluation:** `ReportingAnalystBoundary` grants zero permissions on its own; it restricts effective permissions to the intersection `Identity Policy ∩ Permissions Boundary`. Although `ReportingReadWrite` grants `s3:*` on `arn:aws:s3:::ashford-reporting-ap7f3a/*`, `CapRead` restricts S3 actions in the ceiling exclusively to `s3:Get*` and `s3:List*`. Because `s3:PutObject` matches neither `s3:Get*` nor `s3:List*`, the intersection drops `s3:PutObject` and refuses the write operation.

---

### 4. `sqs:ReceiveMessage` in `us-east-1` — Mechanism 4: Request-Condition Failure

- **Request Context & Execution Record:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `sqs:ReceiveMessage`
  - **Resource:** `arn:aws:sqs:us-east-1:418274630117:ashford-dispatch-events`
  - **Request Context Value:** `aws:RequestedRegion = "us-east-1"`
  - **Reproducible Command:** `aws --region us-east-1 sqs receive-message --queue-url http://127.0.0.1:4566/418274630117/ashford-dispatch-events --max-number-of-messages 1`
  - **Executed Result:** Refused (`AccessDeniedException`; CloudTrail `ReceiveMessage` recorded at `2026-11-19T03:26:14Z` and `2026-11-19T03:28:40Z`). Executing the identical operation with `--region eu-west-1` (`aws:RequestedRegion = "eu-west-1"`) succeeded at `2026-11-19T06:13:56Z` (CloudTrail event ID `105611ba-fb7d-4f2a-94e9-04830ff1328b`).
- **Governing Layer:** Identity Policy Condition Block (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess`).
- **Controlling Statement Citation:**
  - **Document:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Statement Locator:** `Sid: "DispatchQueueHomeRegionOnly"`
  - **Effect:** `Allow`
  - **Action:** `["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]`
  - **Resource:** `"*"`
  - **Condition:** `{"StringEquals": {"aws:RequestedRegion": "eu-west-1"}}`

        {
          "Sid": "DispatchQueueHomeRegionOnly",
          "Effect": "Allow",
          "Action": [
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl",
            "sqs:ReceiveMessage"
          ],
          "Resource": "*",
          "Condition": {
            "StringEquals": {
              "aws:RequestedRegion": "eu-west-1"
            }
          }
        }

- **Reproducible Evaluation:** `DispatchQueueHomeRegionOnly` matches `sqs:ReceiveMessage` on `Resource: "*"` only when `StringEquals: {"aws:RequestedRegion": "eu-west-1"}` evaluates to true. For the `us-east-1` request, `aws:RequestedRegion` is `"us-east-1"`, failing `"us-east-1" == "eu-west-1"`. Because the condition fails, the statement does not match, no other statement in `ReportingAnalystAccess` covers SQS, and `ReportingAnalystBoundary` (`Sid: "CapRead"`) grants nothing by itself.

---

### 5. Direct `sts:AssumeRole` into Dev Account — Mechanism 4: Scope-Conditioned Non-Match (`Resource` Scope)

- **Request Context & Execution Record:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `sts:AssumeRole`
  - **Resource:** `arn:aws:iam::418274630228:role/ashford-dev-maintenance`
  - **Reproducible Command:** `aws sts assume-role --role-arn arn:aws:iam::418274630228:role/ashford-dev-maintenance --role-session-name boundary-review`
  - **Executed Result:** Refused (`AccessDenied`; CloudTrail `AssumeRole` recorded at `2026-11-19T05:29:41Z`, event ID `4334331f-68e0-47f7-8cf1-ee37a287de94`).
- **Governing Layer:** Caller Identity Policy (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess` in account `418274630117`).
- **Target Role Trust Policy Citation (Account `418274630228` — Permits Account `418274630117`):**
  - **Document:** Trust policy attached to `arn:aws:iam::418274630228:role/ashford-dev-maintenance`
  - **Effect:** `Allow`
  - **Principal:** `{"AWS": "arn:aws:iam::418274630117:root"}`
  - **Action:** `"sts:AssumeRole"`
  - **Condition:** None

        {
          "Effect": "Allow",
          "Principal": {
            "AWS": "arn:aws:iam::418274630117:root"
          },
          "Action": "sts:AssumeRole"
        }

- **Controlling Caller Identity Statement Citation (Account `418274630117`):**
  - **Document:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Statement Locator:** `Sid: "ChainB_AssumeReader"`
  - **Effect:** `Allow`
  - **Action:** `"sts:AssumeRole"`
  - **Resource:** `"arn:aws:iam::418274630117:role/ashford-crossacct-reader"`
  - **Condition:** None

        {
          "Sid": "ChainB_AssumeReader",
          "Effect": "Allow",
          "Action": "sts:AssumeRole",
          "Resource": "arn:aws:iam::418274630117:role/ashford-crossacct-reader"
        }

- **Reproducible Evaluation:** Cross-account `sts:AssumeRole` requires an explicit `Allow` from both the target role's trust policy in account `418274630228` and the caller's identity policy in account `418274630117`. Although `ashford-dev-maintenance` trusts `arn:aws:iam::418274630117:root`, the sole `sts:AssumeRole` statement in `ReportingAnalystAccess` (`Sid: "ChainB_AssumeReader"`) scopes `Resource` strictly to `"arn:aws:iam::418274630117:role/ashford-crossacct-reader"`. Because `arn:aws:iam::418274630228:role/ashford-dev-maintenance` falls outside that resource scope—and `ReportingAnalystBoundary` (`Sid: "CapRead"`) grants nothing by itself—no caller-side `Allow` matches.

---

### 6. `iam:CreateUser` in the Unexported CLI Shell — Mechanism 4: Scope-Conditioned Non-Match (`Action` Scope)

- **Request Context & Execution Record:**
  - **Signing Principal:** `arn:aws:iam::418274630117:user/reporting-analyst` (executed in the original shell before `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` from `AssumeRole` were exported)
  - **Action:** `iam:CreateUser`
  - **Resource:** `arn:aws:iam::418274630117:user/proof`
  - **Reproducible Command:** `aws iam create-user --user-name proof`
  - **Executed Result:** Refused (`AccessDenied`; CloudTrail `CreateUser` recorded at `2026-11-19T03:45:29Z` and `2026-11-19T06:15:05Z`, event ID `09d135bf-0589-419d-b20e-351f33ecea64`).
- **Governing Layer:** Caller Identity Policy (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess`).
- **Controlling Policy Statement Enumeration (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess`):**
  - `Sid: "DispatchQueueHomeRegionOnly"` — `Effect: "Allow"`, `Action: ["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]`, `Resource: "*"`, `Condition: {"StringEquals": {"aws:RequestedRegion": "eu-west-1"}}`
  - `Sid: "NoDecrypt"` — `Effect: "Deny"`, `Action: "kms:Decrypt"`, `Resource: "*"`, `Condition: None`
  - `Sid: "SelfKeyManagement"` — `Effect: "Allow"`, `Action: ["iam:CreateAccessKey", "iam:ListAccessKeys"]`, `Resource: "arn:aws:iam::418274630117:user/reporting-analyst"`, `Condition: None`
  - `Sid: "ReportingReadWrite"` — `Effect: "Allow"`, `Action: "s3:*"`, `Resource: ["arn:aws:s3:::ashford-reporting-ap7f3a", "arn:aws:s3:::ashford-reporting-ap7f3a/*"]`, `Condition: None`
  - `Sid: "ChainA_Compute"` — `Effect: "Allow"`, `Action: ["lambda:CreateFunction", "lambda:InvokeFunction"]`, `Resource: "*"`, `Condition: None`
  - `Sid: "ChainA_PassAndRun"` — `Effect: "Allow"`, `Action: "iam:PassRole"`, `Resource: "arn:aws:iam::418274630117:role/ashford-batch-exec"`, `Condition: None`
  - `Sid: "ChainB_AmendReaderPolicy"` — `Effect: "Allow"`, `Action: ["iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion", "iam:DeletePolicyVersion"]`, `Resource: "arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess"`, `Condition: None`
  - `Sid: "ChainB_AssumeReader"` — `Effect: "Allow"`, `Action: "sts:AssumeRole"`, `Resource: "arn:aws:iam::418274630117:role/ashford-crossacct-reader"`, `Condition: None`
- **Reproducible Evaluation:** Because temporary STS credentials had not yet been loaded into the CLI environment, the request was signed by `arn:aws:iam::418274630117:user/reporting-analyst`. None of the eight statements in `ReportingAnalystAccess` includes `iam:CreateUser` in its `Action` scope, and `ReportingAnalystBoundary` (`Sid: "CapRead"`) grants nothing by itself, resulting in a refusal.

---

## What the Layering Reveals About Ashford's Governance Priorities

Grounded strictly in the statements and layer placement cited above, Ashford's governance design targets specific operational and credential risks while leaving distinct control-plane blind spots:

1. **Account-Wide Elimination of Static Long-Lived Credentials (`AshfordGuardrails` SCP — `Sid: "NoLongLivedKeys"`):**
   - **Constrained Actions & Resources:** `iam:CreateAccessKey` and `iam:CreateLoginProfile` across `Resource: "*"` in account `418274630117`.
   - **Risk Addressed:** Prevents principals from minting persistent IAM access keys or console passwords anywhere in the account—even where a local identity policy (`SelfKeyManagement`) explicitly grants self-service key creation—enforcing reliance on temporary STS credentials.

2. **Immutable Read-Only Ceiling on Reporting Data (`ReportingAnalystBoundary` — `Sid: "CapRead"` vs. `ReportingReadWrite`):**
   - **Constrained Actions & Resources:** S3 write and delete operations (`s3:PutObject`, `s3:DeleteObject`, etc.) on `arn:aws:s3:::ashford-reporting-ap7f3a/*`, capped at `s3:Get*` and `s3:List*`.
   - **Risk Addressed:** Protects the integrity of reporting objects in `ashford-reporting-ap7f3a` against tampering or unauthorized uploads by `user/reporting-analyst`, neutralizing the overly broad `s3:*` grant in `ReportingReadWrite`.

3. **Cryptographic Isolation of Encrypted Payloads (`ReportingAnalystAccess` — `Sid: "NoDecrypt"`):**
   - **Constrained Actions & Resources:** `kms:Decrypt` across `Resource: "*"`.
   - **Risk Addressed:** Allows the reporting user to list and read unencrypted bucket metadata and files while blocking decryption of KMS-protected datasets stored in the same environment.

4. **Regional Containment of Queue Operations (`ReportingAnalystAccess` — `Sid: "DispatchQueueHomeRegionOnly"`):**
   - **Constrained Actions & Context:** `sqs:GetQueueAttributes`, `sqs:GetQueueUrl`, and `sqs:ReceiveMessage` whenever `aws:RequestedRegion` is not `"eu-west-1"`.
   - **Risk Addressed:** Confines queue inspection and message consumption strictly to Ashford's primary operating region (`eu-west-1`).

5. **Channeled Cross-Account Entry Point (`ChainB_AssumeReader` vs. `ashford-dev-maintenance` Trust Policy):**
   - **Constrained Actions & Resources:** Direct `sts:AssumeRole` from `user/reporting-analyst` to `arn:aws:iam::418274630228:role/ashford-dev-maintenance`, restricting assumption to `arn:aws:iam::418274630117:role/ashford-crossacct-reader`.
   - **Risk Addressed:** Prevents individual IAM users from assuming cross-account maintenance roles directly, funneling cross-account transitions through a single intermediary role (`ashford-crossacct-reader`).

6. **Control-Plane Gaps Exposed by the Layering:**
   - While Ashford placed strong guardrails on data-plane S3 writes (`CapRead`), KMS decryption (`NoDecrypt`), static credential creation (`NoLongLivedKeys`), and cross-region SQS calls (`DispatchQueueHomeRegionOnly`), `ReportingAnalystBoundary` (`CapRead`) leaves `iam:*` and `lambda:*` uncapped, and `ReportingAnalystAccess` grants `iam:PassRole` on `ashford-batch-exec` (`ChainA_PassAndRun`) and `iam:CreatePolicyVersion` on `AshfordCrossAcctReaderAccess` (`ChainB_AmendReaderPolicy`). Ashford tightly constrained operational data and static credential risks, but left control-plane policy-version mutation and service-role handoff primitives unconstrained.
=======
## Reconciliable authorization-refusal log

Each row is one distinct denied API event from the two signed exports. The signing principal is `arn:aws:iam::418274630117:user/reporting-analyst` in every row; the API error names this user. Repeated attempts are listed separately.

| # | Time and unique CloudTrail locator | Attempted request, target, and response | Governing layer and exact statement |
|---|---|---|---|
| 1 | `03:26:14Z`; event `b635493b-83d7-4852-9577-18547a88029c`; request `JEK9UANj5Z2adoFk2ZbElupDg2NEdEqBIbGGKTEUqTeaBYckuJm7` | `aws --region us-east-1 sqs receive-message --queue-url http://127.0.0.1:4566/418274630117/ashford-dispatch-events`; `sqs:ReceiveMessage` on queue `ashford-dispatch-events`; `AccessDeniedException`. | Identity policy `ReportingAnalystAccess`, `DispatchQueueHomeRegionOnly`: `Allow`, action includes `sqs:ReceiveMessage`, resource `*`, condition `StringEquals aws:RequestedRegion=eu-west-1`. Actual request region was `us-east-1`, so condition did not match; no other identity allow. Boundary `CapRead` (`Allow`, `sqs:*`, resource `*`) is a cap, not a grant. Implicit identity deny. |
| 2 | `03:28:40Z`; event `f3f0028d-d3f6-4777-b30f-757c7c78ed70`; request `knO2roZLvtDC97SuxAqN0YbvcYUBclUqGYAr1I1OE7zj1BUpr49s` | `aws --region us-east-1 sqs receive-message --queue-url .../ashford-dispatch-events`; same queue/action and context; `AccessDeniedException`. | Same exact statement and condition as row 1. The captured queue URL is abbreviated in the event; queue name and denied action are recorded. `aws:RequestedRegion=us-east-1` fails the required `eu-west-1`; implicit identity deny. |
| 3 | `03:44:53Z`; event `feaa3f80-4d73-41ea-bcf2-8cbdc85cf01c`; request `oJsGR5LB7lHSXmevv32KgQQhCzCdlLU6pGv9fcP5C7gj5y83UzI7` | `aws --region us-east-1 sqs receive-message --queue-url .../ashford-dispatch-events`; same queue/action and context; `AccessDeniedException`. | Same exact statement and condition as row 1. The request-region condition fails; no other identity allow applies. |
| 4 | `03:47:02Z`; event `4cdb7c8a-7004-47a0-b2fd-04b7a0566a99`; request `d7nCzR5s6q3i2X64YwH5vXwNGVQ25s8pYWigSYJ4DGDQqC9N6exf` | `aws --region us-east-1 sqs receive-message --queue-url http://127.0.0.1:4566/418274630117/ashford-dispatch-events --max-number-of-messages 1`; same queue/action and context; `AccessDeniedException`. | Same exact statement and condition as row 1. `StringEquals` is false for `us-east-1`; implicit identity deny. |
| 5 | `06:13:58Z`; event `ae85da75-39b4-4eb4-b112-15eca50a5b90`; request `1OE7zj1BUpr49snq7HvSFOu3hYUQAcplHWhJuVF5NFL32Yz7rVYG` | Same queue receive request with `--region us-east-1`; target queue `ashford-dispatch-events`; `AccessDeniedException`. | Same exact statement and condition as row 1. `aws:RequestedRegion=us-east-1` fails the allow condition; implicit identity deny. |
| 6 | `03:26:46Z`; event `9cfd576b-33c3-421c-b0c7-e866e3f21ff9`; request `7gy6IqgEPPcucKabXfj3UOA9DTGOmuJfK6XU6cAtuszjZfoErLA7` | `aws kms decrypt --ciphertext-blob fileb:///dev/null --key-id alias/ashford-reporting`; `kms:Decrypt` on `alias/ashford-reporting`; `AccessDeniedException`. | Identity policy `ReportingAnalystAccess`, `NoDecrypt`: `Deny`, action `kms:Decrypt`, resource `*`, no condition. Explicit identity deny. |
| 7 | `03:44:48Z`; event `ba04bad4-ebfe-4d9a-9c0f-7d04c53ed5c2`; request `zDrFwqjgZFuxPu3LOtrtSfXVZiXOcJPFWrKFJmjAxQmzmKxC4brT` | Same KMS Decrypt command and key; `AccessDeniedException`. | Same `NoDecrypt` statement as row 6: unconditional `Deny` for `kms:Decrypt` on `*`. |
| 8 | `03:47:04Z`; event `cdcfd40d-26cb-46d6-8f8e-ca0d0749c201`; request `ghKAyI1rs4J0kbX8vtFE5bqT7YW7HwtitsdK79odTgl0iqNRYY70` | Same KMS Decrypt command and key; `AccessDeniedException`. | Same `NoDecrypt` statement as row 6: unconditional `Deny` for `kms:Decrypt` on `*`. |
| 9 | `06:14:01Z`; event `028d77f5-68ff-4a17-a171-d9065651708d`; request `wsk28Fw4QipgCr6pdgFnLf3jGRXx5nUgiCje6xoLSynOy7MKQtbH` | Same KMS Decrypt command and key; `AccessDeniedException`. | Same `NoDecrypt` statement as row 6: unconditional `Deny` for `kms:Decrypt` on `*`. |
| 10 | `03:27:32Z`; event `ddfe4ed2-ec10-4409-918f-28d4b4b520d8`; request `GSeHf6b80SJd0KYH9haS2LSSltlgcQr6hXd8ngRHCQFtEbyUIbzQ` | `aws iam create-access-key --user-name reporting-analyst`; target IAM user `arn:aws:iam::418274630117:user/reporting-analyst`; `AccessDenied`. | SCP `AshfordGuardrails`, `NoLongLivedKeys`: `Deny`, actions `iam:CreateAccessKey` and `iam:CreateLoginProfile`, resource `*`, no condition. Identity policy `SelfKeyManagement` allows CreateAccessKey on this exact user; boundary `CapRead` includes `iam:*`. SCP explicit deny overrides the identity allow. |
| 11 | `03:44:49Z`; event `6f2a6985-c2da-4c40-a4a4-a1267385dca0`; request `vXNXvdXw7qG3ppcsCQvz614Cf71qSMpCoRvfFoDg8hZ1cIPDS12B` | Same CreateAccessKey command and target; `AccessDenied`. | Same `NoLongLivedKeys` SCP deny as row 10; it overrides `SelfKeyManagement`. |
| 12 | `03:47:06Z`; event `5fe6aa05-9079-4cd8-98cb-4a239071b17f`; request `HJ1jjLNGSllwUNlFYmvfNNO4beidB1mBZB12JIM9my5Cktt5dGYq` | Same CreateAccessKey command and target; `AccessDenied`. | Same `NoLongLivedKeys` SCP deny as row 10; it overrides `SelfKeyManagement`. |
| 13 | `06:14:04Z`; event `8f8d27c9-d9fa-4084-90fe-7460ae979aed`; request `tutbNk5ugiCF7bSrIx7F2S7ZaEIJvVUiFy9unNXu2F8RHCRh16d1` | Same CreateAccessKey command and target; `AccessDenied`. | Same `NoLongLivedKeys` SCP deny as row 10; it overrides `SelfKeyManagement`. |
| 14 | `05:31:31Z`; event `de31c3a7-baa9-4ac7-81e7-885a147341a0`; request `cbnEDIdKtqUzdQEfaXzEWBkQBi3MkJKY1LFQY8nc5nabDq2y31hO` | `aws s3api put-object --bucket ashford-reporting-ap7f3a --key evidence/probe.txt --body /tmp/ashford-probe.txt`; resource `arn:aws:s3:::ashford-reporting-ap7f3a/evidence/probe.txt`; `AccessDenied`. | Boundary `ReportingAnalystBoundary`, `CapRead`: `Allow`, actions include only S3 `Get*`/`List*`, resource `*`. Identity `ReportingReadWrite` allows `s3:*` on this bucket and its objects, but the boundary intersection excludes `s3:PutObject`. |
| 15 | `06:15:02Z`; event `c42f764c-a43d-4845-b638-d2728e01ccae`; request `yHo9XrfXBfa4gDtumjQJj2ttOgyMym29UjfyAvF9fSgLsKvWb9PA` | Same PutObject command, bucket, key, and `AccessDenied` response. | Same `CapRead` boundary cap as row 14; no matching S3 Put permission survives the identity/boundary intersection. |
| 16 | `05:29:41Z`; event `efbcd6ee-c980-4365-b58c-4f66c2e8ebc0`; request `29XHmZ0gnfqR2qFSOxU97TC0eDIpHj6fi7NiajNXAyNXM5F1ALDK` | `aws sts assume-role --role-arn arn:aws:iam::418274630228:role/ashford-dev-maintenance --role-session-name boundary-review`; target dev role in account `418274630228`; `AccessDenied`. | Caller identity policy `ReportingAnalystAccess`, `ChainB_AssumeReader`: `Allow`, action `sts:AssumeRole`, resource only `arn:aws:iam::418274630117:role/ashford-crossacct-reader`. Dev trust accepts prod account root, but does not add caller permission. Target ARN mismatch causes caller-side implicit deny. |
| 17 | `06:14:07Z`; event `4334331f-68e0-47f7-8cf1-ee37a287de94`; request `nOVrfLqHwg2BOhwv1A1G8tTQcvyRLNQpEbnfOCR8v45OGU4v4sCb` | `aws sts assume-role --role-arn arn:aws:iam::418274630228:role/ashford-dev-maintenance --role-session-name task0-replay`; same target; `AccessDenied`. | Same caller policy statement and resource mismatch as row 16. The destination trust's `Allow` for `arn:aws:iam::418274630117:root` is not the source identity grant. |
| 18 | `03:45:29Z`; event `ea204ec9-128a-4361-8399-fafd9be61682`; request `lKKmZ2rAwnSfHIzYOkEIbYiVAAUPK813hRrUu9q4WwHPW1e111uC` | `aws iam create-user --user-name proof`; target `arn:aws:iam::418274630117:user/proof`; signed by the original reporting user; `AccessDenied`. | `ReportingAnalystAccess` has no statement whose `Action` includes `iam:CreateUser`; `CapRead` cannot grant it. CLI was still using the user's credentials after STS printed a separate role credential set. Implicit identity-policy deny. |
| 19 | `06:15:05Z`; event `09d135bf-0589-419d-b20e-351f33ecea64`; request `MsjACIWaVVItfV4INLBDh8T189Ebf4Xt8SrRcZcz5fXTXDmQpYUk` | `aws iam create-user --user-name ashford-wrong-session-proof`; target user in account `418274630117`; signed by reporting user; `AccessDenied`. | Same absence of `iam:CreateUser` in all eight identity statements as row 18; boundary does not grant. The request was made in the original CLI session, not as the assumed role. |
| 20 | `06:38:30Z`; event `716e9646-d003-4279-bb5e-f149d84e3ce6`; request `cf8pu2pjyTvrj5clsWxtO1PGPC8OsyWtF1wx58Au1UDVKFwb4Rat` | `aws iam create-user --user-name task0-original-cli-context`; target user in account `418274630117`; signed by reporting user; `AccessDenied`. | Same missing identity allow for `iam:CreateUser` as row 18. The CLI caller identity remained the user. |
| 21 | `06:15:12Z`; event `856cae85-1921-44d5-98e2-7954aa145d8a`; request `nrkXFaWh5TmaoBhQOi88T3B8CkjQ2bGWONvGBbzIDo10Ym2Ch3Ui` | `aws lambda invoke --function-name ashford-boundary-probe /tmp/ashford-invoke.json --region eu-west-1`; function `arn:aws:lambda:eu-west-1:418274630117:function:ashford-boundary-probe`; HTTP 403 `AccessDenied`, names `lambda:Invoke`. | Identity statement `ChainA_Compute` allows `lambda:CreateFunction` and `lambda:InvokeFunction` on `*`, but no statement allows the exact evaluated action `lambda:Invoke`. Boundary `CapRead` includes `lambda:*` but cannot grant it. Identity-policy implicit deny; this response does not prove runtime execution. |
| 22 | `05:33:11Z`; event `962018c4-25ca-493a-9a9f-e012b6f5bb0e`; request `1iV1B6ghDKK9a1GPHRnSpC1qITS3ZkpSxCLqd68MOo5qN1AaMNtm` | `aws lambda create-function --function-name ashford-boundary-after-fix --runtime python3.12 --role arn:aws:iam::418274630117:role/ashford-batch-exec --handler handler.handler --zip-file fileb:///tmp/probe.zip`; `AccessDenied` for `lambda:CreateFunction`. | Remediated `ReportingAnalystAccess` removed `ChainA_PassAndRun` (`iam:PassRole` on the batch role). The user could no longer pass the requested role; this was the intended authorization refusal. |
| 23 | `06:41:25Z`; event `3e317ddd-b30d-452c-aae7-497672061f69`; request `XpxjjFFTmP7KtjodsutsgVv9uPeGvbVIQUDIOgjOGpc5BUj9raXu` | Same post-remediation CreateFunction request and role as row 22; `AccessDenied` for `lambda:CreateFunction`. | Same remediation: `ChainA_Compute` still allowed CreateFunction, but the effective identity policy no longer allowed `iam:PassRole` on `ashford-batch-exec`. Boundary cannot restore the removed handoff grant. |

## Excluded non-authorization errors

The malformed S3 body and missing Lambda ZIP failed local CLI validation before an AWS authorization request. The one-character role session name failed parameter validation. Lambda signing failures returned `SignatureDoesNotMatch`; an attempted cleanup of a nonexistent policy version returned `NoSuchEntity`. These are not IAM refusals and are not counted in the 23 rows.

## Governance interpretation

The refusal pattern shows that Ashford specifically restricts KMS decryption, creation of long-lived credentials, S3 writes by the reporting user, queue use outside `eu-west-1`, and direct role assumption outside the reader-role ARN. These controls target confidentiality, data integrity, credential persistence, regional operation, and cross-account entry. The separate policy-version and service-role findings show that these scoped controls do not eliminate privilege paths formed by combining individually allowed actions.
>>>>>>> 0f74f69 ( 16x01 The New Parameters)
