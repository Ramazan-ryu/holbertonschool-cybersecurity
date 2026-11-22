# 0 — Reachability Decisions from the Supplied Network Configuration

All CIDRs, ports, directions, peerings, and endpoint policy below come from `~/marlowe-handover/network-configuration.json`. Security groups are stateful; network ACLs are stateless and have an implicit deny for traffic not matched by an allow. A configured allow at one layer never overrides a deny at another layer.

## Internet to the web service: TCP/443 inbound

**Source:** internet clients in `0.0.0.0/0`. **Destination:** a workload associated with `sg-web-public`. **Direction:** inbound. **Protocol/port:** TCP/443. The security group allows this initial flow. The supplied `acl-app-tier` has no inbound TCP/443 rule, so if it governs the workload subnet, it denies the SYN; the security-group allow cannot override it. The configuration supplies no route from an internet gateway to this workload and no association tying either control to it. **Verdict: the JSON does not establish public TCP/443 reachability.** A stateful security group would allow reply packets only after a permitted connection starts; it cannot repair the missing ACL ingress or route.

## App-tier request and reply: TCP/8080 inbound

**Source:** a host in `10.0.1.0/24`. **Destination:** an app-tier host. **Direction:** inbound request. **Protocol/port:** TCP/8080. ACL rule 100 allows that request. Its reply is outbound from source port 8080 to the client's ephemeral destination port. Rule 100 in the outbound direction allows TCP/443 only, so it does not allow the reply. Because an ACL is stateless, the inbound allow does not establish a working TCP session. **Verdict: the listed ACL allows the request packet but blocks its reply; this is not a completed connection.** A stateful SG may allow the return at its own layer, but cannot override the ACL.

## Workload egress and the exfiltration direction

The SG's egress is all protocols and ports to `0.0.0.0/0`; that rule alone would permit a workload to initiate a TCP/443 callback or transmit data to any IPv4 destination. The app-tier ACL's only egress allow is TCP/443 to `10.0.1.0/24`, which does not allow an arbitrary public destination. No public route, internet gateway, or NAT gateway is specified. **Verdict: the supplied configuration does not establish an external callback or exfiltration path.** This is an ingress/egress asymmetry and a broad SG egress grant, not evidence that data has been exfiltrated. The only listed outbound packet flow allowed by the ACL is TCP/443 with destination in `10.0.1.0/24`; any TCP reply must also match the ACL's inbound rules, which admit TCP/8080 only.

## VPC-to-VPC reachability

`vpc-app` has a listed direct peering with `vpc-data`; `vpc-data` has a separate direct peering with `vpc-analytics`. **Source:** a host in `vpc-app`. **Destination:** a host in `vpc-analytics`. **Direction/protocol/port:** any attempted flow. VPC peering is non-transitive, so the two links do not form an app-to-analytics route. No direct peering or other route is listed. **Verdict: app-to-analytics reachability through `vpc-data` is blocked; this is the sound isolation outcome.** For `vpc-app` to `vpc-data`, the direct peering exists, but no route tables, peer acceptance, CIDRs, or destination SG/ACL rules are supplied; therefore a protocol/port path is not established from this JSON.

## Explicit S3 gateway-endpoint question: TCP/443

**Question:** can a host in `vpc-app` on `10.0.1.0/24` reach the S3 gateway endpoint in `vpc-app` on TCP/443? **Verdict: yes, the configured in-VPC gateway-endpoint path permits TCP/443; no finding for this stated path.** The gateway endpoint is in the source VPC, so the service route is to S3 through the endpoint and does not require an internet gateway or NAT gateway. The endpoint policy is `permissive`; the app-tier outbound ACL rule allows TCP/443; the `sg-web-public` rule is not used as proof for this host because the JSON does not associate that SG with it. This verdict is limited to the endpoint path in the question and does not imply arbitrary internet egress.

## Verdict summary

| Source → destination | Direction and protocol/port | Controlling configuration | Verdict |
|---|---|---|---|
| Internet `0.0.0.0/0` → web workload | Inbound TCP/443 | SG allows; ACL has no 443 ingress; no internet route or association supplied | Public reachability not established |
| `10.0.1.0/24` → app-tier host | Inbound TCP/8080, then outbound reply to ephemeral port | ACL ingress allows request; stateless ACL egress permits only TCP/443 | Request packet allowed; session reply denied |
| App workload → public collector | Outbound TCP/443 | SG egress allows; ACL destination limited to `10.0.1.0/24`; no internet/NAT route supplied | No external callback/exfil path established |
| `vpc-app` → `vpc-analytics` via `vpc-data` | Any | Two direct peering links do not provide transitive routing | Blocked; correctly isolated |
| Host `10.0.1.0/24` → S3 gateway endpoint in `vpc-app` | Outbound TCP/443 | In-VPC gateway-endpoint route; app-tier ACL outbound TCP/443; permissive endpoint policy | Reachable for this endpoint question; no finding |
