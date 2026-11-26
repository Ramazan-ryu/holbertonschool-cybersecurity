# 11 — Reply to Marlowe Commerce

Dear Marlowe team,

Our review found that the catalog image-import feature fetches a caller-selected URL. The preview and redirect controls refused the tested metadata destination, while image import returned the instance metadata credentials. STS identified `marlowe-web-instance-role`. Calls using that identity read one order document, received one customer event, and retrieved the webhook-signing secret. The role could not list IAM users, and we did not test write access.

The instance role also assumed `marlowe-order-processor-role`. The resulting `perimeter-review` session was confirmed by STS and successfully listed S3 buckets, secret names, queue names, and IAM users; its DynamoDB table listing succeeded with an empty result. Separately, the handler source contains seven provider actions. The `fn-review` session made six manual inventory calls outside those code paths. Lambda configuration was not returned, so we cannot confirm that the deployed function is attached to this role or claim that a Lambda invocation made those calls.

A previous medium rating was reasonable when the review had only the application URL-fetch finding. The rating changed after we learned that tokenless metadata returned a real workload identity and demonstrated its reach to order data, a customer event, a signing secret, and a second role. The application feature owner, platform or cloud owner of metadata and roles, and resource owners held separate parts of this picture. No joint review combined those facts into one impact decision.

The two paths meet at the same authority boundary: a request can bring attacker-chosen input into a workload, and code from a changed or compromised package can run inside a workload; in either case, code there can act with the workload identity. The package scan did not prove that its flagged dependencies are exploitable through this handler, and Lambda role attachment remains unverified. These limits matter: we describe the package route as a risk to assess, not an observed compromise.

Strong metadata mode blocked the tested tokenless credential request with HTTP 502 and no credential fields. This protects the metadata service for that request; image import still accepts attacker-controlled destinations. Apply strict destination allowlisting, validate schemes and resolved addresses, recheck redirects, and restrict outbound egress. Separately, an authorized account administrator must apply the proposed least-privilege function policy. It was not applied because `iam:CreatePolicyVersion` was denied. After the change, verify under a fresh function-role session that `iam:ListUsers` is refused and a required call such as `secretsmanager:GetSecretValue` succeeds.

We recommend a repeatable review before deployment. Application, platform or cloud, and security owners should jointly decide the compute identity, IMDS setting, and code-derived role permissions. Reassess them when code, dependencies, configuration, or roles change. Selecting an instance role, function role, or metadata mode determines what code in that workload can become and reach; it is an engineering security decision, not just an infrastructure setting.

For detection, monitor STS `AssumeRole` events targeting `marlowe-order-processor-role`. Record the caller, target, session name, time, source address, and available runtime or network context; compare them with an owner-approved principal and origin baseline. Correlate the event with `GetCallerIdentity` and later API calls. The observed instance-role-to-function-role transition is a candidate signal for review, not proof of unauthorized use. The export is lab-generated, its signature cannot be independently verified here, and `127.0.0.1` appears for workload and reviewer calls; it does not prove an impossible origin. Approved testing, deployment tools, break-glass work, proxies, failover, and architecture or egress changes can create valid mismatches. Keeping the baseline current and investigating alerts takes staff time; no false-positive rate has been measured.

Regards,

Latchkey Security
