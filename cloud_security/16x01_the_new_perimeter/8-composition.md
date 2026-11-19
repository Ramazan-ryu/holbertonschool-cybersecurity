# 8. Review: Nothing Was Broken

## The exercised chain

The starting principal was `arn:aws:iam::418274630117:user/reporting-analyst`, a Finance Ops reporting analyst. `ChainB_AmendReaderPolicy` allowed this user to create and set the default version of `AshfordCrossAcctReaderAccess), attached to `ashford-crossacct-reader). The user made the default `Effect: Allow`, `Action: "*"`, `Resource: "*"` (CloudTrail event `470c5222-ec60-4d00-9baf-526cee5857aa`, 06:15:55Z).

`ChainB_AssumeReader` and the role trust allowed the same user to assume that role. The call succeeded (event `37c3d6ff-b7af-46bd-a454-462e3b944c7b`, 06:15:56Z). Task 7 records the resulting session as `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/task0-prediction-replay` (event `37fec8b1-3a62-4e35-9e07-9f9c74c438d6`). Under that session, `CreateUser` and `DeleteUser` succeeded (events `3a924e0e-2f16-44d0-a67a-773a36d87b58` and `063cc197-ca58-473e-aee7-f6f1dcd3aba2`). Task 7 locates them in `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0616Z_041F727DBEDbDa41.json.gz`.

The demonstrated administrative authority is IAM user creation and deletion. The wildcard role policy remains subject to SCP denies on access-key creation, login profiles, organization exit, and account closure.

## Why valid permissions composed

Policy-version management let the analyst change the authority attached to a role; role assumption let the same analyst obtain that changed authority. Each grant had a plausible isolated purpose, but together they produced IAM user-management capability that neither grant described alone.

## What the clean scan measured

A monthly scan with no findings means it detected no individual configuration defects within its checks and scope. It does not establish that valid policy edits, trust relationships, and role assumptions cannot compose into high-impact access. Ashford measured isolated defects, while this chain depended on effective permissions across identities and state changes.

## A budgetable detection activity

Run effective-permission and identity attack-path analysis monthly and after policy, trust, or role-attachment changes. Model principals, policy attachments and versions, trusts, boundaries, SCPs, state changes, and cross-account transitions; rank paths from ordinary principals to high-impact actions. Validate the highest-risk multi-hop paths in a lab. Budget by account count, scan cadence, and validation hours.
