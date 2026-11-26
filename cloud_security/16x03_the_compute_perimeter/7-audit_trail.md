# 7 — Reconstructed Identity Chains and Detection Signal

## Evidence source and limits

The supplied `evidence/audit-export.json` is a lab-generated, 93-event export for account `500100200300`, exported `2026-11-22T14:16:52Z`. Its event times span `2026-11-21T20:47:44Z` through `2026-11-22T14:16:51Z`. SHA-256: `b1d3aae713d0fac690b7e9960b02701d3cdee32f60001567f5c7964bfe59d8b0`.

The bundle contains several record types: storefront `FetchUrl` events, IMDS credential events, STS events, and cloud API calls. It is the lab's activity record, not independently verified provider-side CloudTrail. Reviewer CloudTrail lookup was denied, and the HMAC cannot be independently checked without its signing key. The event IDs and request IDs below locate the cited records within this supplied export.

## Chain A — storefront SSRF to instance-role use

This chain begins with the storefront `image-import` feature. The application fetch events (`marlowe-web.amazonaws.com`) are distinct from the IMDS credential events and subsequent STS/cloud API calls.

| Order | Time UTC | Event ID / request ID | Event and target | Recorded outcome |
|---|---|---|---|---|
| A1 | Nov 21 20:47:44 | `56171c45-90ea-4cf1-a2e7-0f384d2108d0` / `51FB65F094A746F1` | `FetchUrl`, feature `image-import`, target `http://example.com/` | `reached:true`; storefront server performed the fetch. |
| A2 | Nov 21 20:47:44 | `885aadcb-54a1-4109-9fc0-9b208dfb5cb2` / `3873791B8F524D00`; `e04d5616-7aa7-4035-aec1-410b22ebbb73` / `DE53AA3B16694F05` | `FetchUrl`, features `preview` and `redirect`, targets `http://169.254.169.254/` | Both `reached:false`; the decoys refused the metadata destination. |
| A3 | Nov 21 20:49:19 | `e3bd32a7-f407-4abd-809d-ba8c0b4b6442` / `9E6824502EED4E3B` | `FetchUrl`, feature `image-import`, target `http://169.254.169.254:80/latest/meta-data/iam/security-credentials/marlowe-web-instance-role` | `reached:true`. |
| A4 | Nov 21 20:49:19 | `d08aa849-c5b9-42dd-b906-c95bbf459557` / `2EA7409F2EA6496F` | IMDS `GetInstanceCredentials` for `marlowe-web-instance-role`, paired with A3 | Success; credentials omitted. |
| A5 | Nov 21 21:14:04 | `27445721-d743-4c7e-a01b-fdb3a1d0e83a` / `5624E01EF8E9482E`; paired IMDS event `38cb8b2a-c6e0-4c08-bb87-6fd55d18d099` / `6D808DE5245B4C07` | A later `image-import` fetch to the same credential path and IMDS `GetInstanceCredentials` | Both recorded successful. This is another fetch event, not the later lab-shell probes. |
| A6 | Nov 21 21:14:05 | `78292b6c-70fa-48b3-b929-33b4c1ceb27a` / `EfbPaAHksX7cYq5O6ROS7VvWdtcgeYb0WZRRzsoQvaxfioW6dF4l` | STS `GetCallerIdentity`, source `127.0.0.1` | Returned `arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe`; identity confirms the role behind the credentials. |

The following provider-style calls are recorded after A6 under the same instance-role session `i-0marlowe`, with source `127.0.0.1`:

| Order | Time UTC | Event ID / request ID | Call | Recorded outcome |
|---|---|---|---|---|
| A7 | 21:14:06 | `14772654-5be6-43dc-b38a-f6c3458e0133` / `8ihFkBAXRgiUXYmPDXAGAXHEEpswVJLW6oEgVKjkhffXqFBcTiAX` | S3 `GetObject`, bucket `marlowe-orders-mc4e21`, key `orders/2026-Q1.json` | Success. |
| A8 | 21:14:07 | `2f87e3d9-7cc2-408c-b4ec-6b13a247557b` / `xHUDptXO3ZRPq29f3B7A0nOX74JGzPfrAf5fPGN9zVvEUAeIXrEm` | SQS `ReceiveMessage`, queue `marlowe-customer-events`, maximum 1, visibility 0 | Success; message not deleted and body omitted. |
| A9 | 21:14:08 | `4c5221b8-0aa6-439c-8a17-eb1099f0efe5` / `ZdoxkXFkUKINV6V7Dtc4uIgiHGBjsibkOUAzXyn085q2eamVuqWn` | Secrets Manager `GetSecretValue`, secret `marlowe/stripe-webhook-signing` | Success; secret value omitted. |
| A10 | 21:14:09 | `25b379b9-793f-4c8e-899c-e4e261031117` / `mDOGL1BPwxPc6dMe063RvUTZalTzLqFdPJcDZnEF1y4iFUNYbbNI` | IAM `ListUsers` | `AccessDenied`. |

**Metadata hardening retest:** after strong mode was enabled, the same tokenless metadata target was replayed. The lab export records the application failures below; `1-door.md` records the HTTP 502 response and absence of credential fields. No subsequent IMDS credential event is paired with these failures.

| Order | Time UTC | Event ID / request ID | Event | Recorded outcome |
|---|---|---|---|---|
| A11 | Nov 21 21:48:10 | `6ebfc14a-b023-4c8b-8870-d2cbcd0059db` / `1D86970667954D24` | Metadata URL fetch | `reached:error`. |
| A12 | Nov 21 21:48:28 | `7460abd3-8919-4f2c-ae69-596004ca5fc3` / `2B853364A06D4336` | Explicit port 80 metadata URL fetch | `reached:error`. |

## Chain B — instance role assumes the function execution role

Chain B is a separate later identity transition. It begins with a later IMDS credential retrieval, then the instance-role session requests `AssumeRole` for `marlowe-order-processor-role`. The records below are not storefront fetches except B1, and B4–B8 are downstream inventory calls after STS confirms the new role session.

| Order | Time UTC | Event ID / request ID | Event, principal, target | Recorded outcome |
|---|---|---|---|---|
| B1 | Nov 21 21:17:46 | `ecb0e9fe-1372-45dd-a0e2-1e82475042a5` / `4F19B8DF139D471C`; paired IMDS event `1431b87f-775a-4b82-b978-1271fabec3a3` / `91326FA552144E83` | `FetchUrl` by `marlowe-web` to the instance-role credential path; IMDS retrieves `marlowe-web-instance-role` credentials | Both recorded successful. This is a distinct SSRF/IMDS handoff. |
| B2 | Nov 21 21:17:47 | `8516c4c7-98ea-43e2-8063-2aa913d9f192` / `TO1CMWbLmk5DeK4cb5z7wDFcQQq3HhPYGhLKUCXrLpbpNFoVypuR` | STS `AssumeRole`; caller `arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe`; requested role `arn:aws:iam::500100200300:role/marlowe-order-processor-role`; session name `perimeter-review`; source `127.0.0.1` | No error recorded; success is corroborated by the next STS identity event. |
| B3 | Nov 21 21:17:48 | `5c12fbf8-8f0c-40b6-b21a-b9099aa3cefc` / `HWhfoTEXIxKrkzxQ4rHkvRuaeSUXt7tIO91BbfqnnOKlfoP1ETaG` | STS `GetCallerIdentity`, source `127.0.0.1` | Confirms `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/perimeter-review`. |
| B4 | 21:17:49 | `66d1d4bd-7656-47a4-9cae-abacc53ff73d` / `qEqDrAnI881Gg3ckcGLB84vWvjqRl6SgnkX6g9SWllodXklTuHpJ` | S3 `ListBuckets`, session `perimeter-review` | Success; CLI count 2. |
| B5 | 21:17:50 | `906d3285-f533-411f-9288-910550c73be3` / `UqYjflg9gvcA9l1eW7GyosKCPzsNUgPRmGWMqIFI8MwYXLVJWqFz` | Secrets Manager `ListSecrets`, same session | Success; CLI count 1. |
| B6 | 21:17:51 | `2a4a1c64-8002-4225-a1af-296e753044df` / `fU3Ge72rcqMYDHoyVog8XehU59WzIchzigHgLDJoWDvCdUvZBzjH` | SQS `ListQueues`, same session | Success; CLI count 1. |
| B7 | 21:17:52 | `68df8678-af77-4ed6-b5a5-cfe6f88402d7` / `auzL2HDQmkYAR7c3NVOqBXMCwfCNfw7mrECAE0kpD3k1wQB1p0ES` | IAM `ListUsers`, same session | Success; CLI count 4. |
| B8 | 21:17:53 | `84f19f20-72b8-4c41-bbee-8841427a1b96` / `Vcx6J79V42R7cqqWaCfXIH8jVDe7DMlAAvmkPNWCFch5lxrmoV64` | DynamoDB `ListTables`, same session | Success; empty table list. |

## Later operator-shell probes — separate from both SSRF chains

On Nov 22 at 14:16:45–14:16:51, the operator shell obtained IMDS credentials (`evidence-targets`) and used that separate session for additional inventory. These events are not another storefront `FetchUrl` chain and are not used as evidence for B2's `perimeter-review` session.

| Time UTC | Event ID / request ID | Event | Recorded outcome |
|---|---|---|---|
| 14:16:45 | `55965799-9184-4bc9-bc54-630b1c51f296` / `3BEB923D04AE4986` | IMDS `GetInstanceCredentials` for the operator-shell probes | Success. |
| 14:16:47 | `46ce6c73-95c2-4a13-ae05-109c34a68043` / `wVZcamRwNG0uuAULNwUfoqo5HxO7rqZbCBOpjVbm2riuN7AfCzsm` | STS `AssumeRole`, session `evidence-targets` | Success recorded. |
| 14:16:48 | `c9ff1894-0f45-438d-ad67-0c05109d86b7` / `I7Fgu5CjNNFEUAtp7eRakklVW2xXtgekKouObw1ASUUynJwPXMyn` | STS `GetCallerIdentity`, `evidence-targets` | Identity confirmation recorded. |
| 14:16:49 | `618ab63a-5eef-433e-94a8-dd7f6f43fddf` / `a40lo3HXh57UfVFpxzm57478KeqAjNykrAm0pCnpwGl6fRYBSyyY` | S3 `ListBuckets` | Success; two bucket names. |
| 14:16:50 | `52cf90c5-6ed2-4aa0-83eb-df3b3a8a849a` / `dSd1lHaMkVnJ0NtEcQqhGMhGHNcm5BYSI6dFUQbCIMr6vSC5YPmR` | SQS `ListQueues` | Success; one queue. |
| 14:16:51 | `66a33200-6802-45a9-8999-a43e97b442fd` / `gQ4HK1cDTkdBLOryTsTVjbYgRGIV5ihmkxgwvUtfRABUZtkpgnpC` | Secrets Manager `ListSecrets` | Success; one secret name. |

## Strongest detection candidate and operational rule

The strongest structural signal is B2: a session of `marlowe-web-instance-role`, obtained through the storefront-to-IMDS chain in A, assumes the separate `marlowe-order-processor-role`, followed immediately by B3 identity confirmation and B4–B8 inventory. This instance-workload-to-function-workload identity transition is more discriminating than ordinary S3/SQS/Secrets Manager calls, which may be routine for either workload. It is a candidate context anomaly, not proof of unauthorized activity: the intended trust relationship and approved workflow must be confirmed by the owner.

**Proposed rule:** alert for analyst review when STS `AssumeRole` targets `arn:aws:iam::500100200300:role/marlowe-order-processor-role` and the caller principal is outside an owner-approved list of expected principals for that function role. Record and evaluate `eventTime`, `eventID`, `requestID`, `userIdentity`/caller ARN, target role ARN, `roleSessionName`, `sourceIPAddress`, and available network/runtime context against an owner-approved baseline. Correlate the `AssumeRole` event to the resulting `GetCallerIdentity` session and then to subsequent API calls using the assumed-role session identity and time window. Alert on unexplained principal or origin mismatches for analyst review; do not alert on every role use or use IP alone as the decision.

The observed source is `127.0.0.1` for both workload-session calls and reviewer/operator calls. It does not prove an impossible physical origin. No deployment/network origin baseline or provider-side audit confirmation is available, so the owner must define expected principals and runtime origins before this becomes an enforcement rule.

Maintaining the allowlist and investigating mismatches takes engineering and analyst time. Approved testing, deployment tooling, break-glass operations, proxies, failover, and architecture or egress changes can produce legitimate mismatches. Each change requires baseline review; missed updates create alert noise, while an overly broad baseline weakens detection. No false-positive rate has been measured.
