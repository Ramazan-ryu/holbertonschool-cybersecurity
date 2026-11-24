# Granite Peak Energy — Cloud Assessment Report

## Executive summary

Our review confirmed that a credential exposed in Granite Peak's software repository can reach the production environment and read a file containing real-time regional grid load and switching information. If someone used the same production access to change or stop the service collecting that information, operators could rely on stale or inaccurate readings during balancing, fault response, and restoration. That could delay recovery and increase reliability and safety risks. We found no evidence of a grid-control action, outage, external disclosure, or customer impact.

I ask the board to authorize immediate deactivation of the exposed credential and a temporary hold on automated production releases until a replacement access method is verified. Direct operations, security, and counsel to review access to the restricted data. The assessment account lacked permission to deactivate the credential; an account administrator must apply the fix. The credential in repository history was committed on October 28, after the October 19 logged read, so it is not proven to have caused that earlier event. Our current test did confirm that the repository credential works today. The other findings concern broader key access, reporting permissions, and network or admission settings; they are lower priority. We did not determine how many other records were accessed or whether data was disclosed outside Granite Peak.

## Scope and method actually followed

The review covered the supplied architecture, Terraform, identity exports for build account `210000000001` and platform account `210000000002`, cluster exports, platform repository history, and the fortnightly activity record. It compared documented claims with built-state declarations and traced the account trust, cluster deployment capability, workload identity, object access, and encryption-key relationships into the audit events.

The initial interactive AWS CLI replay failed because command text was entered at the credential prompt. A corrected non-interactive replay succeeded: `get-caller-identity` confirmed the repository credential as IAM user `user/ci-runner`, STS returned the `gp-deploy` and `gp-telemetry-reader` identities, and `s3api get-object` read the named 4,368-byte object to `/dev/null`. Attempts to deactivate the key and update the trust policy were denied by the account API (`AccessDenied` for `iam:UpdateAccessKey` and `iam:UpdateAssumeRolePolicy`), so no live remediation or post-fix denial test is claimed. Network reachability, full effective IAM permissions, and complete admission behavior were not independently tested. The object response had null encryption metadata; `get-bucket-encryption` and `kms:DescribeKey` inspection calls were denied to the reader identity, so encryption configuration is supported by Terraform rather than those API reads.

## Findings

### F-01 — Build identity reached production deployment and telemetry access

**Critical; highest priority.** `infrastructure/identity/gp-deploy.tf` trusts build role `ci-runner`; `identity-export/platform-account.json` shows `gp-deploy-policy` grants `eks:*` and wildcard S3 object actions. `cluster-export/clusterrolebindings.yaml` binds the platform deployer to a role with deployment update and patch rights. `cluster-export/workloads/platform/deployments.yaml` shows `telemetry-ingest` running as `node-agent`. The identity export identifies EC2-trusted `gp-telemetry-reader` as the node instance-profile role, with S3 read access to `gp-grid-telemetry` and KMS decrypt on the shared key.

The activity log at `granite-peak/activity/granite-peak-trail.jsonl` records, with `errorCode: null`, `ci-runner` assuming `gp-deploy` at 2026-10-19 02:00Z; assumed `gp-deploy` updating `telemetry-ingest` in `platform` at 02:03Z; and `gp-telemetry-reader` reading `gp-grid-telemetry/load/2026-grid.ndjson` at 02:12Z. This is the highest consequence because it crosses account, cluster, workload, identity, storage, and key boundaries and ends in a successful read of Granite Peak's most sensitive classified data.

The repository history contains a CI access key in `.ci/deploy.env`, commit `d3ce67de7c82ee8db4b6855347b9c0ef1ccee0b1`, dated 2026-10-28. That is nine days after the activity events; the record does not prove it was used for the October 19 session. No secret values are reproduced. The exact deployment payload, number of objects accessed, and any external disclosure are not established.

In the live replay, that repository credential returned caller ARN `arn:aws:iam::210000000001:user/ci-runner`, while the trust export names `arn:aws:iam::210000000001:role/ci-runner`. The account API nevertheless accepted the subsequent assume-role call to `gp-deploy`. This caller/principal mismatch should be reconciled with the account owner; the successful API response, not an assumed equivalence between the ARNs, proves the tested transition.

### F-02 — Shared platform key does not meet documented narrow custody

**Medium.** `infrastructure/storage/grid-telemetry.tf` selects `alias/gp-platform-shared`; `infrastructure/storage/kms.tf` allows account-root decrypt and data-key generation on `Resource: "*"`; and the identity export grants `gp-telemetry-reader` decrypt. This conflicts with the architecture's tightly held, telemetry-only key claim and contributes to the main chain. The supplied policy does not establish that every platform role can decrypt.

### F-03 — Reporting role has broad read and discovery permissions

**Medium.** `identity-export/platform-account.json` attaches `gp-reporting-broad` (`*:Describe*`, `*:List*`, and `*:Get*` on `*`) to EC2-trusted role `gp-reporting`. The activity file shows ordinary reads by that role. The policy expands information access but contains no write actions in the supplied export and is not connected to the deployment path.

### F-04 — App route contradicts analytics isolation documentation

**Low.** `infrastructure/network/route-analytics.tf` declares a route from `rtb-app` to `10.3.0.0/24` over `pcx-app-analytics`; `vpc-subnet-03.tf` tags that range as analytics. The architecture diagram says there is no route. A configured route is established, but permitted connectivity and a path to telemetry are not.

### F-05 — Admission enforcement differs from the architecture statement

**Low.** The architecture says pod security is enforced in every namespace. `cluster-export/admission/bindings.yaml` binds `pod-security-baseline` with `validationActions: [Audit]`, recording policy violations instead of rejecting them at admission. No violating workload or connection to the telemetry access is evidenced.

### F-06 — App HTTPS ingress uses a broad private source range

**Low.** `infrastructure/network/sg-app-00.tf` through `sg-app-05.tf` permit TCP/443 from `10.0.0.0/8`, not workload-specific source ranges. This is broader than necessary but not internet-wide and is not linked to the telemetry chain.

## Cleared conditions and sound controls

The bucket named `granite-peak-public-grid-data` is not shown to be anonymously readable: `infrastructure/storage/public-grid-data.tf` denies all S3 actions to any principal unless the request uses `vpce-gp-prod`. The name alone does not establish public access. The `cluster-admin-break-glass` ClusterRole is limited to pod `get` and `list`, and no binding to it appears in the supplied cluster role bindings. The Terraform `gp-break-glass` policy has wildcard actions/resources only when `aws:PrincipalTag/break-glass` equals `approved`; the supplied identity export shows no attachment or qualifying principal, so the wildcard does not establish an effective unrestricted grant. App security groups allow private `10.0.0.0/8`, not the public internet. These checks clear the stated alarming indicators, not unreviewed deployed state.

## Material chain and business impact

The full chain and evidence for each transition are in `3-chain.md`. The repository credential was executed against the account API and identified as `ci-runner`; that identity successfully assumed `gp-deploy`; the cluster configuration and October 19 audit event establish the deployment role's update capability and its successful `telemetry-ingest` update; the workload configuration associates the deployment with `node-agent`; from the `gp-deploy` session, the assessment successfully assumed `gp-telemetry-reader` and read `load/2026-grid.ndjson`. The repository credential commit is later than the October 19 event and is not claimed as that session's credential source.

The demonstrated result is access to one named object classified by the architecture as real-time grid load and switching telemetry. Inference from that documented function: access to current load and switching state could help an attacker identify operating conditions or choose a time and target for disruption. A deployment change that alters or stops `telemetry-ingest` could leave operators with inaccurate or stale telemetry during balancing, fault response, and restoration, delaying diagnosis and recovery and increasing reliability and safety risk. The evidence does not show telemetry was altered, grid equipment was controlled, an outage occurred, or a customer was affected. The chain crosses teams responsible for CI, account trust, cluster deployment, workload identity, and data/key management, so reviewing each team's configuration in isolation would miss how the path composes.

## Remediation programme

1. **Contain the material path.** Deactivate the repository-exposed key, reconcile the `user/ci-runner` versus `role/ci-runner` principal discrepancy, and suspend production deployment until a short-lived, narrowly scoped replacement is ready. Reduce `eks:*` and wildcard S3 rights. This pauses the existing deployment pipeline while CI and IAM owners replace its identity. The account API denied both `iam:UpdateAccessKey` and `iam:UpdateAssumeRolePolicy` to the assessment identity, so an authorized IAM administrator must apply containment. The post-fix chain is derived, not live-verified.
2. **Remove telemetry access from node credentials.** Give the intended workload a dedicated identity, block pod access to node credentials, and remove telemetry permissions from the node role. Test ingestion before rollout; incorrect scoping can interrupt telemetry ingestion.
3. **Replace and narrow the shared key.** Create a telemetry-specific key with grants for the approved workload and key administrators; plan re-encryption and recovery testing to preserve access to historical data.
4. **Narrow reporting permissions.** Replace broad `Get`/`List`/`Describe` access with only the reporting actions and resources required. Confirm workloads before removing permissions.
5. **Resolve lower-impact divergences.** Confirm analytics dependencies before removing or restricting the app route; validate admission enforcement with representative workloads; narrow app HTTPS sources from `10.0.0.0/8` to needed callers. These changes require service-owner testing.
6. **Verify and correct records.** Confirm deployed logging, seven-year retention, endpoint policy, key policy, and admission state, then update architecture documentation to verified state. This work depends on access to complete deployed configuration and governance owners.

If only the first item is completed, it removes the broad build-to-production transition while the remaining work addresses workload credential isolation and key access. The detailed sequence and operating costs are in `4-remediation/4-programme.md`.

## Detection guidance from Granite Peak's records

The earliest detection signal is the new action by the build identity, not the final data read. On day 9 after this activity file begins (2026-10-19), `ci-runner` assumed production role `gp-deploy` at 02:00Z. This is the only `ci-runner` assume-role event in the supplied fortnight. Three minutes later, `gp-deploy` updated `telemetry-ingest` in namespace `platform`; this is the only deployment update by that identity in the file. Nine minutes later, `gp-telemetry-reader` read `gp-grid-telemetry/load/2026-grid.ndjson`. These events appear amid ordinary work: for example, `gp-app-03` listed S3 objects at 02:28Z, `gp-app-17` described EC2 instances at 02:41Z, and `gp-app-00` listed S3 objects at 02:48Z. Alert on a first-observed `ci-runner` assumption into `gp-deploy` and especially on the following new `UpdateDeployment` by that role; use the later reader-role `GetObject` as corroboration and to scope the event, not as the first signal. Correlate `eventTime`, `userIdentity.arn`, `eventSource`, `eventName`, `requestParameters.roleArn`, deployment `name` and `namespace`, and S3 `bucketName` and `key`. Preserve these records and inspect the full deployment request and adjacent storage/key events.

## Data classification and counsel handoff

The architecture document identifies the data as real-time grid load and switching telemetry, classifies it as `operational-restricted`, and states that the category requires authorized access, adequate protection at rest, access logging, and seven-year retention. It further states that failure of access control or protection is a reportable condition requiring access review and client notification. The activity record establishes that `gp-telemetry-reader` read `load/2026-grid.ndjson` at 2026-10-19 02:12Z. The same object was successfully read during the assessment replay on 2026-11-25 by the `gp-telemetry-reader` session reached through `gp-deploy`; the exact replay timestamp was not retained. The activity export spans 2026-10-10 through 2026-10-23, but does not establish the first exposure date, continuous access, all affected records, or external disclosure. The identity export and workload configuration establish the reader role and its association with the telemetry node; the successful API replay establishes that `gp-deploy` could obtain that reader identity and read the object. Because the successful reader access is inconsistent with the documented telemetry-service-only access control, the facts meet Granite Peak's own stated condition for access review and client notification. Granite Peak counsel must determine the legal effect and any external notification duty after confirming scope and applicable obligations; this report does not make that legal determination.

## Limitations

The pre-fix identity and storage path was executed successfully, but key deactivation and the trust-policy change were denied (`iam:UpdateAccessKey` and `iam:UpdateAssumeRolePolicy`); no post-fix execution was possible. The full admission binding, network connectivity, complete effective IAM evaluation, deployed logging and retention settings, full audit history, exact deployment payload, pod-to-node credential endpoint, and actual data egress were not independently assessed. The October 19 CI session is not tied to the credential committed on October 28. Conclusions are bounded to the supplied artefacts, executed API responses, and activity window; lack of evidence is not treated as proof that unreviewed controls are safe.
