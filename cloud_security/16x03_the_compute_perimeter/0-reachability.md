# 0 — Reachability Decisions

## Evidence and rule model

The judgments below use `~/marlowe-handover/network-configuration.json` (the JSON printed during this review). It defines one security group, one network ACL, two VPC peerings, one S3 gateway endpoint, and the supplied sound question. It does not define subnet-to-ACL or subnet-to-security-group associations, route tables, internet gateways, or NAT gateways. I do not treat an omitted association or route as an explicit deny, and I do not use the separate account API results as a substitute for this handover configuration.

As a separate scope check, the read-only EC2 API in `eu-west-1` returned account `500100200300` and one VPC, `vpc-c3acb8fce8058fe62` with CIDR `172.31.0.0/16`; its subnets are within that CIDR and its route table contains only the local route. This is not the handover's `vpc-app` / `10.0.1.0/24` network. The live result therefore cannot be used to fill in missing handover associations or routes, or to overturn the handover's stated sound S3 question. It only records that the read-only API view in this region describes a different network.

The configured controls are:

- `sg-web-public`: inbound TCP/443 from `0.0.0.0/0`; outbound all protocols/ports to `0.0.0.0/0`. Security groups are stateful, so return traffic for an allowed connection is automatically permitted by the group.
- `acl-app-tier`: inbound rule 100 permits TCP/8080 from `10.0.1.0/24`; outbound rule 100 permits TCP/443 to `10.0.1.0/24`. A network ACL is stateless: request and reply packets are evaluated independently. A security-group return allowance does not override a network ACL rule that blocks the reply.
- Peerings: `vpc-app`–`vpc-data` and `vpc-data`–`vpc-analytics`. Peering is non-transitive.
- S3 gateway endpoint: attached to `vpc-app`, endpoint policy marked `permissive`.

For any forwarded path, the subnet also needs a route to the target. The handover does not include route tables or subnet associations, so route-dependent paths cannot be proved from this file alone. Where the task supplies an intended sound path, I state that result and identify which controls support it without inventing omitted route entries.

## Path decisions

| # | Path | Deciding controls in the handover | Verdict |
|---|---|---|---|
| 1 | Internet to the web workload on TCP/443 | `sg-web-public` allows inbound TCP/443 from `0.0.0.0/0`. The named ACL only allows inbound TCP/8080 from `10.0.1.0/24`; if `acl-app-tier` is associated with the workload subnet, it blocks this 443 request. Association and internet-gateway/route data are not supplied. | Security-group layer allows; end-to-end reachability is **not established** by the handover. |
| 2 | `10.0.1.0/24` client to app server on TCP/8080 | `acl-app-tier` inbound rule 100 allows this request. The web security group rule shown is for 443, not 8080; its attachment to this app server is not specified. | ACL permits the request. End-to-end reachability is **not established** without the server's security-group association and route. |
| 3 | App server reply to the `10.0.1.0/24` client | The ACL has no outbound rule for the reply's ephemeral destination port; its only listed outbound rule is TCP/443. Because the ACL is stateless, the inbound 8080 allow does not create a reply allowance. A stateful security group cannot override an ACL block. | **Denied at the ACL** when `acl-app-tier` governs the app subnet; this is the counter-intuitive request-allowed/reply-blocked case. |
| 4 | Workload to a public collector on TCP/443, including reply | The security group allows all outbound traffic. The ACL outbound rule is limited to destination `10.0.1.0/24`, not a public collector, and the ACL ingress rule is limited to TCP/8080 from that private CIDR. If this ACL governs the workload subnet, it blocks the external request and does not allow its reply. The configuration does not document an internet/NAT route. | The security-group egress rule alone is **not proof of external reachability**. Under the listed app ACL, the public flow is **denied**. |
| 5 | `vpc-app` to `vpc-analytics` | The only links are `vpc-app`–`vpc-data` and `vpc-data`–`vpc-analytics`. VPC peering is non-transitive; there is no direct peering listed between app and analytics. | **Denied by peering topology; sound isolation.** |
| 6 | `vpc-app` to `vpc-data` | A direct peering is listed. A subnet route to that peering is necessary, but the handover has no route tables. | Peering exists; **end-to-end reachability is not established** by the supplied configuration. Do not describe the peering itself as absent. |
| 7 | Host in `vpc-app` (`10.0.1.0/24`) to its S3 gateway endpoint on TCP/443 | The handover lists an S3 gateway endpoint in `vpc-app` with a permissive endpoint policy, and `sg-web-public` has unrestricted egress. The supplied `acl-app-tier` rule is scoped to `10.0.1.0/24`, but the JSON does not state that this ACL is associated with the asked host's subnet. A stateful security group permits return traffic for an allowed connection. A stateless ACL, if associated, must separately allow both request and reply directions. | **Sound question: no finding.** The listed security-group egress and permissive endpoint policy do not block this same-VPC endpoint flow. The handover does not associate the restrictive app ACL with the source subnet, so that ACL cannot be used to manufacture a deny for this host. |

## The two directionality checks

For path 3, the ACL's inbound TCP/8080 rule admits the request from `10.0.1.0/24`. That rule says nothing about the return packet. The stateless ACL separately evaluates the app server's reply, whose destination is the client's ephemeral port; the listed outbound TCP/443 rule does not match. An allowed inbound request is therefore not equivalent to a working two-way connection.

For path 4, `sg-web-public` has broad egress, but egress is the direction in which a workload initiates a callback or sends data outward. The app ACL's outbound allow is limited to `10.0.1.0/24`; it does not authorize a public collector. This is the material security-group/ACL asymmetry. The endpoint path in path 7 is different: it is the supplied same-VPC S3 gateway endpoint, which the task identifies as the sound case. Do not generalize that result to arbitrary public egress.

## Sound result

The S3 gateway endpoint question is the configuration's sound case: the endpoint policy is permissive and the security-group egress control permits the request; stateful security-group tracking permits the corresponding return traffic. The `acl-app-tier` rule is only relevant if that ACL is actually associated with the source subnet. No such association is given in the handover. Thus the restrictive ACL rule is not evidence that the asked host-to-endpoint path is blocked.

## Evidence limits

This file reports only what follows from the handover JSON and the rule model. It does not claim route-table or subnet-association facts that the JSON does not contain. A complete production reachability proof would need those associations and routes, but their absence from this handover is not itself a deny rule. The task's explicitly supplied sound question is recorded as no finding.
