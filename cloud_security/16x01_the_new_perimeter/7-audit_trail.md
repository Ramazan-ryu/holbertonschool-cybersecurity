# 7. Find Yourself in the Log

I reconstructed the chain from the current lab's own CloudTrail objects in `ashford-cloudtrail-ap7f3a`, under `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/`. The signed export is `evidence/audit-export.json` (93 recorded events; SHA-256 `b81e81504f656a7a04e9a8ea2006cd8deb2d6a10d987410c5350286dddf5cf5c`). The trail bucket read itself is not logged.

## Policy mutation chain

1. At `2026-11-19T03:45:26Z`, `CreatePolicyVersion` changed `arn:aws:iam::418274630117:policy/AshfordCrossAcctReaderAccess` to a default v2 whose request document granted `Action:"*"`, `Resource:"*"`. The event is in `.../2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0346Z_70fB56CA51C7fe8C.json.gz` and has no error.
2. Two seconds later, `AssumeRole` requested `arn:aws:iam::418274630117:role/ashford-crossacct-reader`, session name `esc`, and succeeded in the same object. This is the important transition: the caller became a role whose attached policy had just been widened.
3. An attempted `CreateUser proof` at `03:45:29Z` failed under `user/reporting-analyst`; the response named that user, showing the CLI had not switched credentials. Later, using an actual STS-backed boto3 session, `GetCallerIdentity` returned `assumed-role/ashford-crossacct-reader/chain-proof`. `CreateUser` and `DeleteUser` both succeeded at `05:28:56Z` in `.../2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0529Z_BD35bac2A0d5c77f.json.gz`.
4. At `05:30:14Z`, that assumed admin session also assumed `ashford-dev-maintenance` in account `418274630228`; a caller-identity check confirmed the dev account role session. The matching source audit object is `...T0530Z_a0Ecd55bF8111d2F.json.gz`.

The alert should center on the successful `AssumeRole` into `ashford-crossacct-reader`, because that is when the principal changes. Such assumptions may be ordinary, so alerting on the role name alone would be noisy. Distinguish this path by correlating the same source principal's recent `CreatePolicyVersion`/`SetDefaultPolicyVersion` against a policy attached to the target role, especially when the new default adds wildcard actions/resources, followed immediately by the role assumption. The privileged `CreateUser` event is later evidence; by then the role has already been assumed.
