# 2 — Instance Workload Identity and Executed Reach

## Status

- **Recorded from the operator session, not reproduced under the instance identity.** The calls in the table below were recorded with instance-role credentials. Every reproduction attempt ran as `user/appsec-reviewer`.
- **Environment.** The workstation runs local services from `/opt/ashford/` (`run_emu.py` on port 4567, `metadata_service.py`, `ashford_shim.py`, `marlowe_web.py`). The `default` profile sets `endpoint_url = http://127.0.0.1:4566`, and that port returns `403` with `Server: AmazonS3`. Whether this environment is a simulation or forwards to AWS account `500100200300` is not confirmed. Until the owner confirms it, these results are not evidence about that account.
- **CloudTrail not available.** The reviewer profile is denied `cloudtrail:LookupEvents`. No event or request ID below has been matched to an audit record.

## Entry point

The identity was obtained through the server-side fetch described in `1-door.md`. The recorded request was:

```text
GET /admin/catalog/image-import?src=http://169.254.169.254/latest/meta-data/iam/security-credentials/marlowe-web-instance-role
```

The recorded response was a credential document for `marlowe-web-instance-role`. Credential values are omitted. The metadata responder may be `metadata_service.py` rather than IMDS (see Gaps).

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

## Effective permissions: what the role permits

| Source | Result (read as `appsec-reviewer`) | Effect on the instance identity |
|---|---|---|
| Trust policy | Trusts `ec2.amazonaws.com` and `user/metadata-minter` for `sts:AssumeRole` | Names `metadata-minter` as a principal that may assume the role |
| Permissions boundary | `null` | None applied |
| Attached managed policy | Only `MarloweInstanceRolePolicy`, default version `v1` | Source of the grants below |
| Inline role policies | None | None |
| Conditions in `v1` | None | Grants are not narrowed by condition keys |
| Session policies | None recorded | Not evaluated |
| S3 bucket policy (`marlowe-orders-mc4e21`) | `AccessDenied` | **Unknown** |
| SQS queue policy (`marlowe-customer-events`) | `AccessDenied` | **Unknown** |
| Secret resource policy (`marlowe/stripe-webhook-signing`) | `AccessDenied` | **Unknown** |
| IAM policy simulation | `AccessDenied` | **Not obtained** |

### Grants in `MarloweInstanceRolePolicy` v1

| Statement | Actions | Resource | Call recorded |
|---|---|---|---|
| `Orders` | `s3:GetObject`, `s3:ListBucket`, `s3:PutObject` | `arn:aws:s3:::marlowe-orders-mc4e21`, `arn:aws:s3:::marlowe-orders-mc4e21/*` | Row 1 (`GetObject` only) |
| `CustomerQueue` | `sqs:ReceiveMessage`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes` | `*` | Row 2 (`ReceiveMessage` only) |
| `AssumeFunctionRole` | `sts:AssumeRole` | `arn:aws:iam::500100200300:role/marlowe-order-processor-role` | Row 5 (not verified) |
| `ReadWebhookSecret` | `secretsmanager:GetSecretValue` | `arn:aws:secretsmanager:*:500100200300:secret:marlowe/stripe-webhook-signing*` | Row 3 |

These are grants, not demonstrated permissions. Actions without a recorded call (`s3:ListBucket`, `s3:PutObject`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes`) are not claimed as reach.

## Gaps and limits

1. **Environment.** `run_emu.py` (port 4567), `metadata_service.py`, `ashford_shim.py` and `marlowe_web.py` run from `/opt/ashford/`. The metadata response used in `1-door.md` may come from `metadata_service.py`, not from IMDS. All results describe this environment until the owner confirms otherwise.
2. **AWS endpoint unidentified.** `127.0.0.1:4566` returns `403 Forbidden` with `Server: AmazonS3`. No process listening on port 4566 was identified. Whether it forwards to account `500100200300` is unknown.
3. **Instance identity not tested for resource policies.** Reads of the S3 bucket policy, SQS queue policy and secret resource policy ran as `user/appsec-reviewer` and returned `AccessDenied` (exit 254). They were not run under `marlowe-web-instance-role`.
4. **Simulation not obtained.** `iam:SimulatePrincipalPolicy` is denied to `appsec-reviewer`. No effective-permission decision exists for the role.
5. **Trust principal not examined.** `user/metadata-minter` is named in the role's trust policy. Reads of that user (`GetUser`, attached and inline policies, access keys) are denied to `appsec-reviewer`. Its permissions and key status are unknown.
6. **Event and request IDs unverified.** CloudTrail lookups are denied to `appsec-reviewer`. The request IDs above come from the session and are not matched to audit records.
7. **`sts:AssumeRole` row incomplete.** The reproduction returned HTTP 403. The session recorded no request ID for the successful call.
8. **Session restrictions and conditions.** The identity policy has no `Condition` keys. No session policy was recorded or checked.
9. **Earlier resource-policy claim withdrawn.** The earlier note that the bucket had no policy (`NoSuchBucketPolicy`) is not reproduced in this evidence set and is not claimed here.

## Conclusion

The identity policy grants the actions listed above, with no conditions and no permissions boundary. The effective permission set is **not established**: the resource policies of the three target resources and the IAM simulation could not be read under the reviewer identity, so their allow or deny decisions are unknown.

The session recorded successful calls under the instance identity: `s3:GetObject`, `sqs:ReceiveMessage`, `secretsmanager:GetSecretValue`, and `sts:AssumeRole`. None has been reproduced under that identity or checked against CloudTrail, and the environment serving them is unconfirmed. Do not report them as account evidence until the owner confirms the environment and the calls are re-run under the instance identity with raw responses saved.

The request-forgery entry point and the metadata test are in `1-door.md`. The function role's own reach is not established here.
