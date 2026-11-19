# 2. The Unremarkable Administrator

## Evidence scope and starting principal

The signed source of truth for this replay is `evidence/audit-export-replay.json`. It identifies the initial caller as `arn:aws:iam::418274630117:user/reporting-analyst` (STS `GetCallerIdentity`, 2026-11-19T06:15:55Z, event ID `325b2b66-93bc-4882-9c05-87a083f70bb8`, request ID `NuZlt8a37iepibyilObnnLmf0bNDrqMkefd0Ii0FUpL9iBdFKkVI`). This is the Finance Ops monthly regulatory reporting analyst.

## Edge 1: change the reader policy

**Caller:** `reporting-analyst`.

**Permission and target:** `iam:CreatePolicyVersion` on `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess`. `ReportingAnalystAccess`, statement `ChainB_AmendReaderPolicy`, allows `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, and `iam:DeletePolicyVersion` on that policy ARN without a condition. The user's `ReportingAnalystBoundary` statement `CapRead` includes `iam:*`; the account SCP has no matching deny.

**Request made:**

```bash
aws iam create-policy-version \
  --policy-arn arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}' \
  --set-as-default
```

**Audit result:** CloudTrail records `iam.amazonaws.com / CreatePolicyVersion` with no error at `2026-11-19T06:15:55Z`. Event ID: `470c5222-ec60-4d00-9baf-526cee5857aa`. Request ID: `NgqdI4RzkdgnQaa9bmDbdWaJvzyEVbKNUnFxmYyGbikgpdPyW36O`. The event's request parameters name the policy ARN, include `setAsDefault: true`, and contain `Effect: Allow`, `Action: "*"`, `Resource: "*"`. Its responseElements are null, so this export does not provide a version ID or raw CLI response.

**Capability established:** the successful request set a wildcard policy document as the policy's default. The policy-to-role attachment is described by the role inventory in the project; the export event itself records the policy mutation, not the attachment lookup.

## Edge 2: request the reader role

**Caller:** the same IAM user. `ReportingAnalystAccess`, statement `ChainB_AssumeReader`, allows `sts:AssumeRole` on `arn:aws:iam::418274630117:role/ashford-crossacct-reader` without a condition. The role trust document accepts the user; the user's boundary allows `sts:AssumeRole`, and the SCP has no matching deny.

**Request made:**

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::418274630117:role/ashford-crossacct-reader \
  --role-session-name task0-prediction-replay
```

**Audit result:** CloudTrail records `sts.amazonaws.com / AssumeRole` with no error at `2026-11-19T06:15:56Z`. Event ID: `37c3d6ff-b7af-46bd-a454-462e3b944c7b`. Request ID: `MLOS51HUgDSQRMK5SDv68kroX5lVd5DME6MVgcCx3b5ZOGxGZy3j`. The request names the reader role and session name `task0-prediction-replay`.

This record supports a successful AssumeRole request. The export does not contain a subsequent `GetCallerIdentity` event for the assumed-role ARN or the returned STS credentials, so this report does not claim an independently verified session identity.

## Edge 3: privileged use is not evidenced in this export

Neither `CreateUser` nor `DeleteUser` under the assumed role appears in `audit-export-replay.json`. The only `CreateUser` event in that export is a denial at `2026-11-19T06:15:05Z`, event ID `09d135bf-0589-419d-b20e-351f33ecea64`, request ID `MsjACIWaVVItfV4INLBDh8T189Ebf4Xt8SrRcZcz5fXTXDmQpYUk`; its caller is still `reporting-analyst`. It is not proof of role-based IAM administration.

**Status:** policy mutation and the AssumeRole request are evidenced. The assumed-role identity verification and privileged IAM use are not evidenced by this signed export. Therefore this file does not claim the chain reached or exercised administrative authority.

## Composition supported by the available records

The export shows the same ordinary principal successfully changing the default document of a named managed policy to `Allow * on *`, then successfully requesting `ashford-crossacct-reader`. These are the two verified actions that create a plausible escalation path. Because this export does not prove the resulting session identity or any privileged action under it, the administrative outcome remains unverified here.
