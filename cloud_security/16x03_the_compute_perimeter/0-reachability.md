# 0 — What Can Actually Reach What

## Source and method

The verdicts below are derived from `~/marlowe-handover/network-configuration.json`. The file identifies one security group, one network ACL, two VPC peerings, and an S3 gateway endpoint. It does not provide subnet-to-ACL/security-group associations, route tables, route propagation, endpoint route-table associations, or the S3 prefix-list CIDRs. Where those are necessary, the verdict is conditional instead of claiming a complete end-to-end path.

## Security group: `sg-web-public`

The group allows inbound TCP/443 from `0.0.0.0/0` and allows all outbound traffic to `0.0.0.0/0`. Security groups are stateful: if this group is attached to the target and routing permits it, an allowed inbound connection receives its reply without a separate outbound security-group rule. The egress rule is broad and would permit the group’s workloads to initiate outbound connections to any IPv4 destination; it is a material exfiltration path unless another control blocks it.

The supplied ACL has no matching inbound TCP/443 allow. If `acl-app-tier` is associated with the same target subnet, its implicit deny blocks public TCP/443 despite the security-group allow. The security-group entry alone therefore does not prove public reachability.

## Network ACL: `acl-app-tier`

Rule 100 allows inbound TCP/8080 from `10.0.1.0/24`. Its egress rule allows TCP/443 only to `10.0.1.0/24`. A network ACL is stateless, so an inbound TCP/8080 request does not automatically authorize its response. The response destination is the client’s ephemeral port; the shown egress rule permits only port 443, so that response is denied if this ACL is associated with the path. The inbound allow is not, by itself, a working session.

The egress rule is also far narrower than the security group’s `0.0.0.0/0` allow: it does not authorize arbitrary outbound destinations. Effective egress is the intersection of applicable controls. The actual CIDR shown is the application subnet, not the AWS S3 service prefix list, and the ACL ingress shown does not allow the ephemeral return traffic for a new outbound HTTPS connection.

## VPC peerings

The configuration lists direct peerings `vpc-app`–`vpc-data` and `vpc-data`–`vpc-analytics`. The first is a potential direct path, but the JSON does not prove it is usable: both route tables, peer acceptance, CIDR compatibility, security groups, and ACLs must also permit the flow. The second peering does not make `vpc-data` a transit router. `vpc-app` cannot reach `vpc-analytics` transitively through `vpc-data`; that isolation is the sound property in this topology. AWS documents that VPC peering is point-to-point and does not support transitive routing ([AWS VPC peering](https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-basics.html)).

## S3 gateway endpoint and the stated sound question

The endpoint is listed in `vpc-app` and its policy is `permissive`, so the endpoint policy is not an additional restriction. The security-group egress rule allows HTTPS. However, the supplied ACL only permits egress TCP/443 to `10.0.1.0/24`; S3 gateway endpoint traffic uses S3 service addresses, and the ACL has no S3 service CIDR allow. The ACL also lacks the inbound ephemeral-port rule needed for stateless return traffic. AWS guidance requires subnet ACLs to allow traffic to and from the S3 address ranges used by a gateway endpoint ([S3 gateway endpoint requirements](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html)).

**Verdict:** the endpoint policy itself is permissive, but the supplied network configuration does not prove that the host can complete HTTPS traffic to it; as shown, the ACL does not authorize the required path. A route-table association and suitable S3 CIDR/return-port ACL rules would be needed to establish reachability. The S3 endpoint must not be reported as proven reachable from this JSON alone.
