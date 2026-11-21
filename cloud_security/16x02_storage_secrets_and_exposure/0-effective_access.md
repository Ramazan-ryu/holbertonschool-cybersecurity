# 0 — Effective S3 access review

## Scope and method

**Caller under review:** `arn:aws:iam::734112396500:user/sec-reviewer`
**Lab endpoint:** `http://127.0.0.1:4566` (S3-compatible)
**Reachability limit:** the service listens on loopback. Requests to `192.168.1.94:4566` failed to connect. Every unsigned 403 below is a result from the local lab endpoint, not evidence of Internet reachability.

For each question I evaluated, in precedence order: account-level Block Public Access (BPA), bucket-level BPA, bucket policy (an explicit `Deny` overrides an `Allow`), bucket and object ACLs, and KMS authorization for SSE-KMS objects. Each entry gives a **Verdict** (what the configuration and results support) and an **Evidence** level (what was actually executed). Successful S3 reads wrote their bodies to `/dev/null`; no patient-record contents appear in this report.

**Account-level BPA:** a signed `GET /v20180820/configuration/publicAccessBlock` with `x-amz-account-id: 734112396500` returned HTTP 404 `NoSuchPublicAccessBlockConfiguration` (request ID `G5MK2jRLvaAC4XsYhOt01JiiyuQVFKC3jCRAvazro7RQcU6K3Msx`). No account-level BPA configuration is set. This contradicts the handover's statement that account-level BPA is enabled. Earlier unsigned, malformed-path, host-prefix and `SignatureDoesNotMatch` attempts failed and are superseded by this response. Organization-level controls were not retrieved. Reference: [GetPublicAccessBlock](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_GetPublicAccessBlock.html).

## Results

### 1. PHI records: `alderbrook-phi-records-ab7f3a` / `records/patients-2026.ndjson`

**1A. `sec-reviewer` → GetObject**
- **Verdict:** Allowed.
- **Evidence (executed):** `get-object` to `/dev/null` succeeded: 6,625 bytes, `ServerSideEncryption=aws:kms`, `SSEKMSKeyId=alias/alderbrook-phi`. CloudTrail `c5ad1054-168a-4c70-9769-5a28bd7ee6b4`.
- **Note:** the identity-side policy and KMS grant on `sec-reviewer`'s decrypt path were not retrieved. The successful read establishes effective access regardless.

**1B. Anonymous → ListBucket and GetObject**
- **Verdict:** Exposed by configuration. The bucket policy `LegacyClinicSync` grants `Principal: "*"` `s3:ListBucket` on the bucket ARN and `s3:GetObject` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a/*`. Bucket-level BPA was set to all four flags `false` by `sec-reviewer` at `2026-11-20T00:09:49Z` (CloudTrail `c6b65cb5-7937-49a6-b08e-4333cc7abb42`). The object is SSE-KMS, so an anonymous read would also need `kms:Decrypt`; no anonymous decrypt grant was found in the key policy.
- **Evidence (executed):** unsigned `ListBucket` and `GetObject` probes to the lab endpoint returned HTTP 403, after the flags were set to `false`.
- **Unresolved:** the 403s are not explained. Account-level BPA is not set (see above), so it cannot be the cause. The remaining candidates are the lab endpoint's own policy evaluation or a KMS denial. KMS cannot explain the bucket-list denial. This verdict rests on configuration, not on a reproduced read.
- **Finding:** a wildcard read policy on a bucket holding PHI, with bucket-level BPA disabled. Authorization for the BPA change is unknown and needs review.

**KMS:** `alias/alderbrook-phi` resolves to `arn:aws:kms:eu-west-1:734112396500:key/256370d9-4f10-45e2-92e4-121eda29a14f`. The emulator rejected `GetKeyPolicy` by alias, so the policy was retrieved by key ID. `AllowReportingDecrypt` grants `arn:aws:iam::734112396500:user/reporting-role-key` `kms:Decrypt` and `kms:DescribeKey`, with no `Condition`. The `Root` statement delegates to IAM. No statement grants decrypt to anonymous callers.

### 2. Exports rollup: `alderbrook-exports-ab7f3a` / `exports/clinic-rollup.csv`

**2A. `sec-reviewer` → GetObject**
- **Verdict:** Allowed.
- **Evidence (executed):** `get-object` succeeded. CloudTrail `e7be1a6c-9a4e-4539-9566-609ada90e4a1`.

**2B. Anonymous → GetObject**
- **Verdict:** Exposed by object ACL. The object ACL grants `READ` to the `AllUsers` group. Bucket policy `DenyBroad` covers only `private/*`, so no deny matches this key. No bucket-level BPA is configured.
- **Evidence (executed):** unsigned GET to the lab endpoint returned HTTP 403.
- **Unresolved:** the cause of the 403 is not isolated. Account-level BPA is not set, so it does not explain the denial. Endpoint-specific behavior is the remaining candidate. `DenyBroad` is not the cause, because it does not match this key.

**2C. Anonymous → ListBucket**
- **Verdict:** Not granted. The `AllUsers` ACL is on the object, not the bucket, and the bucket ACL is owner-only.
- **Evidence (executed):** unsigned list returned HTTP 403.

### 3. Partner feed: `alderbrook-partner-share-ab7f3a` / `share/partner-feed.json`

**3A. Northmoor principal `arn:aws:iam::905501234789:root` → GetObject and ListBucket**
- **Verdict:** Not verified for any Northmoor identity. The resource policy `PartnerFeed` delegates both actions to that account with no `Condition`. Whether a Northmoor principal can use them also depends on its own identity policy and any organization controls, which were not checked.
- **Evidence:** none executed. No Northmoor credentials or profile were available, and an unsigned 403 does not answer this question.

**3B. Holder of the presigned URL → GetObject**
- **Verdict:** Allowed by bearer URL. Anyone holding the URL can read the object without an AWS identity.
- **Evidence (executed):** the workstation test returned HTTP 200 and 68 bytes; the body was discarded. CloudTrail `f94fa759-101b-4113-841a-884e30d530a4` records the read, signed by `arn:aws:iam::734112396500:user/grant-issuer`, from `127.0.0.1`. This shows the URL works in the local lab. It does not show that Northmoor used it or that a remote recipient received the data. The URL itself is omitted.
- **Finding:** expiry and recipient list for the URL need review.

**3C. Anonymous, no URL → GetObject and ListBucket**
- **Verdict:** Denied. The partner policy grants only the named Northmoor account, and the ACLs are owner-only.
- **Evidence (executed):** unsigned GET and list returned HTTP 403.

### 4. Ops retention report: `alderbrook-ops-ab7f3a` / `ops/retention-report.md`

**4A. `sec-reviewer` → GetObject**
- **Verdict:** Allowed.
- **Evidence (executed):** `get-object` succeeded. CloudTrail `47492a44-3e73-4847-ad06-dc4ab0d3c9de`.

**4B. Anonymous → ListBucket and GetObject**
- **Verdict:** Denied, and clean. No bucket policy exists (`NoSuchBucketPolicy`, CloudTrail `8c1ae8ea-ba7f-4874-b343-a0a5d4893a57`). The bucket and object ACLs grant only owner `FULL_CONTROL`. No bucket-level BPA is configured.
- **Evidence (executed):** unsigned list and GET returned HTTP 403, consistent with the configuration.

**Clean resource:** `alderbrook-ops-ab7f3a/ops/retention-report.md`. Every layer reviewed agrees, and there is nothing to report for this resource within the tested scope.

### 5. CloudTrail log object: `alderbrook-cloudtrail-ab7f3a` / `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/02/734112396500_CloudTrail_eu-west-1_20261102T0005Z_97B04De44f15FDB0.json.gz`

**5A. `sec-reviewer` → GetObject**
- **Verdict:** Allowed.
- **Evidence (executed):** `get-object` succeeded, 508 bytes. No log contents reproduced.

**5B. Anonymous → ListBucket and GetObject**
- **Verdict:** Denied. No bucket policy (`NoSuchBucketPolicy`), owner-only ACLs, no bucket-level BPA.
- **Evidence (executed):** unsigned list and GET returned HTTP 403.

## Summary

| # | Resource / question | Verdict | Evidence |
|---|---|---|---|
| 1A | PHI, `sec-reviewer` GetObject | Allowed | Executed, 200 |
| 1B | PHI, anonymous list and get | **Exposed by configuration** (cause of 403 unresolved) | Policy and BPA read; lab 403 |
| 2A | Exports, `sec-reviewer` GetObject | Allowed | Executed, 200 |
| 2B | Exports, anonymous GetObject | **Exposed by object ACL** (cause of 403 unresolved) | ACL read; lab 403 |
| 2C | Exports, anonymous ListBucket | Not granted | ACL read; lab 403 |
| 3A | Partner, Northmoor GetObject and ListBucket | Not verified for any Northmoor identity | Resource policy read; not executed |
| 3B | Partner, presigned URL holder | Allowed by bearer URL | Executed, 200 in local lab |
| 3C | Partner, anonymous without URL | Denied | Lab 403 |
| 4A | Ops, `sec-reviewer` GetObject | Allowed | Executed, 200 |
| 4B | Ops, anonymous list and get | **Denied (clean)** | Policy and ACL read; lab 403 |
| 5A | CloudTrail, `sec-reviewer` GetObject | Allowed | Executed, 200 |
| 5B | CloudTrail, anonymous list and get | Denied | Policy and ACL read; lab 403 |

## Open items

1. **Account-level BPA conflict:** the handover says it is enabled; the signed response says it is not set. Confirm with whoever owns the account, and check whether the lab endpoint implements this API faithfully.
2. **Cause of the PHI and exports 403s:** isolate by testing whether the lab endpoint evaluates bucket policies and object ACLs at all, using a control bucket with a known public grant.
3. **BPA change on PHI (CloudTrail `c6b65cb5-7937-49a6-b08e-4333cc7abb42`):** confirm who authorized it and why.
4. **Northmoor (3A):** test with a real identity in account `905501234789`.
5. **Partner presigned URL (3B):** confirm expiry, and who received the URL.
