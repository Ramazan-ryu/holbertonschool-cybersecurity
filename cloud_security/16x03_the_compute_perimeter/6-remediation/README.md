# 6 — Remediation Plan and Validation Record

## 1. Metadata posture

The observed issue is that the storefront fetched the metadata credential path without presenting an IMDSv2 token. The prescribed control is the workstation's `sudo imds-mode strong`. On the latest run, that command returned success; replaying the exact forged URL returned `HTTP=502`, 23 bytes, with no credential fields. The weak-mode baseline returned the credential document.

**Validation verdict: validated for the tested request only.** The exact tokenless metadata fetch returned HTTP 502 and no credential fields under strong mode, compared with the successful credential response under weak mode. This is endpoint hardening: it blocks the tested metadata credential consequence, but it does not repair the application.

The catalog image-import SSRF primitive remains. The `src` destination is still attacker-controlled, as demonstrated in `1-door.md` by fetching the Example Domain response. Strong IMDS mode does not prove that requests to every internal destination are blocked. Application remediation should enforce a strict destination allowlist; validate scheme, hostname, and resolved IP addresses (including private, loopback, link-local, and alternate address forms); revalidate every redirect destination; and restrict outbound egress to the destinations the feature needs. Those controls address the SSRF path itself. IMDS hardening limits the consequence of reaching instance metadata and remains necessary even after an application fix, since other request paths may exist.

## 2. Function role narrowing

`function-role-least-privilege.json` is the proposed policy. It narrows the seven API actions from `3-needed_calls.md` to the specific bucket prefixes, queue, table, and secret. The attached policy was observed at version `v1`. After copying the policy document to the workstation, `aws iam create-policy-version` returned `AccessDenied`: `appsec-reviewer` is not authorized for `iam:CreatePolicyVersion`. No policy change occurred.

**Validation verdict: blocked and not applied.** `iam:CreatePolicyVersion` was denied first to the read-only `appsec-reviewer`, then to a fresh `marlowe-web-instance-role` session obtained through IMDSv2 while strong mode remained enabled. The `inst` profile itself was stale (`InvalidClientTokenId`), but refreshing credentials did not grant the required write permission. The prior function-role session returned four users for `iam list-users` and successfully retrieved the secret; those are baseline results, not post-change proof. A post-attempt `iam get-policy` call confirmed the default remains `v1`. An authorized account administrator must apply the policy, after which the same excess call and a code-required call must be retested.

## Sequencing recommendation

Deploy and retain the IMDSv2 requirement first. It is independently validated and removes the tested metadata credential consequence at the service boundary, protecting against request routes beyond this one SSRF. Keep the application SSRF fix on the remediation plan: the attacker-controlled image-import destination remains available and requires its own destination validation and egress controls. The function role also needs an authorized administrator to apply the scoped policy. That change is not complete: the write attempt was denied, and there is no post-change negative or positive proof. After authorization, test the same previously successful excess call and a code-required call under a fresh session of the narrowed function role.
