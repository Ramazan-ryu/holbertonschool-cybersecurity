# 8. Review: Nothing Was Broken

## The chain

Start: `reporting-analyst`, Finance Ops reporting analyst.

1. **Policy edit.** `ChainB_AmendReaderPolicy` grants `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` on `AshfordCrossAcctReaderAccess`, attached to `ashford-crossacct-reader`. The analyst set a default version allowing `*` on `*` (`470c5222-ec60-4d00-9baf-526cee5857aa`).
2. **Assume role.** `ChainB_AssumeReader` grants `sts:AssumeRole` on that role; its trust names the analyst. The analyst assumed it (`37c3d6ff-b7af-46bd-a454-462e3b944c7b`), gaining a session that carries the edited policy.
3. **Privileged use.** The session's wildcard policy allows `iam:CreateUser` and `iam:DeleteUser`, used on `ashford-prediction-proof` (`3a924e0e-2f16-44d0-a67a-773a36d87b58`, `063cc197-ca58-473e-aee7-f6f1dcd3aba2`). The user's permissions boundary does not apply to a role session.

Bounds: the SCP still denies access-key creation, login profiles, and organisation exit. Proven: IAM user creation and deletion through the role. Not tested: other services.

## Why it composed

Each grant had an ordinary purpose: maintaining one reporting policy and reading through one reporting role. The seam is that the role's authority comes from a policy this principal can edit, and the principal can assume that role. Neither grant describes the combination, so no one approved it.

## What the clean scan measured

A clean scan shows no single configuration is defective. It does not show that effective permissions stay safe when edits, trust and role assumption combine. Ashford's scan measured isolated defects; the property that failed was reachable authority.

## What would find it

A scheduled effective-permission analysis models principals, policies, trust, assume-role edges, boundaries and SCPs, and lists every path from a non-administrative principal to administrative control. Run it on every policy or trust change and monthly. Validate the highest-impact multi-hop paths by hand in a lab and log their event IDs. Its input (an account configuration export), output (a ranked path list) and per-run cost are fixed, so it can be budgeted.
