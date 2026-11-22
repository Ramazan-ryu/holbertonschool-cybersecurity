# 4 — Function Execution Role: Excess Permissions Under One Identity

## Identity

All excess-permission calls in this file were made under one session of the execution role:

- `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/fn-review`
- `UserId AROAXI4CLO5WGP5N66UQA:fn-review`, account `500100200300` (`71-fn-identity.json`)

The session was created with `sts:AssumeRole` from the instance identity (`70-fn-assume.json`, since deleted). The endpoint is `http://127.0.0.1:4566`, which is not confirmed as AWS (see `2-instance_chain.md`). No other session is used as evidence for the excess-permission measurement.

## Code baseline

`3-needed_calls.md` lists seven API actions the handler performs: `secretsmanager:GetSecretValue`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `s3:GetObject`, `s3:PutObject`, `dynamodb:GetItem`, `dynamodb:PutItem`. Each excess action below is absent from this list.

## Excess actions: proven under `fn-review`

Scope note: each call's target is stated in the table. These are account-level inventory calls with no single resource ARN as target. A request ID is not available because CloudTrail is not accessible to the reviewer profile; the provider's response is the evidence.

| # | Excess action | Reproducible call | Target | Authoritative response (saved file) | Absent from code list |
|---|---|---|---|---|---|
| 1 | `s3:ListAllMyBuckets` | `aws --profile fn s3api list-buckets --query 'Buckets[].Name' --output json` | Account `500100200300`, all buckets | Exit 0; `marlowe-orders-mc4e21`, `marlowe-cloudtrail-mc4e21` (`72`) | Yes |
| 2 | `secretsmanager:ListSecrets` | `aws --profile fn secretsmanager list-secrets --query 'SecretList[].Name' --output json` | Account, all secrets in `eu-west-1` | Exit 0; `marlowe/stripe-webhook-signing` (`73`). Secret value not read. | Yes |
| 3 | `sqs:ListQueues` | `aws --profile fn sqs list-queues --query 'QueueUrls' --output json` | Account, all queues | Exit 0; `http://127.0.0.1:4566/500100200300/marlowe-customer-events` (`74`) | Yes |
| 4 | `iam:ListUsers` | `aws --profile fn iam list-users --query 'Users[].UserName' --output json` | Account, all IAM users | Exit 0; `appsec-reviewer`, `marlowe-trail-writer`, `metadata-minter`, `function-role-key` (`75`) | Yes |
| 5 | `iam:GetAccountAuthorizationDetails` (`--filter Role`) | `aws --profile fn iam get-account-authorization-details --filter Role --query 'RoleDetailList[].RoleName' --output json` | Account, all roles | Exit 0; `marlowe-web-instance-role`, `marlowe-order-processor-role` (`76`) | Yes |

Tested but not counted:

- `dynamodb:ListTables`: exit 0, returned `[]` (`77`). An accepted call with no result is not counted as demonstrated permission.

## Measured difference

| Measure | Value |
|---|---|
| Actions required by code | 7 |
| Excess actions proven under `fn-review` | 5 (exact set above) |
| Excess actions in the attached policy but not tested | Not counted (no executed call) |

The difference is the 5 actions above. This measurement covers only the actions in the table. No other action was tested under `fn-review`. Wildcards and service-wide grants in the attached policy are not counted because no executed call shows them.

## Code-path actions: status (separate from excess)

These are not excess. They are recorded separately for the code baseline. They ran under session `fn-review2` of the same role:

- `s3:GetObject`, `sqs:ReceiveMessage`, `secretsmanager:GetSecretValue`: exit 0 (`80`, `81`, `82`; identity in `93-id-80.txt`).
- `dynamodb:GetItem`: `ResourceNotFoundException`. Table `marlowe-orders` is absent from this endpoint, and `list-tables` returned `[]`. Result inconclusive.
- `s3:PutObject`, `dynamodb:PutItem`, `sqs:DeleteMessage`: not executed. They change customer data and need written owner approval.

## Impact boundary

Under the execution role, the five actions above are demonstrated. They disclose account inventory: bucket names, a secret name, a queue URL, user names, and role names. The evidence does not show administrator access or any action not listed in this file.

This role gap is separate from the storefront instance-role compromise in `2-instance_chain.md`.
