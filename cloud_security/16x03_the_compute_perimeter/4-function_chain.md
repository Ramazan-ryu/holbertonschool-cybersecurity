# 4 — Function Execution Role: Demonstrated Excess and Code Gap

## Identity

The execution role is `arn:aws:iam::500100200300:role/marlowe-order-processor-role`.

Section 2 calls were made under this session:

- `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/fn-review`
- `UserId AROAXI4CLO5WGP5N66UQA:fn-review`, account `500100200300` (`71-fn-identity.json`)

The STS session record for this assumption was removed during cleanup and is not retained. The identity is supported by `71-fn-identity.json` only.

The endpoint is the configured lab account endpoint `http://127.0.0.1:4566`; these results establish reach in the Marlowe lab account model, not independent activity in AWS-operated infrastructure.

## 1. Code baseline

`3-needed_calls.md` records seven provider operations directly observed in `handler.py` lines 22, 25, 30, 33, 36, 39 and 42:

1. `secretsmanager:GetSecretValue`
2. `sqs:ReceiveMessage`
3. `sqs:DeleteMessage`
4. `s3:GetObject`
5. `s3:PutObject`
6. `dynamodb:GetItem`
7. `dynamodb:PutItem`

The handler source contains no call to any action in section 2. That comparison is based on the executable call sites in `3-needed_calls.md`.

## 2. Measured excess: demonstrated actions

Each row is one executed call under the assumed role session `fn-review` (`71-fn-identity.json`). The saved response shows an accepted result and no service error. Exit status was not recorded. The responses are evidence of calls made with this session against the configured lab account endpoint; they are not presented as independent AWS-provider records.

| # | Action | Request | Target | Saved response | Result |
|---|---|---|---|---|---|
| 1 | `s3:ListAllMyBuckets` | `aws s3api list-buckets --query 'Buckets[].Name'` | account buckets | `72-s3-buckets.json`: `marlowe-orders-mc4e21`, `marlowe-cloudtrail-mc4e21` | Two bucket names returned. No object was read. |
| 2 | `secretsmanager:ListSecrets` | `aws secretsmanager list-secrets --query 'SecretList[].Name'` | account secrets | `73-secrets.json`: `marlowe/stripe-webhook-signing` | One secret name returned. The secret value was not read. |
| 3 | `sqs:ListQueues` | `aws sqs list-queues --query 'QueueUrls'` | account queues | `74-queues.json`: `http://127.0.0.1:4566/500100200300/marlowe-customer-events` | One queue URL returned. No message was received. |
| 4 | `iam:ListUsers` | `aws iam list-users --query 'Users[].UserName'` | account users | `75-iam-users.json`: `appsec-reviewer`, `marlowe-trail-writer`, `metadata-minter`, `function-role-key` | Four user names returned. |
| 5 | `iam:GetAccountAuthorizationDetails` | `aws iam get-account-authorization-details --filter Role --query 'RoleDetailList[].RoleName'` | roles, role filter | `76-iam-roles.json`: `marlowe-web-instance-role`, `marlowe-order-processor-role` | Two role names returned. Only the `Role` filter was tested. |
| 6 | `dynamodb:ListTables` | `aws dynamodb list-tables` | DynamoDB tables in the configured endpoint/region | `77-ddb.json`: `TableNames: []` | Successful empty response; no table names were disclosed. It still demonstrates that the list action was accepted. |

## 3. Measured difference

Code-observed set (from section 1): 7 named actions.

Demonstrated excess set (from section 2): 6 named actions:
`s3:ListAllMyBuckets`, `secretsmanager:ListSecrets`, `sqs:ListQueues`, `iam:ListUsers`, `iam:GetAccountAuthorizationDetails`, and `dynamodb:ListTables`.

The two sets do not overlap. The measured difference is six additional accepted actions across five service families, compared with seven code-observed actions across four service families. This is the demonstrated set, not an inventory of every effective permission.

The six additional accepted actions are the measured out-of-source gap. This measurement does not assert that the handler exercised these operations, and it does not claim to enumerate every action the role could permit.

## 4. Workload identity and demonstrated reach

If arbitrary code executes inside a function configured with `marlowe-order-processor-role`, it can use that function's temporary execution-role credentials. The deployment attachment was not independently verified because Lambda configuration retrieval failed; therefore this consequence is conditional on that role being the deployed execution role. The tested `fn-review` session provides an STS identity for the role, and the six successful responses in section 2 show the specific inventory actions accepted under that session at the lab endpoint. They establish no administrator access, write access, or untested actions. No result from a second session is included in that measured reach. Handler operations are listed independently in `3-needed_calls.md`.

## 5. Limits

- Exit status was not recorded for the section 2 calls. The output shows success, but no exit code was saved. Section 2 therefore states what the output contains, not what the exit code was.
- The STS session record for `fn-review` is not retained.
- Writes (`PutObject`, `PutItem`, `DeleteMessage`) were not executed.

## 6. Impact boundary

The six section 2 responses demonstrate that the `fn-review` assumed-role session was accepted for those specific inventory operations at the lab account endpoint. They do not establish administrator access, write access, or every action the role may permit. No result from a separate code-path session is used to expand this measured set.

This role gap is separate from the storefront instance-role compromise in `2-instance_chain.md`.
