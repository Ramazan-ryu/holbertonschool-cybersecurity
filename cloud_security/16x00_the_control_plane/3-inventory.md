# 3 — Account Inventory

Inventory is based on calls made as `arn:aws:iam::418274639051:user/svc-audit-intake`. Handover claims are treated as claims and compared with API results. Evidence files preserve the responses supplied for each call.

## S3

Call: `aws s3api list-buckets`. Response: four buckets — `copperline-freight-manifests-cl7f3a`, `copperline-ops-logs-cl7f3a`, `copperline-migration-scratch-cl7f3a`, and `copperline-cloudtrail-cl7f3a` (`evidence/list-buckets.json`). The handover lists only three. `copperline-migration-scratch-cl7f3a` is an undocumented bucket and requires owner/content/purpose review.

Calls: `aws s3api list-objects-v2 --bucket <bucket> --max-keys 5`:

- `copperline-freight-manifests-cl7f3a` returned `manifests/2026-Q1.csv` (2,528 bytes) and `manifests/2026-Q2.csv` (2,556 bytes). This matches the documented freight manifest bucket and confirms object names are visible to this identity.
- `copperline-ops-logs-cl7f3a` returned `access/2026-08.log` (3,569 bytes), consistent with the documented operations logs.
- `copperline-cloudtrail-cl7f3a` returned five CloudTrail object keys and `IsTruncated: true`, consistent with the documented audit bucket.
- Initial review listed the scratch bucket and found two migration artifact keys; after policy remediation, the operator's list request to that bucket returned `AccessDenied` (see `evidence/remediation-v2-session.txt`). Existing inventory observations remain historical evidence; no object bodies were retrieved.

Before remediation, the account returned successful listings for the documented buckets and the scratch bucket, consistent with the original wildcard `s3:List*` statement. After v2 became default, the ops-logs listing still succeeded while the scratch-bucket listing returned `AccessDenied`. Listing proves names and metadata are visible; it does not by itself prove object contents can be read.

## SQS

Call: `aws sqs list-queues`. Response: `http://127.0.0.1:4566/418274639051/copperline-dispatch-events`. This confirms one dispatch queue is in use, matching the handover's description. Queue attributes and access policy remain to be inspected.

## Secrets Manager

Call: `aws secretsmanager list-secrets`. Response: two secrets: `copperline/carrier-api` (“Carrier rate-quote API token”) and `copperline/smtp` (“Dispatch notification relay”). This matches the two described secret purposes. Listing returns metadata, not secret values. No values were requested or accessed.

## KMS

Call: `aws kms list-keys`. Response: one key, ID `803db655-9754-4464-8822-eff23a3ba4e7`. `aws kms list-aliases` maps it to `alias/copperline-migration`, matching the handover. The API also returned AWS-managed aliases for ACM, DynamoDB, EBS, EFS, OpenSearch, Glue, Kinesis Video, Lambda, RDS, Redshift, S3, Secrets Manager, SSM, and X-Ray. The customer key policy and key metadata have not yet been examined.

## Boundary observed

These service inventory calls succeeded. The identity policy includes the matching list actions, and the group policy grants selected describe/get-attributes actions. Other service enumeration and object-content access have not yet been tested; this inventory is bounded by the calls and permissions available to this identity.

### Newly discovered scratch bucket objects

Call: `aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5`. It returned `export/notes.txt` (278 bytes) and `export/pre-cutover-dump.json` (476 bytes). The bucket and both objects are absent from the handover. Their names suggest migration artifacts, but the names alone do not establish contents or data sensitivity. This is a confirmed inventory discrepancy requiring owner validation.

### Object metadata and bucket controls

`aws s3api head-object --bucket copperline-freight-manifests-cl7f3a --key manifests/2026-Q1.csv` succeeded and returned ETag `"4714a2a5ef1a2a17e34105833b11a9d5"`, `ContentLength: 0`, and `ServerSideEncryption: AES256`.

`aws s3api head-object --bucket copperline-ops-logs-cl7f3a --key access/2026-08.log` succeeded and returned ETag `"e0886c0082f9f0cc64e7e430b91f550a"`, `ContentLength: 0`, and `ServerSideEncryption: AES256`.

These successful metadata calls establish that the identity can address these named objects through `HeadObject`. Note the discrepancy that the earlier list responses reported sizes of 2,528 bytes and 3,569 bytes respectively, while `head-object` returned `ContentLength: 0` for both. The cause is not established; both responses are retained as returned.

`aws s3api get-bucket-encryption --bucket copperline-freight-manifests-cl7f3a` returned default server-side encryption algorithm `AES256` (SSE-S3).

`aws s3api get-public-access-block --bucket copperline-freight-manifests-cl7f3a` returned `BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, and `RestrictPublicBuckets` all `true`. For this bucket, the checked encryption and public access block controls are sound. Other buckets remain unchecked.

### Remaining bucket control checks

Operations logs: `get-bucket-encryption` returned SSE-S3 (`AES256`); `get-public-access-block` returned all four controls `true`. These checked controls are sound.

CloudTrail: `get-bucket-encryption` returned SSE-S3 (`AES256`); `get-public-access-block` returned all four controls `true`. These checked controls are sound.

Migration scratch: `get-bucket-encryption` returned `ServerSideEncryptionConfigurationNotFoundError`; `get-public-access-block` returned `NoSuchPublicAccessBlockConfiguration`. These are confirmed missing bucket-level configurations, but do not alone prove an object is unencrypted or public. Bucket policy status/ACL and object encryption need checking before classifying exposure.

### Scratch bucket public-access validation

`aws s3api get-bucket-policy-status --bucket copperline-migration-scratch-cl7f3a` and `get-bucket-policy` both returned `NoSuchBucketPolicy`. `get-bucket-acl` returned a single `FULL_CONTROL` grant to the bucket owner and no grants to other grantees. Based on these responses, public exposure is not demonstrated: no bucket policy exists and the ACL grants control only to the owner. The missing Public Access Block remains a defense-in-depth gap, but this bucket is a non-exploitable public-access candidate on the evidence collected so far. Object encryption still needs validation.

### Follow-up validation: encryption, public access, and scratch object metadata

The operator's command responses are preserved in `evidence/ops-logs-encryption.json`, `evidence/ops-logs-public-access-block.json`, `evidence/cloudtrail-encryption.json`, and `evidence/cloudtrail-public-access-block.json`. Both the operations-log and CloudTrail buckets report default SSE-S3 (`AES256`) and all four bucket-level Public Access Block settings enabled. These checked controls match the handover statement for those buckets.

For `copperline-migration-scratch-cl7f3a`, `GetBucketEncryption` returned `ServerSideEncryptionConfigurationNotFoundError`, and `GetPublicAccessBlock` returned `NoSuchPublicAccessBlockConfiguration` (raw responses in the correspondingly named `evidence/scratch-*-error.txt` files). These responses establish missing bucket-level configurations only. They do not establish that its objects are unencrypted or publicly readable. `GetBucketPolicy` and `GetBucketPolicyStatus` returned `NoSuchBucketPolicy`; `GetBucketAcl` returned only the owner canonical user with `FULL_CONTROL` (see `evidence/scratch-public-access-checks.txt`). Thus public access is not demonstrated by the inspected policy and ACL. The absent Public Access Block is a hardening gap, not proof of public exposure.

The original `list-objects-v2` response in `evidence/scratch-objects.json` reported 278 bytes for `export/notes.txt` and 476 bytes for `export/pre-cutover-dump.json`. Later `head-object` responses (saved as `evidence/scratch-head-notes.json` and `evidence/scratch-head-pre-cutover-dump.json`) reported `ContentLength: 0` for both keys, with matching ETags and a later `LastModified` timestamp. Preserve both observations: the object listing and metadata calls disagree about content length, and this evidence does not explain the discrepancy. The account's `HeadObject` response confirms the identity can retrieve metadata for these keys; object-body retrieval and object-level encryption remain unverified.

The freight-manifest bucket has reported SSE-S3 and all four Public Access Block settings enabled in earlier operator responses documented above. The raw responses for those calls have not yet been added to `evidence/` in this checkout.

### Current-session service and identity findings

The current baseline calls identify the principal as `svc-audit-intake` in account `418274639051`. `iam:ListUsers` returned five users (`cl-platform-admin`, `svc-audit-intake`, `copperline-ci`, `dpearson`, `rmalik`); `ListGroups` returned `migration-readers` and `dispatch-staff`; `ListPolicies` returned `CopperlineDeploy`, `CopperlineOpsLogsReadOnly`, `CopperlinePlatformAdmin`, and `MigrationReadOnly`; the account alias is `copperline-logistics`. The user has one active access-key metadata entry. These responses are preserved in `evidence/current-session-api-results.json` and `evidence/current-session-iam-probes.md`.

SQS inventory found `copperline-dispatch-events`. `GetQueueAttributes --attribute-names All` succeeded and returned `ApproximateNumberOfMessages: 3`, four-day message retention (`345600` seconds), 30-second visibility timeout, and `SqsManagedSseEnabled: true`. No `Policy` attribute appeared in that response, so a queue access policy was not observed in this call. This is evidence of the attributes returned at the time, not a claim about all queue behavior.

Secrets Manager listed `copperline/carrier-api` and `copperline/smtp`. `DescribeSecret` succeeded for the carrier API secret and returned metadata only; no secret value was requested. KMS returned customer-managed key `803db655-9754-4464-8822-eff23a3ba4e7` (`alias/copperline-migration`); `DescribeKey` reports it enabled, customer-managed, and described as a migration-era data key for cutover exports. `GetKeyPolicy` returned the default key policy statement allowing `kms:*` to the account root principal. This is the provider API's response; it does not itself grant this user KMS actions beyond its IAM permissions.

`ListObjectsV2` on CloudTrail returned a first object key and `IsTruncated: true`; only one object was requested. `ec2:DescribeInstances` was explicitly denied with `AccessDenied` for `svc-audit-intake`. This confirms an enumeration boundary for EC2 and does not establish that no instances exist.

### Current object metadata discrepancy

In the current session, S3 listing again reported scratch object sizes of 278 and 476 bytes, while the subsequent `HeadObject` results reported `ContentLength: 0`. Ops logs listing reported 3,569 bytes, while its `HeadObject` also returned `ContentLength: 0`. The matching ETags and timestamps are in `evidence/current-session-s3-results.json` and the individual head response files. Treat list-versus-head size as an unresolved response discrepancy; do not infer object body contents from it.
