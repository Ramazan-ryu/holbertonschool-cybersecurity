# 4 — Function Execution Role: Identity, Granted Permissions, Demonstrated Reach

## Identity

The execution role is `arn:aws:iam::500100200300:role/marlowe-order-processor-role`.

Excess inventory calls (section 3) were made under one session of this role:

- `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/fn-review`
- `UserId AROAXI4CLO5WGP5N66UQA:fn-review`, account `500100200300` (`71-fn-identity.json`)

The STS session record for this assumption was removed during cleanup and is not retained. The identity is supported by `71-fn-identity.json` only.

Code-path calls (section 4) were made under a second session:

- `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/fn-review2` (`92-fn2-identity.json`, `93-id-80.txt`)

The endpoint is `http://127.0.0.1:4566`, which is not confirmed as AWS (see `2-instance_chain.md`). Calls from other sessions, including the instance-role session that results in `84-fn-recheck.json`, are not used as evidence in this file.

## 1. Code baseline

`3-needed_calls.md` derives seven required API actions from `handler.py` lines 22, 25, 30, 33, 36, 39 and 42:

| # | Action | Resource in code |
|---|---|---|
| 1 | `secretsmanager:GetSecretValue` | the signing secret |
| 2 | `sqs:ReceiveMessage` | the customer queue |
| 3 | `sqs:DeleteMessage` | the customer queue |
| 4 | `s3:GetObject` | `marlowe-orders-mc4e21`, prefix `orders/` |
| 5 | `s3:PutObject` | `marlowe-orders-mc4e21`, prefix `processed/` |
| 6 | `dynamodb:GetItem` | table `marlowe-orders` |
| 7 | `dynamodb:PutItem` | table `marlowe-orders` |

The handler contains no call to `s3:ListAllMyBuckets`, `sqs:ListQueues`, `secretsmanager:ListSecrets`, `iam:ListUsers`, `iam:GetAccountAuthorizationDetails`, or `dynamodb:ListTables`.

## 2. Granted permissions (policy text)

Source: `MarloweOrderProcessorExecPolicy`, default version `v1`, read with the reviewer profile (`105-proc-policy.json`, `106-proc-policy-version.json`). The role has this one managed policy attached and no inline policy (`101`, `102`). Both statements use `"Resource": "*"`.

| Measure | Value | Basis |
|---|---|---|
| Required by code | 7 actions across 4 services | Section 1 |
| Explicit non-code actions granted | 6: `iam:ListUsers`, `iam:ListRoles`, `iam:GetAccountAuthorizationDetails`, `secretsmanager:ListSecrets`, `kms:Decrypt`, `ses:SendEmail` | `106`, statement 2 |
| Service wildcards granted | `s3:*`, `dynamodb:*`, `sqs:*`, `logs:*` | `106`, statement 2 |
| Duplicate grant | `secretsmanager:GetSecretValue` appears in both statements | `106` |
| Resource scope of all grants | `*`. The code needs specific bucket prefixes, one queue, one secret and one table. | `106`, section 1 |

Policy text is recorded as a grant, not as proof of reach. Only calls listed in sections 3 and 4 count as demonstrated.

Version check: `iam:ListPolicyVersions` is denied to the reviewer profile. The default version is taken from `get-policy` (`105`), and the document is read from `106`. The full list of policy versions was not checked.

## 3. Demonstrated excess (not in code)

Calls run under `fn-review` (`71`). Saved output shows success. Exit codes were not saved with the files, and the files share one batch timestamp (20:22). The saved content contains no error text.

| # | Action (not in code) | Target and output | Saved file | Result |
|---|---|---|---|---|
| 1 | `s3:ListAllMyBuckets` | `marlowe-orders-mc4e21`, `marlowe-cloudtrail-mc4e21` | `72-s3-buckets.json` | Allowed. Discloses two bucket names. Covered by `s3:*`. |
| 2 | `secretsmanager:ListSecrets` | `marlowe/stripe-webhook-signing` | `73-secrets.json` | Allowed. Discloses one secret name. The secret value was not read. Explicit grant. |
| 3 | `sqs:ListQueues` | `http://127.0.0.1:4566/500100200300/marlowe-customer-events` | `74-queues.json` | Allowed. Discloses one queue URL. Covered by `sqs:*`. |
| 4 | `iam:ListUsers` | `appsec-reviewer`, `marlowe-trail-writer`, `metadata-minter`, `function-role-key` | `75-iam-users.json` | Allowed. Discloses four user names. Explicit grant. |
| 5 | `iam:GetAccountAuthorizationDetails` (`--filter Role`) | `marlowe-web-instance-role`, `marlowe-order-processor-role` | `76-iam-roles.json` | Allowed. Discloses two role names. Only the role filter was tested. Explicit grant. |

`dynamodb:ListTables` returned `[]` (`77-ddb.json`). It is an accepted empty result and is not counted.

Every demonstrated excess action is also in the granted set (section 2), so the two lists agree.

## 4. Code-path calls under `fn-review2`

| Required action | Call | Result | Saved file | Status |
|---|---|---|---|---|
| `s3:GetObject` | `s3api get-object` on an order key | Success | `80-s3-get.json` | Demonstrated |
| `sqs:ReceiveMessage` | `sqs receive-message` on the customer queue | Success | `81-sqs-receive.json` | Demonstrated. Visibility timeout was 0, so the message was not deleted. |
| `secretsmanager:GetSecretValue` | `secretsmanager get-secret-value` | Success | `82-secret.json` | Demonstrated. The secret value is not recorded in this file. |
| `dynamodb:GetItem` | `dynamodb get-item` on table `marlowe-orders` | `ResourceNotFoundException` | `83-ddb-get.json` | Inconclusive. The table is absent from this endpoint (`77`), so neither allowed nor denied is shown. |
| `s3:PutObject` | Not run | — | — | Not tested. Writes require written owner approval. |
| `dynamodb:PutItem` | Not run | — | — | Not tested. Writes require written owner approval. |
| `sqs:DeleteMessage` | Not run | — | — | Not tested. Writes require written owner approval. |

Demonstrated: 3 of 7 required actions. Inconclusive: 1 of 7. Not tested: 3 of 7.

## 5. Measured difference

| Measure | Value |
|---|---|
| Actions required by code | 7 |
| Required actions demonstrated under `fn-review2` | 3 (`s3:GetObject`, `sqs:ReceiveMessage`, `secretsmanager:GetSecretValue`) |
| Required actions inconclusive | 1 (`dynamodb:GetItem`) |
| Required actions not tested | 3 (`s3:PutObject`, `dynamodb:PutItem`, `sqs:DeleteMessage`) |
| Excess actions demonstrated under `fn-review` | 5 (section 3) |
| Granted but not demonstrated | `iam:ListRoles`, `kms:Decrypt`, `ses:SendEmail`, `logs:*`, and the untested remainder of `s3:*`, `dynamodb:*`, `sqs:*` |

The difference between what the code needs and what the policy grants is 6 explicit non-code actions, 4 service wildcards and `Resource: "*"` on every statement. The measured difference, based on demonstrated calls, is the 5 excess actions in section 3.

`kms:Decrypt` may be needed if the secret uses a customer-managed key. This has not been tested.

## 6. Limits of this evidence

- The excess calls in section 3 cannot be re-run from this workstation. The `fn` and `inst` profiles were removed during cleanup. Any re-run needs a separate decision under the engagement brief.
- The STS session record for `fn-review` is not retained. The identity rests on `71` alone.
- Exit codes for `72`–`77` were not saved. The saved content supports success but is not a recorded exit status.
- `iam:ListPolicyVersions` is denied to the reviewer. The full policy version list was not checked.
- Writes (`PutObject`, `PutItem`, `DeleteMessage`) were not executed. Their status is not established.

## 7. Impact boundary

Code running with this role's temporary credentials can make the three demonstrated code-path calls in section 4 and the five inventory calls in section 3. The evidence supports account inventory disclosure, read access to one order object, receipt of one queue message, and retrieval of the signing secret.

The evidence does not support account-administrator access, write access to any resource, or the untested grants in section 2. Those remain open.

This role gap is separate from the storefront instance-role compromise in `2-instance_chain.md`.
