# 1. Who Said No

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
