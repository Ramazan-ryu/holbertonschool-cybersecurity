# 0 — Effective access

## Scope and caller

- Caller: `arn:aws:iam::734112396500:user/sec-reviewer` (`aws sts get-caller-identity`).
- Lab endpoint: `http://127.0.0.1:4566`. The VM's LAN address `192.168.1.94` did not accept connections on 4566 (curl exit 7, HTTP `000`), so all unsigned probes were made from the workstation against loopback. **These results show how the lab endpoint behaves. They do not show reachability from the public Internet.**
- Authenticated object reads were written to `/dev/null`. No patient-record contents appear in this report.

## Layers evaluated

For each resource I checked these layers. Precedence is applied in the order listed.

| Order | Layer | What it controls |
|---|---|---|
| 1 | Account-level Block Public Access (S3 Control) | Can suppress public ACLs and public policies across all buckets. Not verified in this lab (see below). |
| 2 | Bucket-level Block Public Access | Can suppress public ACLs (`IgnorePublicAcls`) and public bucket policies (`RestrictPublicBuckets`) for one bucket. |
| 3 | Bucket policy | Explicit `Deny` always wins. An explicit `Allow` (including `Principal: "*"`) is effective only if no block suppresses it and no `Deny` matches. |
| 4 | Bucket and object ACLs | Grant access only if layers 1–3 do not suppress or deny them. An object ACL cannot override an explicit bucket-policy `Deny`. |
| 5 | KMS key policy (SSE-KMS objects) | The caller also needs `kms:Decrypt`. A bucket policy grant alone is not sufficient for an SSE-KMS object. |

**Composition rule used here:** an allow is effective only if (a) no explicit `Deny` matches, (b) no applicable Block Public Access setting suppresses it, and (c) for SSE-KMS objects, the caller can decrypt. The account-level block sits above the bucket-level block: if the account block is on, a bucket-level `false` does not unblock public access.

Reference: AWS [PublicAccessBlockConfiguration](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PublicAccessBlockConfiguration.html) and [PutPublicAccessBlock](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_PutPublicAccessBlock.html).

**Gap:** the account-level `GetPublicAccessBlock` call failed. The configured endpoint produced the account-prefixed host `734112396500.127.0.0.1:4566`, which is unreachable, and this also failed through boto3 with `inject_host_prefix=False`. Bucket-level queries returned `NoSuchPublicAccessBlockConfiguration` for exports, partner, ops and CloudTrail. The phi bucket query returned HTTP 500. No successful account-level or phi-level read is recorded here.

## Summary

| # | Resource | Principal | Action | Predicted (policy/ACL) | Executed result | Verdict |
|---|---|---|---|---|---|---|
| 1 | `alderbrook-phi-records-ab7f3a` / `records/patients-2026.ndjson` | `sec-reviewer` | GetObject | Allowed | 200, SSE-KMS | Allowed (authorized) |
| 1b | same | anonymous | ListBucket, GetObject | **Allowed by policy** | 403 from lab endpoint, after bucket block set to all `false` | **Exposure in configuration. Not reproduced as reachable on the lab endpoint.** |
| 2 | `alderbrook-exports-ab7f3a` / `exports/clinic-rollup.csv` | `sec-reviewer` | GetObject | Allowed | 200 | Allowed (authorized) |
| 2b | same | anonymous | GetObject, ListBucket | **Allowed by object ACL (`AllUsers` READ)** | 403 from lab endpoint | **Exposure in ACL. Not reproduced as reachable on the lab endpoint.** |
| 3 | `alderbrook-partner-share-ab7f3a` / `share/partner-feed.json` | Northmoor `905501234789` | GetObject, ListBucket | Allowed by bucket policy | Not executed (no Northmoor profile) | **Unverified** |
| 3b | same | anonymous (no ticket) | GetObject, ListBucket | Denied by policy | 403 from lab endpoint | Denied |
| 3c | same | holder of presigned ticket URL | GetObject | Allowed by signature | Fetched without AWS credentials (per workstation transcript) | **Exposure: bearer URL works without login** |
| 4 | `alderbrook-ops-ab7f3a` / `ops/retention-report.md` | `sec-reviewer` | GetObject | Allowed | 200 | Allowed (authorized) |
| 4b | same | anonymous | ListBucket, GetObject | Denied (no policy, owner-only ACLs) | 403 from lab endpoint | Denied. **Clean within tested scope.** |
| 5 | `alderbrook-cloudtrail-ab7f3a` / CloudTrail log object `…20261102T0005Z….json.gz` | `sec-reviewer` | GetObject | Allowed | 200, ContentLength 508 | Allowed (authorized) |
| 5b | same | anonymous | ListBucket, GetObject | Denied (no policy, owner-only ACLs) | 403 from lab endpoint | Denied |

## Resource entries

### 1. PHI records — `alderbrook-phi-records-ab7f3a` / `records/patients-2026.ndjson`

**1a. `sec-reviewer` → `s3:GetObject`**
- Predicted: allowed.
- Executed: `aws s3api get-object --bucket alderbrook-phi-records-ab7f3a --key records/patients-2026.ndjson /dev/null` returned `ContentLength: 6625`, `ServerSideEncryption: aws:kms`, `SSEKMSKeyId: alias/alderbrook-phi`. CloudTrail `c5ad1054-168a-4c70-9769-5a28bd7ee6b4`.
- Result: **allowed**, consistent with prediction.

**1b. Anonymous → `s3:ListBucket` and `s3:GetObject`**
- Predicted: **allowed by policy.** Statement `LegacyClinicSync` grants `Principal: "*"` both `s3:ListBucket` on the bucket ARN and `s3:GetObject` on `bucket/*` (`get-bucket-policy`, CloudTrail `017352bb-1c18-4f02-b1d8-0bb7883dae29`).
- Layers that could suppress it:
  - Bucket ACL and object ACL: owner-only `FULL_CONTROL`. Neither adds public access.
  - Bucket-level Block Public Access: `PutBucketPublicAccessBlock` (CloudTrail `c6b65cb5-7937-49a6-b08e-4333cc7abb42`) set all four flags to `false` at `00:09:49Z`. This removes the bucket's own protection against public policies.
  - Account-level Block Public Access: **unverified**. The handover says it is enabled. If it is enabled, it would suppress the public policy regardless of the bucket-level setting. This needs a successful account-level read.
  - KMS: the object is SSE-KMS. An anonymous caller would also need `kms:Decrypt` on `alias/alderbrook-phi`. This is a likely reason for a denial even if the policy and block allow access; it has not been tested.
- Executed: unauthenticated `curl --noproxy '*'` to `http://127.0.0.1:4566/?list-type=2` and `/records/patients-2026.ndjson` both returned **HTTP 403**, after the bucket block was set to `false`.
- Result: the lab endpoint denied both requests. The policy layer, read alone, predicts allowed. The executed result disagrees. Which layer wins is not established: the candidates are an account-level block (unverified), KMS decryption (untested), or the lab endpoint not evaluating bucket policies the way AWS does.
- **Finding (configuration):** a `Principal: "*"` read policy on a bucket holding PHI, with bucket-level public-access blocking disabled. Severity is high regardless of the lab result, because the configuration would expose PHI to any caller if the blocking layers above it were absent.
- **Action:** confirm who made the `PutBucketPublicAccessBlock` change and whether it was authorized. Remove or restrict `LegacyClinicSync`. Re-enable bucket-level Block Public Access. Obtain a successful account-level `GetPublicAccessBlock` response.

### 2. Clinic rollup — `alderbrook-exports-ab7f3a` / `exports/clinic-rollup.csv`

**2a. `sec-reviewer` → `s3:GetObject`**
- Predicted: allowed.
- Executed: `aws s3api get-object ... /dev/null` succeeded. CloudTrail `e7be1a6c-9a4e-4539-9566-609ada90e4a1`.
- Result: **allowed**, consistent with prediction.

**2b. Anonymous → `s3:GetObject` and `s3:ListBucket`**
- Predicted: **allowed by object ACL.** The object ACL grants the `AllUsers` group `READ` (CloudTrail `5f537e53-f2f9-46f9-bfd5-d51b127e6014`).
- Layers that could suppress it:
  - Bucket policy `DenyBroad` denies `s3:*` only on `private/*`. It does **not** match `exports/clinic-rollup.csv`, so it does not deny this object. This is a case where a container-level statement does not cover the object, which is why the object ACL remains effective at the policy layer.
  - Bucket-level Block Public Access: `NotFound`/`NoSuchPublicAccessBlockConfiguration` for exports. No bucket-level suppression.
  - Account-level Block Public Access: **unverified**. If enabled with `IgnorePublicAcls`, it would suppress this `AllUsers` grant.
- Executed: unauthenticated GET and bucket list to `http://127.0.0.1:4566` returned **HTTP 403**.
- Result: the lab endpoint denied the requests. The object ACL predicts allowed, so the executed result disagrees. The most likely explanation is an account-level `IgnorePublicAcls` setting, but this has not been proven because the account-level read failed.
- **Finding (configuration):** a public-read ACL on a clinic rollup export. Severity depends on whether the rollup contains aggregate-only data or identifiers. The contents were not reviewed.
- **Action:** remove the `AllUsers` grant. Confirm the account-level block with a successful read. Do not attribute the 403 to `DenyBroad`.

### 3. Partner feed — `alderbrook-partner-share-ab7f3a` / `share/partner-feed.json`

**3a. Northmoor account `905501234789` → `s3:GetObject`, `s3:ListBucket`**
- Predicted: allowed. Statement `PartnerFeed` delegates both actions to that account (CloudTrail `b8f6dae4-bf8b-4766-a129-f9329972abb8`).
- Layers that could suppress it: bucket and object ACLs are owner-only. The bucket has no bucket-level public-access-block configuration, so nothing suppresses the delegation.
- Executed: **not executed.** No Northmoor profile exists (`aws configure list-profiles` returned only `default`), so the cross-account identity path has not been tested.
- Result: **unverified.** The resource policy predicts allowed for a specific Northmoor role, but the role was not tested.

**3b. Anonymous, no ticket → `s3:GetObject`, `s3:ListBucket`**
- Predicted: denied (no public grant).
- Executed: unsigned requests to the lab endpoint returned HTTP 403.
- Result: **denied**, consistent with prediction.

**3c. Holder of the presigned ticket URL → `s3:GetObject`**
- Predicted: allowed. The query-string signature is the authorization.
- Executed: the workstation transcript reports the feed was fetched with `curl` without AWS login credentials.
- Result: allowed. **Finding:** the feed can be read by anyone holding the URL, with no identity check. Expiry and distribution need review.
- **Action:** confirm the presigned URL's expiry and who received it. Re-test Northmoor's cross-account access with a real role before recording a verdict for that identity.

### 4. Retention report — `alderbrook-ops-ab7f3a` / `ops/retention-report.md`

**4a. `sec-reviewer` → `s3:GetObject`**
- Predicted: allowed by account permissions.
- Executed: `get-object` to `/dev/null` succeeded (CloudTrail `47492a44-3e73-4847-ad06-dc4ab0d3c9de`).
- Result: **allowed**.

**4b. Anonymous → `s3:ListBucket`, `s3:GetObject`**
- Predicted: denied. The bucket has no policy (`NoSuchBucketPolicy`, CloudTrail `8c1ae8ea-ba7f-4874-b343-a0a5d4893a57`). The bucket ACL and the report's object ACL are owner-only. No bucket-level Block Public Access configuration exists.
- Executed: unsigned list and GET to the lab endpoint returned HTTP 403.
- Result: **denied**, consistent with prediction.

**Clearance:** within the tested scope, this resource's layers agree. There is no public grant at any layer, the caller's authorized access works, and the anonymous requests are denied. **There is nothing to report for `ops/retention-report.md`.**

### 5. CloudTrail log — `alderbrook-cloudtrail-ab7f3a` / `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/02/734112396500_CloudTrail_eu-west-1_20261102T0005Z_97B04De44f15FDB0.json.gz`

**5a. `sec-reviewer` → `s3:GetObject`**
- Predicted: allowed.
- Executed: request to `/dev/null` succeeded, `ContentLength: 508`. No contents displayed.
- Result: **allowed**.

**5b. Anonymous → `s3:ListBucket`, `s3:GetObject`**
- Predicted: denied (no bucket policy, owner-only ACLs, no bucket-level block configuration).
- Executed: both unsigned requests to the lab endpoint returned HTTP 403.
- Result: **denied**, consistent with prediction. The account-level setting is unverified, but no public grant exists at the policy or ACL layers.

## Open items

1. Obtain a successful account-level `GetPublicAccessBlock` response. The current endpoint configuration produces an unreachable host.
2. Attribute the `PutBucketPublicAccessBlock` change on the PHI bucket (CloudTrail `c6b65cb5-7937-49a6-b08e-4333cc7abb42`).
3. Test the PHI anonymous GET with `kms:Decrypt` in mind, to determine whether KMS or the block is the layer that denied the request.
4. Test Northmoor access with a real cross-account role (Section 3a).
5. Confirm the expiry and recipients of the partner feed's presigned URL.
