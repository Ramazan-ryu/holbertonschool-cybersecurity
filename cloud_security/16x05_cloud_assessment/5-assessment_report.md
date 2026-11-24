# Granite Peak Energy — Cloud Assessment Report

## Executive summary

Granite Peak's activity records show that its build identity entered the production deployment role, changed the telemetry workload, and was followed by a successful read of a grid telemetry object. The architecture classifies real-time grid load and switching data as operational-restricted. This establishes access to at least one object and a serious risk to the confidentiality of operational information and the integrity of its telemetry service. The records do not establish external disclosure, the number of other objects accessed, or an effect on grid switching operations. A CI credential also appears in repository history, but the commit is dated nine days after the logged access, so it is not proven to be the credential used in that session.

I recommend that leadership direct an immediate access review, revoke the repository-exposed CI credential, and suspend the build role's production trust until a short-lived replacement is approved. Ask platform operations and counsel to determine the full access scope and applicable response. The shared key and other access-control gaps need remediation, but they do not outrank the demonstrated deployment-to-data path. An independent CLI replay and post-fix validation remain outstanding.

## Scope and method actually followed

The review covered the supplied architecture, Terraform, identity exports for build account `210000000001` and platform account `210000000002`, cluster exports, platform repository history, and the fortnightly activity record. It compared documented claims with built-state declarations and traced the account trust, cluster deployment capability, workload identity, object access, and encryption-key relationships into the audit events.

The attempted AWS CLI replay did not complete: the interactive credential prompt was not answered as intended, so subsequent commands had incomplete or absent credentials. The successful activity events (`errorCode: null`) identify callers and accepted actions, but the supplied terminal output contains no successful `aws sts get-caller-identity` result or separate permission-test response. No live post-remediation test is claimed. Network reachability, full effective IAM permissions, and complete admission behavior were not independently tested.

## Findings

### F-01 — Build identity reached production deployment and telemetry access

**Critical; highest priority.** `infrastructure/identity/gp-deploy.tf` trusts build role `ci-runner`; `identity-export/platform-account.json` shows `gp-deploy-policy` grants `eks:*` and wildcard S3 object actions. `cluster-export/clusterrolebindings.yaml` binds the platform deployer to a role with deployment update and patch rights. `cluster-export/workloads/platform/deployments.yaml` shows `telemetry-ingest` running as `node-agent`. The identity export identifies EC2-trusted `gp-telemetry-reader` as the node instance-profile role, with S3 read access to `gp-grid-telemetry` and KMS decrypt on the shared key.

The activity log at `granite-peak/activity/granite-peak-trail.jsonl` records, with `errorCode: null`, `ci-runner` assuming `gp-deploy` at 2026-10-19 02:00Z; assumed `gp-deploy` updating `telemetry-ingest` in `platform` at 02:03Z; and `gp-telemetry-reader` reading `gp-grid-telemetry/load/2026-grid.ndjson` at 02:12Z. This is the highest consequence because it crosses account, cluster, workload, identity, storage, and key boundaries and ends in a successful read of Granite Peak's most sensitive classified data.

The repository history contains a CI access key in `.ci/deploy.env`, commit `d3ce67de7c82ee8db4b6855347b9c0ef1ccee0b1`, dated 2026-10-28. That is nine days after the activity events; the record does not prove it was used for the October 19 session. No secret values are reproduced. The exact deployment payload, number of objects accessed, and any external disclosure are not established.

### F-02 — Shared platform key does not meet documented narrow custody

**Medium.** `infrastructure/storage/grid-telemetry.tf` selects `alias/gp-platform-shared`; `infrastructure/storage/kms.tf` allows account-root decrypt and data-key generation on `Resource: "*"`; and the identity export grants `gp-telemetry-reader` decrypt. This conflicts with the architecture's tightly held, telemetry-only key claim and contributes to the main chain. The supplied policy does not establish that every platform role can decrypt.

### F-03 — Reporting role has broad read and discovery permissions

**Medium.** `identity-export/platform-account.json` attaches `gp-reporting-broad` (`*:Describe*`, `*:List*`, and `*:Get*` on `*`) to EC2-trusted role `gp-reporting`. The activity file shows ordinary reads by that role. The policy expands information access but contains no write actions in the supplied export and is not connected to the deployment path.

### F-04 — App route contradicts analytics isolation documentation

**Low.** `infrastructure/network/route-analytics.tf` declares a route from `rtb-app` to `10.3.0.0/24` over `pcx-app-analytics`; `vpc-subnet-03.tf` tags that range as analytics. The architecture diagram says there is no route. A configured route is established, but permitted connectivity and a path to telemetry are not.

### F-05 — Admission enforcement differs from the architecture statement

**Low.** The architecture says pod security is enforced in every namespace. `cluster-export/admission/bindings.yaml` contains `validationActions`, inconsistent with the stated enforced mode. The supplied evidence does not show a violating workload was admitted or that this setting enabled the telemetry read.

### F-06 — App HTTPS ingress uses a broad private source range

**Low.** `infrastructure/network/sg-app-00.tf` through `sg-app-05.tf` permit TCP/443 from `10.0.0.0/8`, not workload-specific source ranges. This is broader than necessary but not internet-wide and is not linked to the telemetry chain.

## Cleared conditions and sound controls

The bucket named `granite-peak-public-grid-data` is not shown to be anonymously readable: `infrastructure/storage/public-grid-data.tf` denies all S3 actions to any principal unless the request uses `vpce-gp-prod`. The name alone does not establish public access. The `cluster-admin-break-glass` ClusterRole is limited to pod `get` and `list`, and no binding to it appears in the supplied cluster role bindings. The Terraform `gp-break-glass` policy has wildcard actions/resources only when `aws:PrincipalTag/break-glass` equals `approved`; the supplied identity export shows no attachment or qualifying principal, so the wildcard does not establish an effective unrestricted grant. App security groups allow private `10.0.0.0/8`, not the public internet. These checks clear the stated alarming indicators, not unreviewed deployed state.

## Material chain and business impact

The full chain and evidence for each transition are in `3-chain.md`. In summary: the source repository history contains a CI credential (its later commit date prevents attributing the earlier session to it); the build identity is trusted by platform role `gp-deploy`; the activity log records that role being assumed and updating `telemetry-ingest`; the cluster export associates that workload with `node-agent`; the EC2 node identity `gp-telemetry-reader` has bucket and key read rights; and the activity log records a successful read of `load/2026-grid.ndjson`.

The demonstrated result is access to one named object classified by the architecture as real-time grid load and switching telemetry. The evidence does not show the entire bucket was copied, data was disclosed outside Granite Peak, grid equipment was controlled, or an outage occurred. An attacker with deployment control could alter or disrupt telemetry ingestion; the supplied activity does not show that such an effect occurred. The chain crosses teams responsible for CI, account trust, cluster deployment, workload identity, and data/key management, so reviewing each team's configuration in isolation would miss how the path composes.

## Remediation programme

1. **Contain the material path.** Revoke the repository-exposed credential and suspend `ci-runner` trust to `gp-deploy` until a short-lived, narrowly scoped replacement is ready. Reduce `eks:*` and wildcard S3 rights. This pauses the existing deployment pipeline while CI and platform owners replace its identity. The trust-edge change is derived in `4-remediation/4-fix.md`; it was not applied to the live account.
2. **Remove telemetry access from node credentials.** Give the intended workload a dedicated identity, block pod access to node credentials, and remove telemetry permissions from the node role. Test ingestion before rollout; incorrect scoping can interrupt telemetry ingestion.
3. **Replace and narrow the shared key.** Create a telemetry-specific key with grants for the approved workload and key administrators; plan re-encryption and recovery testing to preserve access to historical data.
4. **Narrow reporting permissions.** Replace broad `Get`/`List`/`Describe` access with only the reporting actions and resources required. Confirm workloads before removing permissions.
5. **Resolve lower-impact divergences.** Confirm analytics dependencies before removing or restricting the app route; validate admission enforcement with representative workloads; narrow app HTTPS sources from `10.0.0.0/8` to needed callers. These changes require service-owner testing.
6. **Verify and correct records.** Confirm deployed logging, seven-year retention, endpoint policy, key policy, and admission state, then update architecture documentation to verified state. This work depends on access to complete deployed configuration and governance owners.

If only the first item is completed, it removes the broad build-to-production transition while the remaining work addresses workload credential isolation and key access. The detailed sequence and operating costs are in `4-remediation/4-programme.md`.

## Detection guidance from Granite Peak's records

The audit signal is an identity taking an action outside its established workload pattern amid ordinary activity. On 2026-10-19, `ci-runner` assumed `gp-deploy` at 02:00Z; three minutes later `gp-deploy` updated `telemetry-ingest` in namespace `platform`; nine minutes after that `gp-telemetry-reader` read `gp-grid-telemetry/load/2026-grid.ndjson`. The same period contains routine `gp-app-*` S3 and EC2 events. Correlate `eventTime`, `userIdentity.arn`, `eventSource`, `eventName`, `requestParameters.roleArn`, deployment `name` and `namespace`, and S3 `bucketName` and `key`. Baseline which identities normally assume deployment roles, update this workload, and access telemetry. Alert on the unexpected identity/action pair, then use later deployment and storage events to scope the event. Preserve source records and inspect the full deployment request and adjacent S3/KMS activity.

## Data classification and counsel handoff

The architecture document identifies the data as real-time grid load and switching telemetry, classifies it as `operational-restricted`, and states that the category requires authorised access, adequate protection at rest, access logging, and seven-year retention. It further states that failure of access control or protection is a reportable condition requiring access review and client notification. The chain establishes that `gp-telemetry-reader` successfully read one named object on 2026-10-19; the activity export covers 2026-10-10 through 2026-10-23. It does not establish the first possible exposure date, all affected records, external disclosure, or whether logging and retention controls operated. The reader's successful access is inconsistent with the documented telemetry-service-only access control, so the client-provided condition for review is present. Granite Peak counsel must determine the legal effect and any required notification after confirming scope and applicable obligations; this report does not make that legal determination.

## Limitations

The AWS CLI replay did not succeed because the interactive credential prompt was not completed correctly; no successful `get-caller-identity` output or separate permission-test response was supplied. No live remediation was applied or post-fix execution obtained. The full admission binding, network connectivity, complete effective IAM evaluation, deployed logging and retention settings, full audit history, deployment payload, and actual data egress were not independently assessed. Conclusions are bounded to the supplied artefacts and activity window; lack of evidence is not treated as proof that unreviewed controls are safe.
