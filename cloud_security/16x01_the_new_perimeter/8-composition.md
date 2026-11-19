# 8. Review: Nothing Was Broken

## The chain

Start: `reporting-analyst`, Finance Ops regulatory reporting analyst.

1. **Policy edit.** `ChainB_AmendReaderPolicy` grants `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` on `AshfordCrossAcctReaderAccess`, which is attached to `ashford-crossacct-reader`. The analyst set a default version allowing `"*"` on `"*"` (event `470c5222-ec60-4d00-9baf-526cee5857aa`).
2. **Assume role.** `ChainB_AssumeReader` grants `sts:AssumeRole` on that role, and its trust names the analyst. The analyst assumed it (event `37c3d6ff-b7af-46bd-a454-462e3b944c7b`), gaining a session that carries the edited policy.
3. **IAM user management through the role.** The session's policy allows `iam:CreateUser` and `iam:DeleteUser`. [VERIFY: event IDs for CreateUser and DeleteUser under the assumed-role session. Keep only IDs that appear in `audit-export-replay.json`. If absent, write "expected, not observed in the export."]

Bounds: the SCP denies access-key creation, login profiles, and organisation exit. Proven: IAM user creation and deletion through the role. Not tested: other services, and any action that would require the SCP exceptions.

## Why it composed

Each grant had an ordinary purpose: maintaining one reporting policy and reading through one reporting role. The seam is that the role's authority comes from a policy this principal can edit, and the principal can assume that role. Neither grant describes the combination, so no one approved it.

## What the clean scan measured

A clean scan shows that no single configuration is defective. It does not show that effective permissions stay safe when edits, trust and role assumption combine. Ashford's scan measured isolated defects. The property that failed was reachable authority.

## What would find it

A scheduled effective-permission analysis models principals, policies, trust, assume-role edges, boundaries and SCPs, and lists every path from a non-administrative principal to a high-impact action. Run it on every policy or trust change and monthly. Validate the highest-impact paths by hand in a lab and log their event IDs. The input (an account configuration export), output (a ranked path list) and per-run cost are fixed, so it can be budgeted.
