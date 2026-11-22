# 4 — Function Execution Role: Executed Reach Beyond the Code

## Identity

All calls in this file were made under one session of the execution role:

- `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/fn-review`
- `UserId AROAXI4CLO5WGP5N66UQA:fn-review`, account `500100200300` (`71-fn-identity.json`)

The session was created with `sts:AssumeRole` from the instance identity (`70-fn-assume.json`). The endpoint is `http://127.0.0.1:4566`, which is not confirmed as AWS (see `2-instance_chain.md`). Calls from other sessions are not used as evidence in this file.

## Code baseline

`3-needed_calls.md` lists seven API calls the handler makes: `secretsmanager:GetSecretValue`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `s3:GetObject`, `s3:PutObject`, `dynamodb:GetItem`, `dynamodb:PutItem`. None of the calls below is in that list.

## Executed calls under `fn-review`

| # | Call (not in code) | Exit | Response (saved file) | Result |
|---|---|---|---|---|
| 1 | `s3api list-buckets` | 0 | `marlowe-orders-mc4e21`, `marlowe-cloudtrail-mc4e21` (`72`) | Allowed. Discloses two bucket names. |
| 2 | `secretsmanager list-secrets` | 0 | `marlowe/stripe-webhook-signing` (`73`) | Allowed. Discloses one secret name. The secret value was not read. |
| 3 | `sqs list-queues` | 0 | `http://127.0.0.1:4566/500100200300/marlowe-customer-events` (`74`) | Allowed. Discloses one queue URL. |
| 4 | `iam list-users` | 0 | `appsec-reviewer`, `marlowe-trail-writer`, `metadata-minter`, `function-role-key` (`75`) | Allowed. Discloses four user names. |
| 5 | `iam get-account-authorization-details --filter Role` | 0 | `marlowe-web-instance-role`, `marlowe-order-processor-role` (`76`) | Allowed. Discloses two role names. Only the role filter was tested. |
| 6 | `dynamodb list-tables` | 0 | `[]` (`77`) | Accepted. No table names returned. Not counted as demonstrated reach. |

## Measured excess

Five calls outside the code baseline succeeded under `fn-review`: `s3:ListAllMyBuckets`, `secretsmanager:ListSecrets`, `sqs:ListQueues`, `iam:ListUsers`, and `iam:GetAccountAuthorizationDetails` (role filter). This is a measured minimum of five excess actions. The full set of effective actions is not established.

## Measured difference: code requirements vs. demonstrated permissions

| Measure | Value | Basis |
|---|---|---|
| Actions required by code | 7 across 4 services (S3, SQS, DynamoDB, Secrets Manager) | `3-needed_calls.md` |
| Required actions demonstrated under `fn-review2` | 3 of 7: `s3:GetObject`, `sqs:ReceiveMessage`, `secretsmanager:GetSecretValue` | Exit 0 in `80`, `81`, `82`; identity in `93-id-80.txt` |
| Required action inconclusive | `dynamodb:GetItem` | `ResourceNotFoundException`: table `marlowe-orders` absent from this endpoint (`list-tables` returned `[]`). Neither allowed nor denied is shown. |
| Required actions not tested (writes, need written owner approval) | `s3:PutObject`, `dynamodb:PutItem`, `sqs:DeleteMessage` | Not executed |
| Excess actions demonstrated under `fn-review` | 5 (exact set below) | Exit 0 in `72`–`76` |

Exact excess set (not in code, exit 0 under `fn-review`):

1. `s3:ListAllMyBuckets` (`72`)
2. `secretsmanager:ListSecrets` (`73`)
3. `sqs:ListQueues` (`74`)
4. `iam:ListUsers` (`75`)
5. `iam:GetAccountAuthorizationDetails`, `--filter Role` (`76`)

Difference = the 5 excess actions. The required set is only partly demonstrated: 3 of 7 with executed results, 1 inconclusive because the table is absent from the test environment, and 3 writes not tested. Wildcards and service-wide grants in the attached policy are not counted.

## Impact boundary

Code running with this role's temporary credentials can make the seven code-path calls (not all of them were executed in this file; only the excess inventory calls above are tested here) and the five inventory calls above. The evidence supports account inventory disclosure. It does not support administrator access or untested service actions.

This role gap is separate from the storefront instance-role compromise in `2-instance_chain.md`.
