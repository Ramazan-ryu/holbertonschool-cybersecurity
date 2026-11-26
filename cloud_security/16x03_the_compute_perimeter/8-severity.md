# 8 — Severity Assessment

## Finding: storefront request reaches a cloud workload identity

A **medium** rating last year was reasonable for the evidence then available: an application URL-fetch issue, without evidence about metadata settings, the resulting identity, its permissions, or the resources it could reach. Request forgery does not receive a critical rating by name alone. The missing information was held across the application feature owner, the platform or cloud owner of IMDS and the instance role, and the owners of the bucket, queue, secret, and function role. The review process did not join those inventories into one impact assessment.

The current evidence supports **High** severity. The image-import request reached the tokenless metadata path and returned credentials for `marlowe-web-instance-role`. STS confirmed that identity. Calls with those credentials read `orders/2026-Q1.json` from `marlowe-orders-mc4e21`, received a message from `marlowe-customer-events`, and retrieved `marlowe/stripe-webhook-signing`. The instance identity also assumed `marlowe-order-processor-role`; a separate confirmed session of that role made inventory calls. `iam:ListUsers` was denied to the instance identity, and no write access was demonstrated. These results show meaningful access to order data, a customer event, and a signing secret; they do not show account administration.

The metadata service accepted the original request without an IMDSv2 token. Replaying that request after strong mode returned HTTP 502 without credential fields. This validates the metadata control for the tested request; the attacker-controlled image-import destination remains an application issue.

**Reusable severity rule: follow each reachable identity and trust boundary, then rate the demonstrated authority, assets reached, and likely business consequences.**
