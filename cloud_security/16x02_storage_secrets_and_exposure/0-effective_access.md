# 0 — Effective S3 access review

## Scope and evaluation method

**Caller under review:** `arn:aws:iam::734112396500:user/sec-reviewer`
**S3-compatible lab endpoint:** `http://127.0.0.1:4566`
**Reachability limit:** the service listens on loopback. Requests to `192.168.1.94:4566` failed to connect, so the unsigned 403 results below describe the local lab endpoint, not Internet reachability.

For each request I evaluated the account-level Block Public Access (BPA), bucket-level BPA, bucket policy (including any matching explicit `Deny`), bucket and object ACLs, and KMS authorization for SSE-KMS objects. An applicable explicit `Deny` overrides an `Allow`; BPA can suppress public-policy or public-ACL access. KMS authorization is additionally required to return an SSE-KMS object's plaintext. I distinguish configured permission from the executed request result.

The successful S3 reads recorded here wrote response bodies to `/dev/null`; no patient-record contents are included. This report records configuration evidence and observed request results from the supplied workstation transcript and CloudTrail.

**Account-level BPA result:** the correctly signed `GetPublicAccessBlock` request to `GET /v20180820/configuration/publicAccessBlock` with `x-amz-account-id: 734112396500` returned HTTP 404 `NoSuchPublicAccessBlockConfiguration` (request ID `G5MK2jRLvaAC4XsYhOt01JiiyuQVFKC3jCRAvazro7RQcU6K3Msx`). AWS documents this response when the account has no `PublicAccessBlockConfiguration` set. Thus no account-level BPA configuration is present in the lab response; no individual flags were returned. The earlier unsigned `MissingAuthenticationToken`, malformed-path 404, AWS CLI host-prefix connection failure, and `SignatureDoesNotMatch` were failed attempts and are superseded by this signed result. Organization-level controls were not independently retrieved. See AWS's [GetPublicAccessBlock API](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_GetPublicAccessBlock.html).

## Results

### 1. PHI record — `alderbrook-phi-records-ab7f3a/records/patients-2026.ndjson`

**Question A — Can `sec-reviewer` read the object?**
**Observed result: allowed.** `GetObject` to `/dev/null` succeeded with 6,625 bytes and reported `ServerSideEncryption=aws:kms` and `SSEKMSKeyId=alias/alderbrook-phi`. CloudTrail event `c5ad1054-168a-4c70-9769-5a28bd7ee6b4` records a successful read by `sec-reviewer` of this object. The exact identity policy or KMS grant that participates in `sec-reviewer`'s decrypt path was not retrieved. The key policy directly names `reporting-role-key` for `kms:Decrypt`; that is a different principal. The successful object read establishes effective access for `sec-reviewer` despite this missing policy detail.

**Question B — Can an unsigned caller list the bucket or read the object?**
**Observed configuration:** the bucket policy `LegacyClinicSync` grants `Principal: "*"` `s3:ListBucket` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a` and `s3:GetObject` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a/*`. The bucket and object ACLs are owner-only. The bucket-level BPA configuration was set with all four flags `false` by `sec-reviewer` at `2026-11-20T00:09:49Z` (CloudTrail event `c6b65cb5-7937-49a6-b08e-4333cc7abb42`). At the resource-policy/ACL layer, the wildcard statement allows anonymous list and get; a higher-level block or KMS denial may still prevent a successful read.

**Observed result: denied at the loopback endpoint; controlling layer unresolved.** Unsigned `ListBucket` and `GetObject` probes returned HTTP 403 after the bucket flags were set false. No account-level BPA configuration is present in the signed response, and the anonymous GET also requires KMS decrypt authorization. The evidence does not isolate the layer causing either denial; KMS cannot explain the bucket-list denial. This does not establish public Internet access.

**KMS check:** `alias/alderbrook-phi` resolves to `arn:aws:kms:eu-west-1:734112396500:key/256370d9-4f10-45e2-92e4-121eda29a14f`. The emulator rejected `GetKeyPolicy` using the alias; the policy was retrieved using the resolved key ID. `AllowReportingDecrypt` grants `arn:aws:iam::734112396500:user/reporting-role-key` `kms:Decrypt` and `kms:DescribeKey`, with no `Condition`. The `Root` statement enables IAM delegation for the account; it does not itself grant every account identity direct decrypt access. This establishes an explicit decrypt grant for `reporting-role-key`, not a direct key-policy grant to anonymous callers or `sec-reviewer`. The successful `sec-reviewer` S3 read proves effective object retrieval, but the `sec-reviewer` identity-side KMS path remains unspecified.

### 2. Exports rollup — `alderbrook-exports-ab7f3a/exports/clinic-rollup.csv`

**Question A — Can `sec-reviewer` read the object?**
**Observed result: allowed.** `GetObject` to `/dev/null` succeeded; CloudTrail event `e7be1a6c-9a4e-4539-9566-609ada90e4a1` records the read.

**Question B — Can an unsigned caller read this object?**
**Observed configuration:** the object ACL grants `READ` to the `AllUsers` group. Bucket policy `DenyBroad` covers only `private/*`, so it does not deny this key. No bucket-level BPA configuration was returned, and no account-level BPA configuration is set in the signed response.

**Observed result: denied at the loopback endpoint; controlling layer unresolved.** The unsigned GET returned HTTP 403. This is not proof that `DenyBroad` caused the denial and is not an Internet-vantage test. The object ACL is a real public-read grant, but effective public reach is not established; organization-level controls and endpoint-specific behavior were not retrieved.

**Question C — Can an unsigned caller list the exports bucket?**
**Observed configuration/result: denied.** The object's `AllUsers READ` ACL applies to object reads, not bucket listing, and no public listing grant is established by that ACL. The unsigned bucket-list probe returned HTTP 403.

### 3. Partner feed — `alderbrook-partner-share-ab7f3a/share/partner-feed.json`

**Question A — Can a Northmoor principal in account `905501234789` read the object or list the bucket?**
**Observed configuration:** `PartnerFeed` grants principal `arn:aws:iam::905501234789:root` `s3:GetObject` and `s3:ListBucket` on the partner bucket and its objects, with no `Condition`. This is a resource-side delegation; the actual Northmoor principal must also be authorized by its identity-side policy and any applicable boundary or organization controls.

**Observed result: unverified.** No Northmoor credentials/profile were available and no request was made as a Northmoor principal. An unsigned 403 does not answer the cross-account question. The statement alone is not proof of effective Northmoor access.

**Question B — Can a holder of the ticket's pre-signed URL read the object?**
**Observed result: allowed.** The supplied workstation test returned HTTP 200 and 68 bytes; the body was discarded. CloudTrail event `f94fa759-101b-4113-841a-884e30d530a4` records a successful `GetObject` for this object by signing identity `arn:aws:iam::734112396500:user/grant-issuer`, source `127.0.0.1`, user agent `Python-urllib/3.12 (presigned)`. This proves use of the bearer URL in the local lab, not that Northmoor used it or that a remote recipient received the data. The raw URL is omitted.

**Question C — Can an unsigned caller without the URL read or list?**
**Observed result: denied at the loopback endpoint.** Unsigned GET and list probes returned HTTP 403. The bucket and object ACLs grant owner `FULL_CONTROL`; the partner resource-policy grant names Northmoor, not `Principal: "*"`. No bucket-level or account-level BPA configuration is present in the retrieved lab responses.

### 4. Ops retention report — `alderbrook-ops-ab7f3a/ops/retention-report.md`

**Question A — Can `sec-reviewer` read the object?**
**Observed result: allowed.** `GetObject` to `/dev/null` succeeded; CloudTrail event `47492a44-3e73-4847-ad06-dc4ab0d3c9de` records the read.

**Question B — Can an unsigned caller list the bucket or read the object?**
**Observed configuration/result: denied at the loopback endpoint.** No public bucket policy exists (`NoSuchBucketPolicy`); the bucket and object ACLs grant only owner `FULL_CONTROL`; no bucket-level BPA configuration was returned. Unsigned list and GET probes returned HTTP 403. No account-level BPA configuration is present in the signed response, and no public grant was found in the reviewed bucket policy or ACLs.

**Clean-resource verdict:** `alderbrook-ops-ab7f3a/ops/retention-report.md` is the explicitly identified clean resource in this review: the reviewed resource-side policy and ACL layers contain no public grant, and the unsigned lab probes were denied.

### 5. CloudTrail log object — `alderbrook-cloudtrail-ab7f3a/AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/02/734112396500_CloudTrail_eu-west-1_20261102T0005Z_97B04De44f15FDB0.json.gz`

**Question A — Can `sec-reviewer` read this log object?**
**Observed result: allowed.** `GetObject` to `/dev/null` succeeded; response metadata reported 508 bytes. No log contents are reproduced here.

**Question B — Can an unsigned caller list the bucket or read this object?**
**Observed configuration/result: denied at the loopback endpoint.** No bucket policy exists (`NoSuchBucketPolicy`); the bucket and listed object ACLs grant only owner `FULL_CONTROL`; no bucket-level BPA configuration was returned. Unsigned list and GET probes returned HTTP 403. No account-level BPA configuration is present in the signed response; this remains a local result, not evidence of Internet reachability.

## Open checks and disposition

| Check | Result |
|---|---|
| Account-level BPA via `GET /v20180820/configuration/publicAccessBlock` with `x-amz-account-id: 734112396500` | **No account configuration set.** Signed response was `404 NoSuchPublicAccessBlockConfiguration`, request ID `G5MK2jRLvaAC4XsYhOt01JiiyuQVFKC3jCRAvazro7RQcU6K3Msx`; no individual flag values returned. |
| PHI KMS key policy | **Retrieved by resolved key ID.** The requested alias form was rejected by the emulator; the returned policy includes a direct `reporting-role-key` decrypt grant and a root-account IAM-delegation statement. It does not directly grant anonymous decrypt. |
| Northmoor `GetObject` and `ListBucket` | **Unverified.** Requires an authorized identity in account `905501234789`; no Northmoor credentials were available. |
| Internet reachability | **Not tested.** The service is loopback-only from the workstation; unsigned 403s are lab endpoint results. |

## Overall verdicts

- **PHI:** authenticated `sec-reviewer` read allowed; wildcard policy configures anonymous list/get, but both unsigned probes were denied and the governing higher-level layer is unresolved. Internet exposure is not proven.
- **Exports:** authenticated read allowed; public object ACL is configured, but unsigned GET was denied and its controlling layer is unresolved. Anonymous listing was denied and is not granted by the object ACL.
- **Partner:** Northmoor effective access unverified; the ticketed bearer URL successfully read the object in the local lab; ordinary unsigned probes were denied.
- **Ops:** authenticated read allowed; unsigned list/read denied; no public resource-side grant found. **Clean resource: `alderbrook-ops-ab7f3a/ops/retention-report.md`.**
- **CloudTrail:** authenticated read allowed; unsigned list/read denied; no public resource-side grant found. No account-level BPA configuration is set in the signed lab response.
