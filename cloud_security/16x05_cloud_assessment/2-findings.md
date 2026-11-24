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

**Rating: Low.** The architecture claims pod security is enforced in every namespace. The exported `cluster-export/admission/bindings.yaml` contains `validationActions`, indicating a validation-action configuration rather than the stated enforced mode. The supplied evidence does not show that a violating workload was admitted or that this setting enabled the telemetry path. Confirm the full binding and set the intended enforcement mode after testing workloads.

### F-06 — App HTTPS ingress uses a broad private source range

**Rating: Low.** `infrastructure/network/sg-app-00.tf` through `sg-app-05.tf` allow TCP/443 from `10.0.0.0/8`, rather than named service ranges. This is broader than least privilege but is not internet-wide, and no evidence connects it to the restricted telemetry path. Narrow the source ranges after identifying required callers.

## Alarming conditions cleared as sound

- **Bucket named `granite-peak-public-grid-data`: cleared.** `infrastructure/storage/public-grid-data.tf` contains an explicit `Deny` for `s3:*` to `Principal: "*"` when `aws:SourceVpce` is not `vpce-gp-prod`. The policy therefore blocks requests outside the named VPC endpoint; the bucket's name does not establish public access. Verify the deployed policy and endpoint during normal change validation.
- **ClusterRole named `cluster-admin-break-glass`: cleared.** `cluster-export/clusterroles.yaml` grants only pod `get` and `list`, and no binding to this role appears in the supplied `clusterrolebindings.yaml`. Its name overstates its exported permissions; no cluster-admin capability is established.
- **`gp-break-glass` star-action policy: conditionally constrained, not a demonstrated broad privilege.** `infrastructure/identity/star-action.tf` allows `Action: "*"` and `Resource: "*"` only when `aws:PrincipalTag/break-glass` equals `approved`. The supplied identity export does not show this policy attached to a principal or a principal with that tag. Without evidence that the condition is met, the wildcard statement is not an effective unrestricted grant; do not report it as exploitable based on the wildcard alone. Validate tag assignment and attachments in routine IAM governance.
- **App security-group source is private, not public.** The cited app rules admit TCP/443 from `10.0.0.0/8`, not `0.0.0.0/0`. This is included as low-priority breadth (F-06), not an internet exposure.

## Sound controls observed

The telemetry bucket is classified in Terraform as `operational-restricted` and has server-side KMS encryption configured. The public-grid-data endpoint deny, read-only exported `cluster-admin-break-glass` role, and conditional/unattached-on-evidence `gp-break-glass` policy were examined across the relevant policy layers and are not established exposures. These clearances do not extend to controls whose complete deployed state was unavailable.
