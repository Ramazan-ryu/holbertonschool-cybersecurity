# 4 — Function Execution Identity and Effective Access

## Identity chain

The review identity `appsec-reviewer` was denied `sts:AssumeRole` for `marlowe-order-processor-role`. The instance-role credentials did succeed in assuming it. STS returned:

```json
{
  "UserId": "AROAXI4CLO5WGP5N66UQA:perimeter-review",
  "Account": "500100200300",
  "Arn": "arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/perimeter-review"
}
```

Anything executing under the function execution role has the identity `marlowe-order-processor-role`. The web instance role is one trusted principal able to assume it, so the two identity chains intersect.

## Executed access tests

Under the function-role session, these calls returned successful responses:

| Call | Account response |
|---|---|
| `s3api list-buckets --query 'length(Buckets)'` | `2` |
| `secretsmanager list-secrets --query 'length(SecretList)'` | `1` |
| `sqs list-queues --query 'length(QueueUrls)'` | `1` |
| `iam list-users --query 'length(Users)'` | `4` |
| `dynamodb list-tables --query 'length(TableNames)'` | `0` |

The IAM result was subsequently repeated without the count filter and returned four user records. The zero-table response is a successful call with no table names returned; it does not establish access to any DynamoDB table data. The assumed role denied `iam:ListAttachedRolePolicies` and `iam:ListRolePolicies`; the review identity could inspect the role configuration and attached policy.

## Measured gap

The handler makes seven API operations across four services (`s3`, `sqs`, `dynamodb`, and `secretsmanager`), as listed in `3-needed_calls.md`. The attached managed policy `MarloweOrderProcessorExecPolicy`, default version `v1`, contains the seven code-required actions in one statement with `Resource: "*"`, and a second statement named `ExcessNobodyReviewed` with eleven additional action patterns: `s3:*`, `dynamodb:*`, `sqs:*`, `iam:ListUsers`, `iam:ListRoles`, `iam:GetAccountAuthorizationDetails`, `secretsmanager:ListSecrets`, `secretsmanager:GetSecretValue`, `kms:Decrypt`, `logs:*`, and `ses:SendEmail`. The second statement repeats `secretsmanager:GetSecretValue` and gives that action wildcard resource scope.

Five extra listing operations were executed. Four returned nonzero resource counts (2 buckets, 1 secret, 1 queue, 4 IAM users); the DynamoDB list call returned zero. This proves four concrete extra resource sets were enumerable and one extra API call returned no resources. The policy also advertises broader wildcard actions, but those untested actions are not represented here as individually proven access.
