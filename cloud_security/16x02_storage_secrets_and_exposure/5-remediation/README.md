# 5 — Remediation record

## Status: prepared, not applied

The proposed replacement policy is in [`phi-records-policy.json`](phi-records-policy.json). It removes the `LegacyClinicSync` wildcard principal and grants only `s3:ListBucket` on the records bucket and `s3:GetObject` on its objects to `arn:aws:iam::734112396500:user/reporting-role-key`.

That principal is the strongest available reporting candidate: the historical `.env.local` file labels its credentials `REPORTING_AWS_*`, the credentials resolve to this IAM user, and the KMS key policy contains `AllowReportingDecrypt` for it. However, the repository contains no reporting job configuration that names the production principal. The identity also has an exposed historical credential pair. The proposed policy must not be described as applied or as closing the credential exposure until the workload identity is confirmed and the exposed credential is rotated or otherwise invalidated.

I could not apply the policy from this environment. SSH to the lab workstation requests an interactive password, and the current workspace has no AWS CLI or lab endpoint. No bucket state was changed by this remediation attempt.

## Apply and verify on the lab workstation

After confirming that `reporting-role-key` is the production job identity and rotating its exposed credential, transfer/use this policy file on the lab workstation and run:

```bash
set -euo pipefail
bucket=alderbrook-phi-records-ab7f3a
aws sts get-caller-identity
aws s3api get-bucket-policy --bucket "$bucket" > /tmp/phi-policy-before.json
aws s3api put-bucket-policy --bucket "$bucket" --policy file://phi-records-policy.json
aws s3api get-bucket-policy --bucket "$bucket" --query Policy --output text

# Anonymous request must be refused after the wildcard grant is removed.
curl --noproxy '*' -sS -o /dev/null -w 'anonymous-get %{http_code}\n' \
  "http://127.0.0.1:4566/$bucket/records/patients-2026.ndjson"
```

Then repeat the reporting identity's body-discarding `GetObject` for `records/patients-2026.ndjson`; record the successful response status, byte count, SSE algorithm, and KMS key ID without printing the body or credentials. Confirm the policy shows only the named reporting principal and retain the post-change CloudTrail events. A successful S3 read by `sec-reviewer` would not test removal of the public grant because that is an authenticated same-account principal; use the unsigned request for the public-refusal check.

## Evidence still needed to mark complete

- Production principal confirmed from actual job configuration, and the exposed credential rotated/invalidated.
- The policy applied in the lab, with the returned policy captured.
- Anonymous object request returns a refusal after the change.
- Legitimate reporting identity retrieves the encrypted record after the change; response metadata confirms the same KMS key and the body is discarded.
- CloudTrail evidence for both post-change outcomes and an impact statement based on the tested reporting operation.

The earlier bucket-level `PutBucketPublicAccessBlock` that set all four flags to `false` is not this remediation (CloudTrail event `c6b65cb5-7937-49a6-b08e-4333cc7abb42`). Preserve the signed audit export before any lab reset because reset clears activity.
