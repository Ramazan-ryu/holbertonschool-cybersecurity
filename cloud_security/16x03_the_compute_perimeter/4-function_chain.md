# 4 — Function Role: Measured Out-of-Code Reach

## Scope and evidence boundary

The role under review is `arn:aws:iam::500100200300:role/marlowe-order-processor-role`. The configured lab endpoint was `http://127.0.0.1:4566`; results below establish accepted calls in the Marlowe lab account model, not activity against AWS-operated infrastructure.

This report keeps two evidence sets separate:

1. **Code baseline:** seven SDK operations visible in the handler source, listed in section 1. These are source observations, not calls made during the role tests.
2. **Role test session:** six out-of-code inventory calls made with the `fn-review` assumed-role credentials, listed in section 2. No handler invocation or handler-path execution is claimed for this session.

The saved STS identity response `71-fn-identity.json` reports:

- `Arn`: `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/fn-review`
- `UserId`: `AROAXI4CLO5WGP5N66UQA:fn-review`
- `Account`: `500100200300`

The STS session record for this assumption was removed during cleanup. The identity basis available for these tests is the saved `71-fn-identity.json` response. The Lambda configuration could not be retrieved successfully, so the deployed function-to-role attachment is not independently confirmed.

### Session separation

| Evidence set | Identity evidence | Permission-call evidence used here | Treatment |
|---|---|---|---|
| `fn-review` | `71-fn-identity.json`: `GetCallerIdentity` identifies the assumed role session shown above. | `72-s3-buckets.json` through `77-ddb.json`: the six manual inventory requests in section 2. | Sole basis for the six measured excess actions. No handler invocation is claimed. |
| `fn-review2` | `92-fn2-identity.json` and `93-id-80.txt` both identify `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/fn-review2`; the JSON also reports account `500100200300` and `UserId AROAXI4CLO5WGP5N66UQA:fn-review2`. | No permission-call response from this session is included in the evidence supplied for this report. | Identity context only; it adds no demonstrated action to the measured set and is not merged with `fn-review`. |

The source-only handler operations in section 1 form a third, distinct evidence category: source inspection, not an executed session. None of the records listed above proves a Lambda invocation or independently confirms the deployed execution-role attachment.

## 1. Source-only baseline

Reading `3-needed_calls.md` and `~/marlowe-package/order_processor/handler.py` gives seven distinct provider operations in `handler(event, context)`:

| Source line | Code-derived operation | Execution point in handler |
|---|---|---|
| 22 | `secretsmanager:GetSecretValue` | Before queue receive; this statement is reached on each invocation. |
| 25 | `sqs:ReceiveMessage` | Before the message loop; this statement is reached on each invocation. |
| 30 | `s3:GetObject` | Inside the loop, for each received message after JSON decoding. |
| 33 | `dynamodb:GetItem` | Inside the loop, for each received message. |
| 36 | `dynamodb:PutItem` | Inside the loop, for each received message. |
| 39 | `s3:PutObject` | Inside the loop, for each received message after fetching the order document. |
| 42 | `sqs:DeleteMessage` | Inside the loop, for each received message after processing. |

These seven entries describe source code only. They are not the `fn-review` test calls, and this report does not claim that the handler was invoked during those tests.

## 2. Out-of-code inventory calls under `fn-review`

Each request below was issued using the `fn-review` session identified above. These are manual inventory probes outside the handler's seven source call sites. The saved output files show accepted responses; shell exit codes were not retained. An empty successful result is reported as acceptance of the action, not as evidence of returned resources.

| # | Action | Exact request | Target | Saved response and observed result |
|---|---|---|---|---|
| 1 | `s3:ListAllMyBuckets` | `aws s3api list-buckets --query 'Buckets[].Name'` | Account bucket inventory | `72-s3-buckets.json`: `marlowe-orders-mc4e21`, `marlowe-cloudtrail-mc4e21`; two names returned. No objects were read. |
| 2 | `secretsmanager:ListSecrets` | `aws secretsmanager list-secrets --query 'SecretList[].Name'` | Account secret inventory | `73-secrets.json`: `marlowe/stripe-webhook-signing`; one name returned. No secret value was read. |
| 3 | `sqs:ListQueues` | `aws sqs list-queues --query 'QueueUrls'` | Account queue inventory | `74-queues.json`: `http://127.0.0.1:4566/500100200300/marlowe-customer-events`; one queue URL returned. No message was received. |
| 4 | `iam:ListUsers` | `aws iam list-users --query 'Users[].UserName'` | Account user inventory | `75-iam-users.json`: `appsec-reviewer`, `marlowe-trail-writer`, `metadata-minter`, `function-role-key`; four names returned. |
| 5 | `iam:GetAccountAuthorizationDetails` | `aws iam get-account-authorization-details --filter Role --query 'RoleDetailList[].RoleName'` | Role inventory, `Role` filter only | `76-iam-roles.json`: `marlowe-web-instance-role`, `marlowe-order-processor-role`; two names returned. No other filter was tested. |
| 6 | `dynamodb:ListTables` | `aws dynamodb list-tables` | Tables in the configured endpoint and region | `77-ddb.json`: `TableNames: []`; successful empty response. No table names were returned. |

The exact demonstrated out-of-code set is six accepted actions: `s3:ListAllMyBuckets`, `secretsmanager:ListSecrets`, `sqs:ListQueues`, `iam:ListUsers`, `iam:GetAccountAuthorizationDetails`, and `dynamodb:ListTables`. This is not a claim that all permissions in the role were enumerated.

## 3. Measured gap

The handler source contains **7** distinct provider operations across **4** services. The `fn-review` test session accepted **6** additional, out-of-code inventory actions across **5** service families. The sets do not overlap. This is a measured lower bound of six additional accepted actions, not a statement that every role grant was tested.

No write operation was tested. In particular, there is no result here for `s3:PutObject`, `dynamodb:PutItem`, or `sqs:DeleteMessage`; their presence in the handler source does not prove this session successfully executed them. Likewise, the successful list operations do not establish administrator access or any untested permission.

## 4. Identity and conditional runtime impact

`fn-review` is an assumed-role session whose STS identity names `marlowe-order-processor-role`. The six results above prove only that this specific session was accepted for those six inventory calls at the configured lab endpoint. The separate `fn-review2` identity response names the same role but has no permission-call result included here. Neither identity response is proof that the handler was invoked or that either session was issued by a live Lambda runtime.

If the deployed order-processing function is configured with `marlowe-order-processor-role`, arbitrary code executing in that function can use the function's temporary execution-role credentials. In that conditional scenario, the tested role identity indicates a demonstrated reach of the six inventory actions in section 2. The attachment remains unverified because Lambda configuration retrieval returned `SignatureDoesNotMatch` before returning configuration. The report therefore does not assert that the deployed function configuration was confirmed or that a code execution event occurred.

The provider calls made by the handler remain the separate seven-operation source baseline in section 1. The manual inventory probes remain the separate six-action session test in section 2. No other session's results are used to increase either count.
