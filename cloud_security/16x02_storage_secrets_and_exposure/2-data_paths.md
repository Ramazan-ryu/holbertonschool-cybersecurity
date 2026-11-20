# 2 — Data paths

## Assessment summary

Three different authorization mechanisms appear in the Alderbrook evidence: a wildcard bucket policy/public object ACL, a cross-account bucket policy for Northmoor, and a SigV4 pre-signed object URL. They are distinct grants. The evidence proves one successful data retrieval through the signed URL. It does not prove anonymous Internet access or effective access by a Northmoor principal.

| Route | Authorizing configuration | Resource and access mechanism | Evidence and destination |
|---|---|---|---|
| Wildcard policy and public ACL | `LegacyClinicSync` on the records bucket has `Effect: Allow`, JSON `Principal: "*"`, `s3:ListBucket` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a`, and `s3:GetObject` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a/*`. The exports object ACL grants `READ` to `http://acs.amazonaws.com/groups/global/AllUsers`. | Anonymous S3-compatible `ListBucket` / `GetObject` against the records object; anonymous `GetObject` against `exports/clinic-rollup.csv`. | Loopback anonymous probes returned HTTP 403. Account-level Block Public Access could not be read, so the controlling deny is unknown. The listener is bound to `127.0.0.1:4566`; the request to `192.168.1.94:4566` failed to connect. No successful public or LAN retrieval was established. A public exfiltration route is therefore **configured at a permission layer, but not proven effective or externally reachable**. |
| Northmoor cross-account policy | `PartnerFeed` has `Effect: Allow`, `Principal: {"AWS":"arn:aws:iam::905501234789:root"}`, `Action: ["s3:GetObject","s3:ListBucket"]`, and `Resource: ["arn:aws:s3:::alderbrook-partner-share-ab7f3a","arn:aws:s3:::alderbrook-partner-share-ab7f3a/*"]`. The statement has no `Condition`. | An eligible identity in account `905501234789` calls S3 `GetObject` on `share/partner-feed.json` or `ListBucket` on the bucket. | `get-bucket-policy` proves only the Alderbrook resource-side grant. The workstation has only the `default` profile; `AWS_PROFILE=northmoor aws sts get-caller-identity` failed because that profile does not exist. No Northmoor-authenticated request was made. The actual caller-side permission and effective object/bucket reach are **not established**. The anonymous 403 is not a Northmoor test. |
| Time-limited SigV4 URL | Support ticket CL-4471 contains a pre-signed `GetObject` URL. It was signed by credentials whose request CloudTrail attributes to `arn:aws:iam::734112396500:user/grant-issuer`. | A holder sends HTTP `GetObject` to the lab endpoint for `alderbrook-partner-share-ab7f3a/share/partner-feed.json`, without presenting a separate AWS login. | Executed from the workstation: HTTP 200, 68 response bytes, body discarded. CloudTrail event `f94fa759-101b-4113-841a-884e30d530a4` records success. This proves local bearer-URL retrieval, not a successful remote Northmoor retrieval: the URL host is `127.0.0.1`, which refers to the caller's own machine outside this workstation. |

The public-policy route, Northmoor resource-policy route, and pre-signed URL are separate grants and use different S3 authorization mechanisms. Only the third has a successful access result. Do not describe the first two as demonstrated exfiltration paths.

## Pre-signed URL: lifetime, use, and limits

The ticket URL's query parameters record `X-Amz-Date=20261119T234926Z` and `X-Amz-Expires=604800`, for a stated expiry of `2026-11-26T23:49:26Z`, subject to earlier invalidation of the signing credentials. The raw URL and signature are intentionally omitted here.

The URL was fetched with Python `urllib`; the response body was streamed and discarded. The command reported `HTTP 200` and `bytes=68`. The matching CloudTrail record is:

- Event ID: `f94fa759-101b-4113-841a-884e30d530a4`
- Event time: `2026-11-20T19:48:16Z`
- Trail object: `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/20/734112396500_CloudTrail_eu-west-1_20261120T1948Z_Dd299e7B0be369bA.json.gz`
- Event source/name: `s3.amazonaws.com` / `GetObject`
- Recorded principal: `arn:aws:iam::734112396500:user/grant-issuer`
- Source address: `127.0.0.1`
- User agent: `Python-urllib/3.12 (presigned)`
- Error code: none
- CloudTrail `additionalEventData.AuthenticationMethod`: null

This URL is a bearer capability: the signature authorizes possession of the URL and does not prove that the requester is the intended Northmoor recipient. Disabling that recipient does not bind or revoke the URL. Revoking the signing credentials or waiting for expiry can invalidate it. The event identifies the signing principal, not the human who held the URL. The successful response went to the workstation process; no transfer to a remote recipient or off-workstation destination is evidenced. Because the URL host is loopback, the ticket's claim that Northmoor could use it remotely is not established by this test.

## Northmoor effective-access result

The exact resource-side grant is shown above. For cross-account access, that grant must be combined with permission for the actual Northmoor caller and any applicable boundary or organization controls. No Northmoor principal ARN, identity policy, permissions boundary, SCP, or authenticated S3 response was available in the supplied evidence. The missing CLI profile is not an S3 denial and cannot be used to infer which policy would allow or deny the call.

**Current result: effective Northmoor access is undetermined.** To settle it, test with an authorized Northmoor identity and capture its caller ARN plus the S3 `GetObject` result for `share/partner-feed.json`. A successful response establishes access to that object. A denial must be evaluated against that caller's identity policies, boundary/SCP, and the `PartnerFeed` resource policy before attributing it to a specific layer. Test `ListBucket` separately if bucket listing is in scope.

## Telemetry and evidence limits

The successful signed-URL use generated an S3 CloudTrail data event. The collected record provides event ID/time, event source/name, caller ARN, source IP, user agent, request bucket/key, and outcome (no `errorCode`). It did not populate `additionalEventData.AuthenticationMethod`, and it does not identify the URL holder or destination. The client output supplies the 68-byte response count; CloudTrail does not establish those bytes or where the client stored them.

For future `GetObject` investigations, retain the S3 data event fields `eventID`, `eventTime`, `eventSource`, `eventName`, `userIdentity`, `sourceIPAddress`, `userAgent`, `requestParameters.bucketName`, `requestParameters.key`, `additionalEventData.AuthenticationMethod`, `errorCode`, and `errorMessage` where present. Compare the caller/session and source context with an approved workflow. The successful event above is evidence of the local signed-URL test, not proof of Northmoor account access or remote exfiltration.
