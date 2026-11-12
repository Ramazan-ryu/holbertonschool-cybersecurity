# Current-session IAM and permission probe outputs

Session identity for these calls: `arn:aws:iam::418274639051:user/svc-audit-intake`.

## `aws iam get-user`

```json
{
    "User": {
        "Path": "/",
        "UserName": "svc-audit-intake",
        "UserId": "AIDA59C2ACB2A2DB59159",
        "Arn": "arn:aws:iam::418274639051:user/svc-audit-intake",
        "CreateDate": "2026-11-12T18:51:23.955462+00:00"
    }
}
```

## `aws iam list-attached-user-policies --user-name svc-audit-intake`

```json
{"AttachedPolicies":[{"PolicyName":"CopperlineOpsLogsReadOnly","PolicyArn":"arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly"}]}
```

## `aws iam list-user-policies --user-name svc-audit-intake`

```json
{"PolicyNames":["intake-ops-access"]}
```

## `aws iam list-groups-for-user --user-name svc-audit-intake`

```json
{"Groups":[{"Path":"/","GroupName":"migration-readers","GroupId":"AGPAEACD5DB3AB745338B","Arn":"arn:aws:iam::418274639051:group/migration-readers","CreateDate":"2026-11-12T18:51:23.879194+00:00"}]}
```

## `aws iam list-access-keys --user-name svc-audit-intake`

```json
{"AccessKeyMetadata":[{"UserName":"svc-audit-intake","AccessKeyId":"AKIAWCL7F3AINTAKE001","Status":"Active","CreateDate":"2026-11-12T18:51:24.004692+00:00"}]}
```

## `aws iam list-attached-group-policies --group-name migration-readers`

```json
{"AttachedPolicies":[{"PolicyName":"MigrationReadOnly","PolicyArn":"arn:aws:iam::418274639051:policy/MigrationReadOnly"}]}
```

## `aws iam list-group-policies --group-name migration-readers`

```json
{"PolicyNames":[]}
```

## `aws iam get-policy --policy-arn arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly`

```json
{"Policy":{"PolicyName":"CopperlineOpsLogsReadOnly","PolicyId":"AY78XTBUI6R0B0X91TLO7","Arn":"arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly","Path":"/","DefaultVersionId":"v1","AttachmentCount":1,"IsAttachable":true,"CreateDate":"2026-11-12T18:51:23.832464+00:00","UpdateDate":"2026-11-12T18:51:23.832469+00:00","Tags":[]}}
```

## `aws iam list-policy-versions --policy-arn arn:aws:iam::418274639051:policy/CopperlineOpsLogsReadOnly`

The account returned one version, `v1`, with `IsDefaultVersion: true`. Its document is preserved verbatim in `iam-get-policy-version.json`.

## `aws iam get-policy --policy-arn arn:aws:iam::418274639051:policy/MigrationReadOnly`

```json
{"Policy":{"PolicyName":"MigrationReadOnly","PolicyId":"APV25VSQRWM6U1NOQFIUW","Arn":"arn:aws:iam::418274639051:policy/MigrationReadOnly","Path":"/","DefaultVersionId":"v1","AttachmentCount":1,"IsAttachable":true,"CreateDate":"2026-11-12T18:51:23.844725+00:00","UpdateDate":"2026-11-12T18:51:23.844728+00:00"}}
```

## `aws iam list-policy-versions --policy-arn arn:aws:iam::418274639051:policy/MigrationReadOnly`

The account returned one version, `v1`, with `IsDefaultVersion: true`. Its document is preserved verbatim in `migration-readonly-policy.json`.

## Directory calls

- `aws iam list-users` succeeded and returned `cl-platform-admin`, `svc-audit-intake`, `copperline-ci`, `dpearson`, and `rmalik`.
- `aws iam list-groups` succeeded and returned `migration-readers` and `dispatch-staff`.
- `aws iam list-policies` succeeded and returned `CopperlineDeploy`, `CopperlineOpsLogsReadOnly`, `CopperlinePlatformAdmin`, and `MigrationReadOnly`.
- `aws iam list-account-aliases` returned `copperline-logistics`.

The complete responses for these directory calls were supplied by the operator in the current conversation. The task's per-permission report should quote the individual response from that transcript or preserve each response separately in `evidence/`.
