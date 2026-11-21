# 4 — Encryption and the key

## Summary

The PHI object `alderbrook-phi-records-ab7f3a/records/patients-2026.ndjson` is encrypted with SSE-KMS under `alias/alderbrook-phi`. Two principals read the object successfully on 2026-11-20:

- `arn:aws:iam::734112396500:user/reporting-role-key` at 20:03:27Z (CloudTrail event `3a23fbfb-7c60-4529-9304-6de2f1dd132a`), using the credential pair stored in `.env.local`.
- `arn:aws:iam::734112396500:user/dashboards-ro` at 20:08:37Z (CloudTrail event `b35067cd-29db-499d-9247-c43e491f1155`). This identity is outside the review's scope list.

The historical CloudTrail set contains a closely matched S3/KMS sequence for `reporting-role-key`: both a successful `GetObject` of this PHI object and a successful `kms:Decrypt` against `alias/alderbrook-phi` are recorded at `2026-11-03T02:12:08Z`, with the same caller, source IP, and user agent. The key policy directly allows that principal to decrypt. This establishes an effective S3-to-KMS read path for the earlier request. Separate `GetObject` reads occurred on 2026-11-20; no matching `Decrypt` event was found for those later reads in the adjacent log objects reviewed. `dashboards-ro` is not named in the key policy, and its exact KMS authorization path remains unresolved.

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
- **`dashboards-ro`:** not named in either key-policy statement. The `Root` statement enables IAM delegation for this account, and a KMS grant is another possible authorization mechanism. Neither its identity-side IAM policies nor applicable KMS grants were retrieved, so its exact KMS authorization path is unknown.

## What is proven

1. **Prior exposed credential reaches the PHI object.** The `.env.local` credential pair was validated as `arn:aws:iam::734112396500:user/reporting-role-key` in task 3. The 2026-11-20 `GetObject` event `3a23fbfb-7c60-4529-9304-6de2f1dd132a` records that principal successfully reading `records/patients-2026.ndjson` (request `rKt1ibmO5ias2B6d1jUOD2z672eLSaNuDDx6v3gscDPeHBy8qvOb`, no error). The returned S3 metadata identified SSE-KMS and `alias/alderbrook-phi`; the response body was discarded.
2. **An earlier S3/KMS pair directly demonstrates the key path.** S3 `GetObject` event `80b0d56b-8c6a-48aa-be95-00af92329d4c` and KMS `Decrypt` event `a69e5975-65a4-4e20-a8d0-ae5eeadb2cab` both occurred at `2026-11-03T02:12:08Z`. Both records identify `reporting-role-key`, source `10.9.2.7`, and user agent `aws-cli/2.17.4 md/command#s3api.get-object`; the S3 event names the PHI object, while the KMS event names `alias/alderbrook-phi`. Both have no error code. Their request IDs differ, so CloudTrail does not provide a shared request ID, but the matching timestamp and caller context strongly link the operations.
3. **The key policy directly authorizes that principal.** `AllowReportingDecrypt` names `reporting-role-key` for `kms:Decrypt` and `kms:DescribeKey`, with no `Condition`. Together with the paired successful events, this proves an effective decrypt path for the 2026-11-03 PHI read, not merely permission suggested by the policy.
4. **A second principal read the same object on 2026-11-20.** CloudTrail event `b35067cd-29db-499d-9247-c43e491f1155` records a successful `GetObject` by `arn:aws:iam::734112396500:user/dashboards-ro` at `2026-11-20T20:08:37Z` (request `XxZDbGRqAdBbsL9XJu2EkPrK0cUuSLNIJH4SkaOmu6nIu3Y7dZsK`, source `127.0.0.1`, no error). This proves effective S3 retrieval for that identity, but the exact key-policy/IAM/grant authorization chain has not been retrieved.

## What is not proven

- **A corresponding `Decrypt` event for the 2026-11-20 reads.** In the adjacent CloudTrail batches reviewed, the 20:03 object-read batch contains the S3 `GetObject` but no KMS `Decrypt`; the 20:08 batch also contains no KMS `Decrypt`. The 2026-11-03 pair proves the earlier `reporting-role-key` path, not the KMS event for either later read.
- **Full-day and 30-day searches.** These have not been run.
- **The exact authorization path for `dashboards-ro`.** Discovery calls were made as `arn:aws:iam::734112396500:user/sec-reviewer`: `iam:GetUser`, `iam:ListAttachedUserPolicies`, `iam:ListUserPolicies`, and `iam:ListGroupsForUser` each returned `AccessDenied`; `kms:ListGrants` returned `AccessDeniedException`. These are denials of the reviewer's inspection calls. They do not deny or explain `dashboards-ro`'s S3/KMS request, and they expose no governing statement for that request. The successful S3 response proves effective retrieval, but the specific IAM policy or KMS grant remains unknown.
- **Direct authorization test.** No minimally scoped decrypt test has been run as either principal.
- **Trail search from `sec-reviewer`.** `cloudtrail:LookupEvents` returned `AccessDeniedException`, so the search relied on reading trail objects from S3.

The successful 2026-11-03 S3/KMS pair and direct key-policy statement establish the `reporting-role-key` decryption route for that request. The 2026-11-20 reads separately show successful object retrieval, but their exact KMS events were not found in the adjacent batches reviewed; do not conflate those later events with the earlier matched pair. For `dashboards-ro`, the S3 success establishes effective retrieval, while the specific IAM policy or KMS grant remains unidentified.

## Value and limits of encryption

SSE-KMS did not stop either principal's successful retrieval. For the earlier `reporting-role-key` request, the direct `AllowReportingDecrypt` key-policy statement and matching KMS event establish the decrypt path. The 2026-11-20 read by `dashboards-ro` proves effective retrieval, but its specific key authorization mechanism is not identified. Encryption at rest does not prevent retrieval by a principal with an effective decrypt path.

Encryption also does not prevent the bucket-level exposure. The `LegacyClinicSync` policy grants anonymous list and read on the same bucket, and the account-level Block Public Access query returned `NoSuchPublicAccessBlockConfiguration`. Those layers are assessed in the access-review section.

This assessment does not copy ciphertext, plaintext or data-key material into the report.

## Findings

1. **Critical: unexplained read by an out-of-scope identity.** `dashboards-ro` enumerated all five buckets at 2026-11-20T20:08:36–37Z, then read `records/patients-2026.ndjson`. Its use is unexplained. The source address `127.0.0.1` is the workstation's loopback, so it does not identify the originating host. Treat the read as unauthorized until the owner confirms it.
2. **High: plaintext AWS credentials for `reporting-role-key` in `.env.local`.** This pair authenticated the 20:03:27Z read. Anyone with read access to the file can use it.
3. **High: `dashboards-ro` credential storage is unknown.** Where its key is kept and who can read it has not been established.
4. **High: `LegacyClinicSync` public policy on the PHI bucket.** Assessed in the access-review section.
5. **Medium: later KMS events and the dashboards authorization chain need review.** The 2026-11-03 `reporting-role-key` decrypt path is supported by paired S3/KMS events and the direct key-policy statement. The corresponding KMS event for the later 2026-11-20 reads was not found in the adjacent batches, and the exact KMS authorization source for `dashboards-ro` remains unknown.

## Open items

1. Retrieve `dashboards-ro`'s IAM policies and KMS grants to identify the authorization mechanism behind its successful read.
2. Search the full 2026-11-20 trail day and the prior 30 days for KMS `Decrypt` events corresponding to the later reads; preserve exact event IDs and request metadata.
3. Rotate the `reporting-role-key` and `dashboards-ro` credentials, and have the owner review `dashboards-ro`'s access before restoring it.
