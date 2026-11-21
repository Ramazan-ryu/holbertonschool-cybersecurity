# 4 — Encryption and the key

## Summary

The PHI object `alderbrook-phi-records-ab7f3a/records/patients-2026.ndjson` is SSE-KMS encrypted under `alias/alderbrook-phi`. Two principals read the object successfully on 2026-11-20:

- `arn:aws:iam::734112396500:user/reporting-role-key` (20:03:27Z, event `3a23fbfb-7c60-4529-9304-6de2f1dd132a`), using the credential pair found in `.env.local`.
- `arn:aws:iam::734112396500:user/dashboards-ro` (20:08:37Z), which is outside this review's scope list.

Both reads are authorized at the S3 layer. The key policy's direct grant to `reporting-role-key` is established. A `kms:Decrypt` event matching either read has **not** been located, so the decrypt step is inferred from the successful S3 reads, not separately proven.

## Key identity

`alias/alderbrook-phi` resolves to the enabled customer-managed key `arn:aws:kms:eu-west-1:734112396500:key/256370d9-4f10-45e2-92e4-121eda29a14f`. The emulator rejected `GetKeyPolicy` by alias, so the policy was retrieved using the resolved key ID.

## Decisive key-policy statement

The statement that directly governs the tested principal, as returned by `GetKeyPolicy`:

```json
{
  "Sid": "AllowReportingDecrypt",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::734112396500:user/reporting-role-key"},
  "Action": ["kms:Decrypt", "kms:DescribeKey"],
  "Resource": ""
}
```

- **Condition:** none. The statement does not restrict encryption context.
- **Admits:** only `reporting-role-key`. It does not admit `dashboards-ro`.
- **Resource value:** the output shows an empty string. In a key policy, `Resource` is normally `"*"`. Verify the raw output before submission and copy it exactly.

A separate `Root` statement grants `arn:aws:iam::734112396500:root` `kms:*` and enables IAM delegation. The `dashboards-ro` read is not explained by that statement, because no key-policy statement names `dashboards-ro`. Its KMS authorization would have to come from an identity-side policy, which was not retrieved.

## What is proven

1. **The principal and object are linked.** CloudTrail `3a23fbfb-7c60-4529-9304-6de2f1dd132a` (2026-11-20T20:03:27Z, request `rKt1ibmO5ias2B6d1jUOD2z672eLSaNuDDx6v3gscDPeHBy8qvOb`) records a successful `GetObject` on the PHI object by `reporting-role-key`, with no error code. It is stored at `AWSLogs/734112396500/CloudTrail/eu-west-1/2026/11/20/734112396500_CloudTrail_eu-west-1_20261120T2003Z_4Ed99EA17A5EE3cD.json.gz`.
2. **A second principal read the same object.** CloudTrail records a successful `GetObject` on `alderbrook-phi-records-ab7f3a/records/patients-2026.ndjson` by `dashboards-ro` at 2026-11-20T20:08:37Z, with no error code. The event ID for this record was not captured in the extract and must be recorded before submission.
3. **The key policy admits `reporting-role-key` to decrypt.** The `AllowReportingDecrypt` statement is quoted above, with no condition.
4. **Key use under the same principal appears elsewhere.** CloudTrail event `a69e5975-65a4-4e20-a8d0-ae5eeadb2cab` (2026-11-03T02:12:08Z, request `CD48B251E1DC4DAF`) records a successful KMS `Decrypt` by `reporting-role-key` against `alias/alderbrook-phi`, from `10.9.2.7`. This is a different request on a different date. It shows that the principal has used the key, but it does not show that it decrypted this object.

## What is not proven

- **The decrypt for the 2026-11-20 reads.** The adjacent CloudTrail batches (19:59, 20:03, 20:06, 20:08 UTC) were searched. The 19:59 batch contains a `kms:GetKeyPolicy` by `sec-reviewer`. The 20:03 batch contains only the S3 `GetObject`. The 20:06 batch contains `sts:GetCallerIdentity` by `dashboards-ro`. The 20:08 batch contains no `kms:Decrypt`. No `Decrypt` event was found for either 20:03:27Z or 20:08:37Z.
- **Whether `sec-reviewer` could query the trail directly.** `cloudtrail:LookupEvents` returned `AccessDeniedException` for `sec-reviewer`, so the search relied on reading trail objects from S3.
- **The decrypt authorization for `dashboards-ro`.** No key-policy statement names it, and its identity-side policy was not retrieved.

Given these gaps, the successful reads are evidence that S3 returned readable object bytes to each principal. Because the object is SSE-KMS, that requires a successful `kms:Decrypt` under the same principal. This inference is strong but unverified until the KMS event is located or a reproducible decrypt test is run.

## Value and limits of encryption

SSE-KMS did not stop either read. It protects the object only against callers without a valid decrypt path. Here, the decrypt path was available to `reporting-role-key` by key-policy grant, and to `dashboards-ro` by a mechanism not yet identified. Encryption at rest therefore gave no protection against the two principals observed, and it does not protect against any principal that holds a valid decrypt grant.

Encryption also does not prevent the bucket-level exposure. The `LegacyClinicSync` policy grants anonymous list and read on the same bucket, and the account-level Block Public Access query returned `NoSuchPublicAccessBlockConfiguration`. Those layers are assessed in the access-review section and are not repeated here.

This assessment does not copy ciphertext, plaintext, or data-key material into the report.

## Findings

1. **Critical: unexplained read by an out-of-scope identity.** `dashboards-ro` enumerated all five buckets at 2026-11-20T20:08:36–37Z, then read `records/patients-2026.ndjson`. Its use is unexplained, and the source address `127.0.0.1` is the lab endpoint's local origin, which does not identify the host. Treat the read as unauthorized until the owner confirms it.
2. **High: plaintext AWS credentials for `reporting-role-key` in `.env.local`.** This credential pair authenticated the 20:03:27Z read. The file is a route into the account for anyone with read access to it.
3. **High: `dashboards-ro` credential storage is unknown.** Where its key is kept and who can read it has not been established.
4. **High: `LegacyClinicSync` public policy on the PHI bucket.** Assessed in the access-review section.
5. **Medium: no key-level verification of the decrypt path for either principal.** The decrypt is inferred from successful reads. This is a gap in evidence, not evidence of misuse on its own.

## Open items

1. Record the CloudTrail event ID and full record for the `dashboards-ro` `GetObject` at 2026-11-20T20:08:37Z.
2. Pull all `dashboards-ro` activity for the past 30 days from the trail objects, not only the 20:08 batch.
3. Verify the raw `GetKeyPolicy` output, including the `Resource` value of `AllowReportingDecrypt`.
4. Retrieve `dashboards-ro`'s identity-side policies to determine how it was authorized to decrypt.
5. Locate a `kms:Decrypt` event for the 20:03:27Z or 20:08:37Z reads, or run a minimally scoped decrypt test as `reporting-role-key` against the PHI object and record the result, without copying ciphertext or plaintext.
6. Rotate `reporting-role-key` and `dashboards-ro` credentials, and disable `dashboards-ro` pending owner confirmation.
