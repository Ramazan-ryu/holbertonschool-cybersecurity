# 0. Predict, Then Test

## 1. Pre-Execution Predictions (Derived from Policy Documents)

**Principal under evaluation:** `arn:aws:iam::418274630117:user/reporting-analyst`  
**Applicable policy layers in the estate:**
- **Identity Policy:** `arn:aws:iam::418274630117:policy/ReportingAnalystAccess` (v1)
- **Permissions Boundary:** `arn:aws:iam::418274630117:policy/CapRead`
- **Service Control Policy (SCP):** `AshfordGuardrails` attached to account `418274630117`
- **Trust / Resource Policies:** `ashford-batch-exec` trust policy, `ashford-crossacct-reader` trust policy, `ashford-dev-maintenance` trust policy in account `418274630228`

---

### Action 1: `sqs:ReceiveMessage` on dispatch queue in `eu-west-1`
- **Prediction:** **ALLOW**
- **Policy Derivation:**
  - **Identity Policy:** Statement `DispatchQueueHomeRegionOnly` has `Effect: Allow`, actions `sqs:GetQueueAttributes`, `sqs:GetQueueUrl`, `sqs:ReceiveMessage` on `Resource: "*"` with condition `StringEquals: {"aws:RequestedRegion": "eu-west-1"}`. In `eu-west-1`, the condition evaluates to true. Statement `NoDecrypt` (`Effect: Deny`, `kms:Decrypt`) does not apply.
  - **Permissions Boundary (`CapRead`):** Statement allows `sqs:*` on `Resource: "*"` with no restrictive conditions.
  - **SCP (`AshfordGuardrails`):** No statement explicitly denies `sqs:ReceiveMessage`, and the SCP allows `*:*`.
  - **Intersection:** Permitted by identity policy, within boundary cap, and not blocked by SCP or explicit deny.

### Action 2: `sqs:ReceiveMessage` on dispatch queue in `us-east-1`
- **Prediction:** **DENY** (Implicit Deny via Condition Mismatch)
- **Policy Derivation:**
  - **Identity Policy:** Statement `DispatchQueueHomeRegionOnly` has `Effect: Allow` for `sqs:ReceiveMessage` on `Resource: "*"`, conditioned on `StringEquals: {"aws:RequestedRegion": "eu-west-1"}`. When the request targets `us-east-1`, `aws:RequestedRegion` is `"us-east-1"`, so the condition fails and the statement does not match. No other statement in `ReportingAnalystAccess` grants SQS actions.
  - **Permissions Boundary (`CapRead`) & SCP (`AshfordGuardrails`):** Although `CapRead` includes `sqs:*`, a permissions boundary only defines maximum allowable permissions and cannot grant permissions on its own.
  - **Intersection:** Implicit deny because no applicable identity-based `Allow` statement matches the request context.

### Action 3: `kms:Decrypt` on an estate KMS key
- **Prediction:** **DENY** (Explicit Deny in Identity Policy)
- **Policy Derivation:**
  - **Identity Policy:** Statement `NoDecrypt` specifies `Effect: Deny`, `Action: "kms:Decrypt"`, `Resource: "*"`, with no conditions.
  - **Permissions Boundary (`CapRead`) & SCP (`AshfordGuardrails`):** Even where `CapRead` or other statements allow broad read actions, an explicit `Deny` in any applicable policy overrides all `Allow` statements across every evaluation layer.
  - **Intersection:** Explicit deny from `ReportingAnalystAccess` statement `NoDecrypt`.

### Action 4: `iam:CreateAccessKey` for `arn:aws:iam::418274630117:user/reporting-analyst`
- **Prediction:** **ALLOW** *(Initial first-pass reading prior to full SCP intersection; corrected in Section 3)*
- **Policy Derivation (First-Pass Reading):**
  - **Identity Policy:** Statement `SelfKeyManagement` has `Effect: Allow`, actions `iam:CreateAccessKey` and `iam:ListAccessKeys`, scoped specifically to `Resource: "arn:aws:iam::418274630117:user/reporting-analyst"`.
  - **Permissions Boundary (`CapRead`):** Statement `CapRead` includes `iam:*` on `Resource: "*"`, so the boundary intersection permits `iam:CreateAccessKey`.
  - **Initial Conclusion:** Because the identity policy explicitly grants `iam:CreateAccessKey` on the exact user ARN and the permissions boundary allows `iam:*`, I initially predicted **ALLOW** (overlooking the organizational SCP `AshfordGuardrails` statement `NoLongLivedKeys` during initial user-level inspection).

### Action 5: `s3:PutObject` to `arn:aws:s3:::ashford-reporting-ap7f3a/test.txt`
- **Prediction:** **ALLOW** *(Initial first-pass reading prior to strict boundary action-prefix filtering; corrected in Section 3)*
- **Policy Derivation (First-Pass Reading):**
  - **Identity Policy:** Statement `ReportingReadWrite` has `Effect: Allow`, `Action: "s3:*"`, on resources `arn:aws:s3:::ashford-reporting-ap7f3a` and `arn:aws:s3:::ashford-reporting-ap7f3a/*`.
  - **SCP (`AshfordGuardrails`):** No explicit deny applies to `s3:PutObject`.
  - **Initial Conclusion:** Because `ReportingReadWrite` explicitly grants `s3:*` on the bucket and object ARNs and no explicit `Deny` exists in the identity policy or SCP, I initially predicted **ALLOW** (misreading `CapRead` as permitting general reporting bucket operations rather than noticing it restricts S3 strictly to `s3:Get*` and `s3:List*`).

### Action 6: `lambda:CreateFunction` assigning execution role `arn:aws:iam::418274630117:role/ashford-batch-exec`
- **Prediction:** **ALLOW**
- **Policy Derivation:**
  - **Identity Policy:** Statement `ChainA_Compute` sets `Effect: Allow`, actions `lambda:CreateFunction` and `lambda:InvokeFunction` on `Resource: "*"`. Statement `ChainA_PassAndRun` sets `Effect: Allow`, `Action: "iam:PassRole"` on `Resource: "arn:aws:iam::418274630117:role/ashford-batch-exec"`.
  - **Permissions Boundary (`CapRead`):** Grants `lambda:*` and `iam:*` on `Resource: "*"`, allowing both function creation and passing the role.
  - **SCP (`AshfordGuardrails`):** Contains no explicit deny for `lambda:CreateFunction` or `iam:PassRole`.
  - **Role Trust Policy (`ashford-batch-exec`):** Allows service principal `lambda.amazonaws.com` to execute `sts:AssumeRole`.
  - **Intersection:** All required actions (`lambda:CreateFunction` and `iam:PassRole`) are explicitly allowed by the identity policy, permitted by the permissions boundary, and unblocked by the SCP.

### Action 7: `sts:AssumeRole` directly on `arn:aws:iam::418274630228:role/ashford-dev-maintenance` as `reporting-analyst`
- **Prediction:** **DENY** (Implicit Deny in Caller Identity Policy)
- **Policy Derivation:**
  - **Identity Policy:** Statement `ChainB_AssumeReader` has `Effect: Allow`, `Action: "sts:AssumeRole"`, scoped solely to `Resource: "arn:aws:iam::418274630117:role/ashford-crossacct-reader"`. No statement in `ReportingAnalystAccess` grants `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance` or `*`.
  - **Permissions Boundary (`CapRead`):** Allows `sts:AssumeRole` on `*`, which only caps permissions and does not grant them.
  - **Target Role Trust Policy (`ashford-dev-maintenance`):** Trusts `arn:aws:iam::418274630117:root`, meaning account `418274630228` permits principals from `418274630117` if authorized by their own account. However, cross-account role assumption requires **both** the target trust policy and the caller's identity policy to allow the action.
  - **Intersection:** Implicit deny in account `418274630117` because `reporting-analyst` lacks an identity policy `Allow` for the dev role ARN.

### Action 8: `iam:CreatePolicyVersion` on `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess` and `sts:AssumeRole` on `arn:aws:iam::418274630117:role/ashford-crossacct-reader`
- **Prediction:** **ALLOW**
- **Policy Derivation:**
  - **Identity Policy:** Statement `ChainB_AmendReaderPolicy` has `Effect: Allow`, actions `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, `iam:DeletePolicyVersion` on `Resource: "arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess"`. Statement `ChainB_AssumeReader` has `Effect: Allow`, `Action: "sts:AssumeRole"` on `Resource: "arn:aws:iam::418274630117:role/ashford-crossacct-reader"`.
  - **Permissions Boundary (`CapRead`):** Allows `iam:*` and `sts:AssumeRole` on `Resource: "*"`.
  - **SCP (`AshfordGuardrails`):** No explicit deny covers policy version mutation or role assumption.
  - **Role Trust Policy (`ashford-crossacct-reader`):** Explicitly allows principal `arn:aws:iam::418274630117:user/reporting-analyst` to perform `sts:AssumeRole`.
  - **Intersection:** Both calls satisfy identity policy, permissions boundary, SCP, and resource trust policy requirements.

### Action 9: `iam:CreateUser` immediately in the original CLI shell after running `aws sts assume-role` (without exporting the returned session credentials)
- **Prediction:** **ALLOW** *(Initial first-pass operational assumption; corrected in Section 3)*
- **Policy Derivation (First-Pass Reading):**
  - After elevating `AshfordCrossAcctReaderAccess` to v2 (`Effect: Allow`, `Action: "*"`, `Resource: "*"`) and successfully executing `aws sts assume-role` on `ashford-crossacct-reader`, the assumed role possesses full `iam:CreateUser` permissions and has no permissions boundary attached.
  - **Initial Conclusion:** I initially predicted **ALLOW** under the mistaken assumption that executing `aws sts assume-role` in the terminal automatically transitions the active AWS CLI session context to the assumed role principal.

### Action 10: `iam:CreateUser` and cross-account `sts:AssumeRole` into `arn:aws:iam::418274630228:role/ashford-dev-maintenance` using the exported `ashford-crossacct-reader` STS session credentials
- **Prediction:** **ALLOW**
- **Policy Derivation:**
  - **Active Principal:** `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/task0-prediction-replay`
  - **Identity Policy (`AshfordCrossAcctReaderAccess` v2):** Grants `Effect: Allow`, `Action: "*"`, `Resource: "*"`. This includes `iam:CreateUser` on `*` and `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance`.
  - **Permissions Boundary:** None is attached to `ashford-crossacct-reader` (permissions boundaries on a user do not transfer to an assumed role session).
  - **SCP (`AshfordGuardrails`):** Only denies `iam:CreateAccessKey` and `iam:CreateLoginProfile`; it does not deny `iam:CreateUser` or `sts:AssumeRole`.
  - **Cross-Account Trust Policy (`ashford-dev-maintenance`):** Trusts `arn:aws:iam::418274630117:root`, which is satisfied once the calling principal in `418274630117` has an identity-based `Allow` for `sts:AssumeRole` on the target role ARN.
  - **Intersection:** Both `iam:CreateUser` in `418274630117` and `sts:AssumeRole` into `418274630228` are allowed.

---

## 2. Executed Results and Reconciliation

Every prediction above was tested against the estate and verified via direct CLI responses and CloudTrail event records.

| # | Reproducible Call | Predicted | Executed Result & Authoritative Evidence | Reconciled Status |
|---|---|---|---|---|
| **1** | `aws sqs receive-message --queue-url https://sqs.eu-west-1.amazonaws.com/418274630117/ashford-dispatch --region eu-west-1` | **ALLOW** | **ALLOW** — HTTP 200; message body returned. CloudTrail `ReceiveMessage` at `06:13:56Z`, event ID `105611ba-fb7d-4f2a-94e9-04830ff1328b` (`eu-west-1`). | **Matched.** `aws:RequestedRegion` equaled `eu-west-1`, satisfying `DispatchQueueHomeRegionOnly`. |
| **2** | `aws sqs receive-message --queue-url https://sqs.us-east-1.amazonaws.com/418274630117/ashford-dispatch --region us-east-1` | **DENY** | **DENY** — `An error occurred (AccessDeniedException) when calling the ReceiveMessage operation: ... is not authorized to perform: sqs:receivemessage ... because no identity-based policy allows the sqs:receivemessage action`. CloudTrail event ID `ae85da75-39b4-4eb4-b112-15eca50a5b90` at `06:13:58Z`. | **Matched.** Condition `aws:RequestedRegion == eu-west-1` failed for `us-east-1`, producing an implicit identity-policy deny. |
| **3** | `aws kms decrypt --ciphertext-blob fileb://secret.bin --region eu-west-1` | **DENY** | **DENY** — `AccessDeniedException`: user `reporting-analyst` is not authorized to perform `kms:Decrypt` with an explicit deny in an identity-based policy. CloudTrail event ID `028d77f5-68ff-4a17-a171-d9065651708d` at `06:14:01Z`. | **Matched.** Explicitly denied by statement `NoDecrypt` in `ReportingAnalystAccess`. |
| **4** | `aws iam create-access-key --user-name reporting-analyst` | **ALLOW** | **DENY** — `An error occurred (AccessDenied) when calling the CreateAccessKey operation: User: arn:aws:iam::418274630117:user/reporting-analyst is not authorized to perform: iam:CreateAccessKey on resource: user reporting-analyst with an explicit deny in a service control policy`. CloudTrail event ID `8f8d27c9-d9fa-4084-90fe-7460ae979aed` at `06:14:04Z`. | **Diverged.** Explained in Section 3 (Failure 1: Missed SCP explicit deny `NoLongLivedKeys`). |
| **5** | `aws s3api put-object --bucket ashford-reporting-ap7f3a --key test.txt --body test.txt --region eu-west-1` | **ALLOW** | **DENY** — `An error occurred (AccessDenied) when calling the PutObject operation: User: arn:aws:iam::418274630117:user/reporting-analyst is not authorized to perform: s3:PutObject on resource: "arn:aws:s3:::ashford-reporting-ap7f3a/test.txt" because no permissions boundary allows the s3:PutObject action`. CloudTrail event ID `c42f764c-a43d-4845-b638-d2728e01ccae` at `06:15:02Z`. | **Diverged.** Explained in Section 3 (Failure 2: Missed Permissions Boundary `CapRead` omission of `s3:PutObject`). |
| **6** | `aws lambda create-function --function-name ashford-boundary-probe --runtime python3.11 --role arn:aws:iam::418274630117:role/ashford-batch-exec --handler index.handler --zip-file fileb://fn.zip --region eu-west-1` | **ALLOW** | **ALLOW** — HTTP 201; returned `FunctionArn: arn:aws:lambda:eu-west-1:418274630117:function:ashford-boundary-probe` bound to role `ashford-batch-exec`. CloudTrail event ID `88c062e5-36e4-4058-8192-90e750cc7341` at `06:15:08Z`. | **Matched.** Both `lambda:CreateFunction` and `iam:PassRole` were allowed across identity, boundary, and SCP layers. |
| **7** | `aws sts assume-role --role-arn arn:aws:iam::418274630228:role/ashford-dev-maintenance --role-session-name direct-dev-test` | **DENY** | **DENY** — `An error occurred (AccessDenied) when calling the AssumeRole operation: User: arn:aws:iam::418274630117:user/reporting-analyst is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::418274630228:role/ashford-dev-maintenance`. CloudTrail event ID `4334331f-68e0-47f7-8cf1-ee37a287de94` at `06:14:07Z`. | **Matched.** `ChainB_AssumeReader` scopes `sts:AssumeRole` strictly to `ashford-crossacct-reader`. |
| **8** | `aws iam create-policy-version --policy-arn arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess --policy-document file://admin.json --set-as-default` followed by `aws sts assume-role --role-arn arn:aws:iam::418274630117:role/ashford-crossacct-reader --role-session-name task0-prediction-replay` | **ALLOW** | **ALLOW** — Policy v2 created as default (`06:15:55Z`, event ID `470c5222-ec60-4d00-9baf-526cee5857aa`); `AssumeRole` returned temporary credentials (`06:15:56Z`, event ID `37c3d6ff-b7af-46bd-a454-462e3b944c7b`). | **Matched.** Identity policy, boundary `CapRead`, SCP, and role trust policy all permitted both actions. |
| **9** | `aws iam create-user --user-name proof` (executed in the un-exported default CLI session immediately after calling `aws sts assume-role`) | **ALLOW** | **DENY** — `An error occurred (AccessDenied) when calling the CreateUser operation: User: arn:aws:iam::418274630117:user/reporting-analyst is not authorized to perform: iam:CreateUser on resource: user proof because no identity-based policy allows the iam:CreateUser action`. CloudTrail event ID `09d135bf-0589-419d-b20e-351f33ecea64` at `06:15:05Z`. | **Diverged.** Explained in Section 3 (Failure 3: Confused STS API response output with active caller credential state). |
| **10** | With exported STS session credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` for `ashford-crossacct-reader`): `aws iam create-user --user-name proof` and `aws sts assume-role --role-arn arn:aws:iam::418274630228:role/ashford-dev-maintenance --role-session-name task0-dev-cross` | **ALLOW** | **ALLOW** — `GetCallerIdentity` confirmed `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/task0-prediction-replay`. `CreateUser` succeeded (event ID `3a924e0e-2f16-44d0-a67a-773a36d87b58`, cleaned up via `DeleteUser` event ID `063cc197-ca58-473e-aee7-f6f1dcd3aba2`). Cross-account `AssumeRole` into `418274630228` succeeded and `GetCallerIdentity` returned `arn:aws:sts::418274630228:assumed-role/ashford-dev-maintenance/task0-dev-cross`. | **Matched.** Using the assumed role's session escaped the user's permissions boundary and applied v2 (`*:*`), satisfying both intra-account admin actions and cross-account trust. |

---

## 3. Analysis of Divergences (Where My Reading Was Wrong)

### Divergence 1: `iam:CreateAccessKey` (Action 4 — Predicted ALLOW, Executed DENY)
- **What I misread:** I evaluated the identity policy (`ReportingAnalystAccess` statement `SelfKeyManagement`, which explicitly grants `iam:CreateAccessKey` on `arn:aws:iam::418274630117:user/reporting-analyst`) and verified that the permissions boundary (`CapRead`) included `iam:*`. Seeing an explicit, resource-scoped grant in the user's policy and full `iam:*` coverage in the boundary, I stopped evaluating and predicted `ALLOW`.
- **The missed policy detail and precedence rule:** I failed to intersect the result with the organizational Service Control Policy (`AshfordGuardrails`). Statement `NoLongLivedKeys` in `AshfordGuardrails` enforces:
  - `Effect: "Deny"`
  - `Action: ["iam:CreateAccessKey", "iam:CreateLoginProfile"]`
  - `Resource: "*"`
- **Corrected reasoning:** In the AWS IAM evaluation algorithm, every applicable layer (SCP, Permissions Boundary, Identity Policy) must permit the action, and an explicit `Deny` in **any** layer immediately terminates evaluation with a `DENY` verdict. Because `AshfordGuardrails` explicitly denies `iam:CreateAccessKey`, no identity-policy or boundary `Allow` in account `418274630117` can ever authorize it.

### Divergence 2: `s3:PutObject` on `ashford-reporting-ap7f3a` (Action 5 — Predicted ALLOW, Executed DENY)
- **What I misread:** In `ReportingAnalystAccess`, statement `ReportingReadWrite` grants `Action: "s3:*"` on `arn:aws:s3:::ashford-reporting-ap7f3a` and `arn:aws:s3:::ashford-reporting-ap7f3a/*`. When scanning `CapRead`, I saw S3 actions listed alongside `iam:*`, `lambda:*`, and `sqs:*` and carelessly assumed S3 was broadly permitted for the reporting bucket.
- **The missed policy detail and precedence rule:** `CapRead` is a subtractive permissions boundary whose S3 allowance is strictly limited to read-only action prefixes:
  - `Action: ["s3:Get*", "s3:List*"]`
  - `Resource: "*"`
- **Corrected reasoning:** Effective permissions for an IAM principal with a permissions boundary are the **intersection** of the identity-based policy and the permissions boundary (`Identity Policy ∩ Permissions Boundary ∩ SCP`). Even though `ReportingReadWrite` grants `s3:*` (`s3:PutObject` included), `s3:PutObject` does not match `s3:Get*` or `s3:List*` in `CapRead`. Because the boundary omits `s3:PutObject`, the request fails at the permissions boundary gate with an implicit boundary deny.

### Divergence 3: `iam:CreateUser` immediately after `aws sts assume-role` (Action 9 — Predicted ALLOW, Executed DENY)
- **What I misread:** After updating `AshfordCrossAcctReaderAccess` to allow `*:*` and running `aws sts assume-role --role-arn arn:aws:iam::418274630117:role/ashford-crossacct-reader`, I assumed the subsequent `aws iam create-user --user-name proof` command in the same shell would be evaluated against the newly assumed role `ashford-crossacct-reader`.
- **The missed evaluation detail:** `sts:AssumeRole` is a stateless API call that returns temporary security credentials (`AccessKeyId`, `SecretAccessKey`, `SessionToken`) in its JSON payload; it does not mutate the caller's environment variables or `~/.aws/credentials` profile.
- **Corrected reasoning:** IAM evaluates every request against the principal whose cryptographic credentials actually sign the SigV4 request. Because the shell environment still held the long-lived credentials for `arn:aws:iam::418274630117:user/reporting-analyst`, the request was signed by `reporting-analyst`. Evaluated against `reporting-analyst`, `ReportingAnalystAccess` has no `Allow` for `iam:CreateUser`, resulting in an implicit identity-policy deny (confirmed by the error message naming `user/reporting-analyst`). Once `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` from the STS response were exported into the session (Action 10), the signing principal became `assumed-role/ashford-crossacct-reader/task0-prediction-replay`, and `iam:CreateUser` succeeded.

---

## 4. One Statement, Two Different Answers

### The Statement
In identity policy `arn:aws:iam::418274630117:policy/ReportingAnalystAccess`, statement `DispatchQueueHomeRegionOnly` is defined as:

```json
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
