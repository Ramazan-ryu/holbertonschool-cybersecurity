# 8. Review: Nothing Was Broken

## The chain

Start: `reporting-analyst`, Finance Ops regulatory reporting analyst.

1. **Policy edit.** `ChainB_AmendReaderPolicy` grants `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` on `AshfordCrossAcctReaderAccess`, which is attached to `ashford-crossacct-reader`. The analyst set a default version allowing `"*"` on `"*"` (event `470c5222-ec60-4d00-9baf-526cee5857aa`).
2. **Assume role.** `ChainB_AssumeReader` grants `sts:AssumeRole` on that role, and its trust names the analyst. The analyst assumed it (event `37c3d6ff-b7af-46bd-a454-462e3b944c7b`), gaining a session that carries the edited policy.
3. **IAM user management (not yet observed).** The session's policy would allow `iam:CreateUser` and `iam:DeleteUser`. The signed export does not contain these calls under the assumed role, so this step is expected, not evidenced.

Bounds: the SCP denies access-key creation, login profiles and organisation exit. Steps 1 and 2 are evidenced in the export. Step 3 is not.

## Why it composed

Each grant had an ordinary purpose: maintaining one reporting policy and reading through one reporting role. The seam is that the role's authority comes from a policy this principal can edit, and the principal can assume that role. Neither grant describes the combination, so no one approved it.

## What the clean scan measured

A clean scan shows that no single configuration is defective. It does not show that effective permissions stay safe when edits, trust and role assumption combine. Ashford's scan measured isolated defects. The property that failed was reachable authority.

## What would find it

A scheduled effective-permission analysis models principals, policies, trust relationships, assume-role edges, permissions boundaries and SCPs. It lists every path from a non-administrative principal to a high-impact action. It runs on every policy or trust change, and on a fixed monthly schedule. Its highest-impact multi-hop paths are then validated by hand in a lab, and the event IDs are logged. Input (an account configuration export), output (a ranked path list) and per-run cost are fixed, so it can be budgeted.
