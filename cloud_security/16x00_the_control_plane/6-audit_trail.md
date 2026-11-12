# 6 — What You Left Behind

## How to locate this work

The caller is consistently `arn:aws:iam::418274639051:user/svc-audit-intake`, principal ID `AIDA59C2ACB2A2DB59159`, access key ID `AKIAWCL7F3AINTAKE001`. The records identify `sourceIPAddress: 127.0.0.1`, region `eu-west-1`, and an AWS CLI user agent. Locate the records in the S3 CloudTrail archive:

- Bucket: `copperline-cloudtrail-cl7f3a`
- Account/region prefix: `AWSLogs/418274639051/CloudTrail/eu-west-1/`
- Work-session date prefix: `2026/11/12/`
- Search key: `userIdentity.arn` or `userIdentity.principalId` above; each event below is pinpointed by its `eventID`.

The operator downloaded the 11/12 objects to the lab shell, expanded their `Records` arrays, and filtered by the identity fields. The filtered JSON was emitted there as `evidence/cloudtrail-own-events.json`; the archive remains in the account's S3 bucket and each event below is directly searchable by `eventID`. The downloaded raw files are not part of this repository checkout. Most records have `responseElements: null`; where no `errorCode` is recorded, the event record indicates the API did not return a CloudTrail error. API response evidence in the project evidence files provides returned data where needed.

## 1. Identity and permission-source discovery — read-only reconnaissance

From 18:38 to 18:46 UTC, the records show identity confirmation, direct/inline attachment discovery, group membership and policy-document review. The actions include `GetCallerIdentity`, `GetUser`, `ListAttachedUserPolicies`, `ListUserPolicies`, `GetUserPolicy`, `ListGroupsForUser`, `ListAttachedGroupPolicies`, `ListGroupPolicies`, `GetPolicy`, and `GetPolicyVersion` for the original managed policy documents.

Event IDs: `0ee33feb-0084-4972-a21c-d4dbf26a15dc` (GetCallerIdentity); `ed6e2f02-262c-4d77-bf23-fa6aa72b4858` (GetUser); `0393b318-86af-4b63-be4f-5f395bb6d8b5` (ListAttachedUserPolicies); `2ee61711-542e-4f70-bef0-089f9fb6f513` (ListUserPolicies); `e286a8a8-2a2f-4dea-af85-0511094cf3ca` (ListGroupsForUser); `e12d80e8-9c46-4650-bda0-ccc4a85460f0` (GetUserPolicy); `79fbdcdf-d1b3-40a5-adfc-7f014324a1e3` (ListAttachedGroupPolicies); `e575665a-84b6-4d10-9859-4a7127afaf7d` (ListGroupPolicies); `259c7b14-675a-4845-99a1-650b72e0ff2a` and `57ed012f-9c86-4875-8987-055c9f0edfeb` (GetPolicy); `3f4e248e-304c-45a1-8228-cdcfd0a09c62` and `6bdf27e2-4cae-49c2-a9fc-4cdc9bfdce6b` (GetPolicyVersion); `40a6e750-fa19-4680-ba3b-0e3356349ce3`, `1db343a8-e826-43c9-9e00-9bfc032dc41a`, `4e86c488-8f24-4b38-92bc-1c799a56950a`, and `3be2e8e7-49f5-4aad-bc03-e7131f28` (first SQS, Secrets Manager, and KMS inventory calls).

A second concentrated inventory pass occurred from 19:06 to 19:09 UTC, including repeated identity/policy enumeration plus SQS, Secrets Manager and KMS inventory. Its event IDs include `fc24212a-2b9f-41d8-b30f-e6f9284f99e5`, `f05eaf76-5765-4a91-9775-57162bd0e466`, `2e447a5c-0538-47c3-aa46-178d55e7bf0a`, `aaac15e5-b192-4300-ab25-405645ce49f8`, `2c0de791-63f3-4ef2-8371-10e027657530`, `3075211f-179e-442a-a0ce-e9b3b51967ae`, `bae008b5-e8f9-4fc1-bc9e-44ce5f665633`, `1f1f0c55-750e-4708-b230-731c58d6675e`, `a979e591-4b38-4edc-8316-d212f5245e6e`, `548c7a1a-86d1-4c21-9eb0-9f524ce20a17`, `ade0ef73-8c09-4513-a607-1e50c91e810a`, `d8b8f893-275a-4062-a2f3-a4345489e000`, `3657435a-6744-43f8-919b-210a62282c74`, `1ab04e5a-05fa-4d12-9ed8-a922f657da81`, `bb5e4359-070b-4531-ba5a-9040f14ac360`, `8a39ec09-2cb5-4725-8540-b5d06a22b73b`, `c5f62253-584c-4b96-b64a-5063acc8a502`, `a1148a67-77b2-45c8-9bf3-db4e0e7f3105`, `ce1eea8d-2b33-4be7-859e-4c6d1f996db8`, `0b312f47-f7ae-4925-8c00-f39e793915a7`, `01173100-878b-4f10-b22f-0700b5f2206f`, `2ecdbd96-eae4-4e85-9a2f-859ab16a02ba`, `8bc30b3a-9f62-48ed-8d89-531b568b744d`, `1d0a5561-e8de-4e57-b18c-6b4e60d9a444`, `43b581c3-eab8-4148-b41a-455e4e26ef84`, `61f96f9b-f039-4a25-b04f-6493a8f34db6`, `34dfe2a4-8ec3-4b01-a301-b3de721022c5`, `75708e38-51ef-45f5-a0a5-09b0265b3e1d`, `a5273648-bf06-4fb6-aa5b-b6418fed884b`, `77d15dc7-0882-49ea-b625-54f75fd10aad`, and `221b8061-457d-435a-a73f-e166c039afa1`.

## 2. S3 discovery and metadata access

The earlier phase queried bucket names, listed objects in freight, ops-logs and migration-scratch, and fetched object metadata. This moved beyond policy-document review: the identity's activity exposed the undocumented scratch bucket's keys and showed metadata access to its objects. The calls did not retrieve those scratch object bodies.

Relevant event IDs: `e3125477-e5a5-4c0b-9ef8-14083b6c1e18` (ListBuckets); `dc61c92b-4df2-4623-ada9-a5ee33bc02dc`, `390a2f05-1f39-4ffc-a2c6-d8bbb9d9a6c1`, and `ff81ebcc-4245-48eb-bb0c-cc0a76183e51` (ListObjects on scratch, freight, and ops-logs); `33ef6646-4149-4048-a7a2-49d437c577e0`, `6fa7f83d-61c8-458e-b29e-9d72880a3851`, and `886e4ef6-68fc-4174-9fa4-b9ba6ac446f0` (HeadObject on scratch notes, freight manifest, and ops log); `08baffe9-5292-4fbb-8d2f-52e6f76bad4b` (scratch HeadObject); `051c4659-0c73-4be6-961e-9c84f978556d`, `73172844-f0f9-40e2-b962-b985439bb8c2`, `7fe84b6a-8f83-4af6-b8d9-17a45453af44`, `f1b14e6e-d648-4285-ab9c-f65cb3dc4e40`, `b277dc19-5115-40ab-b0a6-3690c8ac6fe4`, `03b9b124-dd7c-4833-a447-d13b686381ca`, `fd21865b-0d71-453c-8e0a-82b3ded6211b`, and `8e997367-5e32-4d94-b59f-6127296ea27f` (bucket encryption/Public Access Block checks); `af2c0d3e-5103-4a67-bf45-16ccd52e4d72`, `64e5b518-795f-4f74-9d65-8fdff94ab6ad`, and `0bb4376c-6809-4854-9662-4571db8f6e1d` (scratch policy status, ACL, and policy checks).

The records show the work's progression: first broad read/list access to scratch, then later denied scratch listing after the managed policy was narrowed. The first post-change denial was `ListObjects` on `copperline-migration-scratch-cl7f3a`, event `1ddfd9c0-f36e-485e-ab12-c52d22d878bb` at 19:33:05Z (`errorCode: AccessDenied`, `errorMessage: Access Denied`). The same verification phase successfully listed ops logs, event `541591c7-7181-429d-915f-7149476c18b3` at 19:33:03Z.

### Repeat checks immediately before changing the policy

The audit trail also shows three identity/bucket re-check passes before the successful v2 change. These repeated calls matter: they show the scratch bucket was still listable immediately before remediation, and they provide the before/after comparison.

- 19:11 UTC: `GetCallerIdentity` `4a9e8208-ffab-4289-8532-2779c6755942`; `ListObjects` scratch `78033657-bbfd-478d-bd9e-cc0338694f1e`; `ListObjects` ops-logs `b574b248-351a-4a80-91d5-3f06d14b6f7a`; `HeadObject` ops log `50f6fb0f-ba5e-4f2c-9ad5-d901c49c2378`; `GetPolicy` `58068ee5-90ac-4ef8-be03-6f667c080243`.
- 19:23 UTC: `GetCallerIdentity` events `140c188e-fecd-4080-aaf2-2d544fd132ca` and `4fc38a8f-03b2-4abd-bd3d-71ac717f012e`; `ListObjects` scratch `531674e9-2df6-4666-9c05-b172c533860b`; `ListObjects` ops-logs `745c7e4e-1708-4edd-9559-57869cf4265b`; `HeadObject` ops log `fe45d82e-a369-4463-8f01-4ad79d63d90d`; `GetPolicy` `5400d0b5-f6b7-4f1e-af02-1a62e27b1369`.
- 19:27 UTC, before the rejected update: `GetCallerIdentity` `58065de0-b9a4-452f-846f-8443e514fc12`; malformed `CreatePolicyVersion` `83cdff59-9356-4f2c-a314-2033dea3746a`; `GetCallerIdentity` `9fd96638-e5d8-4c31-af80-f048736f6e66`; `ListObjects` scratch `4cef03ba-678f-4fad-8fad-330bfe46767a`; `ListObjects` ops-logs `4ac6d74d-3b41-49fb-98e4-4542f4eb3b69`; `HeadObject` ops log `785bd23f-64cb-4af4-939e-5ff20271255a`; and `GetPolicy` `831e42b0-948e-4d9b-9408-afc8fa0e3367`.

## 3. Failed probes and failed first remediation attempt

At 19:10:10Z, an EC2 enumeration probe was refused: `DescribeInstances`, event `1ef4b18c-3187-4997-aecc-1f0b87e7dda3`, `errorCode: AccessDenied`. It establishes the refusal for that call, not absence of EC2 resources.

At 19:27:43Z, a `CreatePolicyVersion` request for `CopperlineOpsLogsReadOnly` reached IAM with a malformed document containing two concatenated policy documents. It failed with `MalformedPolicyDocument`; event `83cdff59-9356-4f2c-a314-2033dea3746a`. Three `accessanalyzer:ValidatePolicy` attempts returned HTTP 500, each recorded as `eventName: Unknown`: `e4cfd1df-8b6b-4a2b-8e17-07ee51b2225f`, `1fac7764-103a-4888-81a4-ad053acac34e`, and `dcd27939-ac32-43f0-8910-33c34c5c6223`.

The later CLI invocation without required arguments and the local relative-file loading failure did not reach AWS, so those shell errors do not appear as API events. The CloudTrail record distinguishes the API-rejected malformed request from local CLI failures.

## 4. Successful change and verification

At 19:32:05Z, `CreatePolicyVersion` succeeded for `CopperlineOpsLogsReadOnly`, with `setAsDefault: true`; event `c1ad11aa-b83e-44ee-924e-f6c079686cc0`. A subsequent `GetPolicy` call at 19:32:12Z is event `f6c5d0b9-293f-4761-bb02-be7a8fa998f5`. The response and default version `v2` are independently recorded in `evidence/iam-get-policy-version-v2.json` and `evidence/remediation-v2-session.txt`.

The verification calls are `ListObjects` success on ops-logs (`541591c7-7181-429d-915f-7149476c18b3`) and `ListObjects` denied on migration-scratch (`1ddfd9c0-f36e-485e-ab12-c52d22d878bb`). This is the clearest audit-trail evidence that the policy change altered the principal's effective access.

## 5. Post-change content-read and organization-boundary probes

At 20:01:07Z, 20:01:24Z, and 20:01:32Z, three `GetObject` data events targeted `copperline-ops-logs-cl7f3a/access/2026-08.log`: `0a8405af-c08f-42e9-9682-a0402b883df2`, `7117b8e8-5bb3-4a3d-a1c6-a30d2ec55f80`, and `0b0ebbd7-bda6-40db-a04a-dcf5d370d4b1`. Each was a post-v2 read request; the operator used `--range bytes=0-0`, and the S3 response reported one byte returned from a 3,569-byte object. The repeated reads are visible, even though they were limited to one byte each.

At 20:01:17Z and 20:01:18Z, attempts to inspect organization controls were denied: `ListPoliciesForTarget` event `f13a4a79-b300-485e-99db-18262ffe771d` and `ListParents` event `431c98dc-353b-4ba2-9f29-894cb091ae88`, both `AccessDeniedException`. These records explain why SCP presence could not be established; they do not show whether an SCP is attached.

## 6. Ordinary operational events seen alongside this work

The 10 November archive contains activity from other callers. The filtered summary found: `copperline-ci` made six successful `ListBuckets` and two `PutObject` calls; `copperline-backup` made two successful S3 `GetObject` calls; `copperline-batch-runner` made 12 successful S3 `GetObject` and 17 successful SQS `ReceiveMessage` calls; and one successful `AssumeRole` event had no caller ARN/principal in the summary. Representative event IDs from the summary are `bbd08759-05c4-45ee-bc99-9ef649c17590`, `9092ec8d-9de6-4618-977a-9eb486fad77d`, `f0db698d-a260-4728-9053-a5f8dec6fa18`, `3ab5f9ba-be51-4146-bd5e-9c96b99a4552`, `fc735de5-8a95-4bcf-8e2a-337fe901f428`, and `85328ceb-8bf9-42cc-9e28-972b9555a0f1`. These are separated from the engagement because their `userIdentity` values differ from `svc-audit-intake`.

The filter over the retrieved 12 November records returned only this IAM user; the separate query for other callers produced no rows for that date. The 10 November records show what ordinary automation looked like beside the engagement: recurring bucket/object reads and queue receives, plus CI bucket listing and writes.

## What the record says

The work was not invisible. CloudTrail recorded read-only discovery calls, object metadata access, denied probes, the malformed policy update, the failed policy validation attempts, the successful policy version change, and post-change reads. In particular, the S3 data events expose object-level metadata and content access as separate events from management-plane calls. An investigator can reconstruct both the broad-scope discovery and the corrective change from the caller, timestamp, resource parameters, outcome fields, and event IDs above.
