# 4. Across the Boundary

The account boundary is permeable to the fully assumed administrator role, but not to the original reporting user.

**Caller permission:** In `ReportingAnalystAccess`, `ChainB_AssumeReader` allows `sts:AssumeRole` only on the in-account `ashford-crossacct-reader` role. An attempt by `reporting-analyst` to assume `arn:aws:iam::418274630228:role/ashford-dev-maintenance` returned `AccessDenied` (`AssumeRole`, `2026-11-19T05:29:41Z`, CloudTrail `...T0530Z_a0Ecd55bF8111d2F.json.gz`). That is an identity-policy refusal: the requested role ARN is outside the statement's resource. The user permissions boundary allows `sts:AssumeRole`, but a boundary does not grant it.

**Receiving trust:** The dev role's `get-role` document, retrieved in a valid dev-role session, has `Principal: {"AWS":"arn:aws:iam::418274630117:root"}` and `Action: "sts:AssumeRole"`. A source role with `Action:"*"` can make the request, and this trust accepts the prod account principal.

**Executed result:** First, the user assumed the modified reader role and `GetCallerIdentity` confirmed `arn:aws:sts::418274630117:assumed-role/ashford-crossacct-reader/boundary-proof`. That role then assumed the dev role; STS returned credentials and the following identity call returned `arn:aws:sts::418274630228:assumed-role/ashford-dev-maintenance/cross-account-proof`. CloudTrail has the successful source `AssumeRole` at `05:30:14Z` and the denied direct user request at `05:29:41Z` in `...T0530Z_a0Ecd55bF8111d2F.json.gz`.

Both halves matter: trust alone did not let the original user cross, and the user's policy alone did not authorize dev access. After the policy-mutation chain, the assumed administrator could request it and the receiving trust allowed it. In this configuration the account boundary is a control on ordinary principals, not a hard security boundary against administrative control in prod.
