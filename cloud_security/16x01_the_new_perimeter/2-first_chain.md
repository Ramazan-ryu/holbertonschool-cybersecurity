# 2. The Unremarkable Administrator

## Starting principal and result

Starting principal: `arn:aws:iam::418274630117:user/reporting-analyst`, the Finance Ops monthly regulatory reporting analyst. The replay's initial `GetCallerIdentity` returned this ARN (CloudTrail event `325b2b66-93bc-4882-9c05-87a083f70bb8`, 2026-11-19T06:15:55Z).

The chain reached `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/task0-prediction-replay`. Using that session, the test created and deleted an IAM user. This proves IAM user administration through this role; it does not prove unrestricted control of every AWS service. SCP denies remain in force.

## Edge 1: change the policy attached to the reader role

**Current principal:** `reporting-analyst`.

**Permission and target:** `iam:CreatePolicyVersion` on `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess`, with the new version set as default. `ReportingAnalystAccess`, statement `ChainB_AmendReaderPolicy`, allows `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, and `iam:DeletePolicyVersion` on this exact policy ARN, without a condition. The user's boundary `CapRead` includes `iam:*`; `AshfordGuardrails` has no matching deny. The reader role has no permissions boundary.

**Executed call:**

```bash
aws iam create-policy-version \
  --policy-arn arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}' \
  --set-as-default
```

**Response:** success, `VersionId: v2`, `IsDefaultVersion: true`. CloudTrail: `iam.amazonaws.com / CreatePolicyVersion`, event ID `470c5222-ec60-4d00-9baf-526cee5857aa`, request ID `NgqdI4RzkdgnQaa9bmDbdWaJvzyEVbKNUnFxmYyGbikgpdPyW36O`, time `2026-11-19T06:15:55Z`. The request includes the policy ARN and the submitted wildcard policy document. `list-attached-role-policies` confirmed this policy is attached to `ashford-crossacct-reader`; `get-policy-version` confirmed default v2.

**Capability created:** the user can replace the default permission document attached to the reader role; this version grants all actions on all resources, subject to higher-level controls.

## Edge 2: assume the role whose policy was changed

**Caller before request:** `arn:aws:iam::418274630117:user/reporting-analyst`. `ReportingAnalystAccess`, statement `ChainB_AssumeReader`, allows `sts:AssumeRole` on `arn:aws:iam::418274630117:role/ashford-crossacct-reader`, without a condition. The role trust accepts this user. The boundary allows `sts:AssumeRole`; the SCP has no matching deny.

**Executed call:**

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::418274630117:role/ashford-crossacct-reader \
  --role-session-name task0-prediction-replay
```

**Response:** STS returned temporary credentials successfully; secret fields are omitted. CloudTrail: `sts.amazonaws.com / AssumeRole`, event ID `37c3d6ff-b7af-46bd-a454-462e3b944c7b`, request ID `MLOS51HUgDSQRMK5SDv68kroX5lVd5DME6MVgcCx3b5ZOGxGZy3j`, time `2026-11-19T06:15:56Z`; the event records the target role and session name.

**Identity verification:** `GetCallerIdentity` using the returned credentials reported `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/task0-prediction-replay`. Task 7 records event ID `37fec8b1-3a62-4e35-9e07-9f9c74c438d6`, request ID `8sEw8VHgxzoTCyf4o54itzOqnUp3mQwINQKQd6T3zlDVk0FmcRuP`. The recorded STS access-key identifier matches the following IAM events.

**Capability created:** the caller is now a session of the role whose attached policy was widened in Edge 1.

## Edge 3: exercise the role's IAM authority

**Current principal:** the verified `ashford-crossacct-reader/task0-prediction-replay` session.

**Permission and target:** the new default policy allows `iam:CreateUser` and `iam:DeleteUser` on `*`; neither action is denied by the SCP.

**Executed calls with the returned role credentials:**

```python
iam.create_user(UserName="ashford-prediction-proof")
iam.delete_user(UserName="ashford-prediction-proof")
```

**Responses:** `CreateUser` succeeded and returned `arn:aws:iam::418274630117:user/ashford-prediction-proof`; `DeleteUser` then succeeded with HTTP 200. Task 7 correlates both to the verified session's STS access-key identifier:
- `CreateUser`: event ID `3a924e0e-2f16-44d0-a67a-773a36d87b58`, request ID `fUJmUMS3BysvxLVuS3qxyOXFbbxeg3QHbiWaEihd1c2AJC7I0b6A`.
- `DeleteUser`: event ID `063cc197-ca58-473e-aee7-f6f1dcd3aba2`, request ID `3HWbz4Kjx62nlUfCvEshSWNtDARdjJtxI7FGmoOqLJqwKaaHPtlo`.

Task 7 locates the records in `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0616Z_041F727DBEDbDa41.json.gz`. This proves IAM user management, not every possible administrator action.

## Dangerous composition

Maintaining versions of one policy and assuming one reader role can each have a legitimate purpose. The analyst could change the policy attached to the same role the analyst could assume. The edit changed the role's authority; the permitted assumption changed the analyst's effective identity and permissions. Each permission behaved as configured, but their relationship enabled IAM administration that neither grant described in isolation.
