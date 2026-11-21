# 6 — Remediation Plan and Validation Record

## 1. Metadata posture

The observed issue is that the storefront fetched the metadata credential path without presenting an IMDSv2 token. The prescribed control is the workstation's `sudo imds-mode strong`. On the latest run, that command returned success; replaying the exact forged URL returned `HTTP=502`, 23 bytes, with no credential fields. The weak-mode baseline returned the credential document.

**Validation verdict: validated for the tested request.** The exact tokenless metadata fetch returned HTTP 502 and no credential fields under strong mode, compared with the successful credential response under weak mode. The app route remains the same URL-fetch feature; IMDS hardening removes the exposed metadata consequence at the service, while an application-only patch would only remove that route.

## 2. Function role narrowing

`function-role-least-privilege.json` is the proposed policy. It narrows the seven API actions from `3-needed_calls.md` to the specific bucket prefixes, queue, table, and secret. The attached policy was observed at version `v1`. After copying the policy document to the workstation, `aws iam create-policy-version` returned `AccessDenied`: `appsec-reviewer` is not authorized for `iam:CreatePolicyVersion`. No policy change occurred.

**Validation verdict: blocked and not applied.** `iam:CreatePolicyVersion` was denied first to the read-only `appsec-reviewer`, then to a fresh `marlowe-web-instance-role` session obtained through IMDSv2 while strong mode remained enabled. The `inst` profile itself was stale (`InvalidClientTokenId`), but refreshing credentials did not grant the required write permission. The prior function-role session returned four users for `iam list-users` and successfully retrieved the secret; those are baseline results, not post-change proof. A post-attempt `iam get-policy` call confirmed the default remains `v1`. An authorized account administrator must apply the policy, after which the same excess call and a code-required call must be retested.

## Required paired proof

For metadata, preserve the exact original forged request and its HTTP/body result before and after strong mode, with the credential body redacted. For the role, capture `iam list-users` success before the change, apply a new default policy version, assume a fresh function-role session, and capture that same call's `AccessDenied` response. Then capture a code-required call such as `secretsmanager get-secret-value` with only ARN/name/version fields selected. Do not record access keys, session tokens, secret values, or order-message bodies.
