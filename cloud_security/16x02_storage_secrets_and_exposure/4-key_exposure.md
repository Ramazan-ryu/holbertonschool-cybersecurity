# 4 — Encryption and the key

## Key and governing policy

`alias/alderbrook-phi` resolves to customer-managed KMS key `arn:aws:kms:eu-west-1:734112396500:key/256370d9-4f10-45e2-92e4-121eda29a14f`, state `Enabled`. The `GetKeyPolicy` call succeeded using the resolved key ID; the emulator rejected the alias for this operation.

The governing key-policy statement is:

```json
{
  "Sid": "AllowReportingDecrypt",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::734112396500:user/reporting-role-key"},
  "Action": ["kms:Decrypt", "kms:DescribeKey"],
  "Resource": "*"
}
```

The statement contains no `Condition`. It explicitly admits the `reporting-role-key` IAM user to call `kms:Decrypt` and `kms:DescribeKey` on this key. The policy also has a `Root` statement allowing `arn:aws:iam::734112396500:root` `kms:*` on `Resource: "*"`. Under AWS KMS policy semantics, that account-principal statement enables the account to delegate use through IAM policies; it does not, by itself, grant every IAM user direct decrypt access. See AWS's [KMS key policy documentation](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html) and [account delegation explanation](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html).

## Established principal and object path

The historical `.env.local` reporting credential pair authenticated as `arn:aws:iam::734112396500:user/reporting-role-key`. Using that identity, `ListBucket` succeeded on the records bucket and `HeadObject` succeeded for `records/patients-2026.ndjson`; `HeadObject` also succeeded for the exports rollup. These results establish `ListBucket` on the records bucket and object metadata access to the named records object under this identity. A subsequent `GetObject` under the same credentials succeeded and returned 6,625 bytes; the S3 response reported `ServerSideEncryption: aws:kms` and `SSEKMSKeyId: alias/alderbrook-phi`. The script streamed and discarded the body.

The Terraform candidate also authenticated as `arn:aws:iam::734112396500:user/dashboards-ro`. That identity successfully executed `GetObject` for the same records object, receiving 6,625 bytes with `ServerSideEncryption: aws:kms` and `SSEKMSKeyId: alias/alderbrook-phi`; the body was discarded. The key policy does not name `dashboards-ro` in `AllowReportingDecrypt`. The successful S3-to-KMS retrieval proves effective decryption for this identity, consistent with the `Root` statement enabling IAM delegation; the specific `dashboards-ro` IAM policy or KMS grant was not retrieved. `sec-reviewer` also successfully read the same object; CloudTrail event `c5ad1054-168a-4c70-9769-5a28bd7ee6b4` records that request.

## What encryption did and did not contain

SSE-KMS protects the stored object and requires an authorized decrypt path for a caller to retrieve its contents. It did not prevent the demonstrated successful `sec-reviewer` retrieval. The direct key-policy statement gives `reporting-role-key` the `kms:Decrypt` action. Body-returning `GetObject` calls under both `reporting-role-key` and `dashboards-ro` prove complete S3-to-KMS retrieval paths for those credentials. The latter is not named directly in the key policy, so an IAM allow or KMS grant must also participate; its exact statement or grant has not been retrieved. The governing `AllowReportingDecrypt` statement has no `Condition`, so it imposes no encryption-context condition. The exact set of principals excluded by all IAM policies, key policy statements, and higher-level controls is not established by this key policy alone.
