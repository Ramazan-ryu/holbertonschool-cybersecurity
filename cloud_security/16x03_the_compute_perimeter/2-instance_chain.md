# 2 — Instance Workload Identity and Executed Reach

## Result

The workload identity obtained through the SSRF in `1-door.md` is `marlowe-web-instance-role`, confirmed by STS in two separate calls. Under that identity the following succeeded: `s3:GetObject`, `s3:ListBucket`, `sqs:ReceiveMessage`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes`, `secretsmanager:GetSecretValue`, and `sts:AssumeRole` into `marlowe-order-processor-role`. `iam:ListUsers` was denied. Strong IMDS mode defeats the identical credential request.

The CLI's configured endpoint is `http://127.0.0.1:4566`, the account endpoint supplied for this lab. The calls establish reach in the Marlowe lab account model; they are not claimed as independent evidence from AWS-operated infrastructure.

## Executed calls under the instance identity

| # | Call | Provider response (saved file) | Result |
|---|---|---|---|
| 1 | `sts get-caller-identity` | `Arn: arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe`, `UserId: AROAXI4CLO5WCDXO762J4:i-0marlowe` (`51`, `60`) | Identity confirmed (twice) |
| 2 | `s3api get-object` on `marlowe-orders-mc4e21/orders/2026-Q1.json` | Exit 0; `ContentLength 1868`, ETag `074aacc1288e394e327be2402780c18c` (`52`) | Allowed. Body to `/dev/null`. |
| 3 | `s3api list-objects-v2` on `marlowe-orders-mc4e21`, max 1 item | Exit 0 (`61`) | Allowed. Object keys in `61` are customer order identifiers and are not reproduced here. |
| 4 | `sqs receive-message` on `marlowe-customer-events`, visibility 0 | Exit 0; `MessageId b438c850-07d0-4c51-a93f-4e4d38dd0336` (`53`) | Allowed. Message received, not deleted. Body not recorded. |
| 5 | `sqs get-queue-url` for `marlowe-customer-events` | Exit 0 (`62`) | Allowed |
| 6 | `sqs get-queue-attributes` (`QueueArn`, `ApproximateNumberOfMessages`) | Exit 0 (`63`) | Allowed |
| 7 | `secretsmanager get-secret-value` on `marlowe/stripe-webhook-signing` (ARN and VersionId only) | Exit 0; `VersionId 7eeae3b2-d9d1-4927-b28f-881cea392a98` (`54`) | Allowed. Session record listed `fccb4133-…`; difference unexplained. |
| 8 | `iam list-users` | `AccessDenied`; error names the instance-role ARN (`55`) | Denied |
| 9 | `sts assume-role` into `marlowe-order-processor-role`, session `review-check` | Exit 0; `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/review-check` (`64`) | Allowed. Credentials in `64` are not reproduced. |
| 10 | `s3:PutObject` | Not run. A test write changes client order data and cannot be reliably undone. | Not verified; requires owner approval |

## Remediation

- **Before (weak mode):** the credential request returned `HTTP 200` with a credential document (`50-creds.json`, values not recorded).
- **After (strong mode):** the identical request returned `HTTP 502`. `grep` for `AccessKeyId`, `SecretAccessKey` and `Token` matched 0 times (`56-strong.txt`).

The application-level fix removes only this request route. Strong IMDS mode closes the metadata credential path itself.

## Gaps and limits

1. **Endpoint scope.** `127.0.0.1:4566` is the lab's configured account endpoint. Results establish behavior in that account endpoint, not in an independently verified AWS environment.
2. **Audit trail.** `marlowe-reset` reported `your activity cleared`. CloudTrail is not available to `appsec-reviewer`, so request IDs cannot be matched to audit records.
3. **Resource-based policies** for the bucket, queue and secret were not readable under the reviewer identity, and were not read under the instance identity.
4. **Service control policies and policy simulation** were not obtained.
5. **`s3:PutObject`** was not tested. Its effect on the role is taken from the policy grant only.
6. **Function role reach** (`marlowe-order-processor-role`) is not evaluated here. See `4-function_chain.md`.
7. **Secret VersionId** differs from the earlier session record. The cause is unknown.

## Identity policy (grants)

`MarloweInstanceRolePolicy` v1 is the only attached policy. It has no inline policies, no permissions boundary and no `Condition` keys. Grants: `s3:GetObject`, `s3:ListBucket`, `s3:PutObject` on `marlowe-orders-mc4e21` and `/*`; `sqs:ReceiveMessage`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes` on `*`; `sts:AssumeRole` on `marlowe-order-processor-role`; `secretsmanager:GetSecretValue` on `marlowe/stripe-webhook-signing*`.

## Conclusion

Demonstrated reach under the instance identity: read one order object, list the orders bucket, receive one queue message without deleting it, read queue metadata, read the secret's metadata, and assume the function execution role. Denied: listing IAM users.

Not established: write access to the orders bucket (`PutObject`), the effective permission set after resource policies and organization policies, and whether the endpoint is AWS.
