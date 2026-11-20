# 6 — Audit trail reconstruction

The collected records are under `trail/734112396500/CloudTrail/eu-west-1/2026/11/20/`. The relevant caller is `arn:aws:iam::734112396500:user/sec-reviewer`. Event IDs below identify the records in those gzip files. The sequence is reconstructed from CloudTrail, not from another student’s activity.

| UTC | Event | Resource / result | Event ID |
|---|---|---|---|
| 00:05:35 | `GetBucketPolicy` | Records bucket; success | `017352bb-1c18-4f02-b1d8-0bb7883dae29` |
| 00:05:38–00:05:40 | `GetBucketPolicy` | Exports and partner-share policies; success | `466deb5a-39d8-4606-8b06-0753c26f45af`, `b8f6dae4-bf8b-4766-a129-f9329972abb8` |
| 00:05:42 | `GetBucketPolicy` | Ops bucket; `NoSuchBucketPolicy` | `8c1ae8ea-ba7f-4874-b343-a0a5d4893a57` |
| 00:05:43–00:05:46 | `GetBucketPublicAccessBlock` | Records bucket; repeated HTTP 500 responses | `278a26e8-d99f-426b-baaf-c3377cd6a5bb`, `3600aac1-25c8-4f87-8844-7b32403d25fc`, `0ed1e847-c3c3-4c75-a83b-f8dee40b00e1` |
| 00:05:47 | `GetObjectAcl` | Exports rollup ACL; success, including `AllUsers` READ as shown in the CLI response | `5f537e53-f2f9-46f9-bfd5-d51b127e6014` |
| 00:05:49–00:05:51 | `GetObject` | Records, exports, and ops objects; all success as `sec-reviewer` | `c5ad1054-168a-4c70-9769-5a28bd7ee6b4`, `e7be1a6c-9a4e-4539-9566-609ada90e4a1`, `47492a44-3e73-4847-ad06-dc4ab0d3c9de` |
| 00:06:30–00:06:40 | Policy rereads, three block queries, ACL, and records `GetObject` | Policies succeed except ops `NoSuchBucketPolicy`; block queries 500; ACL and records read succeed | `bb3bb74c-3261-40ba-9b2c-d5ad1e9edad8`, `0694a7e5-3858-49f7-b3b9-c44173e66540`, `9fdae179-866c-4cd7-9635-7f074fbc5954`, `2bdac85e-c8e3-4f01-aa0d-80291ac1ea4d`, `376d71fa-408a-4296-93c4-1cba3461697a`, `d73f7ba8-025e-40da-8746-b5a361ea498a`, `53e992b6-4ffc-4ee8-b095-69637e9840dc`, `b0d48eb7-0292-40a8-b90d-326dbeb41c0f`, `80cabe2c-333e-4bdd-8266-73b87db343fc` |
| 00:07:08–00:07:16 | Policy rereads and three block queries | Policy outcomes repeat; block queries 500 | `2e2a2d09-b36b-4a6b-ab85-208ef1c6cd4e`, `461b6cef-2947-4e54-8bbb-2582e66b6f70`, `880408c6-fd2d-47e8-a7eb-f6138c7084ab`, `b3495ab0-4392-4a03-ae77-203a63cf748c`, `cd3fd34f-c420-43a8-87db-aa0225fa7f3b`, `e0ce9b71-a15e-4137-8739-8e757c6b9f44`, `1662ad09-709b-4d79-92f1-4f9fb833f697` |
| 00:08:08–00:08:43 | ACL and object reads | ACL succeeds; records, exports, and ops `GetObject` calls succeed | `3e503d25-d810-4e92-bd6b-cb6fe00b714b`, `bf44b31e-a974-400c-9020-0cf30927785a`, `c4989804-24b3-4f26-af82-888a2b339f8a`, `f13847e8-642a-412b-b0cd-0142e8c31fee` |
| 00:09:06–00:09:10 | `GetBucketPublicAccessBlock`, `GetBucketPolicy` | Block query returns 500; records policy read succeeds | `d2d7a267-64c0-4ee9-af0f-92e3cad79a0c`, `2be3095c-056b-4587-a453-c3833fe1ec48`, `1544c641-4b5e-4306-8b8d-68d0d0e66f67`, `21520c93-5635-472b-bd86-f9d224f0add8` |
| 00:09:49 | `PutBucketPublicAccessBlock` | Records bucket; all four bucket flags set false; success | `c6b65cb5-7937-49a6-b08e-4333cc7abb42` |
| 00:09:51 | `GetObject` | Records object; success after bucket-level change | `705e0d8f-4867-4003-8d57-057e6b3a41f0` |
| 00:10:25 and 00:11:57 | `GetBucketPolicy` | Partner-share policy reread; success | `d8714b6b-a6c1-4c81-978b-12e7d8be6586`, `3374186f-7b97-4d44-a916-fab655a414d2` |

## Detection answer

The high-value event to alert on is **KMS `Decrypt`**. Ordinary S3 `GetObject` reads are expected in Alderbrook’s reporting workflow; a decrypt event against `alias/alderbrook-phi`, by an unexpected principal or outside the reporting job’s normal time/source/user-agent pattern, is a stronger signal that someone is using the key to turn protected ciphertext into readable data.

The November 20 CloudTrail files currently present do not contain a `kms.amazonaws.com` `Decrypt` event. The S3 `GetObject` of the KMS-encrypted record succeeded, but the corresponding KMS event is not in the copied interval. The signed `latchkey-export` bundle is also absent from the local evidence folder, so this reconstruction is not yet cross-checked against the signed activity record.
