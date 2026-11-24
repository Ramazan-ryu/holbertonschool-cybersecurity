# Material Exposure Chain

## Evidence and test method

The current credential from the platform repository was tested against Granite Peak's local account API without printing its secret. Every identity below was confirmed with `aws sts get-caller-identity`. Temporary STS credentials were held only in shell variables. The S3 object body was sent to `/dev/null`; it was not displayed or saved. Commands were run from the provided lab workstation against its preconfigured local endpoint.

The workstation transcript previously supplied by the operator contained failed attempts because text was entered into an interactive `read` prompt. Those failed attempts are superseded by the successful, non-interactive replay documented here. The October 19 activity events are also preserved as independent historical evidence. The repository commit is dated October 28, so it is not represented as the credential used on October 19.

## Step-by-step chain

### 1. Repository credential authenticates as the build identity — executed

`git log -p -S'AKIAGPDEPLOY00000CIX'` identified commit `d3ce67de7c82ee8db4b6855347b9c0ef1ccee0b1`, dated 2026-10-28, adding `.ci/deploy.env` with an access key ID and secret. The credential values are intentionally not included in this report.

The following commands loaded those values directly from that commit without displaying them and queried the account API:

```sh
export AWS_ACCESS_KEY_ID="$(git -C ~/granite-peak/repo/granite-peak-platform show d3ce67de7c82ee8db4b6855347b9c0ef1ccee0b1:.ci/deploy.env | sed -n 's/^AWS_ACCESS_KEY_ID=//p')"
export AWS_SECRET_ACCESS_KEY="$(git -C ~/granite-peak/repo/granite-peak-platform show d3ce67de7c82ee8db4b6855347b9c0ef1ccee0b1:.ci/deploy.env | sed -n 's/^AWS_SECRET_ACCESS_KEY=//p')"
aws sts get-caller-identity --output json | jq '{Account,Arn}'
```

Observed response: account `210000000001`, ARN `arn:aws:iam::210000000001:user/ci-runner`. The identity exports and deployment trust name `arn:aws:iam::210000000001:role/ci-runner`, so the live caller ARN and exported principal do not match exactly. The account API nevertheless accepted the subsequent `AssumeRole` call in step 2. This proves the committed credential is currently accepted as `user/ci-runner` and can enter `gp-deploy` through the account API; it does not prove this credential was used for the October 19 events, which predate the commit. Reconcile the user-versus-role discrepancy with the account owner.

### 2. Build identity assumes the platform deployment role — executed

`infrastructure/identity/gp-deploy.tf` and `identity-export/platform-account.json` name `arn:aws:iam::210000000001:role/ci-runner` as a trusted principal for `gp-deploy`. The exported `gp-deploy-policy` grants `eks:*` and S3 object read/write actions on wildcard resources. The API call below succeeded:

```sh
aws sts assume-role \
  --role-arn arn:aws:iam::210000000002:role/gp-deploy \
  --role-session-name assessment-chain --output json
```

The returned temporary credentials were loaded into the environment without printing them. A subsequent `aws sts get-caller-identity` returned account `210000000002`, ARN `arn:aws:sts::210000000002:assumed-role/gp-deploy/assessment-chain`. This directly proves the transition from the credential in step 1 to the platform role.

### 3. The deployment role changed the telemetry workload — historical execution plus configuration evidence

`cluster-export/clusterrolebindings.yaml` binds service account `deployer` in namespace `platform` to `platform-deployer`. `cluster-export/clusterroles.yaml` grants that role `get`, `list`, `update`, and `patch` on deployments. `cluster-export/workloads/platform/deployments.yaml` identifies `telemetry-ingest` and sets `serviceAccountName: node-agent`.

The activity record `granite-peak/activity/granite-peak-trail.jsonl` independently records a successful EKS `UpdateDeployment` by `arn:aws:sts::210000000002:assumed-role/gp-deploy/ci-session` for `telemetry-ingest` in namespace `platform` at `2026-10-19T02:03:00Z` (`errorCode: null`). The preceding event at `02:00:00Z` records build `ci-runner` assuming `gp-deploy`, also with no error. This establishes that the deployment role performed an accepted update on the exact target. The exported event does not retain the patch body, so this assessment does not claim a specific malicious field was changed. The deployment already uses `node-agent`, and the exported RBAC permits update and patch of deployments; that capability allows a deployment change to run altered container code under the existing workload identity. The subsequent live API replay independently proves that the `gp-deploy` session can obtain the node reader identity and access the data.

### 4. Deployment session assumes the workload's node identity — executed

The identity export identifies `gp-telemetry-reader` as an EC2-trusted node instance-profile role. The telemetry deployment uses `node-agent`. From the `gp-deploy/assessment-chain` session created in step 2, this API call succeeded:

```sh
aws sts assume-role \
  --role-arn arn:aws:iam::210000000002:role/gp-telemetry-reader \
  --role-session-name assessment-node --output json
```

After loading only the returned temporary credentials, `aws sts get-caller-identity` returned account `210000000002`, ARN `arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/assessment-node`. This is an executed account-side proof that the deployment session can obtain the same reader identity associated with the telemetry workload's node. It is not a Kubernetes pod-level test of the credential endpoint; that exact pod-to-node mechanism was not independently exercised.

### 5. Node identity reads the classified telemetry object — executed

`identity-export/platform-account.json` grants `gp-telemetry-reader` `s3:GetObject` and `s3:ListBucket` on `gp-grid-telemetry`, and KMS decrypt on `gp-platform-shared`. `infrastructure/storage/grid-telemetry.tf` configures the bucket to use `alias/gp-platform-shared`. With the `assessment-node` credentials active, the following call succeeded:

```sh
aws s3api get-object \
  --bucket gp-grid-telemetry \
  --key load/2026-grid.ndjson \
  /dev/null
```

The API response reported `ContentLength: 4368` and `LastModified: 2026-11-24T04:49:11+00:00`; the object body went to `/dev/null`. The returned metadata had null `ServerSideEncryption` and `SSEKMSKeyId` fields, so this particular response does not independently confirm the object's encryption metadata. `get-bucket-encryption` was denied to this identity, and `kms:DescribeKey` was also denied; encryption configuration is therefore supported by Terraform, not by those API reads. The successful object read proves the identity's effective data access regardless of those inspection denials.

The architecture classifies real-time grid load and switching telemetry as **operational-restricted**, states that only the telemetry service identity should access it, and specifies access logging and seven-year retention. The tested object key identifies the affected record; the object body was not inspected.

## Historical audit signal

The fortnightly audit record at `granite-peak/activity/granite-peak-trail.jsonl` shows this sequence on 2026-10-19:

| UTC time | Caller | Event | Result |
|---|---|---|---|
| 02:00 | `arn:aws:iam::210000000001:role/ci-runner` | STS `AssumeRole`, target `gp-deploy` | `errorCode: null` |
| 02:03 | `arn:aws:sts::210000000002:assumed-role/gp-deploy/ci-session` | EKS `UpdateDeployment`, `telemetry-ingest`, `platform` | `errorCode: null` |
| 02:12 | `arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/i-node` | S3 `GetObject`, `gp-grid-telemetry/load/2026-grid.ndjson` | `errorCode: null` |

The CI credential commit is nine days later than these events. The historical records prove the successful identities and actions, but do not identify which credential authenticated the October 19 `ci-runner` session. The current API replay proves that the credential now in repository history authenticates as `user/ci-runner` and reproduces the role/data access path. This differs from the `role/ci-runner` principal recorded in the trust export and historical event; the successful live `AssumeRole` response proves that the current API permits the transition.

## Why this is a cross-domain chain

Repository history supplies a credential that the API currently accepts as IAM user `user/ci-runner`; this caller ARN differs from the exported trusted role ARN. The API nevertheless allowed that caller to enter `gp-deploy`; from there the assessment assumed the node reader identity and read the object. The cluster export and historical audit event separately prove the workload-update capability and its prior use. Each component sits in a different account, cluster, workload, or storage control area, so a single-domain review would miss their composition.

## Business consequence and bounds

An actor with access to the repository credential can assume the production deployment role, and the reproduced role path can obtain the node reader identity and read a 4,368-byte telemetry object. The data is classified by Granite Peak as real-time grid load and switching telemetry. Deployment authority also creates a credible risk to the integrity or availability of telemetry ingestion. The evidence does not show that grid equipment was controlled, that grid operations were changed, that data left the workstation, or that an outage occurred. The historical record confirms the same kinds of role transition, workload update, and object read on October 19, but does not tie that session to the later-committed credential.
