# 0 — Orientation

## Identity reported by Copperline

Command: `aws sts get-caller-identity`

Response:

```json
{
    "UserId": "AIDA59C2ACB2A2DB59159",
    "Account": "418274639051",
    "Arn": "arn:aws:iam::418274639051:user/svc-audit-intake"
}
```

Copperline identifies these credentials as IAM user `svc-audit-intake` in account `418274639051`, with user ID `AIDA59C2ACB2A2DB59159`.

## Why the request succeeded

My first thought is that authentication and access to a company's machines are separate things. These credentials let me prove my identity directly to Copperline's cloud account API. The API can answer questions about the account because the request is addressed to the account service and is authorized by the credentials and their permissions. That does not require a network route to Copperline's dispatch servers or any other host. I have reached an identity control plane, not a machine on the company's network. The account's response proves who these keys represent; it does not mean I can access everything in the account.
