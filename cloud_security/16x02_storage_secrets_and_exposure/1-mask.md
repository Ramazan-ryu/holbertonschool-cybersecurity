# 1 — Private, or lucky

## Finding: broad records-bucket policy masked by a higher-level control

The `LegacyClinicSync` statement on `alderbrook-phi-records-ab7f3a` has `Effect: Allow`, `Principal: "*"`, and grants `s3:GetObject` and `s3:ListBucket` over the bucket and its objects. The policy itself does not restrict callers to Alderbrook identities.

The handover says the account-level S3 Block Public Access setting is enabled. That setting is the stated mitigating control; it is not a property of the bucket policy. The live `aws s3api get-public-access-block --bucket ...` attempts returned HTTP 500, and the account-level `aws s3control get-public-access-block --account-id 734112396500` response is not in the evidence set. Therefore the “safe today” state is reported by the handover but not confirmed by a successful control-plane response in this record. The successful authenticated `GetObject` proves `sec-reviewer` access, not anonymous access.

The bucket-level `PutBucketPublicAccessBlock` call at `2026-11-20T00:09:49Z` set all four bucket-level flags to `false` and succeeded (CloudTrail event `c6b65cb5-7937-49a6-b08e-4333cc7abb42`). That is not the account-level switch. A caller with account-level permission `s3:PutAccountPublicAccessBlock` through S3 Control (an account administrator or equivalent authorized principal) can remove the account-level mitigation by changing its public-access-block settings. If the effective account block no longer blocks public policies, the `Principal: "*"` allow makes the bucket policy admit anonymous `ListBucket` and `GetObject` requests. The person who can do this in Alderbrook’s IAM configuration is not identifiable from the supplied responses.

**Report against:** the `LegacyClinicSync` bucket policy, because it carries the broad grant. **Mitigating factor:** account-level S3 Block Public Access, as described in the handover. The bucket-level block is not a substitute for it.

## Verification needed to close the factual gap

A successful account-level `GetPublicAccessBlock` response and an anonymous request to a harmless object (recording only HTTP status and headers, with the body discarded) are needed to state current effective public access. Do not infer either from the authenticated `GetObject` call.
