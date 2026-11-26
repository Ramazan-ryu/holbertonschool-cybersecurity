# 0 — Reachability Decisions

## Evidence and rule model

The judgments below use `~/marlowe-handover/network-configuration.json` (the JSON printed during this review). It defines one security group, one network ACL, two VPC peerings, one S3 gateway endpoint, and the supplied S3 path question. It does not define subnet-to-ACL or subnet-to-security-group associations, route tables, internet gateways, or NAT gateways. I do not treat an omitted association or route as an explicit deny, and I do not use the separate account API results as a substitute for this handover configuration.

As a separate scope check, the read-only EC2 API in `eu-west-1` returned account `500100200300` and one VPC, `vpc-c3acb8fce8058fe62` with CIDR `172.31.0.0/16`; its subnets are within that CIDR and its route table contains only the local route. This is not the handover's `vpc-app` / `10.0.1.0/24` network. The live result therefore cannot be used to fill in missing handover associations or routes, or to alter the supplied S3 question. It only records that the read-only API view in this region describes a different network.

The configured controls are:

- `sg-web-public`: inbound TCP/443 from `0.0.0.0/0`; outbound all protocols/ports to `0.0.0.0/0`. Security groups are stateful, so return traffic for an allowed connection is automatically permitted by the group.
- `acl-app-tier`: inbound rule 100 permits TCP/8080 from `10.0.1.0/24`; outbound rule 100 permits TCP/443 to `10.0.1.0/24`. A network ACL is stateless: request and reply packets are evaluated independently. A security-group return allowance does not override a network ACL rule that blocks the reply.
- Peerings: `vpc-app`–`vpc-data` and `vpc-data`–`vpc-analytics`. Peering is non-transitive.
- S3 gateway endpoint: attached to `vpc-app`, endpoint policy marked `permissive`.

For any forwarded path, the subnet also needs a route to the target. The handover does not include route tables or subnet associations, so route-dependent paths cannot be proved from this file alone. I state rule-level permits and denies separately from end-to-end conclusions.

## Path decisions

| # | Path | Deciding controls in the handover | Verdict |
|---|---|---|---|
| 1 | Internet to the web workload on TCP/443 | `sg-web-public` allows inbound TCP/443 from `0.0.0.0/0`. The named ACL only allows inbound TCP/8080 from `10.0.1.0/24`; if `acl-app-tier` is associated with the workload subnet, it blocks this 443 request. Association and internet-gateway/route data are not supplied. | Security-group layer allows; end-to-end reachability is **not established** by the handover. |
| 2 | `10.0.1.0/24` client to app server on TCP/8080 | `acl-app-tier` inbound rule 100 allows this request. The web security group rule shown is for 443, not 8080; its attachment to this app server is not specified. | ACL permits the request. End-to-end reachability is **not established** without the server's security-group association and route. |
| 3 | App server reply to the `10.0.1.0/24` client | The ACL has no listed outbound rule for the reply's ephemeral destination port; its only listed outbound rule is TCP/443. Because the ACL is stateless, the inbound 8080 allow does not itself create a reply allowance. The source subnet's ACL association is absent. | **Conditional:** if `acl-app-tier` governs this subnet, the reply is denied there. Without the association, end-to-end reply reachability is **unknown**. |
| 4 | Workload to a public collector on TCP/443, including reply | The security group allows all outbound traffic. The ACL outbound rule is limited to destination `10.0.1.0/24`, not a public collector, and the ACL ingress rule is limited to TCP/8080 from that private CIDR. ACL association and an internet/NAT route are not documented. | The SG permits egress at its layer. End-to-end public reachability is **not established**; if the named ACL governs the source subnet, its egress rule does not match the collector and blocks the request. |
| 5 | `vpc-app` to `vpc-analytics` | The only links are `vpc-app`–`vpc-data` and `vpc-data`–`vpc-analytics`. VPC peering is non-transitive; there is no direct peering listed between app and analytics. | **Denied by peering topology; sound isolation.** |
| 6 | `vpc-app` to `vpc-data` | A direct peering is listed. A subnet route to that peering is necessary, but the handover has no route tables. | Peering exists; **end-to-end reachability is not established** by the supplied configuration. Do not describe the peering itself as absent. |
| 7 | Host in `vpc-app` (`10.0.1.0/24`) to its S3 gateway endpoint on TCP/443 | The handover lists the endpoint and a permissive endpoint policy. `sg-web-public` allows egress, but no association between that SG and the asked host is given. The ACL's outbound TCP/443 destination is `10.0.1.0/24`; its attachment to this host is also not given. If it applies, request and reply are evaluated separately because it is stateless; the listed ingress TCP/8080 rule is not evidence of an S3 reply allowance. Route-table information is absent. | **Unknown / conditional.** Endpoint policy and SG egress are permissive at their respective layers, but the supplied data do not establish SG/ACL association, an endpoint route, or ACL permission for the return flow. The `sound_question` label is not itself proof of end-to-end reachability. |

## The two directionality checks

For path 3, the ACL's inbound TCP/8080 rule admits the request from `10.0.1.0/24`. That rule says nothing about the return packet. If this ACL is associated with the server subnet, it separately evaluates the reply, whose destination is the client's ephemeral port; the listed outbound TCP/443 rule does not match. An allowed inbound request is therefore not equivalent to a working two-way connection. Because the association is missing, the end-to-end result remains conditional.

For path 4, `sg-web-public` has broad egress, but egress is the direction in which a workload initiates a callback or sends data outward. The app ACL's outbound allow is limited to `10.0.1.0/24`; it does not authorize a public collector if associated with the source subnet. This is the material security-group/ACL asymmetry. Route and association evidence is still needed to settle end-to-end public reachability.

## S3 endpoint policy and end-to-end uncertainty

For path 7, the endpoint policy itself is permissive and is not a finding. The complete host-to-endpoint path is **unknown from the available evidence**: the handover does not identify which security group or ACL governs the host, whether the endpoint route is associated with its subnet, or whether a stateless ACL permits the reply direction. `sound_question` is the label for the supplied question; it does not fill those configuration gaps. I therefore cannot certify the entire path as working or blocked from this JSON alone.

## Evidence limits

This file reports only what follows from the handover JSON and the rule model. It does not claim route-table or subnet-association facts that the JSON does not contain. A complete production reachability proof would need those associations and routes; their absence from this handover is not itself a deny rule. The S3 endpoint policy is permissive, while end-to-end network reachability remains unknown pending the omitted association and route evidence.
