# 3 — What Is Actually in This Account

## Scope and evidence

Inventory calls were made as `arn:aws:iam::418274639051:user/svc-audit-intake` in `eu-west-1`. This is the estate visible through the calls below, not a claim that the identity could enumerate every service. The comparison source is the Copperline handover, especially `copperline-handover/02-storage.md` and `01-account-summary.md`.

The tables keep the account's API response separate from what the handover says. “Not observed” means that this call did not return the item; it is not proof the item does not exist.

## S3

### Buckets returned by the account

Call: `aws s3api list-buckets`. The response in `evidence/list-buckets.json` contains exactly these four bucket names:

| Bucket returned by API | Handover status | Reconciliation |
|---|---|---|
| `copperline-freight-manifests-cl7f3a` | Listed in `02-storage.md` | Documented and confirmed present. |
| `copperline-ops-logs-cl7f3a` | Listed in `02-storage.md` | Documented and confirmed present. |
| `copperline-cloudtrail-cl7f3a` | Listed in `02-storage.md` | Documented and confirmed present. |
| `copperline-migration-scratch-cl7f3a` | Not listed; the handover says its three-bucket list is complete | Undocumented fourth bucket. Its presence is confirmed by `list-buckets.json`; object listing below returned two keys. |

The handover's claim that the list is complete is directly contradicted by the fourth bucket in the provider response.

### Object listings and metadata returned

| Provider call and result | Evidence | Handover comparison |
|---|---|---|
| `list-objects-v2` on freight manifests returned `manifests/2026-Q1.csv` (2,528 bytes) and `manifests/2026-Q2.csv` (2,556 bytes). | The response was observed during the inventory call; the request is also present as `ListObjects` event `390a2f05-1f39-4ffc-a2c6-d8bbb9d9a6c1` in the collected CloudTrail event records. | The bucket and quarterly CSV description are documented. The returned key names fit that description; the API listing does not establish the CSV contents or whether they contain the handover's stated consignee data. |
| `list-objects-v2 --bucket copperline-ops-logs-cl7f3a --max-keys 1` returned `access/2026-08.log` (3,569 bytes). The post-v2 response is recorded in `evidence/remediation-v2-session.txt`. | Same response; `HeadObject` response for this key is in `evidence/current-session-s3-results.json`. | Bucket and purpose are documented. The returned key name is an access log. The head response reports `ContentLength: 0` while listing reports 3,569 bytes; both results are retained without explaining the discrepancy. |
| `list-objects-v2 --bucket copperline-cloudtrail-cl7f3a --max-keys 1` returned `AWSLogs/418274639051/CloudTrail/eu-west-1/2026/11/04/418274639051_CloudTrail_eu-west-1_20261104T0005Z_9e4C7EfEda34Ba8D.json.gz`, with `IsTruncated: true`. | `evidence/current-session-s3-results.json` | Bucket and CloudTrail purpose are documented. This call returned one object and indicated additional results; it was not a complete object inventory. |
| Before policy remediation, `list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5` returned `export/notes.txt` (278 bytes) and `export/pre-cutover-dump.json` (476 bytes). | `evidence/scratch-objects.json`; repeated in `evidence/current-session-s3-results.json` | Bucket and keys are absent from the handover, which says the three listed buckets are complete. This is the discovered inventory discrepancy. Key names alone do not establish contents or sensitivity. |

For both scratch objects, `HeadObject` later returned `ContentLength: 0`; the `HeadObject` responses are in `evidence/scratch-head-notes.json` and `evidence/scratch-head-pre-cutover-dump.json`. Listing and head metadata disagree on size. No body was read for those objects, and the evidence does not resolve the discrepancy.

After `CopperlineOpsLogsReadOnly` v2 became default, the same identity's scratch-bucket list request returned `AccessDenied`; its ops-logs list request succeeded. These are post-change permission results, not evidence that the scratch bucket or its objects disappeared. See `evidence/remediation-v2-session.txt`.

### Bucket settings returned by control-plane calls

The handover says all buckets block public access and are encrypted. The following API results are directly preserved:

| Bucket | Account response | Evidence | Comparison with handover |
|---|---|---|---|
| `copperline-ops-logs-cl7f3a` | `GetBucketEncryption`: default `AES256`; `GetPublicAccessBlock`: all four flags `true`. | `evidence/ops-logs-encryption.json`, `evidence/ops-logs-public-access-block.json` | These two checked settings agree with the handover. |
| `copperline-cloudtrail-cl7f3a` | `GetBucketEncryption`: default `AES256`; `GetPublicAccessBlock`: all four flags `true`. | `evidence/cloudtrail-encryption.json`, `evidence/cloudtrail-public-access-block.json` | These two checked settings agree with the handover. |
| `copperline-migration-scratch-cl7f3a` | `GetBucketEncryption` returned `ServerSideEncryptionConfigurationNotFoundError`; `GetPublicAccessBlock` returned `NoSuchPublicAccessBlockConfiguration`. `GetBucketPolicy` and `GetBucketPolicyStatus` returned `NoSuchBucketPolicy`; `GetBucketAcl` returned owner-only `FULL_CONTROL`. | `evidence/scratch-encryption-error.txt`, `evidence/scratch-public-access-block-error.txt`, `evidence/scratch-public-access-checks.txt` | The bucket is omitted from the handover's inventory, while the handover's blanket settings claim covers “all buckets.” The API did not return bucket-level encryption or PAB configurations for this bucket. These responses do not establish whether its existing objects are encrypted or publicly readable. |
| `copperline-freight-manifests-cl7f3a` | `HeadObject` for `manifests/2026-Q1.csv` returned `ServerSideEncryption: AES256`; `ContentLength: 0`. The inventory call also reported bucket-level encryption `AES256` and all four PAB flags true, but those two raw responses are not preserved as separate files in this checkout. | Object metadata summarized in this file; CloudTrail event `6fa7f83d-61c8-458e-b29e-9d72880a3851` records the `HeadObject` request. | Object metadata shows AES256 for this object. Because the bucket-level responses are not retained here, mark the handover's bucket-default/PAB claims for freight as not independently verifiable from the saved raw responses. |

The freight and ops list/head size comparisons are also separate observations: freight listing reported Q1 as 2,528 bytes while `HeadObject` reported 0; ops listing reported 3,569 bytes while `HeadObject` reported 0. No cause is established by these API responses.

## SQS

- `aws sqs list-queues` returned `http://127.0.0.1:4566/418274639051/copperline-dispatch-events` (`evidence/current-session-api-results.json`). The handover says a dispatch queue is used; one queue with that name was returned.
- `get-queue-attributes --attribute-names All` returned `ApproximateNumberOfMessages: 3`, `MessageRetentionPeriod: 345600`, `VisibilityTimeout: 30`, and `SqsManagedSseEnabled: true`; the full response is in `evidence/current-session-api-results.json`.
- The returned `Attributes` object did not contain a `Policy` key. The handover's open item says the queue may have an access policy; this call did not return one. No conclusion about other unqueried queue configuration is made.

## Secrets Manager

`aws secretsmanager list-secrets` returned these two records in `evidence/current-session-api-results.json`:

| Secret name | API-returned description | Handover comparison |
|---|---|---|
| `copperline/carrier-api` | `Carrier rate-quote API token` | Documented carrier API credential. |
| `copperline/smtp` | `Dispatch notification relay` | Documented mail relay credential. |

`describe-secret --secret-id copperline/carrier-api` returned metadata for the same secret (`evidence/current-session-api-results.json`). No `GetSecretValue` call was made; this inventory does not include secret contents.

## KMS

`aws kms list-keys` returned one customer key, ID `803db655-9754-4464-8822-eff23a3ba4e7`. `list-aliases` associated it with `alias/copperline-migration`; both responses are in `evidence/current-session-api-results.json`. This matches the handover's one migration key and alias. The same alias response included AWS-managed service aliases; it is not evidence of additional Copperline customer-managed keys.

`describe-key` returned the key as `Enabled`, `KeyManager: CUSTOMER`, `KeySpec: SYMMETRIC_DEFAULT`, with description `Migration-era data key (cutover exports)`. `get-key-policy --policy-name default` returned a statement allowing `kms:*` to `arn:aws:iam::418274639051:root` on `Resource: "*"` (`evidence/current-session-api-results.json`). The handover called this key policy unreviewed; this inventory retrieved it, but the response alone does not evaluate every principal's effective KMS access.

## IAM directory visible to this identity

The API returned five users: `cl-platform-admin`, `svc-audit-intake`, `copperline-ci`, `dpearson`, and `rmalik`; two groups: `migration-readers` and `dispatch-staff`; four managed policies: `CopperlineDeploy`, `CopperlineOpsLogsReadOnly`, `CopperlinePlatformAdmin`, and `MigrationReadOnly`; and account alias `copperline-logistics`. Responses are in `evidence/current-session-api-results.json`. The five users and alias correspond to the handover's named principals/account alias. The handover does not name either group or inventory the four managed-policy names. This is an IAM directory listing, not a complete enumeration of roles or every account permission source.

## Enumeration boundary

`aws ec2 describe-instances --region eu-west-1` returned `AccessDenied` for `svc-audit-intake`; the exact error is in `evidence/current-session-api-results.json`. Therefore this identity could not enumerate EC2 instances in that region. The handover does not establish that no EC2 instances exist, and this denial must not be read as an empty inventory. The visible estate above is limited by the identity's enumeration permissions.
