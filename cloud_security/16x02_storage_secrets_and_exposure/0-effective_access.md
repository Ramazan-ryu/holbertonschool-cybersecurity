# 0 — Effective access

## Scope and method

I checked the S3 bucket policies, the available bucket ACL, the public-access-block call, and executed `GetObject` calls as `arn:aws:iam::734112396500:user/sec-reviewer`. Object responses were sent to `/dev/null`; no patient-record contents are reproduced here. CloudTrail confirms the API outcomes and caller. The account-level public-access-block query and anonymous tests are missing, so policy grants are not treated as proof of current anonymous access.

## Results by resource

### `alderbrook-phi-records-ab7f3a`

- **Bucket policy:** `LegacyClinicSync` allows `Principal: "*"` `s3:GetObject` and `s3:ListBucket` on the bucket and all objects. `aws s3api get-bucket-policy` returned this policy. CloudTrail event `017352bb-1c18-4f02-b1d8-0bb7883dae29` records the successful policy read at `2026-11-20T00:05:35Z`.
- **Public-access block:** `aws s3api get-public-access-block --bucket ...` returned HTTP 500 on repeated attempts (CloudTrail event `278a26e8-d99f-426b-baaf-c3377cd6a5bb`, among others). The handover says the account-level block is enabled, but the account-level API response is not available here.
- **Executed read:** `aws s3api get-object --bucket alderbrook-phi-records-ab7f3a --key records/patients-2026.ndjson /dev/null` succeeded. The response reported `ContentLength: 6625`, `ServerSideEncryption: aws:kms`, and `SSEKMSKeyId: alias/alderbrook-phi`; CloudTrail event `c5ad1054-168a-4c70-9769-5a28bd7ee6b4` records `GetObject` with no error.
- **Verdict:** `sec-reviewer` can read the record object. The wildcard policy grants anonymous access at the policy layer, but current anonymous reachability was not directly tested; the claimed account-level mask is not independently confirmed in the available API output.

### `alderbrook-exports-ab7f3a`

- **Bucket policy:** `DenyBroad` denies `s3:*` only on `private/*`; it does not cover `exports/clinic-rollup.csv`. The policy read succeeded (CloudTrail `466deb5a-39d8-4606-8b06-0753c26f45af`).
- **Object ACL:** `aws s3api get-object-acl --key exports/clinic-rollup.csv` returned an `AllUsers` group `READ` grant (CloudTrail `5f537e53-f2f9-46f9-bfd5-d51b127e6014`).
- **Executed read:** `aws s3api get-object ... /dev/null` succeeded; CloudTrail `e7be1a6c-9a4e-4539-9566-609ada90e4a1` records successful `GetObject`.
- **Verdict:** `sec-reviewer` can read the rollup. The ACL grants public read at the object layer; the account-level control’s effect on this grant has not been validated with an anonymous request or a successful account-control query. This is not safe to label “private” from the evidence available.

### `alderbrook-partner-share-ab7f3a`

- **Bucket policy:** `PartnerFeed` grants `s3:GetObject` and `s3:ListBucket` to account `905501234789` (Northmoor Labs). The policy read succeeded (CloudTrail `b8f6dae4-bf8b-4766-a129-f9329972abb8`).
- **Other layers and executed read:** no ACL or direct Northmoor-principal result is available. The support-ticket pre-signed URL reportedly returned the feed to `curl` without credentials on the workstation; the HTTP status and body are intentionally not included. CloudTrail records only policy reads for this bucket in the collected interval, not a `GetObject` at the URL-use time.
- **Verdict:** the resource policy delegates access to an external account; the actual Northmoor caller’s effective access has not been proved here. Possession of the pre-signed URL is a separate bearer path, described in `2-data_paths.md`.

### `alderbrook-ops-ab7f3a`

- **Bucket policy:** `GetBucketPolicy` returned `NoSuchBucketPolicy` (CloudTrail `8c1ae8ea-ba7f-4874-b343-a0a5d4893a57`). No ACL result is available.
- **Executed read:** `aws s3api get-object ... ops/retention-report.md /dev/null` succeeded; CloudTrail `47492a44-3e73-4847-ad06-dc4ab0d3c9de` records successful `GetObject`.
- **Verdict:** `sec-reviewer` can read this object. The public/effective posture is not established without the ACL and public-access-block evidence.

### `alderbrook-cloudtrail-ab7f3a`

- **Layers and executed result:** no bucket policy, ACL, block configuration, or object read was provided for this bucket.
- **Verdict:** not assessed; no access claim is made.

## Sound configuration

The available evidence does not establish one resource as sound across all applicable layers. In particular, a successful authenticated read is not proof that a resource is private, and a missing bucket policy is not proof that ACLs or account controls deny public access. I will not name an unverified resource as “fine.”
