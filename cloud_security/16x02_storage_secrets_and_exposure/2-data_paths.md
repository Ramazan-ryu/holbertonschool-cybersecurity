# 2 — Data paths

## Assessment summary

Three different authorization mechanisms appear in the Alderbrook evidence: a wildcard bucket policy/public object ACL, a cross-account bucket policy for Northmoor, and a SigV4 pre-signed object URL. They are distinct grants. The evidence proves one successful data retrieval through the signed URL. It does not prove anonymous Internet access or effective access by a Northmoor principal.

| Route | Authorizing configuration | Resource and access mechanism | Evidence and destination |
|---|---|---|---|
| Wildcard policy and public ACL | Raw `get-bucket-policy` output shows `LegacyClinicSync`, `Effect: Allow`, `Principal: "*"`, `s3:ListBucket` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a`, and `s3:GetObject` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a/*`; it has no `Condition`. `get-bucket-policy-status` reports `IsPublic: true`. The exports object ACL grants `READ` to `http://acs.amazonaws.com/groups/global/AllUsers`; `HeadObject` reports that `exports/clinic-rollup.csv` is currently 0 bytes. | Anonymous `ListBucket` / `GetObject` against the records bucket and object; anonymous `GetObject` against the exports object. | No successful anonymous retrieval is established. The signed account-level Block Public Access query returned `404 NoSuchPublicAccessBlockConfiguration` (request ID `G5MK2jRLvaAC4XsYhOt01JiiyuQVFKC3jCRAvazro7RQcU6K3Msx`), so no account-level configuration was found. CloudTrail records a bucket-level public-access-block write by `sec-reviewer` at `2026-11-20T00:09:49Z` (`c6b65cb5-7937-49a6-b08e-4333cc7abb42`); the supplied evidence says all four flags were false. A later bucket-level read returned 500, so current flags were not independently read. Anonymous loopback probes returned HTTP 403; `--no-sign-request` CLI probes returned `MissingAuthenticationToken`, which is an endpoint response, not an S3 authorization decision. The endpoint listens only on `127.0.0.1:4566`, and the LAN connection failed. The policy/ACL grants are configured, but effective anonymous reach and external exfiltration are **not established**. |
| Northmoor cross-account policy | Raw `get-bucket-policy` output shows `PartnerFeed`, `Effect: Allow`, `Principal: {"AWS":"arn:aws:iam::905501234789:root"}`, actions `s3:GetObject` and `s3:ListBucket`, and resources `arn:aws:s3:::alderbrook-partner-share-ab7f3a` and `arn:aws:s3:::alderbrook-partner-share-ab7f3a/*`; no `Condition` is present. | An eligible identity in account `905501234789` calls `GetObject` on `share/partner-feed.json` or `ListBucket` on the bucket. | This establishes the resource-side delegation only. `aws configure list-profiles` returned only `default`; the known default caller is `arn:aws:iam::734112396500:user/sec-reviewer`, not Northmoor. Attempts using `AWS_PROFILE=northmoor` and `AWS_PROFILE=PROFILE_NAME` both stopped locally because those profiles are not configured. An earlier literal `<northmoor-profile>` attempt was parsed by Bash as redirection. None made a request as a Northmoor identity. Caller-side permission and effective object/bucket reach remain **unverified**. The anonymous 403 is not a Northmoor test. |
| Time-limited SigV4 URL | Support ticket CL-4471 contains a pre-signed `GetObject` URL. It was signed by credentials whose request CloudTrail attributes to `arn:aws:iam::734112396500:user/grant-issuer`. | A holder sends HTTP `GetObject` to the lab endpoint for `alderbrook-partner-share-ab7f3a/share/partner-feed.json`, without presenting a separate AWS login. | Executed from this workstation: HTTP 200, 68 response bytes, body discarded. CloudTrail event `f94fa759-101b-4113-841a-884e30d530a4` records success from source `127.0.0.1`. Here `127.0.0.1` is this same workstation's loopback interface. This proves a local bearer-URL retrieval, not remote Northmoor access or delivery to an external recipient. |

The public-policy/ACL route, Northmoor resource-policy route, and pre-signed URL are separate grants and use different S3 authorization mechanisms. The first two are configuration findings, not executed successful routes. Only the signed URL has a successful access result, and it delivered the response to a local process; no external recipient or remote delivery is confirmed. Therefore, the evidence does **not** establish three exfiltration routes under a criterion requiring each route to have a successful execution and confirmed recipient.

## Pre-signed URL: lifetime, use, and limits

The ticket URL's query parameters record `X-Amz-Date=20261119T234926Z` and `X-Amz-Expires=604800`, for a stated expiry of `2026-11-26T23:49:26Z`, subject to earlier invalidation of the signing credentials. The raw URL and signature are intentionally omitted here.

The URL was fetched from this workstation with Python `urllib`; the response body was streamed and discarded. The command reported `HTTP 200` and `bytes=68`. The matching CloudTrail record is:

- Event ID: `f94fa759-101b-4113-841a-884e30d530a4`
- Event time: `2026-11-20T19:48:16Z`
- Trail object: `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/20/734112396500_CloudTrail_eu-west-1_20261120T1948Z_Dd299e7B0be369bA.json.gz`
- Event source/name: `s3.amazonaws.com` / `GetObject`
- Recorded principal: `arn:aws:iam::734112396500:user/grant-issuer`
- Source address: `127.0.0.1`
- User agent: `Python-urllib/3.12 (presigned)`
- Error code: none
- CloudTrail `additionalEventData.AuthenticationMethod`: null

This URL is a bearer capability: the signature authorizes possession of the URL and does not prove that the requester is the intended Northmoor recipient. Disabling that recipient does not bind or revoke the URL. Revoking the signing credentials or waiting for expiry can invalidate it. The event identifies the signing principal, not the human who held the URL. The successful response went to a process on this same workstation. Since `127.0.0.1` resolves to the machine making the request, this test shows no transfer to Northmoor, another host, or any other remote recipient. The ticket's claim that Northmoor could use the URL remotely is not established by this test.

## Northmoor effective-access result

The exact resource-side grant is shown above. For cross-account access, that grant must be combined with permission for the actual Northmoor caller and any applicable boundary or organization controls. No Northmoor principal ARN, identity policy, permissions boundary, SCP, or authenticated S3 response was available in the supplied evidence. The missing CLI profiles and malformed placeholder command are not S3 denials and cannot be used to infer which policy would allow or deny the call. A valid test requires Northmoor-issued credentials or a Northmoor role that this workstation is authorized to assume; neither is present in the available configuration.

**Current result: effective Northmoor access is undetermined.** To settle it, test with an authorized Northmoor identity and capture its caller ARN plus the S3 `GetObject` result for `share/partner-feed.json`. A successful response establishes access to that object. A denial must be evaluated against that caller's identity policies, boundary/SCP, and the `PartnerFeed` resource policy before attributing it to a specific layer. Test `ListBucket` separately if bucket listing is in scope.

## Telemetry and evidence limits

The successful signed-URL use generated an S3 CloudTrail data event. The collected record provides event ID/time, event source/name, caller ARN, source IP, user agent, request bucket/key, and outcome (no `errorCode`). It did not populate `additionalEventData.AuthenticationMethod`, and it does not identify the URL holder or destination. The client output supplies the 68-byte response count; CloudTrail does not establish those bytes or where the client stored them.

For future `GetObject` investigations, retain the S3 data event fields `eventID`, `eventTime`, `eventSource`, `eventName`, `userIdentity`, `sourceIPAddress`, `userAgent`, `requestParameters.bucketName`, `requestParameters.key`, `additionalEventData.AuthenticationMethod`, `errorCode`, and `errorMessage` where present. Compare the caller/session and source context with an approved workflow. The successful event above is evidence of the local signed-URL test, not proof of Northmoor account access or remote exfiltration.
