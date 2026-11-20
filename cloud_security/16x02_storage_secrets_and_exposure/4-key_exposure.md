# 4 — Encryption and the key

## Assessed exposure path

This assessment follows the G2 credential from Task 3 only: the historical `.env.local` pair authenticated as `arn:aws:iam::734112396500:user/reporting-role-key`. Using that principal, the lab S3 `GetObject` call for `alderbrook-phi-records-ab7f3a/records/patients-2026.ndjson` succeeded and returned 6,625 bytes. The response identified `ServerSideEncryption=aws:kms` and `SSEKMSKeyId=alias/alderbrook-phi`; the body was streamed and discarded. This ties the tested principal, source object, and managed key to one successful S3-to-KMS retrieval path.

## Key identity and decisive policy statement

`alias/alderbrook-phi` resolves to enabled customer-managed key `arn:aws:kms:eu-west-1:734112396500:key/256370d9-4f10-45e2-92e4-121eda29a14f`. The key policy was retrieved using the resolved key ID because the emulator rejected the alias in `GetKeyPolicy`.

The statement that directly governs the tested principal is:

```json
{
  "Sid": "AllowReportingDecrypt",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::734112396500:user/reporting-role-key"},
  "Action": ["kms:Decrypt", "kms:DescribeKey"],
  "Resource": ""
}
```

There is no `Condition`. This key-policy statement directly grants `reporting-role-key` `kms:Decrypt` on this key. The separate `Root` statement allows the account principal `arn:aws:iam::734112396500:root` `kms:*` and supports IAM delegation, but the tested reporting user does not need that delegation path to satisfy the direct `AllowReportingDecrypt` statement. The relevant identity is the same `reporting-role-key` principal established by the successful Task 3 STS call and PHI read.

## Executed decryption evidence and limits

The body-discarding S3 `GetObject` result is an executed retrieval of the identified SSE-KMS object under the principal named in `AllowReportingDecrypt`; it demonstrates that this path was admitted and returned readable object bytes. It does not expose patient contents in this report. CloudTrail also records successful KMS decrypt operations under the same principal and key alias. For example, event `a69e5975-65a4-4e20-a8d0-ae5eeadb2cab` at `2026-11-03T02:12:08Z` has request ID `CD48B251E1DC4DAF`, caller `arn:aws:iam::734112396500:user/reporting-role-key`, source `10.9.2.7`, user agent `aws-cli/2.17.4 md/command#s3api.get-object`, key `alias/alderbrook-phi`, and no error code. This is an executed successful `Decrypt` by the tested principal for the key protecting the PHI object, consistent with the direct key-policy allow. The focused November 20–21 extract did not return a KMS event for the later PHI `GetObject`; the November 3 event is corroborating key-use evidence, not the KMS subrequest for that specific November 20 read. The key-policy statement itself directly authorizes the tested principal and has no condition to restrict encryption context.

The corresponding S3 data event is `3a23fbfb-7c60-4529-9304-6de2f1dd132a`, at `2026-11-20T20:03:27Z`, request ID `rKt1ibmO5ias2B6d1jUOD2z672eLSaNuDDx6v3gscDPeHBy8qvOb`, principal `arn:aws:iam::734112396500:user/reporting-role-key`, source `127.0.0.1`, user agent `Boto3/1.34.46 ...`, bucket/key `alderbrook-phi-records-ab7f3a/records/patients-2026.ndjson`, and no error code. It is stored at `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/20/734112396500_CloudTrail_eu-west-1_20261120T2003Z_4Ed99EA17A5EE3cD.json.gz`.

CloudTrail's November 3 record has no `resources` or `encryptionContext` value, so it cannot independently bind that decrypt to a particular S3 object. The separate November 20 S3 data event binds `reporting-role-key` to the PHI object and reports the KMS alias; the successful response returned the object bytes. Together with the direct key-policy allow, this establishes the effective principal, key authorization, and successful object retrieval, while the exact KMS subrequest for the November 20 GET remains unlocated. Do not copy `ciphertextBlob`, plaintext, or data-key material into the report. This finding is limited to the tested principal and object: SSE-KMS protects the record from principals without an authorized decrypt path, while it did not contain the demonstrated `reporting-role-key` path.
