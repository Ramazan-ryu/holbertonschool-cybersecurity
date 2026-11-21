# 1 — Private, or lucky

## Finding: the records bucket policy independently grants public access

**Risk-bearing layer:** bucket policy statement `LegacyClinicSync` on `alderbrook-phi-records-ab7f3a`.

The exact statement has `Effect: Allow`, `Principal: "*"`, and grants `s3:ListBucket` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a` plus `s3:GetObject` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a/*`. Standing alone, this policy allows an unauthenticated internet caller to list the bucket and read any object key, including `records/patients-2026.ndjson`. The successful `get-bucket-policy` response is recorded as CloudTrail event `017352bb-1c18-4f02-b1d8-0bb7883dae29`.

## Masking control: not in place

The handover states that account-level S3 Block Public Access is enabled. The signed account-level request (`GET /v20180820/configuration/publicAccessBlock`, `x-amz-account-id: 734112396500`) returned HTTP 404 `NoSuchPublicAccessBlockConfiguration` (request ID `G5MK2jRLvaAC4XsYhOt01JiiyuQVFKC3jCRAvazro7RQcU6K3Msx`). That response means no account-level configuration is set, so `RestrictPublicBuckets` is not active at account scope. The handover and the observed account state conflict, and the observed state is the one this review relies on.

The bucket-level block on `alderbrook-phi-records-ab7f3a` was set to all four flags `false` by `sec-reviewer` at `2026-11-20T00:09:49Z` (CloudTrail `c6b65cb5-7937-49a6-b08e-4333cc7abb42`). No mask is therefore in place at either level.

The unsigned 403s from `http://127.0.0.1:4566` are lab-endpoint results. The cause of those denials is not isolated: no account-level or bucket-level mask explains them, and the KMS and endpoint-evaluation explanations are untested. The 403s do not show that the bucket is private.

**Verdict:** the policy `LegacyClinicSync` grants public list and read by configuration. No verified mask suppresses it. The lab denial is unexplained and must not be read as protection.

## Who can change the mask

Re-enabling protection requires S3 Control `PutPublicAccessBlock` for account `734112396500` (`s3:PutAccountPublicAccessBlock`), or `PutBucketPublicAccessBlock` on `alderbrook-phi-records-ab7f3a`. The `sec-reviewer` identity made a bucket-scoped change at `2026-11-20T00:09:49Z`. The evidence does not identify which Alderbrook role holds the account-scoped permission: `sec-reviewer` was denied `iam:SimulatePrincipalPolicy` and `iam:ListRoles`, so no role was enumerated.

**Finding belongs to:** `LegacyClinicSync`, the policy carrying the broad grant. No verified mask is in place. The account-level setting is not configured (signed 404 `NoSuchPublicAccessBlockConfiguration`, request ID `G5MK2jRLvaAC4XsYhOt01JiiyuQVFKC3jCRAvazro7RQcU6K3Msx`), and the bucket-level flags are all `false`. The handover's statement that account-level block is enabled conflicts with that response, and this review relies on the response.

**Network scope:** the VM's LAN address `192.168.1.94` is on interface `enp0s8`. `ss -ltnp` shows the lab endpoint listening on `127.0.0.1:4566` only, and requests to `192.168.1.94:4566` failed to connect. All 403 results in this review came from `127.0.0.1`. They describe the lab endpoint, not reachability from another host or the Internet.
