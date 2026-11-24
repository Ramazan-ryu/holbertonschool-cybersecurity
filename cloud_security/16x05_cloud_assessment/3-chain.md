# Material Exposure Chain

## Evidence standard and execution

The chain below combines repository history, Terraform and cluster exports, historical account activity, and a successful replay against Granite Peak's local account API. The credential secret and temporary credentials are not printed here. The object body was written to `/dev/null`, not displayed or saved.

The operator loaded the access key and secret from commit `d3ce67de7c82ee8db4b6855347b9c0ef1ccee0b1` into profile `ci`. `aws sts get-caller-identity --profile ci` returned account `210000000001` and ARN `arn:aws:iam::210000000001:user/ci-runner`. The operator then assumed `gp-deploy`; the resulting caller identity was account `210000000002`, ARN `arn:aws:sts::210000000002:assumed-role/gp-deploy/chain-check`. From that session, the operator assumed `gp-telemetry-reader`; the resulting caller identity was account `210000000002`, ARN `arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/chain-check-node`. Finally, `s3api get-object` succeeded for the telemetry object.

The live caller is an IAM **user**, while the identity export and `gp-deploy` trust policy name an IAM **role** `arn:aws:iam::210000000001:role/ci-runner`. The account API accepted the assume-role call despite this mismatch. Record this as an unresolved identity discrepancy; rely on the successful API response for the tested transition, not on an assumption that the user and role ARNs are interchangeable.

## Steps

### 1. A credential in repository history authenticates to the build account — executed

The supplied `git log -p -S'gpCIdeploySECRET'` output shows commit `d3ce67de7c82ee8db4b6855347b9c0ef1ccee0b1`, dated 2026-10-28, adding `.ci/deploy.env` with an AWS access key ID and secret. The values are omitted. Using those values, `aws sts get-caller-identity --profile ci` returned:

```json
{
  "Account": "210000000001",
  "Arn": "arn:aws:iam::210000000001:user/ci-runner"
}
```

This proves that the committed credential was accepted by the account API as the listed IAM user at assessment time. It does not prove the credential was used for the separate 2026-10-19 activity sequence, which predates the commit by nine days.

### 2. The authenticated caller obtains the platform deployment role — executed

`infrastructure/identity/gp-deploy.tf` and `identity-export/platform-account.json` show the cross-account trust to `ci-runner`. The identity export attaches `gp-deploy-policy`, which allows `eks:*` and S3 object read/write actions on wildcard resources. The operator executed:

```sh
aws --profile ci sts assume-role \
  --role-arn arn:aws:iam::210000000002:role/gp-deploy \
  --role-session-name chain-check --output json
```

After loading the returned temporary credentials into profile `deploy`, `aws sts get-caller-identity --profile deploy` returned:

```json
{
  "Account": "210000000002",
  "Arn": "arn:aws:sts::210000000002:assumed-role/gp-deploy/chain-check"
}
```

The successful STS response and caller identity prove the transition from the repository credential to `gp-deploy` against the account API.

### 3. The deployment role can update the telemetry workload — cluster evidence and historical execution

`cluster-export/clusterrolebindings.yaml` binds service account `deployer` in namespace `platform` to `platform-deployer`. `cluster-export/clusterroles.yaml` gives that role `get`, `list`, `update`, and `patch` on deployments. `cluster-export/workloads/platform/deployments.yaml` identifies deployment `telemetry-ingest` and sets `serviceAccountName: node-agent`.

The activity file `granite-peak/activity/granite-peak-trail.jsonl` records a successful EKS `UpdateDeployment` by `arn:aws:sts::210000000002:assumed-role/gp-deploy/ci-session` for `telemetry-ingest` in namespace `platform` at `2026-10-19T02:03:00Z`, with `errorCode: null`. The preceding `02:00:00Z` event records `ci-runner` assuming `gp-deploy`, also with no error. The event proves an accepted update on the target deployment; the RBAC export proves update and patch capability.

The audit event does not preserve the patch body, so this assessment does not claim which field changed. The deployment already uses `node-agent`; update/patch rights permit changing the deployment while retaining that workload identity. The account API replay in the next step independently proves the deployment session can obtain the node reader identity and access the data.

### 4. The deployment session obtains the node reader identity — executed

The identity export identifies `gp-telemetry-reader` as an EC2-trusted node instance-profile role. The deployment uses `node-agent`. From profile `deploy`, the operator executed:

```sh
aws --profile deploy sts assume-role \
  --role-arn arn:aws:iam::210000000002:role/gp-telemetry-reader \
  --role-session-name chain-check-node --output json
```

After loading the returned temporary credentials into profile `node`, `aws sts get-caller-identity --profile node` returned:

```json
{
  "Account": "210000000002",
  "Arn": "arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/chain-check-node"
}
```

This directly proves the account API allowed the deployment session to obtain the reader role used by the telemetry workload's node. The pod-to-node credential endpoint was not separately exercised; the role/workload relationship is established by the supplied identity and deployment exports, and the role assumption itself was executed.

### 5. The node reader identity reads the telemetry object — executed

`identity-export/platform-account.json` grants `gp-telemetry-reader` `s3:GetObject` and `s3:ListBucket` on `gp-grid-telemetry`, plus KMS decrypt on `gp-platform-shared`. `infrastructure/storage/grid-telemetry.tf` configures the bucket to use `alias/gp-platform-shared`. With profile `node`, the operator executed:

```sh
aws --profile node s3api get-object \
  --bucket gp-grid-telemetry \
  --key load/2026-grid.ndjson \
  /dev/null
```

The successful API response reported `ContentLength: 4368`, `LastModified: 2026-11-24T04:49:11+00:00`, ETag `e8bbb18b18d21172ded54320a5845f03`, and `ContentType: binary/octet-stream`. The body was sent to `/dev/null`. This proves effective read access to the named object. The response did not include encryption metadata; `get-bucket-encryption` and `kms:DescribeKey` were denied to this identity, so the encryption configuration is supported by Terraform rather than those API reads.

The architecture classifies real-time grid load and switching telemetry as **operational-restricted**, says only the telemetry service identity may access it, and specifies access logging and seven-year retention. The object key and successful read bound the demonstrated access to this one object; its content was not inspected.

## Historical audit sequence and credential timing

The activity file records this successful sequence on 2026-10-19:

| UTC time | Caller | Event | Result |
|---|---|---|---|
| 02:00 | `arn:aws:iam::210000000001:role/ci-runner` | STS `AssumeRole`, target `gp-deploy` | `errorCode: null` |
| 02:03 | `arn:aws:sts::210000000002:assumed-role/gp-deploy/ci-session` | EKS `UpdateDeployment`, `telemetry-ingest`, `platform` | `errorCode: null` |
| 02:12 | `arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/i-node` | S3 `GetObject`, `gp-grid-telemetry/load/2026-grid.ndjson` | `errorCode: null` |

The repository credential commit is dated 2026-10-28, after the historical activity. The log proves the identities and actions in the October 19 sequence but does not identify the credential used then. The current API replay independently proves that the credential now in repository history can authenticate and reproduce the path to the telemetry object.

## Cross-domain composition and business impact

Repository history contains a currently accepted credential; IAM trust permits a transition into the platform account; the deployment role has broad cluster deployment capability; the workload is configured with a node identity; and that reader identity can access the operational data store. The current credential-to-role-to-reader-to-object transitions were executed against the API. Cluster RBAC and the historical audit event establish the deployment capability and its prior use. CI, account IAM, cluster operations, workload identity, storage, and key management sit in separate control areas; the combined path is visible only when those layers are traced together.

An actor with access to the repository credential can assume the deployment role, obtain the reader identity through the reproduced path, and read the named 4,368-byte telemetry object. Deployment authority also creates a risk to the integrity and availability of telemetry ingestion. The evidence does not show the entire bucket was copied, that data left the workstation, that grid equipment was controlled, that operations changed, or that an outage occurred. The historical October 19 session is not attributed to the later-committed credential.
