# 8. Review: Nothing Was Broken

## The chain

Start: `reporting-analyst`, a Finance Ops reporting analyst.

1. **Policy edit.** `ChainB_AmendReaderPolicy` grants `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` on `AshfordCrossAcctReaderAccess`, attached to `ashford-crossacct-reader`. The analyst set a default version granting `Action: "*"` on `Resource: "*"` (event `470c5222-ec60-4d00-9baf-526cee5857aa`).
2. **Assume role.** `ChainB_AssumeReader` grants `sts:AssumeRole` on that role, and its trust names the analyst. The analyst assumed it (event `37c3d6ff-b7af-46bd-a454-462e3b944c7b`), gaining a session with the edited policy.
3. **IAM user management (not observed).** The session's policy would allow `iam:CreateUser` and `iam:DeleteUser`, but the export contains no such calls under the assumed role.

Bounds: the SCP denies access-key creation, login profiles and organisation exit. The administrative outcome is expected, not established.

## Why it composed

Each grant had an ordinary purpose: one reporting policy, one reporting role. The seam is that the role's authority comes from a policy this principal can edit, and the principal can assume that role. No single grant approved that combination.

## What the clean scan measured

A clean scan shows that no single configuration is defective. It does not show that effective permissions stay safe when edits, trust and role assumption combine. Ashford's scan measured isolated defects; the property that failed was reachable authority.

## What would find it

A scheduled effective-permission analysis models principals, policies, trust, assume-role edges, boundaries and SCPs, and lists paths from a non-administrative principal to high-impact actions. It runs on each policy or trust change and monthly. Top paths are validated by hand in a lab. Its input, output and cost per run are fixed, so it can be budgeted.
