# 9. Review: The Refusal

## The refusal

`reporting-analyst` attempted `iam:CreateAccessKey` on `arn:aws:iam::418274630117:user/reporting-analyst`. It was refused at `2026-11-19T03:44:49Z` (CloudTrail `6f2a6985-c2da-4c40-a4a4-a1267385dca0`) and again at `06:14:04Z` (`8f8d27c9-d9fa-4084-90fe-7460ae979aed`).

**Granting statement:** `ReportingAnalystAccess` / `SelfKeyManagement`, `Effect: Allow`, actions `iam:CreateAccessKey` and `iam:ListAccessKeys`, on the user's own ARN. The request matches it.

**Controlling statement:** SCP `AshfordGuardrails` / `NoLongLivedKeys`:

```json
{"Effect":"Deny","Action":["iam:CreateAccessKey","iam:CreateLoginProfile"],"Resource":"*"}
```

**Precedence:** An explicit deny in any applicable policy overrides every allow. The SCP applies to all principals in account `418274630117`. Its deny removes `iam:CreateAccessKey` from the effective permissions, even though the identity allow matches. The permissions boundary `CapRead` includes `iam:*`, so it does not cause this refusal. The SCP alone does.

## What the control was built to stop

The statement blocks static keys and console logins for every principal in the account. That design points to one concern: credentials that outlive the task they were issued for. This is an inference from the statement's shape, not a documented incident.

## Does the rest of the estate support it?

The control blocks one route to administrator authority, but the same authority is reachable without a key:

- **Policy rewrite and role assumption.** `ChainB_AmendReaderPolicy` lets the user set `AshfordCrossAcctReaderAccess` to `Action: "*"`, then `ChainB_AssumeReader` assumes `ashford-crossacct-reader`. Neither step creates a key.
- **Role delegation.** `ChainA_PassAndRun` lets the user pass `ashford-batch-exec` (`AshfordBatchExecAdmin`, `Action: "*"`) to Lambda. The function was created with that role. This is configuration, not a demonstrated runtime escalation.
- **Federation.** `ashford-deploy-pipeline` checks only `aud`, so any matching OIDC subject can assume an administrator role without a key.

**Conclusion:** The concern was justified, because persistent credentials are a real risk. But the SCP covers one route of persistence out of at least three. It constrains credential creation, not role assumption, `iam:PassRole`, or federated subjects, so the admin authority remains reachable.
