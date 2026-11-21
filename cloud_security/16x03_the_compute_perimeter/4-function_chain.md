# 4 — Function Execution Role: Identity, Measured Access, and Gap

## Principal and identity evidence

The execution-role principal is `arn:aws:iam::500100200300:role/marlowe-order-processor-role` in account `500100200300`. The role trust response names `lambda.amazonaws.com` as a trusted service principal for `sts:AssumeRole`. It also names the web instance role and the `function-role-key` user as trusted principals. The appsec review user itself was denied `sts:AssumeRole`; the web instance role's temporary credentials succeeded.

The STS response for the tested assumed-role session was:

```json
{
  "UserId": "AROAXI4CLO5WGP5N66UQA:perimeter-review",
  "Account": "500100200300",
  "Arn": "arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/perimeter-review"
}
```

This identifies the exact principal and session used for the following execution-role permission probes: assumed role `marlowe-order-processor-role`, account `500100200300`, session `perimeter-review`, stable role ID `AROAXI4CLO5WGP5N66UQA`. It is a direct STS provider response, not an identity inferred from the function name. Lambda's configuration API did not return successfully, so this is a controlled role-session test, not a claim that a Lambda invocation generated this particular session name.

A later fresh session was independently confirmed by `aws sts get-caller-identity`:

```json
{
  "UserId": "AROAXI4CLO5WGP5N66UQA:reference-check",
  "Account": "500100200300",
  "Arn": "arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/reference-check"
}
```

The additional permission tests below were run under this exact `reference-check` session.

## Observed effective access

The first five calls were made with the `perimeter-review` role credentials; the final three were rerun with the fresh `reference-check` session. Each returned a successful service response:

| Session | Reproducible call | Account response | Meaning and limit |
|---|---|---|---|
| `perimeter-review` | `aws s3api list-buckets --query 'length(Buckets)' --output text` | `2` | The role could enumerate two S3 buckets. The captured response retained the count, not bucket names. |
| `perimeter-review` | `aws secretsmanager list-secrets --query 'length(SecretList)' --output text` | `1` | The role could enumerate one secret. The captured response retained the count, not its name. |
| `perimeter-review` | `aws sqs list-queues --query 'length(QueueUrls)' --output text` | `1` | The role could enumerate one queue. The captured response retained the count, not its URL. |
| `perimeter-review` | `aws iam list-users --query 'length(Users)' --output text` | `4` | The role could enumerate four IAM users; a subsequent unfiltered call returned the four user records. |
| `perimeter-review` | `aws dynamodb list-tables --query 'length(TableNames)' --output text` | `0` | The API call succeeded but returned no table names; this is not proof of table data access. |
| `reference-check` | `aws iam get-account-authorization-details --filter Role --query 'RoleDetailList[].RoleName' --output json` | `[` `"marlowe-web-instance-role"`, `"marlowe-order-processor-role"` `]` | The role could enumerate the two IAM role records returned by the filtered account authorization query. This proves IAM authorization-detail read access, not policy mutation. |
| `reference-check` | `aws iam list-users --query 'Users[].UserName' --output json` | `[` `"appsec-reviewer"`, `"marlowe-trail-writer"`, `"metadata-minter"`, `"function-role-key"` `]` | Confirms the four enumerated IAM user names. |
| `reference-check` | `aws secretsmanager list-secrets --query 'SecretList[].Name' --output json` | `[` `"marlowe/stripe-webhook-signing"` `]` | Confirms the one enumerable secret name; the secret value was not requested. |

Additional IAM role-policy introspection calls made with this role, `iam:ListAttachedRolePolicies` and `iam:ListRolePolicies`, returned `AccessDenied`. The read-only review identity independently returned the attached policy name and policy document, as recorded below. No S3, queue, or secret policy document was retrieved in this exercise; the successful service calls establish effective access for the listed operations, not an exhaustive permission inventory for every account resource.

## Policy and scope checked

The account's IAM responses identify one attached managed policy, `MarloweOrderProcessorExecPolicy` (`arn:aws:iam::500100200300:policy/MarloweOrderProcessorExecPolicy`), default version `v1`, and no inline role policies. `get-role` returned no `PermissionsBoundary` field. The successful `AssumeRole` request supplied only a role ARN and session name; no session policy was passed. The policy document contained two `Allow` statements, both with `Resource: "*"`:

1. Seven code-needed actions: `s3:GetObject`, `s3:PutObject`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `dynamodb:GetItem`, `dynamodb:PutItem`, and `secretsmanager:GetSecretValue`.
2. The statement `ExcessNobodyReviewed`: `s3:*`, `dynamodb:*`, `sqs:*`, `iam:ListUsers`, `iam:ListRoles`, `iam:GetAccountAuthorizationDetails`, `secretsmanager:ListSecrets`, `secretsmanager:GetSecretValue`, `kms:Decrypt`, `logs:*`, and `ses:SendEmail`.

These statements show the identity-policy grant surface. Effective access still depends on resource policies and service-specific conditions; where tested, the service's successful or denied response below is authoritative for that request. The account evidence does not establish that every action in the policy is usable against every resource, so only executed results are counted as proven reach.

## Measured code-to-role gap

The handler needs **7 API actions across 4 services**, on the resource ARNs/prefixes in `3-needed_calls.md`. The excess statement has **11 policy entries**, each with `Resource: "*"`: `s3:*`, `dynamodb:*`, `sqs:*`, three IAM enumeration actions, two Secrets Manager actions (one repeats a required action), `kms:Decrypt`, `logs:*`, and `ses:SendEmail`. The three service wildcards subsume the six required S3/SQS/DynamoDB actions while also granting every other action in those services; their excess action count cannot be reduced to a finite number from this policy text. Six distinct API operations outside the handler's code-derived set were executed: S3 bucket listing returned 2, secret listing returned 1, queue listing returned 1, IAM user listing returned 4, IAM authorization details returned 2 role names, and DynamoDB table listing returned success with zero names. Thus proven unnecessary capabilities include S3, SQS, Secrets Manager, and IAM enumeration; the zero-result DynamoDB call proves API authorization but no table reach. `iam:GetAccountAuthorizationDetails` was tested with the `Role` filter only and exposed the two named role records; unfiltered account-wide authorization-detail visibility has not yet been tested. The remaining policy actions are policy-text evidence, not individually executed capability claims.

**Runtime impact:** code executing under the Lambda execution role receives temporary credentials for this same role principal. The tests prove that role can enumerate four IAM users and enumerate S3, Secrets Manager, and SQS resources, in addition to the seven code-required operations. `iam:ListAttachedRolePolicies` and `iam:ListRolePolicies` were denied. This finding is the role's demonstrated cloud reach and wildcard grant scope, separate from the instance-identity finding in `2-instance_chain.md`.
