# 1 — Private, or lucky

## Finding: the records bucket policy is public by configuration

The current `get-bucket-policy` response contains statement `LegacyClinicSync`:

```json
{
  "Sid": "LegacyClinicSync",
  "Effect": "Allow",
  "Principal": "*",
  "Action": ["s3:GetObject", "s3:ListBucket"],
  "Resource": [
    "arn:aws:s3:::alderbrook-phi-records-ab7f3a",
    "arn:aws:s3:::alderbrook-phi-records-ab7f3a/*"
  ]
}
```

The policy response was successful; CloudTrail event `017352bb-1c18-4f02-b1d8-0bb7883dae29` records the `GetBucketPolicy` call. `get-bucket-policy-status` returned `PolicyStatus.IsPublic: true`. Therefore the stored bucket policy is classified as public. It grants `s3:ListBucket` on the bucket and `s3:GetObject` on its objects, including `records/patients-2026.ndjson`.

## Masking control: none verified

The signed account-level `GetPublicAccessBlock` request returned HTTP 404 `NoSuchPublicAccessBlockConfiguration`, request ID `G5MK2jRLvaAC4XsYhOt01JiiyuQVFKC3jCRAvazro7RQcU6K3Msx`. This means the account has no account-level `PublicAccessBlockConfiguration` set in the lab response; no flag values were returned. The handover's statement that account-level Block Public Access is enabled conflicts with this result. Organization-level controls were not separately retrieved.

The bucket-level `GetPublicAccessBlock` read for `alderbrook-phi-records-ab7f3a` returned HTTP 500, so its present values could not be read directly. CloudTrail records a successful `PutBucketPublicAccessBlock` by `sec-reviewer` at `2026-11-20T00:09:49Z` (event `c6b65cb5-7937-49a6-b08e-4333cc7abb42`); the command result reported all four bucket flags set to `false`. This is the latest matching write in the collected trail. It is evidence of that change, not a successful current-state read.

The bucket and object ACLs grant only owner `FULL_CONTROL`; they do not mask or grant public access. No verified account- or bucket-level BPA setting suppresses the wildcard policy. AWS identifies `RestrictPublicBuckets` as the account/bucket BPA setting that restricts access through a public bucket policy; `BlockPublicPolicy` prevents future public-policy writes and does not remove an already stored policy. See the [BPA configuration reference](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PublicAccessBlockConfiguration.html).

## Request outcomes and limits

The unsigned `aws s3api list-objects-v2` and `get-object --no-sign-request` calls returned `MissingAuthenticationToken`. Earlier unsigned `curl` probes returned HTTP 403. These responses show that the loopback lab endpoint did not process those requests as anonymous S3 policy evaluations; they do not identify an active Block Public Access setting. The endpoint listens on `127.0.0.1:4566`; requests to `192.168.1.94:4566` failed to connect. No off-workstation or Internet request was tested.

The PHI object is SSE-KMS encrypted. KMS authorization can prevent an object GET from returning plaintext, but it cannot explain a `ListBucket` denial. No observed response ties either unsigned denial to a particular masking layer. Therefore the effective anonymous result at a real S3 service and the cause of the lab endpoint's denial remain unverified. Do not describe the 403 as proof that the bucket is private.

**Verdict:** `LegacyClinicSync` is a public grant by policy, and `get-bucket-policy-status` confirms the policy is public. The account has no BPA configuration in the signed response; the bucket-level read failed and the latest recorded bucket setting was all `false`. No current masking control is established. The lab endpoint's missing-auth responses do not demonstrate that a mask is active or that an Internet caller can retrieve the data.

## Who can change the masking state

An authorized account administrator with `s3:PutAccountPublicAccessBlock` can set account-level BPA. An authorized caller with `s3:PutBucketPublicAccessBlock` can set bucket-level BPA. The captured `sec-reviewer` bucket-scoped write shows it can change bucket BPA in this lab; no evidence identifies a principal with the account-scoped permission. Setting `RestrictPublicBuckets` is a mitigation option; this review records the observed configuration and does not claim that a mask is currently active.
