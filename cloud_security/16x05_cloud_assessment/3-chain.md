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

The activity file `granite-peak/activity/granite-peak-trail.jsonl` records a successful EKS `UpdateDeployment` by `arn:aws:sts::210000000002:assumed-role/gp-deploy/ci-session` for `telemetry-ingest` in namespace `platform` at `2026-10-19T02:03:00Z`, with `errorCode: null`. The preceding `02:00:00Z` event records the historical `ci-runner` principal assuming `gp-deploy`, also with no error. Separately, the current credential-to-`gp-deploy` transition was reproduced in steps 1–2. The historical event proves that a `gp-deploy` session performed an accepted update on the target deployment; the RBAC export proves update and patch capability.

The audit event does not preserve the patch body, so this assessment does not claim which field changed. The deployment already uses `node-agent`; update/patch rights permit changing the running deployment while retaining its current workload identity. The current account API path from the `gp-deploy` session to the reader identity is directly tested in the next step; it is not inferred from the October 19 event or from a presumed pod metadata exchange.

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

This directly proves the account API allowed the deployment session to obtain `gp-telemetry-reader`. The identity export identifies that role as the EC2 node instance-profile role, and the deployment export associates `telemetry-ingest` with `node-agent`. Thus the tested access path does not depend on an untested pod-to-node metadata exchange: the deployment session itself successfully assumed the data-reading node role. The historic workload update is corroborating evidence of production deployment use, not the causal source of the current API replay.

### 5. The node reader identity reads the telemetry object — executed

`identity-export/platform-account.json` grants `gp-telemetry-reader` `s3:GetObject` and `s3:ListBucket` on `gp-grid-telemetry`, plus KMS decrypt on `gp-platform-shared`. `infrastructure/storage/grid-telemetry.tf` configures the bucket to use `alias/gp-platform-shared`. With profile `node`, the operator executed:

```sh
aws --profile node s3api get-object \
  --bucket gp-grid-telemetry \
  --key load/2026-grid.ndjson \
  /dev/null
```

The successful response reported `ContentLength: 4368`, ETag `e8bbb18b18d21172ded54320a5845f03`, and `ContentType: binary/octet-stream`; the original command sent the body to `/dev/null`. A fresh follow-up `GetObject` on 2026-11-26 returned `ContentLength: 4368`, the same ETag, and `LastModified: 2026-11-25T21:32:39+00:00`. The script counted 4,368 received bytes and discarded them without displaying or saving them. A separate `HeadObject` response gave `ContentLength: 0` with the same ETag, so that HEAD length conflicts with both successful GetObject responses and is not used as the object size here. Neither GetObject response included `ServerSideEncryption` or `SSEKMSKeyId`; `kms:DescribeKey` was denied to this identity. The Terraform file declares default SSE-KMS, but these live responses do not confirm encryption of this specific object.

The architecture classifies real-time grid load and switching telemetry as **operational-restricted**, says only the telemetry service identity may access it, and specifies access logging and seven-year retention. The object key and successful read bound the demonstrated access to this one object; its content was not inspected.

## Historical audit sequence and credential timing

The activity file records this successful sequence on 2026-10-19:

| UTC time | Caller | Event | Result |
|---|---|---|---|
| 02:00 | `arn:aws:iam::210000000001:role/ci-runner` | STS `AssumeRole`, target `gp-deploy` | `errorCode: null` |
| 02:03 | `arn:aws:sts::210000000002:assumed-role/gp-deploy/ci-session` | EKS `UpdateDeployment`, `telemetry-ingest`, `platform` | `errorCode: null` |
| 02:12 | `arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/i-node` | S3 `GetObject`, `gp-grid-telemetry/load/2026-grid.ndjson` | `errorCode: null` |

The repository credential commit is dated 2026-10-28, after the historical activity. The log proves the identities and actions in the October 19 sequence but does not identify the credential used then. The current API replay independently proves that the credential now in repository history can authenticate and reproduce the path to the telemetry object.

## Cross-domain composition and bounded consequence

The current replay executed the credential-to-`gp-deploy`-to-`gp-telemetry-reader`-to-object transitions against the account API. Cluster exports and the October 19 activity record separately show that `gp-deploy` has deployment rights and previously updated `telemetry-ingest`. These pieces sit across repository, account identity, cluster, workload identity, and storage controls; reviewing only one team's artefacts would not show the combined path. The October 19 activity is not attributed to the repository credential committed on October 28.

The demonstrated endpoint is successful `GetObject` access to `gp-grid-telemetry/load/2026-grid.ndjson`. The fresh response reports 4,368 bytes, `LastModified: 2026-11-25T21:32:39+00:00`, and ETag `e8bbb18b18d21172ded54320a5845f03`. The architecture classifies real-time grid load and switching telemetry as `operational-restricted`. The original command sent the body to `/dev/null`; the follow-up counted the returned bytes and discarded them without display or storage. The body was not inspected or analysed. This proves retrieval access to this named object only. It does not prove access to other objects, human understanding of the content, retention, external disclosure, a change to telemetry, or control of grid equipment.

In Granite Peak's terms, a holder of the tested credential path can retrieve this one restricted telemetry object. Because the architecture describes the data as real-time load and switching telemetry, a person who later examined the bytes could learn information about operating conditions; that is a possible consequence, not an observed use or harm. The architecture states that access must be controlled, logged, and retained for seven years, and that an access-control or protection failure calls for an access review and client notification. This is Granite Peak's written handling rule, not a conclusion about legal duties or proof that an external notification has occurred.
