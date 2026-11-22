# 7 — Two Credential Chains in the Lab Audit Record

## Evidence source and its limits

Source file: `16x03_the_compute_perimeter/evidence/audit-export.json`.

- Lab-generated export. Top-level fields: `account`, `event_count` (93), `events` (93 entries), `exported` (`2026-11-22T14:16:52Z`), `hmac_sha256`, `lab` (`16x03-the-compute-perimeter`), `principal` (`arn:aws:iam::500100200300:user/appsec-reviewer`).
- SHA-256 of the file: `b1d3aae713d0fac690b7e9960b02701d3cdee32f60001567f5c7964bfe59d8b0`.
- Time range of events: `2026-11-21T20:47:44Z` to `2026-11-22T14:16:51Z`.
- The `events` list mixes application records (`marlowe-web.amazonaws.com` `FetchUrl`, which have `userIdentity: null`), IMDS records, STS records and service calls. These are not all provider API records.
- CloudTrail lookup was denied to the reviewer principal. No provider-side record independently confirms these events.
- The HMAC cannot be verified here, because the signing key is not in the evidence set.

This file cites the bundle as the lab's record of events. It does not claim that every event was observed at the cloud provider, and it does not treat the bundle as independent proof.

## How to read this file

There are two chains. Each step has a number. Chain A runs from storefront input to obtaining instance-role credentials. Chain B starts at a handoff: the instance-role credentials are used to assume the processor role. Chain B does not start until Chain A's last credential step is complete.

Chain A ends at step A6 (its credential use continues through A10). Chain B begins at step B1, a second fetch by `marlowe-web`.

## Chain A — storefront URL fetch to instance-role credentials

Initiating activity: `marlowe-web` `FetchUrl` requests on the storefront `image-import` feature.

| Step | UTC | Event ID / request ID | Activity | Result |
|---|---|---|---|---|
| A1 | Nov 21 20:47:44 | `56171c45-90ea-4cf1-a2e7-0f384d2108d0` / `51FB65F094A746F1` | `marlowe-web` `FetchUrl`, `image-import`, target `http://example.com/`; source `127.0.0.1` | `reached:true`. Shows the server-side fetch path works. |
| A2 | Nov 21 20:47:44 | `885aadcb-54a1-4109-9fc0-9b208dfb5cb2` / `3873791B8F524D00`; `e04d5616-7aa7-4035-aec1-410b22ebbb73` / `DE53AA3B16694F05` | `FetchUrl` for `preview` and `redirect`, each targeting `http://169.254.169.254/` | Both `reached:false`. `1-door.md` records HTTP 403 and HTTP 400. |
| A3 | Nov 21 20:49:19 | `e3bd32a7-f407-4abd-809d-ba8c0b4b6442` / `9E6824502EED4E3B` | `marlowe-web` `FetchUrl`, `image-import`, target `http://169.254.169.254:80/latest/meta-data/iam/security-credentials/marlowe-web-instance-role` | `reached:true`. |
| A4 | Nov 21 20:49:19 | `d08aa849-c5b9-42dd-b906-c95bbf459557` / `2EA7409F2EA6496F` | IMDS `GetInstanceCredentials` for `marlowe-web-instance-role`, paired with A3 | Success. Credential values are not included. |
| A5 | Nov 21 21:14:04 | `27445721-d743-4c7e-a01b-fdb3a1d0e83a` / `5624E01EF8E9482E`; paired IMDS `38cb8b2a-c6e0-4c08-bb87-6fd55d18d099` / `6D808DE5245B4C07` | Repeated `image-import` fetch to the same credential path, and IMDS `GetInstanceCredentials` | Both recorded as successful. |
| A6 | Nov 21 21:14:05 | `78292b6c-70fa-48b3-b929-33b4c1ceb27a` / `EfbPaAHksX7cYq5O6ROS7VvWdtcgeYb0WZRRzsoQvaxfioW6dF4l` | STS `GetCallerIdentity` as `arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe`; source `127.0.0.1`, AWS CLI 2.31.35 | Recorded as successful. Shows the role behind the retrieved credentials. |

Downstream use of the same `i-0marlowe` session. These follow A6 and are part of Chain A's use of the credentials:

| Step | UTC | Event ID / request ID | Action and target | Outcome recorded |
|---|---|---|---|---|
| A7 | 21:14:06 | `14772654-5be6-43dc-b38a-f6c3458e0133` / `8ihFkBAXRgiUXYmPDXAGAXHEEpswVJLW6oEgVKjkhffXqFBcTiAX` | S3 `GetObject`, `marlowe-orders-mc4e21`, key `orders/2026-Q1.json` | Success |
| A8 | 21:14:07 | `2f87e3d9-7cc2-408c-b4ec-6b13a247557b` / `xHUDptXO3ZRPq29f3B7A0nOX74JGzPfrAf5fPGN9zVvEUAeIXrEm` | SQS `ReceiveMessage`, `marlowe-customer-events`, maximum 1, visibility 0 | Success |
| A9 | 21:14:08 | `4c5221b8-0aa6-439c-8a17-eb1099f0efe5` / `ZdoxkXFkUKINV6V7Dtc4uIgiHGBjsibkOUAzXyn085q2eamVuqWn` | Secrets Manager `GetSecretValue`, `marlowe/stripe-webhook-signing` | Success; secret value omitted |
| A10 | 21:14:09 | `25b379b9-793f-4c8e-899c-e4e261031117` / `mDOGL1BPwxPc6dMe063RvUTZalTzLqFdPJcDZnEF1y4iFUNYbbNI` | IAM `ListUsers`, account `500100200300` | `AccessDenied` |

Remediation check, after `sudo imds-mode strong` and replay of the same forged request:

| Step | UTC | Event ID / request ID | Result |
|---|---|---|---|
| A11 | 21:48:10 | `6ebfc14a-b023-4c8b-8870-d2cbcd0059db` / `1D86970667954D24` | Metadata URL, `reached:"error"` |
| A12 | 21:48:28 | `7460abd3-8919-4f2c-ae69-596004ca5fc3` / `2B853364A06D4336` | Explicit `:80` URL, `reached:"error"` |

`1-door.md` records HTTP 502 and no credential fields. No `GetInstanceCredentials` event follows those retries.

## Handoff

Chain A produced the instance-role credentials at A4 and A5 and used them at A6–A10. Chain B uses those credentials to assume a different role.

## Chain B — instance role to processor execution role

Initiating activity: a second `marlowe-web` fetch to the same credential path, separate from Chain A's steps.

| Step | UTC | Event ID / request ID | Action, principal, and target | Outcome recorded |
|---|---|---|---|---|
| B1 | Nov 21 21:17:46 | `ecb0e9fe-1372-45dd-a0e2-1e82475042a5` / `4F19B8DF139D471C`, paired with IMDS `1431b87f-775a-4b82-b978-1271fabec3a3` / `91326FA552144E83` | `marlowe-web` `FetchUrl` to the instance-role credential path; IMDS returns credentials for `marlowe-web-instance-role` | Both recorded as successful. |
| B2 | 21:17:47 | `8516c4c7-98ea-43e2-8063-2aa913d9f192` / `TO1CMWbLmk5DeK4cb5z7wDFcQQq3HhPYGhLKUCXrLpbpNFoVypuR` | STS `AssumeRole` by `arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe` for `arn:aws:iam::500100200300:role/marlowe-order-processor-role`; session `perimeter-review`; source `127.0.0.1` | Verified in the bundle: principal, role, session, source and request ID match. `responseElements` is null and no error code is recorded. The success is inferred from the absence of an error. This is the handoff. |
| B3 | 21:17:48 | `5c12fbf8-8f0c-40b6-b21a-b9099aa3cefc` / `HWhfoTEXIxKrkzxQ4rHkvRuaeSUXt7tIO91BbfqnnOKlfoP1ETaG` | STS `GetCallerIdentity` as `...marlowe-order-processor-role/perimeter-review`; source `127.0.0.1` | Recorded as successful |
| B4 | 21:17:49 | `66d1d4bd-7656-47a4-9cae-abacc53ff73d` / `qEqDrAnI881Gg3ckcGLB84vWvjqRl6SgnkX6g9SWllodXklTuHpJ` | S3 `ListBuckets`, account `500100200300`; session `perimeter-review` | Recorded as successful; CLI count 2 |
| B5 | 21:17:50 | `906d3285-f533-411f-9288-910550c73be3` / `UqYjflg9gvcA9l1eW7GyosKCPzsNUgPRmGWMqIFI8MwYXLVJWqFz` | Secrets Manager `ListSecrets`; same session | Recorded as successful; CLI count 1 |
| B6 | 21:17:51 | `2a4a1c64-8002-4225-a1af-296e753044df` / `fU3Ge72rcqMYDHoyVog8XehU59WzIchzigHgLDJoWDvCdUvZBzjH` | SQS `ListQueues`; same session | Recorded as successful; CLI count 1 |
| B7 | 21:17:52 | `68df8678-af77-4ed6-b5a5-cfe6f88402d7` / `auzL2HDQmkYAR7c3NVOqBXMCwfCNfw7mrECAE0kpD3k1wQB1p0ES` | IAM `ListUsers`; same session | Recorded as successful; CLI count 4 |
| B8 | 21:17:53 | `84f19f20-72b8-4c41-bbee-8841427a1b96` / `Vcx6J79V42R7cqqWaCfXIH8jVDe7DMlAAvmkPNWCFch5lxrmoV64` | DynamoDB `ListTables`; same session | Recorded as successful; zero table names |
| B9 | Nov 22 14:16:47 | `46ce6c73-95c2-4a13-ae05-109c34a68043` / `wVZcamRwNG0uuAULNwUfoqo5HxO7rqZbCBOpjVbm2riuN7AfCzsm` | STS `AssumeRole` by instance session `i-0marlowe` for the processor role; session `evidence-targets`; source `127.0.0.1` | Recorded as successful |
| B10 | Nov 22 14:16:48 | `c9ff1894-0f45-438d-ad67-0c05109d86b7` / `I7Fgu5CjNNFEUAtp7eRakklVW2xXtgekKouObw1ASUUynJwPXMyn` | STS identity confirmation for session `evidence-targets` | Recorded as successful |
| B11 | 14:16:49 | `618ab63a-5eef-433e-94a8-dd7f6f43fddf` / `a40lo3HXh57UfVFpxzm57478KeqAjNykrAm0pCnpwGl6fRYBSyyY` | S3 `ListBuckets`; names `marlowe-orders-mc4e21`, `marlowe-cloudtrail-mc4e21` | Recorded as successful |
| B12 | 14:16:50 | `52cf90c5-6ed2-4aa0-83eb-df3b3a8a849a` / `dSd1lHaMkVnJ0NtEcQqhGMhGHNcm5BYSI6dFUQbCIMr6vSC5YPmR` | SQS `ListQueues`; names `marlowe-customer-events` | Recorded as successful |
| B13 | 14:16:51 | `66a33200-6802-45a9-8999-a43e97b442fd` / `gQ4HK1cDTkdBLOryTsTVjbYgRGIV5ihmkxgwvUtfRABUZtkpgnpC` | Secrets Manager `ListSecrets`; names `marlowe/stripe-webhook-signing` | Recorded as successful |

Verification status: the event IDs for B1, B2, B9, B11 and B8 and the Chain A events A1 and A6 were confirmed present in the bundle, each once. Only B2's full record was read. The other rows are cited from the bundle's content and have not all been checked field by field.

Note on B9: the `evidence-targets` credentials were obtained at 14:16:45 through metadata `GetInstanceCredentials` event `55965799-9184-4bc9-bc54-630b1c51f296` (request `3BEB923D04AE4986`). That retrieval was run from the lab shell for the inventory probes. It is not an SSRF event.

Chain B does not show that a package vulnerability was exploited or that a Lambda invocation created these sessions. The chain supports: instance-role credentials → STS `AssumeRole` → processor-role session → inventory calls. It does not show account-wide administration.

## Detection signal and what is not established

The candidate signal: `marlowe-web` fetches the instance credential path (A3, B1), IMDS returns `GetInstanceCredentials` for `marlowe-web-instance-role` (A4, B1), and session `i-0marlowe` then makes AWS CLI calls from `sourceIPAddress=127.0.0.1` (A6–A10, B2–B13).

This file does not establish that the source is impossible for the workload:

- `127.0.0.1` is the source of every management call in this lab, including the reviewer's own commands. It does not separate the workload from an operator.
- No deployment specification is in the evidence set. The reviewer's `16x03_the_compute_perimeter` folder contains only the audit export and `6-remediation/function-role-least-privilege.json`.
- The bundle is lab-generated, so it cannot independently show what the provider observed.

Without a deployment specification and a provider-side record, no event can be shown to be outside the workload's legitimate boundary. The observation is a context mismatch that needs analyst review.

To establish the boundary, the owner would need to supply the instance's network placement, expected egress addresses, and confirmation of how the lab export is generated. A production detector would compare session and source against those values and alert on unexplained mismatches for analyst review. False positives include approved operator access, approved proxy or endpoint egress, and session-name reuse.
