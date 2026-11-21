# 4 — Encryption and the key

## Summary

The PHI object `alderbrook-phi-records-ab7f3a/records/patients-2026.ndjson` is encrypted with SSE-KMS under `alias/alderbrook-phi`. Two principals read the object successfully on 2026-11-20:

- `arn:aws:iam::734112396500:user/reporting-role-key` at 20:03:27Z (CloudTrail event `3a23fbfb-7c60-4529-9304-6de2f1dd132a`), using the credential pair stored in `.env.local`.
- `arn:aws:iam::734112396500:user/dashboards-ro` at 20:08:37Z. This identity is outside the review's scope list. The event ID for this record must be recorded before submission.

The key policy admits `reporting-role-key` to decrypt. No key-policy statement names `dashboards-ro`. A `kms:Decrypt` event matching either read has **not** been located, so the decrypt step is inferred from the successful S3 reads and is not separately proven.

## Key identity

`alias/alderbrook-phi` resolves to the enabled customer-managed key `arn:aws:kms:eu-west-1:734112396500:key/256370d9-4f10-45e2-92e4-121eda29a14f`. The emulator rejected `GetKeyPolicy` by alias, so the policy was retrieved using the resolved key ID:

```bash
aws kms get-key-policy --key-id arn:aws:kms:eu-west-1:734112396500:key/256370d9-4f10-45e2-92e4-121eda29a14f --policy-name default --output text
```

## Key policy

The `default` key policy contains two statements:

```json
{
  "Sid": "Root",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::734112396500:root"},
  "Action": "kms:*",
  "Resource": "*"
}
```

```json
{
  "Sid": "AllowReportingDecrypt",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::734112396500:user/reporting-role-key"},
  "Action": ["kms:Decrypt", "kms:DescribeKey"],
  "Resource": "*"
}
```

- **Governing statement for the tested principal:** `AllowReportingDecrypt`. It has no `Condition`, so it does not restrict encryption context. It admits only `reporting-role-key`.
- **`Root` statement:** grants the account root `kms:*` and enables IAM delegation. Through that delegation, an IAM policy in this account could grant KMS access to other principals. No such IAM policy was retrieved.
- **`dashboards-ro`:** not named in any key-policy statement. Its KMS authorization can only come from an identity-side policy, which has not been retrieved.

## What is proven

1. **Principal and object are linked.** CloudTrail `3a23fbfb-7c60-4529-9304-6de2f1dd132a` (2026-11-20T20:03:27Z, request `rKt1ibmO5ias2B6d1jUOD2z672eLSaNuDDx6v3gscDPeHBy8qvOb`) records a successful `GetObject` on the PHI object by `reporting-role-key`, with no error code. It is stored at `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/20/734112396500_CloudTrail_eu-west-1_20261120T2003Z_4Ed99EA17A5EE3cD.json.gz`.
2. **A second principal read the same object.** CloudTrail records a successful `GetObject` on the PHI object by `dashboards-ro` at 2026-11-20T20:08:37Z, with no error code.
3. **The key policy admits `reporting-role-key` to decrypt.** The `AllowReportingDecrypt` statement above has no condition.
4. **The principal has used this key before, on a different request.** CloudTrail event `a69e5975-65a4-4e20-a8d0-ae5eeadb2cab` (2026-11-03T02:12:08Z, request `CD48B251E1DC4DAF`) records a successful KMS `Decrypt` by `reporting-role-key` against `alias/alderbrook-phi`, from `10.9.2.7`. It does not show that it decrypted this object.

## What is not proven

- **The decrypt for the 2026-11-20 reads.** The adjacent CloudTrail batches (19:59, 20:03, 20:06 and 20:08 UTC) were searched. The 19:59 batch contains `kms:GetKeyPolicy` by `sec-reviewer`. The 20:03 batch contains only the S3 `GetObject`. The 20:06 batch contains `sts:GetCallerIdentity` by `dashboards-ro`. The 20:08 batch contains no `kms:Decrypt`. No `Decrypt` event was found for 20:03:27Z or 20:08:37Z.
- **Full-day and 30-day searches.** These have not been run.
- **The authorization path for `dashboards-ro`.** Its identity-side IAM policies have not been retrieved, so the path that allowed its KMS access is unknown.
- **Direct authorization test.** No minimally scoped decrypt test has been run as either principal.
- **Trail search from `sec-reviewer`.** `cloudtrail:LookupEvents` returned `AccessDeniedException`, so the search relied on reading trail objects from S3.

Because of these gaps, the successful reads show that S3 returned readable bytes to each principal. For an SSE-KMS object, that requires a successful `kms:Decrypt` under the same principal. The inference is strong but unverified until a decrypt event is located or a scoped decrypt test is run.

## Value and limits of encryption

SSE-KMS did not stop either read. It protects the object only against callers without a valid decrypt path. `reporting-role-key` had one by key-policy grant. `dashboards-ro` had one by a mechanism not yet identified. Encryption at rest gave no protection against the two principals observed, and it does not protect against any principal that holds a valid decrypt grant.

Encryption also does not prevent the bucket-level exposure. The `LegacyClinicSync` policy grants anonymous list and read on the same bucket, and the account-level Block Public Access query returned `NoSuchPublicAccessBlockConfiguration`. Those layers are assessed in the access-review section.

This assessment does not copy ciphertext, plaintext or data-key material into the report.

## Findings

1. **Critical: unexplained read by an out-of-scope identity.** `dashboards-ro` enumerated all five buckets at 2026-11-20T20:08:36–37Z, then read `records/patients-2026.ndjson`. Its use is unexplained. The source address `127.0.0.1` is the workstation's loopback, so it does not identify the originating host. Treat the read as unauthorized until the owner confirms it.
2. **High: plaintext AWS credentials for `reporting-role-key` in `.env.local`.** This pair authenticated the 20:03:27Z read. Anyone with read access to the file can use it.
3. **High: `dashboards-ro` credential storage is unknown.** Where its key is kept and who can read it has not been established.
4. **High: `LegacyClinicSync` public policy on the PHI bucket.** Assessed in the access-review section.
5. **Medium: no key-level evidence of the decrypt path for either principal.** The decrypt is inferred from successful reads. This is an evidence gap, not proof of misuse.

## Open items

1. Record the CloudTrail event ID and full record for the `dashboards-ro` `GetObject` at 2026-11-20T20:08:37Z.
2. Retrieve `dashboards-ro`'s IAM policies (`list-attached-user-policies`, `list-user-policies`) to determine how it was authorized for KMS decrypt.
3. Pull `kms:Decrypt` events for the full day of 2026-11-20 and the 30 days before, from the trail objects.
4. Locate a `kms:Decrypt` event for 20:03:27Z or 20:08:37Z, or run a minimally scoped decrypt test as `reporting-role-key` and record only the result metadata.
5. Rotate the `reporting-role-key` and `dashboards-ro` credentials, and disable `dashboards-ro` pending owner confirmation.
