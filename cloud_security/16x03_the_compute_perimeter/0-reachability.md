# 0 — Reachability Decisions from the Supplied Network Configuration

## Scope and inputs

All CIDRs, ports, directions, peerings, and endpoint policy come from `~/marlowe-handover/network-configuration.json`. Live EC2 output is excluded from this analysis because it does not map to the logical topology (`vpc-app`, `10.0.1.0/24`).

Evaluation rules:

- Security groups are stateful. They permit return traffic for connections they allow.
- Network ACLs are stateless. Each direction is evaluated separately, so return traffic needs its own explicit allow.
- ACLs have an implicit deny for unmatched traffic. A security-group allow does not override an ACL deny.
- VPC peering is non-transitive.

Input assumptions (confirm each against the JSON):

| ID | Assumption |
|---|---|
| A1 | `acl-app-tier` is associated with the app-tier subnet `10.0.1.0/24`. |
| A2 | The web workload subnet is governed by `acl-app-tier`. |
| A3 | The app workload subnet is governed by `acl-app-tier`. |
| A4 | `sg-web-public` is attached to the web workload. |
| A5 | No other ACL rules exist for `acl-app-tier` beyond those listed in this document. |

Each verdict below names the assumption it depends on.

## Verdicts

### 1. Internet to web workload, inbound TCP/443

- **Source:** `0.0.0.0/0`
- **Destination:** web workload (`sg-web-public`)
- **Direction:** inbound
- **Protocol/port:** TCP/443

| Control | Value |
|---|---|
| Subnet ACL, inbound | `acl-app-tier` (A2). No inbound TCP/443 rule. Implicit deny. |
| Security group, inbound | `sg-web-public` allows TCP/443 (A4). |
| Route | No internet gateway route supplied. |

**Verdict: Denied.** The subnet ACL blocks the inbound SYN. The security-group allow cannot override the ACL deny.

### 2. Client to app-tier server, TCP/8080 request

- **Source:** `10.0.1.0/24`
- **Destination:** app-tier server
- **Direction:** inbound
- **Protocol/port:** TCP destination port 8080

| Control | Value |
|---|---|
| Subnet ACL, inbound | `acl-app-tier` rule 100 allows TCP/8080 from `10.0.1.0/24` (A1). |

**Verdict: Allowed.** The request packet is permitted.

### 3. App-tier server to client, TCP/8080 reply

- **Source:** app-tier server, TCP source port 8080
- **Destination:** `10.0.1.0/24`, client ephemeral port (typically 1024–65535, depending on the client OS)
- **Direction:** outbound
- **Protocol/port:** TCP

| Control | Value |
|---|---|
| Subnet ACL, outbound | Only allow is TCP/443 to `10.0.1.0/24` (A1). Destination CIDR matches; destination port does not. |
| Security group | Stateful return allowance does not apply, because the ACL has already denied the flow. |

**Verdict: Denied.** The reply is blocked, so the TCP session cannot complete.

### 4. App workload to public collector, outbound TCP/443

- **Source:** app workload (IP not supplied in the JSON; in `10.0.1.0/24` per A3)
- **Destination:** `0.0.0.0/0`
- **Direction:** outbound, with inbound reply
- **Protocol/port:** TCP/443

| Control | Value |
|---|---|
| Subnet ACL, outbound | Only allow is TCP/443 to `10.0.1.0/24`. `0.0.0.0/0` does not match (A3). |
| Subnet ACL, inbound | Only allow is TCP/8080. The HTTPS reply to an ephemeral port is not allowed. |
| Security group, outbound | `sg-web-public` allows all IPv4, but it is attached to the web workload (A4), not to the app workload. This does not apply to this path. |
| Route | No internet gateway or NAT route supplied. |

**Verdict: Denied.** The ACL blocks the outbound request, and the reply would be blocked on the inbound side too. No route to the public internet exists in the supplied configuration.

### 5. `vpc-app` to `vpc-analytics` (via `vpc-data`)

- **Source:** host in `vpc-app`
- **Destination:** host in `vpc-analytics`
- **Direction/protocol/port:** any

| Control | Value |
|---|---|
| Peering | `vpc-app` to `vpc-data` and `vpc-data` to `vpc-analytics` are separate direct peerings. |
| Routing | Peering is non-transitive. No direct `vpc-app` to `vpc-analytics` peering or route is supplied. |

**Verdict: Denied.** No path exists. This is the correct isolation outcome.

### 6. `vpc-app` to `vpc-data`

- **Source:** host in `vpc-app`
- **Destination:** host in `vpc-data`
- **Direction/protocol/port:** any

| Control | Value |
|---|---|
| Peering | Direct peering exists. |
| Route tables | Not supplied in the JSON. |
| Destination SG and ACL | Not supplied in the JSON. |

**Verdict: Undetermined.** A required control, the route-table entry for the peering, is missing from the JSON. Once it is supplied, the verdict depends on the destination SG and ACL rules.

### 7. App-tier host to S3 gateway endpoint, TCP/443

- **Source:** `10.0.1.0/24`
- **Destination:** S3 gateway endpoint in `vpc-app` (S3 prefix list)
- **Direction:** outbound request, inbound reply
- **Protocol/port:** TCP/443

| Control | Value |
|---|---|
| Endpoint policy | `permissive`. This does not block traffic. |
| Subnet ACL, outbound | Only allow is TCP/443 to `10.0.1.0/24`. The S3 destination is outside that CIDR, so the request is not matched (A1). |
| Subnet ACL, inbound | Only allow is TCP/8080. The TCP/443 reply to the ephemeral port is not matched. |
| Route table | Not supplied in the JSON. |

**Verdict: Denied.** Under `acl-app-tier` (A1), the outbound request to S3 matches no allow rule, so it is blocked. The endpoint policy does not change this. The route-table entry is also missing, which is a second blocker that would need to be resolved before the path could work.

## Verdict summary

| # | Path | Direction / protocol / port | Deciding control | Verdict |
|---|---|---|---|---|
| 1 | Internet to web workload | Inbound TCP/443 | Subnet ACL: no inbound 443 rule (A2) | Denied |
| 2 | `10.0.1.0/24` to app server | Inbound TCP/8080 request | ACL inbound rule 100 | Allowed |
| 3 | App server to `10.0.1.0/24` | Outbound TCP/8080 reply | ACL outbound: only TCP/443 (A1) | Denied |
| 4 | App workload to public collector | Outbound TCP/443 | ACL outbound: only `10.0.1.0/24` (A3) | Denied |
| 5 | `vpc-app` to `vpc-analytics` | Any | Non-transitive peering; no route | Denied |
| 6 | `vpc-app` to `vpc-data` | Any | Route table not supplied | Undetermined |
| 7 | `10.0.1.0/24` to S3 endpoint | Outbound TCP/443 request | ACL outbound: only `10.0.1.0/24` (A1) | Denied |

## What to check against the JSON

1. Confirm A1 to A5. Verdicts 1, 3, 4, and 7 depend on them.
2. Confirm the ACL rule numbers and CIDRs cited above.
3. For verdict 6, add the route-table entry for the `vpc-app` to `vpc-data` peering. If it exists, the verdict changes to Allowed or Denied based on the destination SG and ACL.
