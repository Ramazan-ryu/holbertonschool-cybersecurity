# Findings

## Rating scale

**Critical** is reserved for the demonstrated cross-domain path to production deployment and operational-restricted telemetry. **High** is a substantial weakness with meaningful exposure but without the same demonstrated end-to-end consequence. **Medium** and **Low** are bounded weaknesses whose likely impact, reach, or evidence is materially narrower. Ratings describe consequence, not scanner output.

## F-01 — Build-to-platform deployment path reaches restricted telemetry

**Rating: Critical — the single highest-priority finding.**

The platform identity export and `infrastructure/identity/gp-deploy.tf` show that platform role `gp-deploy` trusts build-account role `ci-runner`; the attached `gp-deploy-policy` grants `eks:*` and broad S3 object actions on `*`. The cluster export gives the platform deployer permission to update and patch deployments, and `telemetry-ingest` runs with service account `node-agent`. The platform identity export identifies EC2-trusted `gp-telemetry-reader` as the node instance-profile role and grants it `GetObject`/`ListBucket` on `gp-grid-telemetry` plus KMS decrypt on the shared key.

The successful activity records on 2026-10-19 show `ci-runner` assuming `gp-deploy` at 02:00Z, `gp-deploy` updating `telemetry-ingest` at 02:03Z, and `gp-telemetry-reader` reading `gp-grid-telemetry/load/2026-grid.ndjson` at 02:12Z. This is the material chain detailed in `3-chain.md`. The CI repository history also contains an access key in `.ci/deploy.env` (commit `d3ce67de7c82ee8db4b6855347b9c0ef1ccee0b1`, 2026-10-28). Because that commit is later than the October 19 activity, the evidence does not prove it was the credential used in that session. No credential values are reproduced.

In a current account API replay, that credential returned caller ARN `arn:aws:iam::210000000001:user/ci-runner`; the API then issued a `gp-deploy` session, which assumed `gp-telemetry-reader` and successfully read the named object. The caller ARN differs from the trust export's `arn:aws:iam::210000000001:role/ci-runner`, although the API accepted the transition. The replay proves the credential's current path, not its use on October 19; reconcile the user-versus-role identity discrepancy.

The business consequence is confirmed access to a named object of real-time regional grid load and switching telemetry, plus deployment authority over its ingestion workload. The evidence does not show control of grid equipment, external disclosure, or an outage. This path outranks all other findings because it crosses account, cluster, workload identity, storage, and key boundaries and ends in a successful read of the estate's most sensitive classified data.

## Lower-impact findings

### F-02 — Shared platform key does not meet the documented narrow custody

**Rating: Medium.** `infrastructure/storage/grid-telemetry.tf` selects `alias/gp-platform-shared`; `infrastructure/storage/kms.tf` grants the account root decrypt and data-key generation on `Resource: "*"`; and the identity export grants `gp-telemetry-reader` decrypt. This is broader than the architecture's tightly held telemetry-only key claim and contributes to the material chain. The policy excerpt does not establish that every platform role can decrypt, so the finding is limited to the shared key and demonstrated reader permission. Replace it with a telemetry-specific key and narrowly scoped grants.

### F-03 — Reporting role has broad read and discovery permissions

**Rating: Medium.** `identity-export/platform-account.json` attaches `gp-reporting-broad` (`*:Describe*`, `*:List*`, `*:Get*` on `*`) to EC2-trusted `gp-reporting`. The activity file shows ordinary reads by the reporting role. These permissions expose more metadata and readable resources than a reporting task should need, but the policy grants no write actions and the evidence does not connect it to the deployment chain. Limit it to the reporting resources and actions it uses.

### F-04 — App route contradicts the analytics isolation diagram

**Rating: Low.** `infrastructure/network/route-analytics.tf` declares a route from `rtb-app` to `10.3.0.0/24` over `pcx-app-analytics`; `vpc-subnet-03.tf` tags that CIDR as analytics. This is a real document-to-code divergence, but no supplied evidence demonstrates permitted traffic or a route from this subnet to telemetry. Confirm dashboard and pipeline dependencies, then remove or constrain the route if unnecessary. It does not approach the impact of F-01.

### F-05 — Admission enforcement differs from the architecture statement

**Rating: Low.** The architecture claims pod security is enforced in every namespace. `cluster-export/admission/bindings.yaml` binds policy `pod-security-baseline` with `validationActions: [Audit]`, which records violations for review rather than rejecting them at admission. This is a real enforcement divergence, but no violating workload or connection to the telemetry read is evidenced. Confirm the intended policy mode with platform owners and test workloads before changing it.

### F-06 — App HTTPS ingress uses a broad private source range

**Rating: Low.** `infrastructure/network/sg-app-00.tf` through `sg-app-05.tf` allow TCP/443 from `10.0.0.0/8`, rather than named service ranges. This is broader than least privilege but is not internet-wide, and no evidence connects it to the restricted telemetry path. Narrow the source ranges after identifying required callers.

## Alarming conditions cleared as sound

- **Bucket named `granite-peak-public-grid-data`: no public read path in the supplied policy.** I checked the whole `infrastructure/storage/public-grid-data.tf` resource: it has one bucket-policy statement, an explicit `Deny` for every S3 action, every principal (`*`), and every resource (`*`) whenever `aws:SourceVpce` is not exactly `vpce-gp-prod`. There is no `Allow` statement in this bucket policy. A request from outside the named endpoint therefore matches the deny; a request through that endpoint is not granted access by this policy and would still need a separate allow. The alarming bucket name and wildcard principal occur in a deny, not an allow. This clears anonymous/public access as a finding from the supplied configuration; the deployed endpoint and policy were not separately read through the account API.
- **ClusterRole named `cluster-admin-break-glass`: the exported role is read-only and unbound.** In `cluster-export/clusterroles.yaml` the role has only core API `pods` with verbs `get` and `list`; it has no write, exec, secret, or cluster-administration verbs. I checked both binding inventories: `cluster-export/clusterrolebindings.yaml` binds only `platform-deployer`, and `cluster-export/rolebindings.yaml` binds a namespaced `sandbox-admin` Role, not this ClusterRole. Thus the broad-sounding name has neither broad permissions nor a subject bound to it in the exported cluster state. No cluster-admin capability is established.
- **Terraform policy `gp-break-glass`: not an effective grant in the supplied identity export.** `infrastructure/identity/star-action.tf` defines a wildcard `Allow`, but only if the caller has principal tag `break-glass=approved`; this condition alone is not the basis for clearance. The platform identity export lists all attached policies for its exported roles and its complete policy inventory: it contains `gp-deploy-policy`, `gp-telemetry-read`, and `gp-reporting-broad`, but no `gp-break-glass`, and no role's `attached` list names it. The Terraform tree also has no policy-attachment resource for `gp-break-glass`. With no attachment in the supplied deployed-state inventory, this statement grants no role the wildcard actions; the alarming policy definition is not an effective privilege in that snapshot. Live IAM attachment/tag enumeration was not available: the account API denied `iam:ListEntitiesForPolicy` and `iam:ListRoles` to the assessment identity. The clearance is therefore bounded to the supplied Terraform and identity-export state, not a claim about a later live change.
- **App HTTPS rules are private-source rules, with a separate least-privilege gap.** `sg-app-00.tf` through `sg-app-05.tf` each allow TCP/443 from `10.0.0.0/8`, not `0.0.0.0/0`; that clears internet-wide ingress. Because the private range is broader than named callers, the rule remains F-06 at Low severity rather than being cleared as fully least-privileged.

## Sound controls observed

The operational telemetry bucket has an SSE-KMS default-encryption declaration in `infrastructure/storage/grid-telemetry.tf`; the live object response did not include encryption metadata, and the reader identity could not query bucket encryption. I therefore treat the declared encryption as source evidence, not a live-verified control. The three alarming conditions above are cleared only to the extent shown by the cited full policy/RBAC/export state; the `gp-break-glass` live attachment state remains unverified because IAM list calls were denied.
