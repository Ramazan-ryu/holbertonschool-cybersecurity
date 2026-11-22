# 2 — Instance Workload Identity and Executed Reach

## Result

The workload identity obtained through the SSRF in `1-door.md` is `marlowe-web-instance-role`, confirmed by an STS call made with the returned credentials. Under that identity, `s3:GetObject`, `sqs:ReceiveMessage` and `secretsmanager:GetSecretValue` succeeded, and `iam:ListUsers` was denied. Strong IMDS mode defeats the identical credential request.

The endpoint used for these calls, `http://127.0.0.1:4566`, is not confirmed as forwarding to AWS account `500100200300`. This must be confirmed before the findings are reported as account evidence.

## Executed calls under the instance identity

| # | Call | Provider response (saved file) | Result |
|---|---|---|---|
| 1 | `sts get-caller-identity` | `Arn: arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe`, `UserId: AROAXI4CLO5WCDXO762J4:i-0marlowe` (`51-instance-identity.json`) | Identity confirmed |
| 2 | `s3api get-object` on `marlowe-orders-mc4e21/orders/2026-Q1.json` | Exit 0; `ContentLength 1868`, ETag `074aacc1288e394e327be2402780c18c` (`52-s3.json`). Body written to `/dev/null`. | Allowed |
| 3 | `sqs receive-message` on `marlowe-customer-events`, visibility timeout 0 | Exit 0; `MessageId b438c850-07d0-4c51-a93f-4e4d38dd0336` (`53-sqs.json`). Message body not recorded. | Allowed. The message was received but not deleted. |
| 4 | `secretsmanager get-secret-value` on `marlowe/stripe-webhook-signing` | Exit 0; ARN `…secret:marlowe/stripe-webhook-signing-OZUeBE`, `VersionId 7eeae3b2-d9d1-4927-b28f-881cea392a98` (`54-secret.json`). Secret value not retrieved into the record. | Allowed. The session record listed VersionId `fccb4133-…`; the difference is unexplained. |
| 5 | `iam list-users` | `AccessDenied`; the error names `assumed-role/marlowe-web-instance-role/i-0marlowe` (`55-iam.json`) | Denied |
| 6 | `sts assume-role` into `marlowe-order-processor-role` | Not run in this review | Not verified |

## Remediation

- **Before (weak mode):** the credential request returned `HTTP 200` with a credential document containing `AccessKeyId`, `SecretAccessKey`, `Token`, `Code`, `Expiration`, `LastUpdated` and `Type`. Values were not recorded (`50-creds.json`).
- **After (strong mode):** the identical request returned `HTTP 502`. A search of the response for `AccessKeyId`, `SecretAccessKey` and `Token` matched 0 times (`56-strong.txt`).

The application-level fix removes only this request route. Strong IMDS mode closes the metadata credential path itself.

## Gaps and limits

1. **Endpoint.** `127.0.0.1:4566` is not confirmed as AWS. The `/opt/ashford/` services (`run_emu.py` on port 4567, `metadata_service.py`) suggest a local environment.
2. **Audit trail.** `marlowe-reset` reported `your activity cleared`. The audit trail may have been cleared, so the request IDs from the earlier session cannot be matched to records.
3. **CloudTrail not available** to `appsec-reviewer`.
4. **Resource policies** for the bucket, queue and secret were not readable under the reviewer identity, and were not read under the instance identity. Their effect on the instance role is unknown.
5. **Policy simulation** not obtained.
6. **Trust principal** `user/metadata-minter` was not examined.
7. **`sts:AssumeRole`** was not run in this review.
8. **Secret VersionId** differs from the earlier session record. The cause is unknown.

## Identity policy (grants, not demonstrated permissions)

`MarloweInstanceRolePolicy` v1 is the only attached policy. There are no inline policies, no permissions boundary and no `Condition` keys. It grants `s3:GetObject`, `s3:ListBucket`, `s3:PutObject` on `marlowe-orders-mc4e21`, `sqs:ReceiveMessage`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes` on `*`, `sts:AssumeRole` on `marlowe-order-processor-role`, and `secretsmanager:GetSecretValue` on `marlowe/stripe-webhook-signing*`. Actions without a recorded call (`s3:ListBucket`, `s3:PutObject`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes`) are not claimed as reach.

## Conclusion

The role's demonstrated reach is one order object read, one queue message received, and one secret's metadata read. The role cannot list IAM users. Remediation in strong IMDS mode was verified by the same request returning 502 without credential fields. The effective permission set beyond these calls is not established.
