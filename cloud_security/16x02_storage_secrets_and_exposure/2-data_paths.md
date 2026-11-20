# 2 — Data paths

## Three distinct routes

| Route | Grant or principal | Resource and action | Observed result |
|---|---|---|---|
| Public policy / ACL | `Principal: "*"` in `LegacyClinicSync`; `AllUsers` group in the exports object ACL | Records bucket `s3:ListBucket` and `s3:GetObject` on its objects; exports object `exports/clinic-rollup.csv` has ACL `READ` | Unsigned list/read probes to the loopback lab endpoint returned HTTP 403. The account-level Block Public Access state could not be queried, so the denial's controlling layer is not established. The permission-bearing configurations are real; current public reachability from the Internet is not proven. |
| Named external account | `arn:aws:iam::905501234789:root` in partner bucket statement `PartnerFeed` | Partner bucket and `share/partner-feed.json`; `s3:ListBucket` and `s3:GetObject`; no `Condition` appears in the returned statement | Resource-side delegation is confirmed by `get-bucket-policy`. Effective access for a Northmoor principal remains untested: no Northmoor profile exists, and its identity-side permissions were not available. |
| Time-limited bearer URL | SigV4 pre-signed `GetObject` URL in support ticket CL-4471 | `alderbrook-partner-share-ab7f3a/share/partner-feed.json` | Executed request returned HTTP 200 and 68 bytes. Matching CloudTrail `GetObject` event is `f94fa759-101b-4113-841a-884e30d530a4`. |

These routes have different authorizations: wildcard policy/object ACL, cross-account resource policy, and a signed URL. The partner bucket's resource policy alone does not establish what a specific Northmoor identity can do; its identity-side grant and any applicable higher-level controls must also allow the request.

## Pre-signed URL: grant, exercise, and limits

Support ticket CL-4471 contains a SigV4 pre-signed `GetObject` URL for `alderbrook-partner-share-ab7f3a/share/partner-feed.json`. Its `X-Amz-Date` is `2026-11-19T23:49:26Z` and `X-Amz-Expires=604800`, giving a stated expiry of `2026-11-26T23:49:26Z`, unless the signing credentials are revoked earlier.

The request was exercised on the workstation with Python `urllib` using the URL from the ticket. The program streamed and discarded the response body, reporting `HTTP 200` and `bytes=68`; no feed contents were printed. CloudTrail records the corresponding successful S3 `GetObject` at `2026-11-20T19:48:16Z`:

- Event ID: `f94fa759-101b-4113-841a-884e30d530a4`
- Trail object: `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/20/734112396500_CloudTrail_eu-west-1_20261120T1948Z_Dd299e7B0be369bA.json.gz`
- Recorded identity: `arn:aws:iam::734112396500:user/grant-issuer`
- Source: `127.0.0.1`; user agent: `Python-urllib/3.12 (presigned)`; no error code

This is a successful local lab access by the bearer URL. The signature authorizes possession of the URL, not proof that the requester is Northmoor. Disabling the intended recipient does not invalidate the URL. Revoking/deactivating the signing credentials or waiting for expiry can invalidate it, subject to any other uses of those credentials. The CloudTrail record attributes the request to `grant-issuer`; it does not identify the person holding or replaying the URL. The URL host is loopback, and no off-workstation transfer is demonstrated.

## Northmoor cross-account path

The returned `PartnerFeed` policy has `Effect: Allow`, principal `arn:aws:iam::905501234789:root`, actions `s3:GetObject` and `s3:ListBucket`, and resources `arn:aws:s3:::alderbrook-partner-share-ab7f3a` and `arn:aws:s3:::alderbrook-partner-share-ab7f3a/*`. This delegates resource-side access to eligible principals in account `905501234789`; it does not by itself prove an individual Northmoor role's effective access.

`aws configure list-profiles` returned only `default`; attempting `AWS_PROFILE=northmoor` produced “profile could not be found.” No call was made with Northmoor credentials, so the caller-side identity policy and the effective Northmoor result are unresolved. The loopback unsigned request returned 403, but that is not a Northmoor-principal test and cannot be used to attribute a denial to a caller-side policy. An authorized Northmoor identity must test `GetObject` and, if relevant, `ListBucket` for a conclusive result.

## Data destination and telemetry

The demonstrated transfer path is: holder of CL-4471's bearer URL → HTTP `GetObject` to the lab S3-compatible endpoint at `127.0.0.1:4566` → object `share/partner-feed.json` → the workstation's Python process. The process received 68 bytes and discarded them. No remote recipient or off-workstation destination is evidenced; the route is usable by a holder who can direct their own client to a reachable S3 endpoint.

The matching CloudTrail S3 data event shows event time and ID, bucket/key through `requestParameters`, caller ARN, source IP, user agent, and success (no `errorCode`). Its `additionalEventData.AuthenticationMethod` was null, so the authentication method was not explicitly populated there; the `Python-urllib/3.12 (presigned)` user agent and successful request establish the signed-URL exercise. The transcript records 68 response bytes, while the CloudTrail event does not establish a recipient or off-site destination. The collected interval previously had no partner `GetObject` event; the new event is evidence of the later test, not of earlier use.
