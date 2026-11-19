# 8. Review: Nothing Was Broken

## The chain, each step in the signed export

Start: `reporting-analyst`, the Finance Ops regulatory reporting analyst. `GetCallerIdentity` returned the user ARN (event `325b2b66-93bc-4882-9c05-87a083f70bb8`).

1. **Policy edit.** Decisive permission: `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion`, granted by `ChainB_AmendReaderPolicy` on `AshfordCrossAcctReaderAccess`. Capability created: the policy attached to `ashford-crossacct-reader` now has a default version allowing `*` on `*` (event `470c5222-ec60-4d00-9baf-526cee5857aa`).
2. **Assume role.** Decisive permission: `sts:AssumeRole`, granted by `ChainB_AssumeReader`. The role's trust names the analyst. Capability created: a session of the role, which carries the edited policy. Event `37c3d6ff-b7af-46bd-a454-462e3b944c7b`. `GetCallerIdentity` returned `assumed-role/ashford-crossacct-reader/task0-prediction-replay` (event `37fec8b1-3a62-4e35-9e07-9f9c74c438d6`).
3. **Privileged IAM use.** Permission: the role's default policy, not the user's policy. The user's permissions boundary does not apply to a role session. `CreateUser` (`3a924e0e-2f16-44d0-a67a-773a36d87b58`) and `DeleteUser` (`063cc197-ca58-473e-aee7-f6f1dcd3aba2`) both show the assumed-role session as their caller.

Bounds: the SCP still denies access-key creation, login profiles, and organisation exit. What is proven is IAM user creation and deletion through the role. Other services are not tested.

## Why it composed

Each grant had an ordinary purpose: keeping one reporting policy current, and reading through one reporting role. The seam is that the role's authority comes from a policy this same principal can edit, and the same principal can assume that role. Neither grant describes the combination, so no one approved it.

## What the clean scan measured

A clean scan shows that no single configuration is defective. It does not show that effective permissions stay safe when edits, trust, and role assumption are combined. Ashford's monthly scan measured isolated defects. The property that failed was reachable authority.

## What would find it

A scheduled effective-permission analysis that models principals, policies, trust, assume-role edges, boundaries, and SCPs, and lists every path from a non-administrative principal to administrative control. Run it after each policy or trust change and on a fixed schedule. Validate the highest-impact paths by hand in a lab and record their event IDs. Its input, output, and cost per run are defined, which manual review's are not.
