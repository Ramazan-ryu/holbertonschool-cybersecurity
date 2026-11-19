# 1. Who Said No

This document attributes every authorization refusal encountered while evaluating Ashford's baseline estate to the governance layer, policy document, and statement (`Sid`) that produced the decision. Because the API interface returns uniform `AccessDenied` or `AccessDeniedException` responses regardless of which layer blocked the request, every attribution below is derived strictly from the governing policy documents rather than inferred from error text.

---

## Overview of Refusal Attribution Across Ashford's Governance Layers

Ashford's layered governance enforces denials through **four distinct mechanisms**, alongside **two baseline refusals** where the caller's identity policy contains no matching `Allow` for the requested resource or action:

| # | Attempted Action & Target | Signing Principal | Governance Mechanism | Controlling Document & Statement (`Sid`) |
|---|---|---|---|---|
| **1** | `kms:Decrypt` on `alias/ashford-reporting` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Mechanism 1: Direct / Explicit Policy Removal** (`Effect: "Deny"` in Identity Policy) | `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (`Sid: NoDecrypt`) |
| **2** | `iam:CreateAccessKey` on `user/reporting-analyst` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Mechanism 2: Organization-Level Control Overriding a Lower-Level Grant** (SCP `Deny` > Identity `Allow`) | `AshfordGuardrails` SCP on account `418274630117` (`Sid: NoLongLivedKeys`) |
| **3** | `s3:PutObject` on `ashford-reporting-ap7f3a/evidence/probe.txt` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Mechanism 3: Permissions Boundary Cap Granting Nothing by Itself** (Subtractive Ceiling Intersection) | `arn:aws:iam::418274630117:policy/ReportingAnalystBoundary` (`Sid: CapRead`) |
| **4** | `sqs:ReceiveMessage` on `ashford-dispatch-events` (`us-east-1`) | `arn:aws:iam::418274630117:user/reporting-analyst` | **Mechanism 4: Request-Condition Failure** (`aws:RequestedRegion` Mismatch) | `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (`Sid: DispatchQueueHomeRegionOnly`) |
| **5** | `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance` | `arn:aws:iam::418274630117:user/reporting-analyst` | **Baseline Absent Grant (Resource Scope)** — Caller identity policy scopes `sts:AssumeRole` to a different role ARN | `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (`Sid: ChainB_AssumeReader`) |
| **6** | `iam:CreateUser` for `user/proof` (unexported CLI shell) | `arn:aws:iam::418274630117:user/reporting-analyst` | **Baseline Absent Grant (Action Scope)** — Caller identity policy contains no `iam:CreateUser` statement | `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (all statements enumerated below) |

---

## Part I: The Four Layered Governance Denial Mechanisms

### 1. `kms:Decrypt` — Mechanism 1: Direct / Explicit Policy Removal

- **Request Context & Outcome:**
  - **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
  - **Action:** `kms:Decrypt`
  - **Resource:** `alias/ashford-reporting` (account `418274630117`, region `eu-west-1`)
  - **Reproducible Call:** `aws kms decrypt --ciphertext-blob fileb:///dev/null --key-id alias/ashford-reporting`
  - **Executed Outcome:** Denied (`AccessDeniedException`; CloudTrail `Decrypt` at `2026-11-19T03:26:46Z` and `2026-11-19T03:44:48Z`).
- **Governing Governance Layer:** Customer-Managed Identity Policy (`arn:aws:iam::418274630117:policy/ReportingAnalystAccess`).
- **Governing Statement Citation:**
  - **Document:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`
  - **Locator:** `Sid: "NoDecrypt"`
  ```json
  {
    "Sid": "NoDecrypt",
    "Effect": "Deny",
    "Action": "kms:Decrypt",
    "Resource": "*"
  }

  Condition: None

Evaluation Proof: Statement NoDecrypt matches Action: "kms:Decrypt" across Resource: "*" with an unconditional Effect: "Deny". Under IAM evaluation precedence, an explicit Deny directly removes the permission regardless of any Allow statement in any policy layer.

2. iam:CreateAccessKey — Mechanism 2: Organization-Level Control Overriding a Lower-Level Grant
Request Context & Outcome:

Principal: arn:aws:iam::418274630117:user/reporting-analyst

Action: iam:CreateAccessKey

Resource: arn:aws:iam::418274630117:user/reporting-analyst

Reproducible Call: aws iam create-access-key --user-name reporting-analyst

Executed Outcome: Denied (AccessDenied; CloudTrail CreateAccessKey at 2026-11-19T03:27:32Z and 2026-11-19T03:44:49Z).

Governing Governance Layer: AWS Organizations Service Control Policy (AshfordGuardrails, attached to account 418274630117).

Lower-Level Statement Citation (Overridden Grant):

Document: arn:aws:iam::418274630117:policy/ReportingAnalystAccess

Locator: Sid: "SelfKeyManagement"


{
  "Sid": "SelfKeyManagement",
  "Effect": "Allow",
  "Action": [
    "iam:CreateAccessKey",
    "iam:ListAccessKeys"
  ],
  "Resource": "arn:aws:iam::418274630117:user/reporting-analyst"
}

Condition: None

Permissions Boundary Ceiling Check: arn:aws:iam::418274630117:policy/ReportingAnalystBoundary (Sid: "CapRead") grants nothing by itself; its ceiling pattern "iam:*" on Resource: "*" does not subtract iam:CreateAccessKey from SelfKeyManagement.

Controlling Organization-Level Statement Citation:

Document: Service Control Policy AshfordGuardrails (attached to account 418274630117)

Locator: Sid: "NoLongLivedKeys"

{
  "Sid": "NoLongLivedKeys",
  "Effect": "Deny",
  "Action": [
    "iam:CreateAccessKey",
    "iam:CreateLoginProfile"
  ],
  "Resource": "*"
}

Condition: None

Evaluation Proof: Within account 418274630117, SelfKeyManagement explicitly grants iam:CreateAccessKey on arn:aws:iam::418274630117:user/reporting-analyst, and the permissions boundary ceiling does not remove it. However, the organization-level SCP AshfordGuardrails (Sid: "NoLongLivedKeys") applies an unconditional Effect: "Deny" to iam:CreateAccessKey on Resource: "*". Because an SCP explicit Deny overrides every account-level Allow, the organization control produces the refusal.

3. s3:PutObject — Mechanism 3: Permissions Boundary Cap Granting Nothing by Itself
Request Context & Outcome:

Principal: arn:aws:iam::418274630117:user/reporting-analyst

Action: s3:PutObject

Resource: arn:aws:s3:::ashford-reporting-ap7f3a/evidence/probe.txt

Reproducible Call: aws s3api put-object --bucket ashford-reporting-ap7f3a --key evidence/probe.txt --body /tmp/ashford-probe.txt

Executed Outcome: Denied (AccessDenied; CloudTrail PutObject at 2026-11-19T05:31:31Z).

Governing Governance Layer: IAM Permissions Boundary (arn:aws:iam::418274630117:policy/ReportingAnalystBoundary, attached as permissions boundary to user/reporting-analyst).

Identity Statement Citation (Capped Grant):

Document: arn:aws:iam::418274630117:policy/ReportingAnalystAccess

Locator: Sid: "ReportingReadWrite"

{
  "Sid": "ReportingReadWrite",
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::ashford-reporting-ap7f3a",
    "arn:aws:s3:::ashford-reporting-ap7f3a/*"
  ]
}

Condition: None

Controlling Permissions Boundary Citation:

Document: arn:aws:iam::418274630117:policy/ReportingAnalystBoundary

Locator: Sid: "CapRead"

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

Condition: None

Evaluation Proof: A permissions boundary grants zero permissions by itself; it defines the maximum permission ceiling via set intersection (Identity Policy ∩ Permissions Boundary). While ReportingReadWrite grants s3:* on arn:aws:s3:::ashford-reporting-ap7f3a/*, CapRead restricts S3 actions in the ceiling strictly to s3:Get* and s3:List*. Because s3:PutObject does not match s3:Get* or s3:List*, the intersection eliminates s3:PutObject and blocks the write operation.

4. sqs:ReceiveMessage in us-east-1 — Mechanism 4: Request-Condition Failure
Request Context & Outcome:

Principal: arn:aws:iam::418274630117:user/reporting-analyst

Action: sqs:ReceiveMessage

Resource: arn:aws:sqs:us-east-1:418274630117:ashford-dispatch-events

Request Context: aws:RequestedRegion = "us-east-1"

Reproducible Call: aws --region us-east-1 sqs receive-message --queue-url http://127.0.0.1:4566/418274630117/ashford-dispatch-events --max-number-of-messages 1

Executed Outcome: Denied (AccessDeniedException; CloudTrail ReceiveMessage at 2026-11-19T03:26:14Z and 2026-11-19T03:28:40Z). When executed with --region eu-west-1 (aws:RequestedRegion = "eu-west-1"), the identical queue call succeeded at 2026-11-19T06:13:56Z (CloudTrail event ID 105611ba-fb7d-4f2a-94e9-04830ff1328b).

Governing Governance Layer: Identity Policy Condition Block (arn:aws:iam::418274630117:policy/ReportingAnalystAccess).

Controlling Statement Citation:

Document: arn:aws:iam::418274630117:policy/ReportingAnalystAccess

Locator: Sid: "DispatchQueueHomeRegionOnly"

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

Evaluation Proof: Statement DispatchQueueHomeRegionOnly matches sqs:ReceiveMessage on Resource: "*" only when StringEquals: {"aws:RequestedRegion": "eu-west-1"} evaluates to true. For the us-east-1 request, aws:RequestedRegion is "us-east-1", failing "us-east-1" == "eu-west-1". Because the condition fails, the statement does not activate, no other identity statement covers SQS, and ReportingAnalystBoundary (Sid: "CapRead") grants nothing by itself.

Request Context & Outcome:

Principal: arn:aws:iam::418274630117:user/reporting-analyst

Action: sts:AssumeRole

Resource: arn:aws:iam::418274630228:role/ashford-dev-maintenance

Reproducible Call: aws sts assume-role --role-arn arn:aws:iam::418274630228:role/ashford-dev-maintenance --role-session-name boundary-review

Executed Outcome: Denied (AccessDenied; CloudTrail AssumeRole at 2026-11-19T05:29:41Z, event ID 4334331f-68e0-47f7-8cf1-ee37a287de94).

Governing Statement Citations:

Target Role Trust Policy (arn:aws:iam::418274630228:role/ashford-dev-maintenance in Account 418274630228):

{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::418274630117:root"
  },
  "Action": "sts:AssumeRole"
}

Condition: None

Caller Identity Policy (arn:aws:iam::418274630117:policy/ReportingAnalystAccess, Sid: "ChainB_AssumeReader"):

{
  "Sid": "ChainB_AssumeReader",
  "Effect": "Allow",
  "Action": "sts:AssumeRole",
  "Resource": "arn:aws:iam::418274630117:role/ashford-crossacct-reader"
}
Condition: None

Evaluation Proof: Cross-account sts:AssumeRole requires an explicit Allow from both the target role's trust policy in account 418274630228 and the caller's identity policy in account 418274630117. Although ashford-dev-maintenance trusts arn:aws:iam::418274630117:root, the only sts:AssumeRole statement in ReportingAnalystAccess (Sid: "ChainB_AssumeReader") restricts Resource strictly to "arn:aws:iam::418274630117:role/ashford-crossacct-reader". Because arn:aws:iam::418274630228:role/ashford-dev-maintenance does not match that Resource ARN—and ReportingAnalystBoundary (Sid: "CapRead") grants nothing by itself—no caller-side Allow applies.
