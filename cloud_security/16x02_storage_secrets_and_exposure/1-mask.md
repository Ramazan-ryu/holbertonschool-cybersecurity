# 1 — Private, or lucky

## Finding: the records bucket policy independently grants public access

**Risk-bearing layer:** bucket policy statement `LegacyClinicSync` on `alderbrook-phi-records-ab7f3a`.

The exact statement has `Effect: Allow`, `Principal: "*"`, and grants `s3:ListBucket` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a` plus `s3:GetObject` on `arn:aws:s3:::alderbrook-phi-records-ab7f3a/*`. Standing alone, this policy allows an unauthenticated internet caller to list the bucket and read any object key, including `records/patients-2026.ndjson`. The successful `get-bucket-policy` response is recorded as CloudTrail event `017352bb-1c18-4f02-b1d8-0bb7883dae29`.

## Masking control: not in place

The handover states that account-level S3 Block Public Access is enabled. The signed account-level request (`GET /v20180820/configuration/publicAccessBlock`, `x-amz-account-id: 734112396500`) returned HTTP 404 `NoSuchPublicAccessBlockConfiguration` (request ID `G5MK2jRLvaAC4XsYhOt01JiiyuQVFKC3jCRAvazro7RQcU6K3Msx`). That response means no account-level configuration is set, so `RestrictPublicBuckets` is not active at account scope. The handover and the observed account state conflict, and the observed state is the one this review relies on.

The bucket-level block on `alderbrook-phi-records-ab7f3a` was set to all four flags `false` by `sec-reviewer` at `2026-11-20T00:09:49Z` (CloudTrail `c6b65cb5-7937-49a6-b08e-4333cc7abb42`). No mask is therefore in place at either level.

The unsigned 403s from `http://127.0.0.1:4566` are lab-endpoint results. The cause of those denials is not isolated: no account-level or bucket-level mask explains them, and the KMS and endpoint-evaluation explanations are untested. The 403s do not show that the bucket is private.

**Verdict:** the policy `LegacyClinicSync` grants public list and read by configuration. No verified mask suppresses it. The lab denial is unexplained and must not be read as protection.

## Who can unmask the policy

The ordinary administrative action is S3 Control `PutPublicAccessBlock` for account `734112396500`, requiring `s3:PutAccountPublicAccessBlock` on that account. An Alderbrook platform-administration identity or automation role with that account-scoped permission can disable `RestrictPublicBuckets`; the permission is listed in the [AWS S3 Control API reference](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_PutPublicAccessBlock.html). That routine control-plane update would make the already-present wildcard grant effective without any bucket-policy edit.

The evidence does **not** identify a particular Alderbrook admin role or prove which identity currently holds the account-scoped action: `sec-reviewer` is denied `iam:SimulatePrincipalPolicy` and `iam:ListRoles`, and its observed `PutBucketPublicAccessBlock` was bucket-scoped, not account-scoped. I therefore identify the principal class and exact required permission, not an unobserved role name.

**Finding belongs to:** `LegacyClinicSync`, the policy carrying the broad grant. **Mitigating factor:** the handover reports account-level Block Public Access, specifically `RestrictPublicBuckets` as the relevant control for this public policy. The lab endpoint’s unsigned-denial tests are consistent with that mask, but a successful account-level configuration read is still needed to verify the flag itself. The VM reports `192.168.1.94/24` on interface `enp0s8`; this is a private LAN address and does not establish public Internet reachability. The reported 403s were from `127.0.0.1`. The `ss -ltnp` output shows the service listening on `127.0.0.1:4566` only; requests to `192.168.1.94:4566` failed to connect. This explains the interface probe and establishes that this lab endpoint was not listening on the VM’s LAN interface. No request from a second LAN host or public Internet client was provided. Disabling that mitigation makes the existing policy effective; no policy change is needed.
