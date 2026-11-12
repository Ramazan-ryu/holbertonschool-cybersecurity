# 1 — Identity Map

The account's own IAM API shows three permission sources associated with `svc-audit-intake`: one attached managed policy, one inline user policy, and membership in one group. The policy documents have not yet been retrieved, so their actual statements and contributions remain unassessed.

## Identity confirmation

Command: `aws iam get-user`

Response:

```json
{
    "User": {
        "Path": "/",
        "UserName": "svc-audit-intake",
        "UserId": "AIDA59C2ACB2A2DB59159",
        "Arn": "arn:aws:iam::418274639051:user/svc-audit-intake",
        "CreateDate": "2026-11-12T18:14:23.603457+00:00"
    }
}
```

## Attached managed policy

Command: `aws iam list-attached-user-policies --user-name svc-audit-intake`

Response:

```json
{
    "AttachedPolicies": [
        {
            "PolicyName": "CopperlineOpsLogsReadOnly",
            "PolicyArn": "arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly"
        }
    ]
}
```

This is an attached managed policy. Its name suggests log access, but its JSON has not been inspected and the name is not evidence of its permissions.

## Inline user policy

Command: `aws iam list-user-policies --user-name svc-audit-intake`

Response:

```json
{
    "PolicyNames": [
        "intake-ops-access"
    ]
}
```

This is a policy written directly on the user. Its statements and contribution are not yet known.

## Group membership

Command: `aws iam list-groups-for-user --user-name svc-audit-intake`

Response:

```json
{
    "Groups": [
        {
            "Path": "/",
            "GroupName": "migration-readers",
            "GroupId": "AGPAEACD5DB3AB745338B",
            "Arn": "arn:aws:iam::418274639051:group/migration-readers",
            "CreateDate": "2026-11-12T18:14:23.509300+00:00"
        }
    ]
}
```

The user inherits any applicable permissions attached to group `migration-readers` or written inline on that group. Those policies have not yet been enumerated, so this source is incomplete.

## Policy documents and contributions

The managed policy metadata call was `aws iam get-policy --policy-arn arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly`; it returned default version `v1`, attachment count `1`. The document was retrieved with `aws iam get-policy-version --policy-arn arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly --version-id v1` and is preserved in `evidence/iam-get-policy-version.json`.

Its `ReadOpsLogs` statement allows `s3:GetObject` and `s3:ListBucket` on the operations log bucket and its objects. Its `IntakeSupport` statement additionally allows every action matching `s3:Get*` and `s3:List*` on every resource (`"Resource": "*"`). The latter is broader than the handover description; its effective reach still requires API validation.

The inline document was returned by `aws iam get-user-policy --user-name svc-audit-intake --policy-name intake-ops-access` and is preserved in `evidence/iam-get-user-policy.json`. It grants self-inspection and IAM directory/policy/group read calls, inventory calls for SQS, Secrets Manager, and KMS, and S3 read access to the CloudTrail bucket. The `MaintainIntakePolicy` statement grants `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, and `iam:DeletePolicyVersion` on `CopperlineOpsLogsReadOnly`. This is a policy-change capability, not merely read-only intake access. Actual ability and impact must be confirmed by safe, reversible API tests; no destructive action is justified.

The group calls were `aws iam list-attached-group-policies --group-name migration-readers` and `aws iam list-group-policies --group-name migration-readers`. They returned attached managed policy `MigrationReadOnly` and no inline policies. The attached group's JSON has not yet been retrieved, so its contribution remains undetermined.

### Group managed policy: `MigrationReadOnly`

The policy metadata call returned default version `v1` and attachment count `1`. The document was retrieved with `aws iam get-policy-version --policy-arn arn:aws:iam::418274639051:policy/MigrationReadOnly --version-id v1`; the response is preserved in `evidence/migration-readonly-policy.json`.

Its `MigrationDescribe` statement allows `secretsmanager:DescribeSecret`, `kms:DescribeKey`, `kms:GetKeyPolicy`, `sqs:GetQueueAttributes`, and `sqs:GetQueueUrl` on `Resource: "*"`. This is the group's contribution. It allows describing resources and reading KMS key policy, but does not itself grant secret values or queue message access. Whether each call succeeds still needs confirmation against the account API.

### Complete source list found so far

The identity has one attached user managed policy (`CopperlineOpsLogsReadOnly`), one inline user policy (`intake-ops-access`), and group membership in `migration-readers`, which contributes attached policy `MigrationReadOnly` and no inline group policies. No other permission source has been established by the calls recorded here. Permissions boundary and organization-level controls have not yet been checked; effective permissions must account for any such restrictions if present.
