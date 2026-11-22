# 0 — Reachability Decisions from the Supplied Network Configuration

All CIDRs, ports, directions, peerings, and endpoint policy below come from `~/marlowe-handover/network-configuration.json`. Security groups are stateful; network ACLs are stateless and have an implicit deny for traffic not matched by an allow. A configured allow at one layer never overrides a deny at another layer.

## Internet to the web service: TCP/443 inbound

**Source:** internet clients in `0.0.0.0/0`. **Destination:** a workload associated with `sg-web-public`. **Direction:** inbound. **Protocol/port:** TCP/443. The security group allows this initial flow. The supplied `acl-app-tier` has no inbound TCP/443 rule, so if it governs the workload subnet, it denies the SYN; the security-group allow cannot override it. The configuration supplies no route from an internet gateway to this workload and no association tying either control to it. **Verdict: the JSON does not establish public TCP/443 reachability.** A stateful security group would allow reply packets only after a permitted connection starts; it cannot repair the missing ACL ingress or route.

## App-tier request and reply: TCP/8080 inbound

**Source:** a client host in `10.0.1.0/24`. **Destination:** an app-tier server host. **Direction:** inbound request, then outbound response. **Protocol/port:** TCP destination port 8080 for the request; response destination is the client's ephemeral port. ACL rule 100 allows inbound TCP/8080 from `10.0.1.0/24`. The ACL's only listed egress allow is TCP/443 to `10.0.1.0/24`, so if `acl-app-tier` is associated with the server subnet, it blocks the server's response to the client's ephemeral port. The JSON does not supply that ACL association or identify the server's security group; a stateful SG cannot override an applicable stateless ACL denial. **Verdict: a request packet is allowed by the listed ACL rule, but a completed TCP session is not established by the supplied configuration.**

## Workload egress and the exfiltration direction

**Source:** an app-tier workload (the JSON does not give its IP). **Destination:** a public collector in `0.0.0.0/0`. **Direction:** outbound initiation and inbound reply. **Protocol/port:** TCP/443 initiation, with response to the workload's ephemeral port. `sg-web-public` permits all outbound IPv4 protocols and ports if attached to the workload. If `acl-app-tier` governs the workload subnet, its only listed egress allow is TCP/443 to `10.0.1.0/24`, not an arbitrary public address; its ingress allows TCP/8080 only, not the HTTPS reply's ephemeral destination port. The JSON supplies no SG or ACL associations and no internet/NAT route. **Verdict: the configuration does not establish an external callback or exfiltration path.** This shows broad SG egress in isolation against narrower listed ACL egress; it is not evidence that data was exfiltrated. The only listed outbound ACL packet rule is TCP/443 to `10.0.1.0/24`, and a completed TCP flow also needs a matching return rule.

## VPC-to-VPC reachability

`vpc-app` has a listed direct peering with `vpc-data`; `vpc-data` has a separate direct peering with `vpc-analytics`. **Source:** a host in `vpc-app`. **Destination:** a host in `vpc-analytics`. **Direction/protocol/port:** any attempted flow. VPC peering is non-transitive, so the two links do not form an app-to-analytics route. No direct peering or other route is listed. **Verdict: app-to-analytics reachability through `vpc-data` is blocked; this is the sound isolation outcome.** For `vpc-app` to `vpc-data`, the direct peering exists, but no route tables, peer acceptance, CIDRs, or destination SG/ACL rules are supplied; therefore a protocol/port path is not established from this JSON.

## Explicit S3 gateway-endpoint question: TCP/443

**Question:** can a host in `vpc-app` on `10.0.1.0/24` reach the S3 gateway endpoint in `vpc-app` on TCP/443? **Verdict: the endpoint policy itself has no deny, but the supplied configuration does not establish end-to-end reachability, so the host cannot be cleared as proven reachable.** The JSON lists an S3 endpoint in `vpc-app` with policy `permissive`; that establishes the endpoint's policy is not the blocking control. It does not include an endpoint ID/type, route table or endpoint route, subnet-to-ACL association, endpoint-to-route-table association, or S3 service-prefix CIDRs. The only listed ACL egress allow is TCP/443 to `10.0.1.0/24`, not a demonstrated S3 destination range; its ingress allows only TCP/8080, not the ephemeral destination port required for a stateless TCP response. If `acl-app-tier` governs this source subnet, those listed rules do not pass the S3 HTTPS request and response. The SG allows all egress, but the JSON does not associate `sg-web-public` with this source host and a security-group allow cannot override an ACL deny. A gateway endpoint avoids an internet gateway/NAT path, but still needs a route-table association and ACLs that pass request and return traffic. Therefore there is **no finding against the endpoint policy**, while reachability through the full network path remains unproven by this JSON.

## Verdict summary

| Source → destination | Direction and protocol/port | Controlling configuration | Verdict |
|---|---|---|---|
| Internet `0.0.0.0/0` → web workload | Inbound TCP/443 | SG allows; ACL has no 443 ingress; no internet route or association supplied | Public reachability not established |
| `10.0.1.0/24` → app-tier host | Inbound TCP/8080, then outbound reply to ephemeral port | ACL ingress allows request; stateless ACL egress permits only TCP/443 | Request packet allowed; session reply denied |
| App workload → public collector | Outbound TCP/443 | SG egress allows; ACL destination limited to `10.0.1.0/24`; no internet/NAT route supplied | No external callback/exfil path established |
| `vpc-app` → `vpc-analytics` via `vpc-data` | Any | Two direct peering links do not provide transitive routing | Blocked; correctly isolated |
| Host `10.0.1.0/24` → S3 gateway endpoint in `vpc-app` | Outbound TCP/443 and inbound ephemeral response | Endpoint policy is permissive; route-table/ACL associations and S3 CIDRs are absent; listed ACL does not show S3 or ephemeral-return allows | Endpoint policy has no finding; end-to-end reachability is not established |

## Live EC2 API cross-check

Read-only EC2 queries returned one VPC, `vpc-0717fc12efc99fe8e`, with CIDR `172.31.0.0/16` and no tags; its three returned subnets are `172.31.0.0/20`, `172.31.16.0/20`, and `172.31.32.0/20`. The only returned route table for that VPC contains the local `172.31.0.0/16` route, `describe-instances` returned an empty list, and `describe-vpc-endpoints` returned `VpcEndpoints: []`. The returned network ACL is associated with those three subnets and has allow-all inbound and outbound rules. These live IDs/CIDRs do not map to the supplied logical `vpc-app` / `10.0.1.0/24` topology, so they cannot establish or disprove associations for that logical path. They also do not fill in the route evidence missing from the supplied JSON. Therefore the live API responses and the handover JSON do not establish an end-to-end S3 path.
