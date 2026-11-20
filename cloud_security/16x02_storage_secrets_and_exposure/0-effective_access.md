# 0 — Effective access

## Evaluation method

The principal used for authenticated S3 calls was `arn:aws:iam::734112396500:user/sec-reviewer`. The calls and responses below are from the workstation transcript; matching event IDs are from the November 20 CloudTrail objects in `trail/734112396500/CloudTrail/eu-west-1/2026/11/20/`. `GetObject` responses were directed to `/dev/null`; no patient-record contents are included.

S3 effective access here is the composition of (1) the bucket policy, (2) the object ACL/owner grant for the requested key, and (3) applicable bucket/account Block Public Access settings. An explicit matching bucket-policy `Deny` wins over an `Allow` or ACL grant. `IgnorePublicAcls` can suppress a public ACL; `RestrictPublicBuckets` can restrict access through a public bucket policy. `BlockPublicPolicy` prevents setting a public policy and does not, by itself, revoke an already existing public policy. A failed block-configuration read is not evidence that a block is on or off. These semantics follow AWS’s [public-access-block configuration reference](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PublicAccessBlockConfiguration.html) and [bucket/account precedence description](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_PutPublicAccessBlock.html).

## Effective-access entries

### Records object: `alderbrook-phi-records-ab7f3a / records/patients-2026.ndjson`

**Question A — Can `sec-reviewer` read this object?** Yes. The exact request `aws s3api get-object --bucket alderbrook-phi-records-ab7f3a --key records/patients-2026.ndjson /dev/null` returned success, `ContentLength: 6625`, `ServerSideEncryption: aws:kms`, and `SSEKMSKeyId: alias/alderbrook-phi`. CloudTrail `c5ad1054-168a-4c70-9769-5a28bd7ee6b4` records a successful `GetObject` by `sec-reviewer`.

**Question B — Can an anonymous internet caller list this bucket or read this object?** The bucket policy alone allows it: `LegacyClinicSync` is `Effect: Allow`, `Principal: "*"`, actions `s3:ListBucket` and `s3:GetObject`, resources the bucket ARN and `/*`. `aws s3api get-bucket-policy --bucket alderbrook-phi-records-ab7f3a` returned that statement; CloudTrail `017352bb-1c18-4f02-b1d8-0bb7883dae29` records the successful read. The object ACL was not fetched. The handover reports account-level Block Public Access enabled; the attempted bucket-level `get-public-access-block` calls returned HTTP 500 (for example, CloudTrail `278a26e8-d99f-426b-baaf-c3377cd6a5bb`). No successful account-level block response or anonymous `ListBucket`/`GetObject` response is present. Therefore the policy-layer grant is established, but the current anonymous effective result remains unproved.

**Layer verdict:** authenticated `sec-reviewer` read = **allowed and executed**. Anonymous access absent the higher-level block = **allowed by the bucket policy**. Anonymous access under the current account-level setting = **unknown from available response evidence**.

### Rollup object: `alderbrook-exports-ab7f3a / exports/clinic-rollup.csv`

**Question A — Can `sec-reviewer` read this object?** Yes. `aws s3api get-object --bucket alderbrook-exports-ab7f3a --key exports/clinic-rollup.csv /dev/null` returned success; CloudTrail `e7be1a6c-9a4e-4539-9566-609ada90e4a1` records successful `GetObject` by `sec-reviewer`.

**Question B — Can an anonymous internet caller read this object?** The object ACL returned an `AllUsers` group `READ` grant from `aws s3api get-object-acl --bucket alderbrook-exports-ab7f3a --key exports/clinic-rollup.csv` (CloudTrail `5f537e53-f2f9-46f9-bfd5-d51b127e6014`). The bucket policy `DenyBroad` denies `s3:*` only on `arn:aws:s3:::alderbrook-exports-ab7f3a/private/*`; it does not match `exports/clinic-rollup.csv` and does not deny this key. Thus, at the policy/ACL layers, this key has a public-read grant and no matching bucket-policy deny. The account-level public-access-block response and anonymous GET result are unavailable, so effective anonymous access under the current block is **unknown**.

**Layer verdict:** authenticated `sec-reviewer` read = **allowed and executed**. Anonymous `GetObject` absent an effective public-access block = **allowed by this object's ACL**. Current anonymous result = **unknown from available response evidence**.

### Partner feed: `alderbrook-partner-share-ab7f3a / share/partner-feed.json`

**Question A — Can the intended Northmoor account read/list the bucket through its own AWS identity?** The bucket policy `PartnerFeed` grants `s3:GetObject` and `s3:ListBucket` to AWS account `905501234789`. `aws s3api get-bucket-policy --bucket alderbrook-partner-share-ab7f3a` returned that policy (CloudTrail `b8f6dae4-bf8b-4766-a129-f9329972abb8`). An individual Northmoor role’s identity policy and an actual request using Northmoor credentials were not provided. Therefore the resource policy’s delegation is proved, but effective access for a specific Northmoor role is **not tested**.

**Question B — Can a caller possessing the ticket URL fetch the feed without AWS login credentials?** The workstation transcript says `curl -s "<ticket URL>" | head` served the partner feed without credentials. This is a separate signed-query bearer request, not proof of Northmoor’s cross-account IAM path. The URL-use HTTP status and matching CloudTrail data event are not in the supplied output. No ACL or successful block-configuration result is available.

**Layer verdict:** Northmoor resource-policy delegation = **present**; specific Northmoor role read = **unverified**. Ticket URL bearer read from the workstation = **reported successful**, but no external-host reachability is proved because the URL host is `127.0.0.1:4566`.

### Retention report: `alderbrook-ops-ab7f3a / ops/retention-report.md`

**Question A — Can `sec-reviewer` read this object?** Yes. `aws s3api get-object --bucket alderbrook-ops-ab7f3a --key ops/retention-report.md /dev/null` returned success; CloudTrail `47492a44-3e73-4847-ad06-dc4ab0d3c9de` records successful `GetObject` by `sec-reviewer`.

**Question B — Can an anonymous internet caller read this object?** `aws s3api get-bucket-policy --bucket alderbrook-ops-ab7f3a` returned `NoSuchBucketPolicy` (CloudTrail `8c1ae8ea-ba7f-4874-b343-a0a5d4893a57`). No ACL/owner-grant result, successful public-access-block response, or anonymous GET result is available. Absence of a bucket policy does not answer whether the object ACL or higher-level block allows the request. Current anonymous effective access is **unknown**.

**Layer verdict:** authenticated `sec-reviewer` read = **allowed and executed**. Anonymous read = **not determined** because the object ACL and effective block were not observed.

### CloudTrail log object class: `alderbrook-cloudtrail-ab7f3a / AWSLogs/*`

**Question — Can `sec-reviewer` or an anonymous caller read the account’s CloudTrail objects?** No policy, ACL, bucket/account block response, or S3 `GetObject` test for this bucket was included in the collected output. Its contents being present in a local `trail/` directory are not treated as proof of the S3 call that obtained them. Effective access for `sec-reviewer` and anonymous callers is **not assessed**; no access claim is made.

## Clean-resource conclusion

I cannot truthfully clear a resource as correctly configured from these results: no entry has a verified, consistent bucket policy, object ACL, and effective public-access-block result together with the required denied/allowed execution. The available evidence is not enough to say “nothing to report” for any resource. In particular, do not treat the ops bucket’s missing policy as a clean result.
