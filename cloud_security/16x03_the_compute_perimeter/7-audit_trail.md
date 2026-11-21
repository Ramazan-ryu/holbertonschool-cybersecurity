# 7 — Audit Trail and Detection Signal

## Record inventory

The supplied terminal transcript lists CloudTrail objects in `s3://marlowe-cloudtrail-mc4e21/AWSLogs/`. It shows seeded records from 2026-11-02 through 2026-11-11, then two newer objects:

| Listed object time (UTC) | Object key suffix | Listed size |
|---|---|---:|
| 2026-11-21 20:48 | `20261121T2048Z_41CFA39AFfe3bA1F.json.gz` | 670 bytes |
| 2026-11-21 20:49 | `20261121T2049Z_Dad8a8eb2ecc37Df.json.gz` | 549 bytes |

The workstation's `sudo latchkey-export > evidence/audit-export.json` reported `60 events signed`. The bundle has top-level fields `account`, `event_count`, `events`, `exported`, `hmac_sha256`, `lab`, and `principal`. The events below are dated 2026-11-21 UTC; all listed API events have `sourceIPAddress=127.0.0.1` and an AWS CLI user agent.

| UTC | Event ID | Identity / event | Result |
|---|---|---|---|
| 21:14:05 | `78292b6c-70fa-48b3-b929-33b4c1ceb27a` | Instance role / STS `GetCallerIdentity` | Success |
| 21:14:06 | `14772654-5be6-43dc-b38a-f6c3458e0133` | Instance role / S3 `GetObject` | Success |
| 21:14:07 | `2f87e3d9-7cc2-408c-b4ec-6b13a247557b` | Instance role / SQS `ReceiveMessage` | Success |
| 21:14:08 | `4c5221b8-0aa6-439c-8a17-eb1099f0efe5` | Instance role / Secrets Manager `GetSecretValue` | Success |
| 21:14:09 | `25b379b9-793f-4c8e-899c-e4e261031117` | Instance role / IAM `ListUsers` | `AccessDenied` |
| 21:17:47 | `8516c4c7-98ea-43e2-8063-2aa913d9f192` | Instance role / STS `AssumeRole` to function role | Success |
| 21:17:48 | `5c12fbf8-8f0c-40b6-b21a-b9099aa3cefc` | Function role / STS `GetCallerIdentity` | Success |
| 21:17:49 | `66d1d4bd-7656-47a4-9cae-abacc53ff73d` | Function role / S3 `ListBuckets` | Success |
| 21:17:50 | `906d3285-f533-411f-9288-910550c73be3` | Function role / Secrets Manager `ListSecrets` | Success |
| 21:17:51 | `2a4a1c64-8002-4225-a1af-296e753044df` | Function role / SQS `ListQueues` | Success |
| 21:17:52 | `68df8678-af77-4ed6-b5a5-cfe6f88402d7` | Function role / IAM `ListUsers` | Success |
| 21:17:53 | `84f19f20-72b8-4c41-bbee-8841427a1b96` | Function role / DynamoDB `ListTables` | Success; zero table names returned in CLI response |
| 21:19:42 | `6ffea391-04f7-4911-a0af-384492a3227b` | Instance role / STS `AssumeRole` to function role | Success |
| 21:19:43 | `0855bd0f-350b-4956-9234-0f55a35534ed` | Function role / IAM `ListAttachedRolePolicies` | `AccessDenied` |
| 21:19:44 | `5e381cb4-d3d7-4fc1-97ca-24ce580303b2` | Function role / IAM `ListRolePolicies` | `AccessDenied` |
| 21:25:44 | `586df653-81f9-4417-bba9-2c029d0cb6ff` | Instance role / STS `AssumeRole` to function role | Success |
| 21:25:45 | `e0d19075-5623-491d-a4c5-85a3a7a2f6f9` | Function role / STS `GetCallerIdentity` | Success |
| 21:25:46 | `e5d3c693-ce70-42e7-a07a-205f190deb74` | Function role / IAM `ListUsers` | Success |
| 21:25:47 | `dde8b7c0-cafe-4b6b-a8d0-1b2a6b175315` | Function role / Secrets Manager `GetSecretValue` | Success |
| 21:51:42 | `22f475cf-5f36-4c74-8657-697643f649f4` | `appsec-reviewer` / IAM `CreatePolicyVersion` | `AccessDenied` |
| 22:11:52 | `12a1608c-894e-4eb3-bd2a-53c86e29b6a1` | Instance role / IAM `CreatePolicyVersion` | `AccessDenied` |

The event identities were `arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe`, `.../marlowe-order-processor-role/perimeter-review`, and `.../marlowe-order-processor-role/perimeter-after`. Each listed event had source IP `127.0.0.1`; the user agent was AWS CLI 2.31.35. The signed 60-event bundle is stored at `evidence/audit-export.json`. Its SHA-256 (`45a3536822cd49128623a429f580af97797e2609392b0545261af61456a400f9`) matched between the workstation and this checkout, confirming the copy was not altered. Do not edit its HMAC or event records.

## Detection signal

The high-value structural signal is use of `marlowe-web-instance-role` credentials away from the compute instance to which the role belongs. In this signed record, the role's EC2-style session name is `i-0marlowe`, while the calls are AWS CLI requests from the operator workstation through the local account endpoint (`127.0.0.1`), not calls from the storefront application. Alert when the instance role's temporary credentials are used from a source context not associated with the expected compute/VPC path. Correlate role session, source IP/VPC endpoint, user agent, instance identity, and event time; alert on the identity-location mismatch rather than on ordinary S3 or queue operations alone.

Expected false positives include legitimate role use through NAT gateways, approved proxy or egress services, instance replacement/scale events, and operator-approved debugging. Maintain an inventory of valid egress paths and expected compute identities so the detector excludes those paths while still flagging a role session used from an unrelated workstation or network. The signed activity record confirms the off-compute use in this engagement; the compressed CloudTrail object bodies still need to be matched by event ID to complete independent S3-trail corroboration.
