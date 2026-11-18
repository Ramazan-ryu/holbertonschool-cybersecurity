# 5 — Close It, and Prove It Is Closed

## Identity and Remediation Context

All discovery, policy modification, and post-remediation verification calls were executed in account `418274639051` (`eu-west-1`) using the same Copperline IAM principal:

- **ARN:** `arn:aws:iam::418274639051:user/svc-audit-intake`
- **UserId:** `AIDA59C2ACB2A2DB59159`
- **Account:** `418274639051`

Caller identity confirmation is preserved in `5-remediation/evidence/0-caller-identity.json`.

---

## 1. The Over-Grant Removed and the Narrowed Policy

### Policy Source and Statement Removed

During baseline analysis (Task 1 and Task 2), the customer-managed policy `arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly` (default version `v1`, preserved in `5-remediation/evidence/iam-get-policy-version-v1.json`) was attached directly to `svc-audit-intake`. Version `v1` contained two statements:

1. `Sid: ReadOpsLogs` — `Effect: Allow` for `["s3:GetObject", "s3:ListBucket"]` scoped specifically to `["arn:aws:s3:::copperline-ops-logs-cl7f3a", "arn:aws:s3:::copperline-ops-logs-cl7f3a/*"]`.
2. `Sid: IntakeSupport` — `Effect: Allow` for action patterns `["s3:Get*", "s3:List*"]` on resource `"*"`.

The `IntakeSupport` statement was the unintended over-grant. Because it granted `s3:Get*` and `s3:List*` across `*`, it allowed `svc-audit-intake` to list and inspect objects inside the undocumented migration scratch bucket (`arn:aws:s3:::copperline-migration-scratch-cl7f3a` and `arn:aws:s3:::copperline-migration-scratch-cl7f3a/*`), as well as enumerate bucket settings across the account.

Neither the user's inline policy (`intake-ops-access`, which grants S3 access only to `arn:aws:s3:::copperline-cloudtrail-cl7f3a` and `arn:aws:s3:::copperline-cloudtrail-cl7f3a/*` via `AuditTrailRead`) nor the inherited group policy (`MigrationReadOnly` on group `migration-readers`, which grants only `secretsmanager:DescribeSecret`, `kms:DescribeKey`, `kms:GetKeyPolicy`, `sqs:GetQueueAttributes`, and `sqs:GetQueueUrl`) contains any wildcard or inheritance path granting `s3:ListBucket` or `s3:GetObject` on `copperline-migration-scratch-cl7f3a`.

### Narrowed Policy Document (`v2`)

To remove the unintended `s3:Get*` and `s3:List*` grant on `"*"` while preserving `svc-audit-intake`'s legitimate operational role (reading and listing the operations logs bucket `copperline-ops-logs-cl7f3a`), the `IntakeSupport` statement was removed in its entirety.

The complete narrowed policy document (`5-remediation/narrowed-policy.json`, applied as default version `v2` of `arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly`) is:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOpsLogs",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::copperline-ops-logs-cl7f3a",
        "arn:aws:s3:::copperline-ops-logs-cl7f3a/*"
      ]
    }
  ]
}
```

### Applying the Policy Change

Using the `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` permissions granted by `MaintainIntakePolicy` in `intake-ops-access`, `svc-audit-intake` published version `v2` as the new default policy version before executing the validation tests below:

**Command executed:**

```bash
aws iam create-policy-version \
  --policy-arn arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly \
  --policy-document file://5-remediation/narrowed-policy.json \
  --set-as-default
```

**Actual provider response (`5-remediation/evidence/create-policy-version-v2.json`):**

```json
{
    "PolicyVersion": {
        "VersionId": "v2",
        "IsDefaultVersion": true,
        "CreateDate": "2026-11-04T00:15:00+00:00"
    }
}
```

The live active default policy document was verified via `aws iam get-policy-version --policy-arn arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly --version-id v2` and is stored in `5-remediation/evidence/iam-get-policy-version-v2.json` and `5-remediation/evidence/remediation-v2-session.txt`.

---

## 2. Proof of Closure: Formerly Allowed Dangerous Call Is Now Refused

### Pre-Remediation Baseline (Under `v1`)

Before remediation, `svc-audit-intake` executed `s3:ListBucket` against the undocumented scratch bucket `arn:aws:s3:::copperline-migration-scratch-cl7f3a`:

```bash
aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5
```

Under `v1`, this call succeeded and returned keys `export/notes.txt` (278 bytes) and `export/pre-cutover-dump.json` (476 bytes) (baseline response preserved in `5-remediation/evidence/pre-remediation-scratch-objects.json`).

### Post-Remediation Verification (Under `v2`)

Immediately after `CopperlineOpsLogsReadOnly` version `v2` was set as the default version, the exact same `s3:ListBucket` operation against the same target resource (`arn:aws:s3:::copperline-migration-scratch-cl7f3a`) was re-run by the same principal (`arn:aws:iam::418274639051:user/svc-audit-intake`):

**Command executed after policy change:**

```bash
aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 1
```

**Actual provider denial response (`5-remediation/evidence/post-remediation-scratch-list-denied.txt` and `5-remediation/evidence/remediation-v2-session.txt`):**

```text
An error occurred (AccessDenied) when calling the ListObjectsV2 operation: User: arn:aws:iam::418274639051:user/svc-audit-intake is not authorized to perform: s3:ListBucket on resource: "arn:aws:s3:::copperline-migration-scratch-cl7f3a" because no identity-based policy allows the s3:ListBucket action
```

This confirms an explicit IAM authorization refusal (`AccessDenied`) on `s3:ListBucket` for `arn:aws:s3:::copperline-migration-scratch-cl7f3a` due to the removal of `IntakeSupport`.

---

## 3. Proof of Least Privilege: Required Legitimate Call Still Succeeds

### Operational Requirement for `svc-audit-intake`

The documented operational purpose of `svc-audit-intake` and its attached policy `CopperlineOpsLogsReadOnly` (`Sid: ReadOpsLogs`) is to allow the audit intake service to list (`s3:ListBucket`) and retrieve (`s3:GetObject`) operational access logs stored in `arn:aws:s3:::copperline-ops-logs-cl7f3a` and `arn:aws:s3:::copperline-ops-logs-cl7f3a/*`.

### Post-Remediation Verification — Listing Operations Logs (`s3:ListBucket`)

Executed after `v2` became the active default policy version, using the same `svc-audit-intake` credentials in the same session:

**Command executed after policy change:**

```bash
aws s3api list-objects-v2 --bucket copperline-ops-logs-cl7f3a --max-keys 1
```

**Actual successful provider response (`5-remediation/evidence/post-remediation-ops-logs-list.json` and `5-remediation/evidence/remediation-v2-session.txt`):**

```json
{
    "IsTruncated": false,
    "Contents": [
        {
            "Key": "access/2026-08.log",
            "LastModified": "2026-11-04T00:00:00+00:00",
            "ETag": "\"e0886c0082f9f0cc64e7e430b91f550a\"",
            "Size": 3569,
            "StorageClass": "STANDARD"
        }
    ],
    "Name": "copperline-ops-logs-cl7f3a",
    "Prefix": "",
    "MaxKeys": 1,
    "EncodingType": "url",
    "KeyCount": 1
}
```

### Post-Remediation Verification — Reading an Operations Log Object (`s3:GetObject`)

To verify that both actions in `ReadOpsLogs` (`s3:ListBucket` and `s3:GetObject`) remain functional after `v2` activation, a 1-byte ranged `GetObject` request was also executed against `arn:aws:s3:::copperline-ops-logs-cl7f3a/access/2026-08.log`:

**Command executed after policy change:**

```bash
aws s3api get-object \
  --bucket copperline-ops-logs-cl7f3a \
  --key access/2026-08.log \
  --range bytes=0-0 \
  /tmp/copperline-getobject-probe.bin
```

**Actual successful provider response (`5-remediation/evidence/ops-logs-get-object-range.json`):**

```json
{
    "AcceptRanges": "bytes",
    "ContentRange": "bytes 0-0/3569",
    "ContentLength": 1,
    "ETag": "\"e0886c0082f9f0cc64e7e430b91f550a\"",
    "ContentType": "text/plain",
    "Metadata": {}
}
```

---

## 4. Evidence Manifest (`5-remediation/evidence/`)

All raw responses referenced above are committed in `5-remediation/evidence/` and tie to the same principal (`arn:aws:iam::418274639051:user/svc-audit-intake`) and post-remediation policy state (`CopperlineOpsLogsReadOnly` version `v2`):

- `5-remediation/evidence/0-caller-identity.json` — Raw `aws sts get-caller-identity` output confirming principal `arn:aws:iam::418274639051:user/svc-audit-intake`.
- `5-remediation/evidence/iam-get-policy-version-v1.json` — Pre-remediation `v1` policy document showing the unintended `IntakeSupport` (`s3:Get*`, `s3:List*` on `*`) statement.
- `5-remediation/evidence/create-policy-version-v2.json` — Raw response from `aws iam create-policy-version --set-as-default` activating `v2`.
- `5-remediation/evidence/iam-get-policy-version-v2.json` — Post-remediation `v2` policy document confirming only `ReadOpsLogs` remains.
- `5-remediation/evidence/pre-remediation-scratch-objects.json` — Baseline pre-remediation `list-objects-v2` output showing that `copperline-migration-scratch-cl7f3a` was formerly accessible.
- `5-remediation/evidence/post-remediation-scratch-list-denied.txt` — Post-remediation raw `AccessDenied` response when calling `list-objects-v2` on `copperline-migration-scratch-cl7f3a`.
- `5-remediation/evidence/post-remediation-ops-logs-list.json` — Post-remediation raw successful `list-objects-v2` response on `copperline-ops-logs-cl7f3a`.
- `5-remediation/evidence/ops-logs-get-object-range.json` — Post-remediation raw successful `get-object` response on `copperline-ops-logs-cl7f3a/access/2026-08.log`.
- `5-remediation/evidence/remediation-v2-session.txt` — Combined chronological CLI session transcript showing policy update to `v2`, verification of active default version `v2`, denied scratch bucket call, and successful ops-logs calls.
