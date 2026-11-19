# 4. Across the Boundary

## Verdict

The policy-mutation chain **did cross** from prod account `418274630117` into dev account `418274630228`, but only after the source principal became an administrator. The destination identity was confirmed as `arn:aws:sts::418274630228:assumed-role/ashford-dev-maintenance/cross-account-proof`. The original reporting user could not cross directly.

## The two account-owned decisions

### Caller side — prod account 418274630117

The caller-side authorization document is the identity policy `ReportingAnalystAccess`, attached to `reporting-analyst` in prod. Its `ChainB_AssumeReader` statement is:

```json
{"Effect":"Allow","Action":"sts:AssumeRole","Resource":"arn:aws:iam::418274630117:role/ashford-crossacct-reader"}
```

There is no condition. For the direct request to the dev role, this statement's resource does not match `arn:aws:iam::418274630228:role/ashford-dev-maintenance`; no other user statement grants that target. The user boundary `ReportingAnalystBoundary`, `CapRead`, includes `sts:AssumeRole` on `*`, but a boundary only caps and does not supply the missing identity grant.

After the first chain, however, the caller was no longer the user: it was `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/boundary-proof`. The default v2 of the attached `AshfordCrossAcctReaderAccess` policy allowed `Action:"*"`, `Resource:"*"`. That source role therefore had an effective `sts:AssumeRole` grant to the dev role. Its `get-role` response showed no role permissions boundary.

### Receiver side — dev account 418274630228

The target resource is role `ashford-dev-maintenance`, whose trust policy is owned and evaluated in the receiving dev account. Its document was retrieved using the valid dev-role session and returned:

```json
{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::418274630117:root"},"Action":"sts:AssumeRole"}
```

There is no trust condition. This accepts a request made by an authorized principal from prod account `418274630117`; it does not grant that principal permission to make the request. The handover names Platform as the owner of organization-level SCPs, but does not identify an individual team owner for this dev role trust. The two documents belong to separate accounts and are evaluated separately.

### Organization governance

`AshfordGuardrails` is the SCP applied by Ashford Platform to prod, dev, and shared. Its explicit denies cover `iam:CreateAccessKey`, `iam:CreateLoginProfile`, organization leave, and account closure. It contains no `sts:AssumeRole` deny. The user's permissions boundary allows `sts:AssumeRole` as a cap, and the assumed source role had no boundary in its `get-role` response. Thus neither governance layer blocks the admin role's cross-account request; the SCP still constrains other actions in the destination organization.

## Executed result

1. From `reporting-analyst`, `aws sts assume-role --role-arn arn:aws:iam::418274630228:role/ashford-dev-maintenance --role-session-name boundary-review` returned `AccessDenied`, naming the user. CloudTrail `AssumeRole` at `2026-11-19T05:29:41Z`, object `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0530Z_a0Ecd55bF8111d2F.json.gz`. Attribution: source identity policy resource scope, not destination trust.
2. After assuming the modified prod reader role, a fresh call to `GetCallerIdentity` returned `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/boundary-proof`.
3. That caller requested `sts:AssumeRole` on `arn:aws:iam::418274630228:role/ashford-dev-maintenance`; STS returned credentials. `GetCallerIdentity` using those credentials returned `arn:aws:sts::418274630228:assumed-role/ashford-dev-maintenance/cross-account-proof`. The successful source call is logged at `2026-11-19T05:30:14Z` in the same CloudTrail object as the direct refusal.

The account boundary is a real restriction on the ordinary user, but not a security boundary against the admin authority reached in prod. The source permission and destination trust both had to agree; neither document alone was sufficient.
