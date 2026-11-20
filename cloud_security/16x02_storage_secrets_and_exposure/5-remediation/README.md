# 5 — Remediation record

## Status: not completed

No S3 policy change, refusal check, or legitimate post-change read is evidenced here. The task requires all three, so this directory does not claim the exposure is closed.

The observed risk-bearing policy is `LegacyClinicSync` on `alderbrook-phi-records-ab7f3a`: wildcard principal with `s3:GetObject` and `s3:ListBucket`. The proper remediation is to replace that broad principal with the exact production workload principal established from Alderbrook’s job configuration, then prove the reviewer/public read is refused and the legitimate reporting job still succeeds. The workload principal was not established in the supplied evidence, so no replacement policy was invented or applied.

A separate successful `PutBucketPublicAccessBlock` at `2026-11-20T00:09:49Z` set the bucket-level flags to `false` (CloudTrail event `c6b65cb5-7937-49a6-b08e-4333cc7abb42`). This is a state change already present in the recorded session, not a remediation. Do not mistake it for an account-level change. Preserve the signed audit export before using any lab reset, since the lab notes say reset clears activity.

## Artifacts still required

- Exact policy change applied in the lab.
- The previously successful read re-run after the change, including the refusal response.
- A legitimate reporting operation after the change, including its success response.
- A final statement of the disruption/cost based on the actual workload tested.
