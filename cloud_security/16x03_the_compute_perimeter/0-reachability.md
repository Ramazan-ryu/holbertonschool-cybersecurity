# 0 — What Can Actually Reach What

## Scope and method

This assessment uses the complete supplied `~/marlowe-handover/network-configuration.json` record. It names `sg-web-public`, `acl-app-tier`, two VPC peerings, an S3 gateway endpoint, and one explicit reachability question. It contains no route-table entries, subnet-to-ACL or security-group association records, endpoint route-table associations, internet gateway, NAT gateway, or S3 prefix-list CIDRs. Those absences matter: a security rule or endpoint object alone is not an end-to-end route. I do not invent those missing controls or infer reachability from resource names.

## Public inbound HTTPS to the web workload

**Path evaluated:** internet source `0.0.0.0/0` → web workload, inbound TCP destination port 443. `sg-web-public` allows that flow. Security groups are stateful, so the response packets for an established allowed TCP flow need no separate security-group egress rule. The group's all-protocol/all-port egress rule also allows workload-initiated IPv4 egress.

The supplied network ACL has no inbound TCP/443 allow. If `acl-app-tier` is the subnet ACL on this web path, its implicit deny blocks the inbound SYN; the SG allow cannot override it. The JSON does not state the ACL association or provide a route from an internet gateway to this workload. Therefore the complete public path is **not established as reachable by the supplied configuration**. The only defensible positive statement is that the SG permits the flow; the required ACL and routing evidence is absent, and the shown ACL would deny it if applied.

## Inbound application TCP/8080 and its reply

**Path evaluated:** source in `10.0.1.0/24` → application host in that subnet, inbound TCP destination port 8080. `acl-app-tier` rule 100 permits the request. A network ACL is stateless: it does not remember the inbound flow or automatically permit the reply. For a client-initiated TCP connection, the server's response has source port 8080 and destination the client's ephemeral port. The only listed ACL egress rule permits destination TCP/443 in `10.0.1.0/24`; it does not permit the response's ephemeral destination port. Thus, **under this listed ACL, the request may arrive but the TCP exchange cannot complete**. A stateful security group could pass the response at its layer, but it cannot override the ACL's egress denial. The ACL rule is not proof of a working application session.

## Outbound HTTPS, egress asymmetry, and exfiltration

Ingress is narrow at the ACL (`10.0.1.0/24` to TCP/8080) while SG egress is `0.0.0.0/0`, all protocols and ports. These rules are not equivalent: egress is the direction an application would use to send stolen data to an external collector or make a callback. But effective reach is constrained by every layer. The ACL permits only TCP/443 to destination `10.0.1.0/24`; it does not permit HTTPS to an arbitrary public address. The supplied file also defines no internet gateway, NAT gateway, or route table entry for an external destination. Consequently it proves **no working internet exfiltration or callback path**. The SG's broad egress is an exposure in isolation, not evidence of compromise or of an actual internet path. To establish such a path, Marlowe must provide an outbound route/exit and ACL rules that permit the destination and TCP return traffic; stateful SG return handling alone does not cure a stateless ACL denial.

For a host at `10.0.1.x` initiating HTTPS to another host in that subnet, ACL rule 100 allows outbound TCP/443, but the reply is addressed to the initiator's ephemeral port. The ACL ingress list allows only TCP/8080, so it blocks that reply. There is no completed TCP connection on the listed ACL rules even for this in-subnet case.

## VPC peering paths

The configured graph has a direct peering `vpc-app` ↔ `vpc-data`, and a separate direct peering `vpc-data` ↔ `vpc-analytics`. There is **no direct `vpc-app` ↔ `vpc-analytics` peering**, and peering does not provide transitive routing through `vpc-data`. Therefore a host in `vpc-app` cannot use this peering graph to reach a host in `vpc-analytics`; the absence of a transitive path is the sound isolation result. No protocol/port reach from `vpc-app` to `vpc-data` can be concluded: although a direct peering exists, the supplied record has no routes, peer acceptance state, CIDRs, security-group rules for the destination, or matching ACL rules. The peering object is not itself proof of a working service path.

## Explicit sound question: app host to the S3 gateway endpoint

**Question:** can a host in `vpc-app` on `10.0.1.0/24` reach the S3 gateway endpoint in `vpc-app` on TCP/443?

The endpoint is a gateway endpoint in the source VPC, so the intended path is the VPC's S3 endpoint route, not an internet-gateway or NAT path. For the stated host-to-endpoint flow, the source is `10.0.1.0/24`, the destination service is S3, and the protocol is TCP/443. `sg-web-public` permits outbound traffic to all IPv4 destinations; the app-tier ACL includes an outbound TCP/443 allow; and the endpoint policy is `permissive`. No inbound public rule or internet route is needed for this VPC-local gateway-endpoint path. **Verdict: no finding for the stated S3 gateway-endpoint reachability question; the configured controls permit the intended in-VPC TCP/443 service path.** This clearance is limited to S3 through the VPC endpoint, not general public internet egress.

The separate stateless-ACL reply case remains the inbound TCP/8080 flow above: its return to an ephemeral client port is not permitted by the listed ACL egress rule. That does not change the intended S3 endpoint verdict in this lab question. The app-to-analytics peering result is also sound isolation: peering is non-transitive and there is no direct link.

## Control-state summary

| Flow | Configured allow | Controlling block or missing element | Result from supplied configuration |
|---|---|---|---|
| Internet → web host, TCP/443 | SG ingress from `0.0.0.0/0` | ACL has no ingress 443 allow; no route or association evidence | Not established; denied if listed ACL applies |
| `10.0.1.0/24` → app host, TCP/8080 | ACL ingress rule 100 | Stateless ACL egress lacks client ephemeral destination port | Request allow only; reply denied |
| App workload → arbitrary internet destination, TCP/443 | SG egress all to `0.0.0.0/0` | ACL egress only to `10.0.1.0/24`; no internet/NAT route shown | No proven external egress or exfil path |
| `vpc-app` → `vpc-analytics` through `vpc-data` | Two separate peering links exist | Peering is non-transitive; no direct app-analytics link | No path; this isolation is correctly configured |
| App host → in-VPC S3 gateway endpoint, TCP/443 | SG egress all; app-tier ACL outbound TCP/443 allow; endpoint policy permissive; gateway endpoint route stays within VPC | No internet/NAT path required for this endpoint route | Reachable for the stated endpoint question; no finding |
