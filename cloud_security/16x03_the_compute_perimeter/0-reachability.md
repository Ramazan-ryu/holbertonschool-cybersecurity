# 0 — Reachability Decisions

## Scope

Client: Marlowe Commerce, account `500100200300`, region `eu-west-1`.
Question set: the handover paths in `network-configuration.json` and the supplied question
"Can a host in `vpc-app` on `10.0.1.0/24` reach the S3 gateway endpoint in `vpc-app` on 443?"

## Evidence sources

- **E1 — Handover JSON** (`~/marlowe-handover/network-configuration.json`). Contains `network_acls`,
  `security_groups`, `peerings`, `endpoints`, and `sound_question`. It does not contain `subnets`,
  `route_tables`, `internet_gateways`, or `nat_gateways`.
- **E2 — Live EC2 API, read-only**, profile `default`, account `500100200300`, all regions returned by
  `describe-regions`. Queries: `describe-vpcs` (CIDR `10.0.1.0/24`), `describe-subnets`,
  `describe-network-acls` (CIDR `10.0.1.0/24` or port 8080), `describe-security-groups`
  (`sg-web-public`), `describe-vpc-peering-connections`, `describe-vpc-endpoints` (S3 service name).
- **Not covered:** `us-gov-east-1`, `us-gov-west-1`, `cn-north-1`, `cn-northwest-1` returned
  `AuthFailure` for the `default` profile. Results for these regions are unknown.

## Rule model applied

- Security groups are stateful: return traffic for an allowed connection is permitted automatically.
- Network ACLs are stateless: each direction is evaluated separately, and return traffic needs an
  explicit rule for the reply direction and the ephemeral port.
- An ACL deny cannot be overridden by a security-group allow.
- A subnet needs a route-table entry to send traffic to a peering connection, gateway endpoint, or
  internet gateway. A route entry is required for every forwarded path.
- VPC peering is non-transitive.

## Verdicts

| # | Path | Direction, protocol, port | Deciding controls | Verdict |
|---|---|---|---|---|
| 1 | Internet `0.0.0.0/0` to web workload | Inbound TCP/443 | `acl-app-tier` has no inbound 443 rule (E1); no internet gateway in E1 or E2 | **Denied** |
| 2 | `10.0.1.0/24` client to app server | Inbound TCP/8080 request | `acl-app-tier` ingress rule 100 allows TCP/8080 from `10.0.1.0/24` (E1) | **Allowed** (request only) |
| 3 | App server to `10.0.1.0/24` client | Outbound TCP/8080 reply to ephemeral port | `acl-app-tier` egress rule 100 allows only TCP/443 to `10.0.1.0/24` (E1). No rule for the ephemeral port. ACL is stateless, so the security-group return allowance does not apply. | **Denied** |
| 4 | Workload to public collector | Outbound TCP/443 and inbound reply | `acl-app-tier` egress allows only TCP/443 to `10.0.1.0/24`, so `0.0.0.0/0` is not matched (E1). Ingress allows only TCP/8080, so the reply to an ephemeral port is not matched. No route to `0.0.0.0/0` in E1 or E2. | **Denied** |
| 5 | `vpc-app` to `vpc-analytics` | Any | Two separate peerings (E1). Peering is non-transitive, so no `vpc-app` to `vpc-analytics` path exists. E2 finds no peering connection in the account. | **Denied** (correct isolation) |
| 6 | `vpc-app` to `vpc-data` | Any | Peering exists in E1. No route-table entry in E1. E2 finds no VPC with `10.0.1.0/24` and no peering connection in the account. Without a route entry, traffic cannot be forwarded over the peering. | **Denied** (no route as configured; no peering found in account) |
| 7 | `10.0.1.0/24` to S3 gateway endpoint in `vpc-app` on TCP/443 | Outbound request, inbound reply | Endpoint listed in E1 with policy `permissive`; the endpoint policy does not block traffic. Request: `acl-app-tier` egress allows only `10.0.1.0/24` on TCP/443, and S3 addresses are outside that CIDR, so the request is not matched. Reply: ingress allows only TCP/8080, so the TCP/443 reply is not matched. No route-table entry to the endpoint in E1. E2: no VPC with `10.0.1.0/24`, no S3 endpoint in the account. | **Denied** |

## Detail for path 7 (the supplied question)

Checklist for `10.0.1.0/24` to S3 on TCP/443:

| Control | Value | Result |
|---|---|---|
| Source subnet | `10.0.1.0/24` in `vpc-app` (E1). Not found in account (E2). | Not present in account |
| Subnet-to-ACL association | Not in E1. Not found in E2. | Unknown |
| Network ACL egress | `acl-app-tier` rule 100: TCP/443 to `10.0.1.0/24` only | No match for S3 destinations |
| Network ACL ingress | `acl-app-tier` rule 100: TCP/8080 from `10.0.1.0/24` only | No match for TCP/443 reply |
| Security group | `sg-web-public` (E1) has no stated attachment to the source host | Does not override ACL |
| Route table | Not in E1. Not found in E2. | No route to endpoint |
| Endpoint | Listed in E1 (`s3`, `vpc-app`, `permissive`). Not found in E2. | Not present in account |

**Verdict: Denied.** The supplied ACL drops the request and the reply, and the configuration has no
route to the endpoint. The endpoint's `permissive` policy does not affect the result. Live results show
the endpoint and source subnet do not exist in the account.

## Cleared path

**`vpc-app` to `vpc-analytics`: no finding.**
- Non-transitive peering: the links are `vpc-app`–`vpc-data` and `vpc-data`–`vpc-analytics` (E1).
- No direct `vpc-app`–`vpc-analytics` peering in E1 or E2.
- No route-table entry from `vpc-app` to `vpc-analytics` in E1.
- Controls agree: no forwarding path exists at the peering layer, so no ACL or security-group rule can
  create one.

## Outbound exposure and ingress/egress asymmetry

What a workload can send outward, from the supplied configuration:

- **Security group:** `sg-web-public` allows egress on all ports (`port -1`) to `0.0.0.0/0` (E1).
  Its attachment target is not stated in E1, so this does not establish that any workload can use it.
- **Network ACL:** `acl-app-tier` egress allows only TCP/443 to `10.0.1.0/24` (E1). Traffic to public
  addresses is not allowed by this ACL.
- **Route tables, internet gateway, NAT gateway:** not in E1. E2 found no internet gateway or NAT
  gateway in the checked regions. No `0.0.0.0/0` route is configured in the supplied configuration.

Asymmetry: ingress is restricted to TCP/443 from the internet on the web security group, and TCP/8080
from `10.0.1.0/24` on the app ACL. Egress is broad at the security-group layer but narrow at the ACL
layer. The ACL is the stateless control that determines whether packets leave the subnet, and it does
not permit an external destination.

**Result:** No configured exit path to an external callback or collector exists in the supplied
configuration or the checked account regions. This is not evidence that data cannot leave by another
method, such as a compromised instance role reaching a public API endpoint, which is outside this
network analysis.

## Limits

- `us-gov-east-1`, `us-gov-west-1`, `cn-north-1`, and `cn-northwest-1` were not checked (AuthFailure).
  Results for these regions are unknown.
- E1 does not contain `subnets`, `route_tables`, `internet_gateways`, or `nat_gateways`. Verdicts that
  depend on routing reflect the absence of those entries in the supplied configuration.
- The `default` profile was not confirmed to belong to the client's intended environment.
  Confirm with the client before reporting the live results as definitive.
