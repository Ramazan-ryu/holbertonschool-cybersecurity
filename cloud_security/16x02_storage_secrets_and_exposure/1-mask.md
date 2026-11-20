# 1 — Private, or lucky

## Finding: the records bucket policy independently grants public access

**Risk-bearing layer:** bucket policy `LegacyClinicSync` on `alderbrook-phi-records-ab7f3a`.

The exact statement has `Effect: Allow`, `Principal: "*"`, actions `s3:ListBucket` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a` and `s3:GetObject` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a/*`. In plain terms, if no public-access block suppresses it, an anonymous internet caller with no Alderbrook identity can list the bucket and issue `GetObject` for any object key in it, including `records/patients-2026.ndjson`. The policy read returned this statement; CloudTrail event `017352bb-1c18-4f02-b1d8-0bb7883dae29` records the successful `GetBucketPolicy` at `2026-11-20T00:05:35Z`.

This is a finding against the bucket policy because the broad grant is stored there and would become effective without any policy edit if the higher-level mask were removed. The authenticated `sec-reviewer` `GetObject` success (CloudTrail `c5ad1054-168a-4c70-9769-5a28bd7ee6b4`) confirms the object is readable through an authorized account path; it does not prove anonymous access.

## Higher-level mask and current-state evidence

The handover states that Alderbrook’s account-level S3 Block Public Access is on. For an already-existing public bucket policy, the relevant suppressing component is `RestrictPublicBuckets=true`; `BlockPublicPolicy` alone only rejects new public policies and does not neutralize this existing statement. If account-level `RestrictPublicBuckets` is enabled, it limits access through this public policy to authorized principals in the bucket owner’s account and AWS service principals, so an anonymous internet caller is blocked. AWS documents that this setting restricts buckets with public policies and that account and bucket settings are both evaluated ([configuration reference](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PublicAccessBlockConfiguration.html), [account API](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_PutPublicAccessBlock.html)). The handover claim is the available evidence of this setting, but the live `aws s3api get-public-access-block --bucket alderbrook-phi-records-ab7f3a` calls returned HTTP 500. No successful `aws s3control get-public-access-block --account-id 734112396500` response and no anonymous GET result are present. Therefore the current mask is **reported by handover, not independently demonstrated by the supplied API response**; I do not describe an anonymous refusal as observed.

The successful `PutBucketPublicAccessBlock` event `c6b65cb5-7937-49a6-b08e-4333cc7abb42` at `2026-11-20T00:09:49Z` set the four **bucket-level** flags to false. It is not a call that changes the account-level setting and cannot establish or remove the account mask.

## Who can unmask it

The account-level control is changed through S3 Control with `s3:PutAccountPublicAccessBlock` scoped to account `734112396500` (the API is `PutPublicAccessBlock` with the account ID; AWS lists this required permission in its [API reference](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_PutPublicAccessBlock.html)). The relevant principal is an Alderbrook account administrator or automation role whose effective IAM permissions include that action on the account; changing the account public-access-block configuration is an ordinary administrative control-plane update and would appear as a routine S3 Control write in the audit record. The supplied evidence proves that `sec-reviewer` could call bucket-scoped `PutBucketPublicAccessBlock`; it does **not** prove that this user or any named Alderbrook role has account-scoped `s3:PutAccountPublicAccessBlock`. The actual authorized admin principal was not identified in the available responses, so I do not attribute the permission to a named role.

If an account administrator disables `RestrictPublicBuckets` (and no other effective higher-level block remains), the existing wildcard policy immediately supplies anonymous `ListBucket` and `GetObject`; no bucket-policy change is needed. The exposure is therefore persistent in the policy even while the handover-reported mask is on.

**Report against:** `LegacyClinicSync` bucket policy. **Mitigating factor:** account-level S3 Block Public Access, specifically `RestrictPublicBuckets`, as described in the handover. The block is a reversible mitigation, not evidence that the wildcard policy is safe.

## Proof still absent

A successful account-level public-access-block response, plus an anonymous `GetObject`/`ListBucket` test with response status recorded (and any data body discarded), is needed to prove the current effective denial and which principal is authorized to change it. Those results are not in the collected evidence.
