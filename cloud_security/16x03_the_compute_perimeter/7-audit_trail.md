# 7 — Two Credential Chains in the Audit Record

## Evidence bundle

`evidence/audit-export.json` is the signed bundle with 93 events, exported at `2026-11-22T14:16:52Z` for account `500100200300`. Expected SHA-256: `b1d3aae713d0fac690b7e9960b02701d3cdee32f60001567f5c7964bfe59d8b0`. Verify before relying on any event below:

```sh
sha256sum evidence/audit-export.json
```

The event IDs and request IDs below come from this bundle. Management calls through the lab shim show source `127.0.0.1`. Application fetch records use the `marlowe-web` user agent. The metadata service records `169.254.169.254`. These addresses describe the lab's local service context, not public addresses.

## Chain A — storefront URL fetch to instance-role credentials

The application audit events establish the application-side initiation and result. The paired IMDS event identifies the requested role credential path. `1-door.md` supplies the HTTP response evidence.

| UTC | Event ID / request ID | Source, event, and target | Result |
|---|---|---|---|
| Nov 21 20:47:44 | `56171c45-90ea-4cf1-a2e7-0f384d2108d0` / `51FB65F094A746F1` | `marlowe-web.amazonaws.com` `FetchUrl`; caller context `127.0.0.1`, user agent `marlowe-web`; feature `image-import`, target `http://example.com/` | `reached:true`; confirms the server-side fetch path works. |
| Nov 21 20:47:44 | `885aadcb-54a1-4109-9fc0-9b208dfb5cb2` / `3873791B8F524D00`; `e04d5616-7aa7-4035-aec1-410b22ebbb73` / `DE53AA3B16694F05` | `FetchUrl` for `preview` and `redirect`, each targeting `http://169.254.169.254/`; same application caller context | Both `reached:false`; `1-door.md` records HTTP 403 and HTTP 400 respectively. |
| Nov 21 20:49:19 | `e3bd32a7-f407-4abd-809d-ba8c0b4b6442` / `9E6824502EED4E3B` | `marlowe-web.amazonaws.com` `FetchUrl`; `127.0.0.1`, user agent `marlowe-web`; `image-import` target `http://169.254.169.254:80/latest/meta-data/iam/security-credentials/marlowe-web-instance-role` | `reached:true`. |
| Nov 21 20:49:19 | `d08aa849-c5b9-42dd-b906-c95bbf459557` / `2EA7409F2EA6496F` | `imds.amazonaws.com` `GetInstanceCredentials`; metadata context `169.254.169.254`; path `/latest/meta-data/iam/security-credentials/marlowe-web-instance-role` | Success for role `marlowe-web-instance-role`. Credential values are not included. |
| Nov 21 21:14:04 | `27445721-d743-4c7e-a01b-fdb3a1d0e83a` / `5624E01EF8E9482E`; paired IMDS event `38cb8b2a-c6e0-4c08-bb87-6fd55d18d099` / `6D808DE5245B4C07` | Repeated image-import fetch to the same metadata credential path, followed by `GetInstanceCredentials` for `marlowe-web-instance-role` | Both records succeeded. |
| Nov 21 21:14:05 | `78292b6c-70fa-48b3-b929-33b4c1ceb27a` / `EfbPaAHksX7cYq5O6ROS7VvWdtcgeYb0WZRRzsoQvaxfioW6dF4l` | STS `GetCallerIdentity`; principal `arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe`; source `127.0.0.1`, AWS CLI 2.31.35 | Success; confirms the role represented by the retrieved credentials. |

The same `i-0marlowe` session then used the role against these targets:

| UTC | Event ID / request ID | Service action and target | Outcome |
|---|---|---|---|
| 21:14:06 | `14772654-5be6-43dc-b38a-f6c3458e0133` / `8ihFkBAXRgiUXYmPDXAGAXHEEpswVJLW6oEgVKjkhffXqFBcTiAX` | S3 `GetObject`, bucket `marlowe-orders-mc4e21`, key `orders/2026-Q1.json` | Success |
| 21:14:07 | `2f87e3d9-7cc2-408c-b4ec-6b13a247557b` / `xHUDptXO3ZRPq29f3B7A0nOX74JGzPfrAf5fPGN9zVvEUAeIXrEm` | SQS `ReceiveMessage`, `marlowe-customer-events`, maximum 1, visibility 0 | Success |
| 21:14:08 | `4c5221b8-0aa6-439c-8a17-eb1099f0efe5` / `ZdoxkXFkUKINV6V7Dtc4uIgiHGBjsibkOUAzXyn085q2eamVuqWn` | Secrets Manager `GetSecretValue`, `marlowe/stripe-webhook-signing` | Success; secret value omitted |
| 21:14:09 | `25b379b9-793f-4c8e-899c-e4e261031117` / `mDOGL1BPwxPc6dMe063RvUTZalTzLqFdPJcDZnEF1y4iFUNYbbNI` | IAM `ListUsers`, account `500100200300` | `AccessDenied` |

**Remediation check:** after `sudo imds-mode strong`, the same forged image-import request was replayed. At 21:48:10, event `6ebfc14a-b023-4c8b-8870-d2cbcd0059db`, request `1D86970667954D24`, records the metadata URL with `reached:"error"`. At 21:48:28, event `7460abd3-8919-4f2c-ae69-596004ca5fc3`, request `2B853364A06D4336`, records the explicit `:80` URL with `reached:"error"`. `1-door.md` records HTTP 502 and no credential fields. No `GetInstanceCredentials` event followed those retries.

## Chain B — instance role to processor execution role

This is a separately traceable handoff from the instance-role credentials into the function's execution role, followed by calls outside the handler's seven-action baseline in `3-needed_calls.md`.

| UTC | Event ID / request ID | Service action, principal, and target | Outcome |
|---|---|---|---|
| Nov 21 21:17:46 | `ecb0e9fe-1372-45dd-a0e2-1e82475042a5` / `4F19B8DF139D471C`, paired with IMDS `1431b87f-775a-4b82-b978-1271fabec3a3` / `91326FA552144E83` | `marlowe-web` `FetchUrl` to the instance-role credential path; IMDS returns credentials for `marlowe-web-instance-role` | Both succeed. |
| 21:17:47 | `8516c4c7-98ea-43e2-8063-2aa913d9f192` / `TO1CMWbLmk5DeK4cb5z7wDFcQQq3HhPYGhLKUCXrLpbpNFoVypuR` | STS `AssumeRole` by `...assumed-role/marlowe-web-instance-role/i-0marlowe` for `arn:aws:iam::500100200300:role/marlowe-order-processor-role`; session `perimeter-review`; source `127.0.0.1` | Success |
| 21:17:48 | `5c12fbf8-8f0c-40b6-b21a-b9099aa3cefc` / `HWhfoTEXIxKrkzxQ4rHkvRuaeSUXt7tIO91BbfqnnOKlfoP1ETaG` | STS `GetCallerIdentity` as `...marlowe-order-processor-role/perimeter-review`; source `127.0.0.1` | Success |
| 21:17:49 | `66d1d4bd-7656-47a4-9cae-abacc53ff73d` / `qEqDrAnI881Gg3ckcGLB84vWvjqRl6SgnkX6g9SWllodXklTuHpJ` | S3 `ListBuckets`, account `500100200300`; session `perimeter-review`, source `127.0.0.1` | Success; CLI returned count 2. |
| 21:17:50 | `906d3285-f533-411f-9288-910550c73be3` / `UqYjflg9gvcA9l1eW7GyosKCPzsNUgPRmGWMqIFI8MwYXLVJWqFz` | Secrets Manager `ListSecrets`; same session and source | Success; CLI returned count 1. |
| 21:17:51 | `2a4a1c64-8002-4225-a1af-296e753044df` / `fU3Ge72rcqMYDHoyVog8XehU59WzIchzigHgLDJoWDvCdUvZBzjH` | SQS `ListQueues`; same session and source | Success; CLI returned count 1. |
| 21:17:52 | `68df8678-af77-4ed6-b5a5-cfe6f88402d7` / `auzL2HDQmkYAR7c3NVOqBXMCwfCNfw7mrECAE0kpD3k1wQB1p0ES` | IAM `ListUsers`; same session and source | Success; CLI returned count 4. |
| 21:17:53 | `84f19f20-72b8-4c41-bbee-8841427a1b96` / `Vcx6J79V42R7cqqWaCfXIH8jVDe7DMlAAvmkPNWCFch5lxrmoV64` | DynamoDB `ListTables`; same session and source | Success; zero table names. |
| Nov 22 14:16:47 | `46ce6c73-95c2-4a13-ae05-109c34a68043` / `wVZcamRwNG0uuAULNwUfoqo5HxO7rqZbCBOpjVbm2riuN7AfCzsm` | STS `AssumeRole` by instance session `i-0marlowe` for the same processor role; session `evidence-targets`; source `127.0.0.1` | Success |
| Nov 22 14:16:48 | `c9ff1894-0f45-438d-ad67-0c05109d86b7` / `I7Fgu5CjNNFEUAtp7eRakklVW2xXtgekKouObw1ASUUynJwPXMyn` | STS identity confirmation for session `evidence-targets` | Success |
| 14:16:49 | `618ab63a-5eef-433e-94a8-dd7f6f43fddf` / `a40lo3HXh57UfVFpxzm57478KeqAjNykrAm0pCnpwGl6fRYBSyyY` | S3 `ListBuckets`; names `marlowe-orders-mc4e21`, `marlowe-cloudtrail-mc4e21` | Success |
| 14:16:50 | `52cf90c5-6ed2-4aa0-83eb-df3b3a8a849a` / `dSd1lHaMkVnJ0NtEcQqhGMhGHNcm5BYSI6dFUQbCIMr6vSC5YPmR` | SQS `ListQueues`; names `marlowe-customer-events` | Success |
| 14:16:51 | `66a33200-6802-45a9-8999-a43e97b442fd` / `gQ4HK1cDTkdBLOryTsTVjbYgRGIV5ihmkxgwvUtfRABUZtkpgnpC` | Secrets Manager `ListSecrets`; names `marlowe/stripe-webhook-signing` | Success |

The `evidence-targets` credentials were obtained at 14:16:45 through metadata `GetInstanceCredentials` event `55965799-9184-4bc9-bc54-630b1c51f296` (request `3BEB923D04AE4986`). That retrieval was run from the lab shell to perform the inventory probes. It is not presented as an SSRF event. The SSRF chain is the paired `marlowe-web` and IMDS records in Chain A.

The execution-role probes were controlled role-session tests. They do not show that a package vulnerability was exploited or that a Lambda invocation created those sessions. The supported chain is: instance-role credentials → STS `AssumeRole` → processor-role session → inventory calls. It does not show account-wide administration.

## Detection signal and what is not established

The candidate signal is the sequence: `marlowe-web` fetches the instance credential path, IMDS returns `GetInstanceCredentials` for `marlowe-web-instance-role`, and the session `i-0marlowe` then makes AWS CLI calls from `sourceIPAddress=127.0.0.1`.

This file does not establish that the source is impossible for the workload:

- `127.0.0.1` is the source of every management call in this lab, including the reviewer's own commands. It does not distinguish the workload from an operator.
- No deployment specification is in the evidence set. It does not state where the Marlowe instance runs, which addresses it uses, or which egress paths are approved.
- Without that specification, no event can be shown to be outside the workload's legitimate boundary. The anomaly is a context mismatch that needs analyst review, not a proven structural impossibility.

To establish the boundary, the owner would need to supply the instance's network placement and expected egress addresses. A production detector would compare the session and source against those values, and alert on unexplained mismatches for analyst review rather than blocking. False positives include approved operator access, approved proxy or endpoint egress, and session-name reuse.
