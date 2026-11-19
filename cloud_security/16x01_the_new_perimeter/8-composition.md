# 8. Review: Nothing Was Broken

## The chain

Starting principal: `reporting-analyst`, the Finance Ops regulatory reporting analyst. Every permission below behaved as its statement says.

1. `ChainB_AmendReaderPolicy` allows `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` on `AshfordCrossAcctReaderAccess`, the policy attached to `ashford-crossacct-reader`. The analyst made a default version allowing `*` on `*` (CloudTrail `470c5222-ec60-4d00-9baf-526cee5857aa`).
2. `ChainB_AssumeReader` allows `sts:AssumeRole` on that role, and the role's trust names the analyst. The analyst assumed the role (CloudTrail `37c3d6ff-b7af-46bd-a454-462e3b944c7b`).

The session carries the role's wildcard policy, bounded by the SCP's denials on access keys and organisation exit. The export does not yet show the assumed-role identity check or any privileged action under the session, so administrative control is the expected result of these permissions, not yet an observed one.

## Why it composed

Each grant had a plausible purpose: maintaining one reporting policy and reading through one reporting role. The seam is that the role's authority comes from a policy the same principal can edit, and the principal can become that role. No single grant describes that combination, so no one approved it.

## What the clean scan measured

A clean scan shows that no configuration is individually defective. It does not show that effective permissions stay safe when combined across policy edits, trust, and role assumption. Ashford's scan measured isolated defects. The property that failed here was reachable authority.

## What would find it

A scheduled effective-permission analysis that models principals, policies, trust, assume-role edges, boundaries, and SCPs, and lists every path from a non-administrative principal to administrative control. Graph tools such as PMapper can run it against the account. Run it after each policy or trust change and on a fixed schedule. Validate the highest-impact paths by hand in a lab and record their event IDs. It has a defined input, output, and cost per run, unlike open-ended manual review.
