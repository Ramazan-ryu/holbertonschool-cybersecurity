Both chains ended in the same place: code running as a trusted workload and inheriting that workload's cloud permissions, whether the code arrived as a web request or shipped inside a deployment package."

Consequence for how they build. Compute identity is a security decision, not an infrastructure detail. The role an instance or function runs under, and whether its metadata is protected, determines what any code running there can reach. Today that choice is made by whoever is closest to a deadline. It should be owned jointly by the application or platform team and security, and reviewed before every deployment and whenever code, dependencies, configuration or roles change, not after an incident.

The one detection. Alert when a workload's role session is used from outside its expected runtime boundary: source address, network path, account or service origin. This signal would have flagged both chains. The instance-role session was used from a source outside its expected boundary, then assumed the processor role. We cannot yet confirm that boundary from documentation, so the owner must define it first. It is the highest-value signal because it fires on misuse of the identity itself, whatever the entry point.

Honest cost. Expected boundaries must be maintained as exceptions. Approved testing, deployment tooling, proxies, failover and architecture changes will trip the alert until those attributes are updated. We have not measured a false-alarm rate for your environment, and expect noise until a baseline is built from your logs. Budget engineering time for exception review, or the alert will be switched off.





























# 11 — Reply to Marlowe Commerce

Dear Marlowe team,

Our review confirmed that the catalog image-import feature fetches a caller-selected URL. The preview and redirect controls rejected the metadata destination, but image import returned the instance metadata credentials. STS identified the resulting principal as `marlowe-web-instance-role`; live calls proved it could read an order document, receive a customer event, and retrieve the Stripe webhook-signing secret. This is an identity exposure with demonstrated data access, not only an application-layer issue.

We also assumed `marlowe-order-processor-role` through the instance role and confirmed it can enumerate two S3 buckets, one secret, one SQS queue, and four IAM users. The handler makes seven operations across four services; the attached `v1` policy includes broad S3, DynamoDB, SQS, IAM, KMS, Logs, and SES permissions. The least-privilege replacement is prepared in the deliverables, but both `appsec-reviewer` and the instance role were denied `iam:CreatePolicyVersion`; the policy remains unchanged pending an authorized account administrator. The exact forged request was later replayed under strong metadata mode and returned HTTP 502 without credential fields.

We recommend enabling and retaining the stronger metadata mode immediately, then applying the scoped function-role policy and verifying both a refused excess call and a successful handler-required call. These are separate controls: fixing the image-import route alone would not prevent other paths to instance metadata, while narrowing the function role limits the impact of code executing in that function. The role remediation remains unverified pending the policy update and paired calls.

The network review found a real reply-path issue in the stateless application ACL and broad security-group egress that is constrained by the ACL. The app-to-analytics path is not transitive through the data VPC. The S3 endpoint policy is permissive, but the supplied ACL and route details do not establish a complete host-to-endpoint path. The dependency scan found vulnerable pinned versions of PyYAML and `requests`; the handler source does not import either, so exploitability through this handler was not demonstrated. Finally, we have not yet validated the audit anomaly against the signed activity export and CloudTrail event bodies, or retrieved Lambda environment configuration because the configuration API returned `SignatureDoesNotMatch`.

Regards,
Latchkey Security

