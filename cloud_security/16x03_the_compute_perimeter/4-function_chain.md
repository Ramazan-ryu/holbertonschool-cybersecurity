# 4 — Function Execution Role: Identity, Executed Reach, and Code Gap

## Identity used for the probes

The execution role is `arn:aws:iam::500100200300:role/marlowe-order-processor-role`. The tested session was created by calling `sts:AssumeRole` with the instance-role credentials; STS returned:

```json
{
  "UserId": "AROAXI4CLO5WGP5N66UQA:reference-check",
  "Account": "500100200300",
  "Arn": "arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/reference-check"
}
```

This is an authoritative identity response for the controlled `reference-check` session. It establishes the identity the probes used. It does not claim that Lambda itself created a session with that name; the Lambda configuration request failed with `SignatureDoesNotMatch`.

The target-inventory probes used a fresh, separately confirmed session. `aws sts get-caller-identity` returned `UserId=AROAXI4CLO5WGP5N66UQA:evidence-targets`, account `500100200300`, and ARN `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/evidence-targets`. The bucket, queue, and secret-list outputs in the table below were returned under this exact identity.

## Executed calls outside the handler

`3-needed_calls.md` derives seven required calls from executable handler lines 22, 25, 30, 33, 36, 39, and 42. The handler contains no calls to `s3:ListAllMyBuckets`, `sqs:ListQueues`, `secretsmanager:ListSecrets`, `iam:ListUsers`, `iam:GetAccountAuthorizationDetails`, or `dynamodb:ListTables`.

The following calls were executed using the processor-role credentials. Each is outside that seven-call source-code baseline:

| Action and reproducible request | Target and authoritative response | What this proves |
|---|---|---|
| `aws s3api list-buckets --query 'Buckets[].Name' --output json` | Session `evidence-targets`; account `500100200300`; success, `["marlowe-orders-mc4e21","marlowe-cloudtrail-mc4e21"]`; audit event `618ab63a-5eef-433e-94a8-dd7f6f43fddf` at 14:16:49Z. | `s3:ListAllMyBuckets` disclosed two account bucket names. It does not prove access to their objects. |
| `aws secretsmanager list-secrets --query 'SecretList[].Name' --output json` | Session `evidence-targets`; account `500100200300`; success, `["marlowe/stripe-webhook-signing"]`; audit event `66a33200-6802-45a9-8999-a43e97b442fd` at 14:16:51Z. | `secretsmanager:ListSecrets` disclosed the named secret. This call did not retrieve its value. |
| `aws sqs list-queues --query 'QueueUrls' --output json` | Session `evidence-targets`; account `500100200300`; success, `["http://127.0.0.1:4566/500100200300/marlowe-customer-events"]`; audit event `52cf90c5-6ed2-4aa0-83eb-df3b3a8a849a` at 14:16:50Z. | `sqs:ListQueues` disclosed the customer-events queue URL; it does not by itself prove message access. |
| `aws iam list-users --query 'Users[].UserName' --output json` | Session `reference-check`; account `500100200300`; success, `["appsec-reviewer","marlowe-trail-writer","metadata-minter","function-role-key"]`; audit event `660ea880-8935-479d-848a-a81a5483eaa7` at 23:11:55Z. | `iam:ListUsers` disclosed four user names. |
| `aws iam get-account-authorization-details --filter Role --query 'RoleDetailList[].RoleName' --output json` | Session `reference-check`; account `500100200300`; success, `["marlowe-web-instance-role","marlowe-order-processor-role"]`; audit event `aa4b16c1-96c6-4609-9111-330184ece96e` at 23:11:54Z. | `iam:GetAccountAuthorizationDetails` disclosed these two role names under the tested `Role` filter; it does not prove unfiltered account-wide visibility or mutation rights. |
| `aws dynamodb list-tables --query 'TableNames' --output json` | Session `perimeter-review`; account `500100200300`; success, no table names (`[]`); audit event `84f19f20-72b8-4c41-bbee-8841427a1b96` at 21:17:53Z. | The request was accepted, but it exposed no table name and proves no table-data access. It is not counted as demonstrated resource reach. |

The earlier `perimeter-review` session also ran `aws s3api list-buckets --query 'length(Buckets)' --output text` → `2`, `aws secretsmanager list-secrets --query 'length(SecretList)' --output text` → `1`, `aws sqs list-queues --query 'length(QueueUrls)' --output text` → `1`, and `aws iam list-users --query 'length(Users)' --output text` → `4`. A subsequent `reference-check` run returned the named users and secret shown above. `iam:ListAttachedRolePolicies` and `iam:ListRolePolicies` were denied under the role session. These are observed results, not claims that every action in an IAM policy is usable.

## Measured difference from the code baseline

The source baseline is **7 required API actions across 4 services**: `secretsmanager:GetSecretValue`, `sqs:ReceiveMessage`, `s3:GetObject`, `dynamodb:GetItem`, `dynamodb:PutItem`, `s3:PutObject`, and `sqs:DeleteMessage`, each on the specific secret, queue, bucket prefixes, and table in `3-needed_calls.md`.

The probes demonstrated **5 additional accepted API actions** outside that set: `s3:ListAllMyBuckets`, `secretsmanager:ListSecrets`, `sqs:ListQueues`, `iam:ListUsers`, and filtered `iam:GetAccountAuthorizationDetails`. All five returned concrete inventory: two bucket names, one secret name, the customer-events queue URL, four user names, and two role names. These are account-inventory calls, broader in scope than the handler's named bucket, queue, secret, and table operations. `dynamodb:ListTables` returned an empty set, so it is recorded as an accepted empty query and excluded from demonstrated resource reach. This is a measured minimum of five excess API capabilities; the total number of effective actions is not asserted from these probes.

The supplied managed-policy document also contains service wildcards and other grants, but those entries are not included in the empirical count unless an API call and result above demonstrate them. The successful `GetAccountAuthorizationDetails` output included IAM role and managed-policy records, establishing read-only inspection in the tested scope. It does not establish permission to change policies. No IAM mutation succeeded; the instance role's `CreatePolicyVersion` request was denied in the audit record.

**Impact boundary:** code executing with the Lambda execution role's temporary credentials could make the required order-processing calls and the additional inventory calls proven above. The evidence supports inventory disclosure and the tested order-processing access; it does not support account-administrator access or untested service actions. This is a role-permission gap distinct from the storefront instance-role compromise in `2-instance_chain.md`.
