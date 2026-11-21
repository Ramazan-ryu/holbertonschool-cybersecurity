# 2 — Data paths

## Summary

Three routes can move Alderbrook data out. They use different grants, and only one has an executed success.

| # | Route | Authorizing grant | Executed result | Status |
|---|---|---|---|---|
| 1 | Public bucket policy and public object ACL | `LegacyClinicSync` (records bucket, `Principal: "*"`); `AllUsers READ` ACL (exports object) | Anonymous loopback probes: HTTP 403 | Configured, not proven effective. Cause of the 403 not isolated. |
| 2 | Northmoor cross-account resource policy | `PartnerFeed` (partner bucket, `Principal: arn:aws:iam::905501234789:root`) | None. No identity in account `905501234789` was tested. | Not established. |
| 3 | Time-limited SigV4 pre-signed URL from ticket CL-4471 | Signature by `arn:aws:iam::734112396500:user/grant-issuer` | HTTP 200, 68 bytes, body discarded. CloudTrail `f94fa759-101b-4113-841a-884e30d530a4` | Established as a local retrieval from `127.0.0.1` on the workstation. Remote delivery not shown. |

Routes 1 and 2 are configured paths, not demonstrated exfiltration. Route 3 is the only executed success, and it does not show data reaching an external recipient.

## Route 1: public bucket policy and public object ACL

**Configured grants**
- `LegacyClinicSync` on `alderbrook-phi-records-ab7f3a`: `Effect: Allow`, `Principal: "*"`, `s3:ListBucket` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a`, `s3:GetObject` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a/*`. No `Condition`. `get-bucket-policy-status` reports `IsPublic: true`.
- `exports/clinic-rollup.csv` has an object ACL granting `READ` to `http://acs.amazonaws.com/groups/global/AllUsers`.
- `DenyBroad` on the exports bucket covers only `private/*` and does not match this key.

**Executed.** Anonymous `ListBucket` and `GetObject` against the records bucket, and anonymous `GetObject` against the exports object, returned HTTP 403 from `127.0.0.1:4566`. The listener is bound to loopback only; a request to `192.168.1.94:4566` failed to connect.

**Why this is not proven.** The 403s could come from a masking layer, KMS on the SSE-KMS PHI object, or the lab's own policy evaluation. Account-level Block Public Access returned `NoSuchPublicAccessBlockConfiguration`, so it is not the cause. KMS can explain a denied GetObject on the PHI object, but not a denied ListBucket. The cause remains open.

**Verdict:** the grant exists in configuration. Whether an anonymous caller on a real network can reach the data is not established.

## Route 2: Northmoor cross-account resource policy

**Configured grant.** `PartnerFeed` on `alderbrook-partner-share-ab7f3a`: `Effect: Allow`, `Principal: {"AWS": "arn:aws:iam::905501234789:root"}`, `Action: ["s3:GetObject", "s3:ListBucket"]`, `Resource: ["arn:aws:s3:::alderbrook-partner-share-ab7f3a", "arn:aws:s3:::alderbrook-partner-share-ab7f3a/*"]`, no `Condition`.

**What the resource policy proves.** It trusts the Northmoor account as a whole. It does not prove that any Northmoor identity can reach the data. A Northmoor principal also needs an identity policy allowing the action, and no permissions boundary or organization control may deny it.

**Executed.** Nothing. The workstation has only the `default` profile. `AWS_PROFILE=northmoor aws sts get-caller-identity` failed because the profile does not exist. The anonymous 403 is not a Northmoor test.

**Verdict:** effective Northmoor access is **undetermined**.

**Test required:**
1. Obtain a credential for an identity in account `905501234789` that is authorized for this partner feed.
2. Run `aws sts get-caller-identity` with that profile and record the ARN.
3. Run `aws s3api get-object --bucket alderbrook-partner-share-ab7f3a --key share/partner-feed.json /dev/null` and `aws s3api list-objects-v2 --bucket alderbrook-partner-share-ab7f3a`.
4. If it succeeds, record the result and the CloudTrail event ID, which will show the Northmoor caller ARN. If it is denied, attribute the denial to the layer that produced it: the `PartnerFeed` statement, the Northmoor identity policy, or a boundary or SCP. Use the error code and the IAM policy simulator to decide which.

## Route 3: the grant that walked out

**What it is.** A SigV4 pre-signed `GetObject` URL for `alderbrook-partner-share-ab7f3a/share/partner-feed.json`, attached to support ticket CL-4471, signed by `arn:aws:iam::734112396500:user/grant-issuer`. The raw URL and signature are omitted.

**Lifetime.** `X-Amz-Date=20261119T234926Z`, `X-Amz-Expires=604800`, stated expiry `2026-11-26T23:49:26Z`. The URL also stops working earlier if the signing credential is deactivated or deleted. For temporary credentials, it stops at the session's expiry.

**Use.** Fetched with Python `urllib` from the workstation. HTTP 200, 68 bytes, body discarded.

**Why it works for someone other than its recipient.** A pre-signed URL is a bearer capability. S3 checks the signature, not the identity of whoever presents the URL, so possession is enough and no AWS login is needed. S3 evaluates the request as the signing identity, so the signer's permissions still apply. If `grant-issuer` no longer has `s3:GetObject` on that key, the URL fails before expiry.

**What disabling the intended recipient achieves.** Nothing. The URL was never bound to that person. Removing their access does not change the signature check.

**What disabling the signer achieves.** Deactivating or deleting `grant-issuer`'s access key, or ending the session for temporary credentials, makes the URL fail. Removing the signer's `GetObject` permission on the key also makes it fail. Either is the containment that works before expiry.

**Alderbrook's record of the use.** CloudTrail event `f94fa759-101b-4113-841a-884e30d530a4`:
- Time: `2026-11-20T19:48:16Z`
- Event source and name: `s3.amazonaws.com`, `GetObject`
- Caller (`userIdentity`): `arn:aws:iam::734112396500:user/grant-issuer`
- Source IP: `127.0.0.1`
- User agent: `Python-urllib/3.12 (presigned)`
- Error: none
- `additionalEventData.AuthenticationMethod`: null
- Trail object: `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/20/734112396500_CloudTrail_eu-west-1_20261120T1948Z_Dd299e7B0be369bA.json.gz`

**What this does not show.** The event names the signer, not the person holding the URL. It does not show where the 68 bytes went. Because the source is loopback, it is consistent with a local process and does not show remote delivery.

## The exfiltration path, end to end

For the executed route (Route 3):
- **Principal:** whoever holds the pre-signed URL. The signature belongs to `grant-issuer`.
- **Interface:** HTTPS to the S3 endpoint, carrying the signed query string.
- **Destination:** the requesting process. In the test, the workstation at `127.0.0.1`. Remote delivery is not established.
- **What Alderbrook's records show:** the CloudTrail data event above. A remote caller would show a different source IP with the same signer.
- **Containment:** deactivate `grant-issuer`'s access key, or revoke the session, or remove its `GetObject` permission on the key.

Routes 1 and 2 are written up as configured paths to be tested, not demonstrated ones.

## Open items

1. Run the Northmoor test in Route 2. Until then, that route stays "not established."
2. Run an anonymous and LAN test from a second host, or confirm the lab does not expose the endpoint off-host.
3. Confirm whether `grant-issuer`'s key is still active, and whether the ticket's intended recipient was Northmoor.
4. Determine the cause of the Route 1 403s (KMS, lab policy evaluation, or other).
