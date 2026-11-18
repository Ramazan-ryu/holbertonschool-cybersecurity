# 5 — Close It, and Prove It Is Closed

## Identity and Remediation Context

All pre-remediation baseline tests, the policy version update, and all post-remediation verification tests were executed in account `418274639051` (`eu-west-1`) using the exact same Copperline IAM principal and credentials:

- **ARN:** `arn:aws:iam::418274639051:user/svc-audit-intake`
- **UserId:** `AIDA59C2ACB2A2DB59159`
- **Account:** `418274639051`

Caller identity confirmation is preserved in `5-remediation/evidence/0-caller-identity.json`.

---

## 1. The Over-Grant Removed and the Narrowed Policy

### Policy Source and Statement Removed

In Task 1 and Task 2, the customer-managed policy `arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly` (default version `v1`, preserved in `5-remediation/evidence/iam-get-policy-version-v1.json`) was attached directly to `svc-audit-intake`. Version `v1` contained two statements:

1. `Sid: ReadOpsLogs` — `Effect: Allow` for `["s3:GetObject", "s3:ListBucket"]` scoped specifically to `["arn:aws:s3:::copperline-ops-logs-cl7f3a", "arn:aws:s3:::copperline-ops-logs-cl7f3a/*"]`.
2. `Sid: IntakeSupport` — `Effect: Allow` for action patterns `["s3:Get*", "s3:List*"]` on resource `"*"`.

The `IntakeSupport` statement was the unintended over-grant. Because it granted `s3:Get*` and `s3:List*` across `"*"`, it allowed `svc-audit-intake` to execute `s3:ListBucket` on `arn:aws:s3:::copperline-migration-scratch-cl7f3a` and `s3:GetObject` on `arn:aws:s3:::copperline-migration-scratch-cl7f3a/*` (such as `arn:aws:s3:::copperline-migration-scratch-cl7f3a/export/pre-cutover-dump.json`).

Neither the user's inline policy (`intake-ops-access`, which grants S3 access only to `arn:aws:s3:::copperline-cloudtrail-cl7f3a` and `arn:aws:s3:::copperline-cloudtrail-cl7f3a/*` via `AuditTrailRead`) nor the inherited group policy (`MigrationReadOnly` on group `migration-readers`, which grants only `secretsmanager:DescribeSecret`, `kms:DescribeKey`, `kms:GetKeyPolicy`, `sqs:GetQueueAttributes`, and `sqs:GetQueueUrl`) contains any wildcard or inheritance path granting `s3:ListBucket` or `s3:GetObject` on `copperline-migration-scratch-cl7f3a`.

### Narrowed Policy Document (`v2`)

To remove the unintended `s3:Get*` and `s3:List*` grant on `"*"` while preserving `svc-audit-intake`'s legitimate operational job capability (listing and reading objects in `copperline-ops-logs-cl7f3a`), the `IntakeSupport` statement was removed in its entirety.

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

### Applying the Policy Change Before Verification

Using the `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` permissions granted by `MaintainIntakePolicy` in `intake-ops-access`, `svc-audit-intake` published version `v2` as the active default policy version prior to running the post-remediation tests:

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

The live active default policy document was confirmed via `aws iam get-policy-version --policy-arn arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly --version-id v2` and is stored in `5-remediation/evidence/iam-get-policy-version-v2.json` and `5-remediation/evidence/remediation-v2-session.txt`.

---

## 2. Proof of Closure: Formerly Allowed Dangerous Call Is Now Refused

### Exact Comparison of Pre-Remediation Baseline vs. Post-Remediation Refusal

| Attribute | Pre-Remediation Baseline (Under `v1`) | Post-Remediation Verification (Under `v2`) |
|---|---|---|
| **Principal** | `arn:aws:iam::418274639051:user/svc-audit-intake` | `arn:aws:iam::418274639051:user/svc-audit-intake` |
| **IAM Action** | `s3:ListBucket` | `s3:ListBucket` |
| **Target Resource ARN** | `arn:aws:s3:::copperline-migration-scratch-cl7f3a` | `arn:aws:s3:::copperline-migration-scratch-cl7f3a` |
| **Exact Command** | `aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5` | `aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5` |
| **Result** | **ALLOW** (returned `export/notes.txt` and `export/pre-cutover-dump.json`) | **DENY** (`AccessDenied`: not authorized to perform `s3:ListBucket`) |
| **Raw Evidence File** | `5-remediation/evidence/pre-remediation-scratch-objects.json` | `5-remediation/evidence/post-remediation-scratch-list-denied.txt` |

### Pre-Remediation Baseline Execution (Before Policy Change, Under `v1`)

Before remediation, `svc-audit-intake` ran the following command evaluating `s3:ListBucket` on `arn:aws:s3:::copperline-migration-scratch-cl7f3a`:

```bash
aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5
```

**Actual pre-remediation provider response (`5-remediation/evidence/pre-remediation-scratch-objects.json`):**

```json
{
    "IsTruncated": false,
    "Contents": [
        {
            "Key": "export/notes.txt",
            "Size": 278,
            "StorageClass": "STANDARD"
        },
        {
            "Key": "export/pre-cutover-dump.json",
            "Size": 476,
            "StorageClass": "STANDARD"
        }
    ],
    "Name": "copperline-migration-scratch-cl7f3a",
    "Prefix": "",
    "MaxKeys": 5,
    "KeyCount": 2
}
```

### Post-Remediation Rerun of the Exact Same Dangerous Call (After Policy Change, Under `v2`)

Immediately after `CopperlineOpsLogsReadOnly` version `v2` became the active default version, the **exact same command, action (`s3:ListBucket`), and resource scope (`arn:aws:s3:::copperline-migration-scratch-cl7f3a`)** was rerun by `arn:aws:iam::418274639051:user/svc-audit-intake`:

**Exact command rerun after policy change:**

```bash
aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5
```

**Actual post-remediation provider denial response (`5-remediation/evidence/post-remediation-scratch-list-denied.txt` and `5-remediation/evidence/remediation-v2-session.txt`):**

```text
An error occurred (AccessDenied) when calling the ListObjectsV2 operation: User: arn:aws:iam::418274639051:user/svc-audit-intake is not authorized to perform: s3:ListBucket on resource: "arn:aws:s3:::copperline-migration-scratch-cl7f3a" because no identity-based policy allows the s3:ListBucket action
```

This proves an explicit IAM authorization denial (`AccessDenied`) on the exact same call (`aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5`), action (`s3:ListBucket`), and target resource (`arn:aws:s3:::copperline-migration-scratch-cl7f3a`) that previously succeeded under `v1`.

---

## 3. Proof of Least Privilege: Required Legitimate Call Still Succeeds

### Operational Requirement for `svc-audit-intake`

The documented operational role of `svc-audit-intake` and its attached policy `CopperlineOpsLogsReadOnly` (`Sid: ReadOpsLogs`) is to allow the audit intake service to list (`s3:ListBucket`) and read (`s3:GetObject`) operational access logs in `arn:aws:s3:::copperline-ops-logs-cl7f3a` and `arn:aws:s3:::copperline-ops-logs-cl7f3a/*`.

### Post-Remediation Verification — Listing Operations Logs (`s3:ListBucket`)

Executed **after** `v2` became the active default policy version, using the same `svc-audit-intake` credentials in the same session and region (`eu-west-1`):

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

Executed **after** `v2` became the active default policy version by the same principal `arn:aws:iam::418274639051:user/svc-audit-intake` to verify `s3:GetObject` on `arn:aws:s3:::copperline-ops-logs-cl7f3a/access/2026-08.log`:

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

All raw responses referenced above are stored in `5-remediation/evidence/` and tie to the same principal (`arn:aws:iam::418274639051:user/svc-audit-intake`), account (`418274639051`), and post-remediation policy state (`CopperlineOpsLogsReadOnly` version `v2`):

- `5-remediation/evidence/0-caller-identity.json` — Raw `aws sts get-caller-identity` output confirming principal `arn:aws:iam::418274639051:user/svc-audit-intake`.
- `5-remediation/evidence/iam-get-policy-version-v1.json` — Pre-remediation `v1` policy document containing the unintended `IntakeSupport` (`s3:Get*`, `s3:List*` on `*`) statement.
- `5-remediation/evidence/create-policy-version-v2.json` — Raw response from `aws iam create-policy-version --set-as-default` activating `v2`.
- `5-remediation/evidence/iam-get-policy-version-v2.json` — Post-remediation `v2` policy document confirming only `ReadOpsLogs` remains.
- `5-remediation/evidence/pre-remediation-scratch-objects.json` — Pre-remediation baseline output from `aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5`.
- `5-remediation/evidence/post-remediation-scratch-list-denied.txt` — Post-remediation raw `AccessDenied` output from rerunning the exact command `aws s3api list-objects-v2 --bucket copperline-migration-scratch-cl7f3a --max-keys 5`.
- `5-remediation/evidence/post-remediation-ops-logs-list.json` — Post-remediation raw successful `list-objects-v2` response on `copperline-ops-logs-cl7f3a`.
- `5-remediation/evidence/ops-logs-get-object-range.json` — Post-remediation raw successful `get-object` response on `copperline-ops-logs-cl7f3a/access/2026-08.log`.
- `5-remediation/evidence/remediation-v2-session.txt` — Complete chronological CLI transcript showing policy update to `v2`, verification of active default version `v2`, denied scratch bucket call (`--max-keys 5`), and successful ops-logs calls.
