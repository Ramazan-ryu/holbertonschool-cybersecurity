# 2 — Instance Workload Identity and Executed Reach

## Status

- **Recorded from the operator session, not reproduced.** The calls below were recorded with the instance-role credentials. A reproduction attempt in the reviewer session did not confirm them.
- **Endpoint not confirmed.** The `default` AWS profile sets `endpoint_url = http://127.0.0.1:4566`. Whether that endpoint forwards to AWS account `500100200300` is unknown. Until the owner confirms it, nothing in this file is evidence about that account.
- **Reproduction ran under the wrong identity.** The reproduction calls ran as `user/appsec-reviewer`, not `marlowe-web-instance-role`. Their results describe the reviewer's permissions, not the instance role's.
- **CloudTrail not available.** The reviewer profile is denied `cloudtrail:LookupEvents`, so no event or request ID below has been checked against the audit log.

## Entry point

The identity was obtained through the server-side fetch described in `1-door.md`. The recorded request was:

```text
GET /admin/catalog/image-import?src=http://169.254.169.254/latest/meta-data/iam/security-credentials/marlowe-web-instance-role
```

The recorded response was a credential document for `marlowe-web-instance-role`. Credential values are omitted.

## Principal (recorded)

The session recorded this `aws sts get-caller-identity` output with the returned temporary credentials:

```json
{
  "UserId": "AROAXI4CLO5WCDXO762J4:i-0marlowe",
  "Account": "500100200300",
  "Arn": "arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe"
}
```

This output has not been reproduced.

## Recorded calls under the instance identity (not reproduced)

| # | Call | Recorded result | Reproduction (as `appsec-reviewer`) | Status |
|---|---|---|---|---|
| 1 | `s3api get-object` on `marlowe-orders-mc4e21/orders/2026-Q1.json` | Success; ETag `"074aacc1288e394e327be2402780c18c"`, ContentLength `1868`; request ID `8ihFkBAXRgiUXYmPDXAGAXHEEpswVJLW6oEgVKjkhffXqFBcTiAX` | `AccessDenied` via `127.0.0.1:4566` | Recorded, unverified |
| 2 | `sqs receive-message` on `marlowe-customer-events` | Success; message ID `b438c850-07d0-4c51-a93f-4e4d38dd0336`; request ID `xHUDptXO3ZRPq29f3B7A0nOX74JGzPfrAf5fPGN9zVvEUAeIXrEm` | HTTP 400 | Recorded, unverified |
| 3 | `secretsmanager get-secret-value` on `marlowe/stripe-webhook-signing` | Success; version `fccb4133-4ad9-413d-ad92-5083a55d0eaa`; request ID `ZdoxkXFkUKINV6V7Dtc4uIgiHGBjsibkOUAzXyn085q2eamVuqWn` | HTTP 400 | Recorded, unverified |
| 4 | `iam list-users` | `AccessDenied`; request ID `mDOGL1BPwxPc6dMe063RvUTZalTzLqFdPJcDZnEF1y4iFUNYbbNI` | `AccessDenied` | Recorded, unverified |
| 5 | `sts assume-role` into `marlowe-order-processor-role` | Success; request ID not recorded | HTTP 403 | Not verified; request ID missing |

Event IDs from the session (`14772654-…`, `2f87e3d9-…`, `4c5221b8-…`, `25b379b9-…`) could not be checked: CloudTrail lookups are denied to the reviewer profile.

## Identity policy (granted, not executed)

The attached policy `arn:aws:iam::500100200300:policy/MarloweInstanceRolePolicy` (default version `v1`) is the only policy attached to the role. The role has no inline policies or permissions boundary. These are policy grants, not demonstrated permissions.

| Statement | Actions | Resource scope | Call recorded |
|---|---|---|---|
| `Orders` | `s3:GetObject` | `arn:aws:s3:::marlowe-orders-mc4e21/*` | Row 1 |
| `Orders` | `s3:ListBucket`, `s3:PutObject` | `arn:aws:s3:::marlowe-orders-mc4e21` and `/*` | None |
| `CustomerQueue` | `sqs:ReceiveMessage` | `*` | Row 2 |
| `CustomerQueue` | `sqs:GetQueueUrl`, `sqs:GetQueueAttributes` | `*` | None |
| `AssumeFunctionRole` | `sts:AssumeRole` | `arn:aws:iam::500100200300:role/marlowe-order-processor-role` | Row 5 |
| `ReadWebhookSecret` | `secretsmanager:GetSecretValue` | `arn:aws:secretsmanager:*:500100200300:secret:marlowe/stripe-webhook-signing*` | Row 3 |

## Conclusion

The session recorded that the forged metadata request returned credentials for `marlowe-web-instance-role`. It also recorded successful calls under that identity: `s3:GetObject` on one order object, `sqs:ReceiveMessage`, `secretsmanager:GetSecretValue`, and `sts:AssumeRole`. `iam:ListUsers` was recorded as denied.

None of these results has been reproduced under the instance identity or checked against CloudTrail, and the endpoint serving them is unconfirmed. Do not report them as account evidence until the endpoint owner confirms it forwards to AWS and the calls are re-run with raw responses saved.

Actions listed in the policy but not executed (`s3:ListBucket`, `s3:PutObject`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes`) are not claimed as reach.

The request-forgery entry point and the metadata test are in `1-door.md`. The function role's own reach, which row 5 would lead to, is not established here.
