# 2. The Unremarkable Administrator

## Starting principal and ordinary role

- **Principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
- **Ordinary role:** Finance Ops monthly regulatory reporting analyst.
- **Expected scope:** read and write on reporting data in `ashford-reporting-ap7f3a`, the queue receive in `eu-west-1`, and assuming the reader role `ashford-crossacct-reader` for read-only cross-account work.
- **Confirmed identity:** `aws sts get-caller-identity` returned the user ARN above.
- **Direct permissions that exceed the role:** `ChainB_AmendReaderPolicy` in `ReportingAnalystAccess` allows `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, and `iam:DeletePolicyVersion` on `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess`. This is the seam described below. It is not part of the expected scope of a reporting analyst.

## Final administrative identity and authority

- **Reached identity:** `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/chain-proof`
- **Effective authority:** the role's default policy after Edge 1, `Allow` on `Action: "*"`, `Resource: "*"`, with no permissions boundary on the role.
- **Bounds on that authority:** the organisation SCP `AshfordGuardrails` still denies `iam:CreateAccessKey` and `iam:CreateLoginProfile` on all resources, and it denies leaving the organisation. The session therefore cannot mint long-lived keys or console passwords, or remove the account from the organisation.

## Chain

### Edge 1: reporting user replaces the default version of the reader role's policy

- **Current principal:** `arn:aws:iam::418274630117:user/reporting-analyst`
- **Permission used:** `iam:CreatePolicyVersion` with `iam:SetDefaultPolicyVersion`, from `ReportingAnalystAccess` statement `ChainB_AmendReaderPolicy`
  - Effect `Allow`
  - Action `["iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion", "iam:DeletePolicyVersion"]`
  - Resource `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess`
  - Condition none
- **Other layers checked:**
  - `ReportingAnalystBoundary`, statement `CapRead`, allows `iam:*` on `*`, so it does not block these actions.
  - SCP `AshfordGuardrails` denies only `iam:CreateAccessKey`, `iam:CreateLoginProfile`, and organisation exit or closure. It does not deny policy-version operations.
  - `ashford-crossacct-reader` has no permissions boundary, per `get-role`.
- **Call:**

  ```
  aws iam create-policy-version \
    --policy-arn arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess \
    --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}' \
    --set-as-default
  ```

- **Response:** `VersionId: v2`, `IsDefaultVersion: true`.
  `[paste raw response here]`
- **Evidence the change took effect:** `get-role --role-name ashford-crossacct-reader` and `list-attached-role-policies` show this policy attached to the role. `get-policy-version` for the default version returns v2 with `Allow`, `Action: "*"`, `Resource: "*"`.
  `[paste raw get-policy-version output here]`
- **CloudTrail record:** `CreatePolicyVersion` at `2026-11-19T03:45:26Z`, `userIdentity.arn` = reporting user. Source object: `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0346Z_70fB56CA51C7fe8C.json.gz`.
  `[paste the eventName, userIdentity.arn and eventTime fields from the record]`
- **Capability created:** the reporting user can replace the default document of the policy attached to `ashford-crossacct-reader`. The role's effective grant changes from `s3:GetObject`, `s3:ListBucket`, and `sts:AssumeRole` to all actions on all resources.
- **Why this step was permitted:** the statement `ChainB_AmendReaderPolicy` exists so that someone can maintain the reader's policy. It names this one policy ARN, with no condition. Nothing in the layers checked removes these actions for this user.

### Edge 2: reporting user assumes the role whose policy it changed

- **Current principal:** `arn:aws:iam::418274630117:user/reporting-analyst`. A separate boto3 session returned this ARN from `GetCallerIdentity` before the assume call.
  `[paste GetCallerIdentity output]`
- **Permission used:** `sts:AssumeRole` from `ReportingAnalystAccess` statement `ChainB_AssumeReader`
  - Effect `Allow`
  - Action `sts:AssumeRole`
  - Resource `arn:aws:iam::418274630117:role/ashford-crossacct-reader`
  - Condition none
- **Trust policy on the target role** (from `get-role`):
  - Effect `Allow`
  - Principal `{"AWS": "arn:aws:iam::418274630117:user/reporting-analyst"}`
  - Action `sts:AssumeRole`
- **Other layers checked:** the permissions boundary allows `sts:AssumeRole`, and the SCP has no deny for it.
- **Call:**

  ```
  aws sts assume-role \
    --role-arn arn:aws:iam::418274630117:role/ashford-crossacct-reader \
    --role-session-name esc
  ```

- **Response:** temporary STS credentials.
  `[paste raw response, with the secret fields redacted]`
- **Follow-up call:** `GetCallerIdentity` with the returned credentials loaded into a boto3 session returns `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/chain-proof`.
  `[paste raw response]`
- **CloudTrail record:** `AssumeRole` at `2026-11-19T03:45:28Z`.
  `[paste the eventName, userIdentity and eventTime fields]`
- **Capability created:** a session of `ashford-crossacct-reader`, now carrying the `*`/`*` default policy from Edge 1.
- **Why this step was permitted:** the reader role exists so the reporting analyst can use it for cross-account reads. Its trust names this user, and the identity statement names this role. Each side is individually valid. Neither checks what the role's policy currently allows.

### Edge 3: the role session uses the authority it obtained

- **Current principal:** `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/chain-proof`, confirmed with `GetCallerIdentity` immediately before the test.
  `[paste output]`
- **Permission used:** `iam:CreateUser` and `iam:DeleteUser` on `*`, from the Edge 1 default version, which allows all actions. The SCP does not deny either action.
- **Call:**

  ```python
  iam.create_user(UserName="ashford-chain-proof-cleanup")
  iam.delete_user(UserName="ashford-chain-proof-cleanup")
  ```

- **Response:** the user ARN for create, then success for delete.
  `[paste both raw responses]`
- **CloudTrail record:** `CreateUser` and `DeleteUser` at `2026-11-19T05:28:56Z`. Source object: `.../2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0529Z_BD35bac2A0d5c77f.json.gz`.
  `[paste eventName, userIdentity and eventTime fields]`
- **Capability demonstrated:** IAM user creation and deletion under the role identity. This is a sample of the authority, not a demonstration of all of it. It is not proof of full administrative control; it is proof that the role's authority includes IAM user management.
- **Limit:** the test did not attempt access-key creation or organisation actions, which the SCP denies.

## Composition: why the combination is not what anyone approved

Two grants look ordinary on their own.

1. **`ChainB_AmendReaderPolicy` (Edge 1).** A reporting team may need to update the reader policy when a new bucket is added. The statement is scoped to one policy ARN and has no condition.
2. **`ChainB_AssumeReader` plus the role trust (Edge 2).** The reporting analyst needs to read cross-account data through the reader role. The trust names this user and the statement names this role.

The seam is that the reader role's permissions are defined by a policy this same user can rewrite. Rewriting that policy changes what the role can do. Assuming the role then gives the user those changed permissions. Nobody approved "the reporting user can rewrite the permissions of the role it can assume." Each approval covered one half of that sentence.

The problem is not a single over-broad grant. It is that policy-version control and role assumption live on the same role, held by the same identity, with no separation between who defines the permissions and who uses them. A permissions boundary on the role, or an SCP denying policy-version writes on `AshfordCrossAcctReaderAccess`, would each break the seam by itself.

## Remediation, by edge

- **Edge 1:** remove `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, and `iam:DeletePolicyVersion` from `reporting-analyst`. Move policy maintenance to a separate administrative identity. Add an SCP or resource control denying these actions on `AshfordCrossAcctReaderAccess` for all principals except that administrator.
- **Edge 2:** narrow the trust policy so only the intended automation identity can assume the reader role. Require conditions such as `aws:MultiFactorAuthPresent` or an external ID if a human needs access. Attach a permissions boundary to `ashford-crossacct-reader` that caps it to read-only actions on the reporting bucket, so that a changed default version cannot exceed the cap.
- **Edge 3:** the cap in Edge 2 removes `iam:*` from the role. Verify this with a re-run in a sandbox account, not in production.
- **Detection:** alarm on CloudTrail `CreatePolicyVersion`, `SetDefaultPolicyVersion`, and `AssumeRole` for `ashford-crossacct-reader`, grouped by principal.

## Open items

- The raw responses marked `[paste ...]` must be filled in from the session for the file to meet the requirement that each step is shown, not described.
- Edge 3 demonstrates only `CreateUser` and `DeleteUser`. Do not describe it as administrative control over the account until more actions are shown under the same evidence standard.
