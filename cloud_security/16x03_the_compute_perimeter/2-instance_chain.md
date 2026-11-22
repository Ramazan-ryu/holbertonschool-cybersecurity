# 2 — Instance Workload Identity and Executed Reach

## Principal established by STS

The forged image-import request reached the metadata role-credential path. The returned credential values are omitted. With those temporary credentials, `aws sts get-caller-identity` returned:

```json
{
  "UserId": "AROAXI4CLO5WCDXO762J4:i-0marlowe",
  "Account": "500100200300",
  "Arn": "arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe"
}
```

The resulting principal is the assumed role `marlowe-web-instance-role`, account `500100200300`, session `i-0marlowe`, stable role ID `AROAXI4CLO5WCDXO762J4`. This is the cloud workload identity exposed by the metadata response.

## Metadata remediation effect

The original tokenless forged GET to `http://169.254.169.254:80/latest/meta-data/iam/security-credentials/marlowe-web-instance-role` returned this role's credential document. After `sudo imds-mode strong`, replaying that identical image-import request returned HTTP `502` with no `AccessKeyId`, `SecretAccessKey`, or `Token` fields. This closes the tokenless metadata route while leaving the URL-fetch feature itself present; an application-only patch would remove that route but would not harden metadata against other callers.

## Permission proofs under that identity

Each successful call below was made with the credentials whose STS identity is shown above. The requests were limited to one target and did not print an order body, queue body, or secret value.

| Executed request | Account response | Proven permission and target |
|---|---|---|
| `aws s3api get-object --bucket marlowe-orders-mc4e21 --key orders/2026-Q1.json /dev/null --query '{ETag:ETag,ContentLength:ContentLength}'` | Success; ETag `"074aacc1288e394e327be2402780c18c"`, content length `1868` | `s3:GetObject` on `s3://marlowe-orders-mc4e21/orders/2026-Q1.json`. The object body was written to `/dev/null`. |
| `aws sqs receive-message --queue-url https://sqs.eu-west-1.amazonaws.com/500100200300/marlowe-customer-events --max-number-of-messages 1 --visibility-timeout 0 --query 'Messages[].MessageId'` | Success; message ID `b438c850-07d0-4c51-a93f-4e4d38dd0336` | `sqs:ReceiveMessage` on the named customer-events queue. Visibility was reset to zero immediately and the message body was omitted. |
| `aws secretsmanager get-secret-value --secret-id marlowe/stripe-webhook-signing --query '{ARN:ARN,Name:Name,VersionId:VersionId}'` | Success; ARN `arn:aws:secretsmanager:eu-west-1:500100200300:secret:marlowe/stripe-webhook-signing-OZUeBE`, version `fccb4133-4ad9-413d-ad92-5083a55d0eaa` | `secretsmanager:GetSecretValue` on the named signing secret. The secret value was not printed. |
| `aws iam list-users` | `AccessDenied`: not authorized for `iam:ListUsers` | This identity cannot perform the tested IAM user enumeration request. |

## Policy configuration evidence and limits

Using the function-role session `instance-policy-review`, the account returned the `marlowe-web-instance-role` record and attached managed policy document. The role record identifies role ID `AROAXI4CLO5WCDXO762J4`, trusts service principal `ec2.amazonaws.com` and user `metadata-minter`, has no inline role policies, and has no `PermissionsBoundary` field. The only attached policy is `MarloweInstanceRolePolicy` (`arn:aws:iam::500100200300:policy/MarloweInstanceRolePolicy`), default version `v1`. Its returned statements are:

| Statement | Actions | Resource scope | Condition |
|---|---|---|---|
| `Orders` | `s3:GetObject`, `s3:ListBucket`, `s3:PutObject` | `arn:aws:s3:::marlowe-orders-mc4e21` and `arn:aws:s3:::marlowe-orders-mc4e21/*` | None shown |
| `CustomerQueue` | `sqs:ReceiveMessage`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes` | `*` | None shown |
| `AssumeFunctionRole` | `sts:AssumeRole` | `arn:aws:iam::500100200300:role/marlowe-order-processor-role` | None shown |
| `ReadWebhookSecret` | `secretsmanager:GetSecretValue` | `arn:aws:secretsmanager:*:500100200300:secret:marlowe/stripe-webhook-signing*` | None shown |

This is identity-policy evidence, not a substitute for service calls. The executed S3 read, SQS receive, and secret read above prove those three actions on their named resources. `s3:ListBucket`, `s3:PutObject`, `sqs:GetQueueUrl`, and `sqs:GetQueueAttributes` appear in the policy but were not separately tested here, so this report does not claim an executed result for them.

The identity-policy `sts:AssumeRole` grant was exercised: `aws sts assume-role --role-arn arn:aws:iam::500100200300:role/marlowe-order-processor-role --role-session-name perimeter-review` succeeded, and STS identified the resulting principal as `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/perimeter-review` in account `500100200300`. Thus the instance identity's proven chain includes the function execution identity, whose excess reach is documented in `4-function_chain.md`.

The function-role session's `aws s3api get-bucket-policy --bucket marlowe-orders-mc4e21` returned `NoSuchBucketPolicy`, so the bucket has no bucket policy. Its `aws sqs get-queue-attributes --queue-url https://sqs.eu-west-1.amazonaws.com/500100200300/marlowe-customer-events --attribute-names Policy` produced no response text in the captured terminal output, so no conclusion about an SQS resource policy is drawn. `aws secretsmanager get-resource-policy --secret-id marlowe/stripe-webhook-signing` returned `AccessDenied` for the function-role principal; that is not evidence that a secret resource policy is absent. The successful secret read is direct proof of access despite the unavailable resource-policy document.

**Conclusion:** the obtained workload identity is `marlowe-web-instance-role`. Its executed reach is the named order object, customer-events queue, webhook-signing secret, and the function execution role via `sts:AssumeRole`; `iam:ListUsers` was denied. The attached identity policy additionally lists untested actions, which are labeled as policy grants rather than proven calls. The issue is compromise of a workload identity and its cloud reach, separate from the request-forgery door in `1-door.md`.
