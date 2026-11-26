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

### 3. A historical deployment update is tied to the deployment role — cluster evidence and audit event

`cluster-export/clusterrolebindings.yaml` binds Kubernetes ServiceAccount `deployer` in namespace `platform` to Kubernetes ClusterRole `platform-deployer`. `cluster-export/clusterroles.yaml` gives that ClusterRole `get`, `list`, `update`, and `patch` on deployments. The deployment manifest identifies `telemetry-ingest` and sets `serviceAccountName: node-agent`. These are Kubernetes identities; the supplied files do not map either ServiceAccount to AWS IAM role `gp-deploy`, and this report does not treat them as the same identity.

The activity file `granite-peak/activity/granite-peak-trail.jsonl` records EKS `UpdateDeployment` by AWS session `arn:aws:sts::210000000002:assumed-role/gp-deploy/ci-session` for deployment `telemetry-ingest` in namespace `platform` at `2026-10-19T02:03:00Z`, with `errorCode: null`. Its preceding `02:00:00Z` event records the historical `ci-runner` principal assuming `gp-deploy`, also with no error. This audit event directly proves that the historical `gp-deploy` session performed the update. Separately, the current repository credential was successfully used to assume `gp-deploy` in steps 1–2. The evidence does not prove that this later-tested credential caused the October 19 event or that the current session repeated the deployment update.

The audit event does not preserve the patch body, so the changed field is unknown. The cluster export establishes Kubernetes deployment permissions for `platform-deployer`; the audit event independently establishes the AWS `gp-deploy` session's successful update. The evidence does not show that the Kubernetes ServiceAccount `deployer` is the AWS role `gp-deploy`.

### 4. A fresh deployment-role session successfully assumes the telemetry-reader role — executed, with a trust-policy discrepancy

The identity export lists `ec2.amazonaws.com` as the trust principal for `gp-telemetry-reader` and describes it as the node instance-profile role. Separately, a fresh API replay first made this request from the valid `ci` profile:

```python
response = ci.client("sts", endpoint_url=endpoint).assume_role(
    RoleArn="arn:aws:iam::210000000002:role/gp-deploy",
    RoleSessionName="assessment-readonly-followup"
)
```

`GetCallerIdentity` returned account `210000000002`, ARN `arn:aws:sts::210000000002:assumed-role/gp-deploy/assessment-readonly-followup`. Using that in-memory `gp-deploy` session, the follow-up script then made this STS request:

```python
response = deploy.client("sts", endpoint_url=endpoint).assume_role(
    RoleArn="arn:aws:iam::210000000002:role/gp-telemetry-reader",
    RoleSessionName="assessment-readonly-followup"
)
```

The script used the returned temporary credentials in memory and called `GetCallerIdentity`, which returned account `210000000002`, ARN `arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/assessment-readonly-followup`:

```json
{
  "Account": "210000000002",
  "Arn": "arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/assessment-readonly-followup"
}
```

This directly proves that the fresh `gp-deploy/assessment-readonly-followup` session received a successful STS response for `gp-telemetry-reader/assessment-readonly-followup`. It also creates an unresolved discrepancy: the export says `gp-telemetry-reader` trusts EC2, while the tested STS call from `gp-deploy` succeeded. The report records both observations without claiming that the EC2 trust explains the call or equating Kubernetes `node-agent` with an AWS identity. The historical deployment event and this current STS replay are separate evidence timelines.

### 5. The node reader identity reads the telemetry object — executed

`identity-export/platform-account.json` grants `gp-telemetry-reader` `s3:GetObject` and `s3:ListBucket` on `gp-grid-telemetry`, plus KMS decrypt on `gp-platform-shared`. `infrastructure/storage/grid-telemetry.tf` configures the bucket to use `alias/gp-platform-shared`. With profile `node`, the operator executed:

```sh
aws --profile node s3api get-object \
  --bucket gp-grid-telemetry \
  --key load/2026-grid.ndjson \
  /dev/null
```

The successful response reported `ContentLength: 4368`, ETag `e8bbb18b18d21172ded54320a5845f03`, and `ContentType: binary/octet-stream`; the original command sent the body to `/dev/null`. In the fresh follow-up, the same `gp-telemetry-reader/assessment-readonly-followup` session performed `GetObject`; the response reported `ContentLength: 4368`, the same ETag, and `LastModified: 2026-11-25T21:32:39+00:00`. The script counted 4,368 received bytes and discarded them without displaying or saving them. A separate `HeadObject` response gave `ContentLength: 0` with the same ETag, so that HEAD length conflicts with both successful GetObject responses and is not used as the object size here. Neither GetObject response included `ServerSideEncryption` or `SSEKMSKeyId`; `kms:DescribeKey` was denied to this identity. The Terraform file declares default SSE-KMS, but these live responses do not confirm encryption of this specific object.

The architecture classifies real-time grid load and switching telemetry as **operational-restricted**, says only the telemetry service identity may access it, and specifies access logging and seven-year retention. The identity export describes `gp-telemetry-reader` as a node instance-profile role; the supplied files do not establish that it is the same identity as the architecture's telemetry service identity. The successful request establishes access to this one object by the tested reader-role session; its content was not inspected.

## Historical audit sequence and credential timing

The activity file records this successful sequence on 2026-10-19:

| UTC time | Caller | Event | Result |
|---|---|---|---|
| 02:00 | `arn:aws:iam::210000000001:role/ci-runner` | STS `AssumeRole`, target `gp-deploy` | `errorCode: null` |
| 02:03 | `arn:aws:sts::210000000002:assumed-role/gp-deploy/ci-session` | EKS `UpdateDeployment`, `telemetry-ingest`, `platform` | `errorCode: null` |
| 02:12 | `arn:aws:sts::210000000002:assumed-role/gp-telemetry-reader/i-node` | S3 `GetObject`, `gp-grid-telemetry/load/2026-grid.ndjson` | `errorCode: null` |

The repository credential commit is dated 2026-10-28, after the historical activity. The log proves the identities and actions in the October 19 sequence but does not identify the credential used then. The current API replay independently proves that the credential now in repository history can authenticate and reproduce the path to the telemetry object.

## Cross-domain composition and bounded consequence

The current replay executed the credential-to-`gp-deploy`-to-`gp-telemetry-reader`-to-object transitions against the account API. Cluster exports and the October 19 activity record separately show the deployment update. The evidence spans repository credential history, AWS account trust and role permissions, Kubernetes deployment authorization, the telemetry-reader role, and S3. These controls sit in separate configuration areas; reviewing only the repository, IAM export, cluster export, or storage configuration alone would not reveal the complete route. The Kubernetes ServiceAccounts and AWS IAM roles remain distinct identities in this analysis. The October 19 activity is not attributed to the repository credential committed on October 28.

The demonstrated endpoint is one successful `GetObject` response for `gp-grid-telemetry/load/2026-grid.ndjson` under the `gp-telemetry-reader/assessment-readonly-followup` session. The response reports 4,368 bytes, `LastModified: 2026-11-25T21:32:39+00:00`, and ETag `e8bbb18b18d21172ded54320a5845f03`. The architecture classifies real-time grid load and switching telemetry as `operational-restricted`. The original command sent the body to `/dev/null`; the fresh follow-up counted the returned bytes and discarded them without display or storage. The body was not inspected or analysed. This establishes retrieval of this named object in that tested session; it does not establish access to other objects or that anyone examined, retained, copied, or disclosed its contents. It also does not establish a change to telemetry or control of grid equipment.

For Granite Peak, the observed result is retrieval of one record classified for restricted operational handling. If an unauthorized person later examined this record, its documented function could reveal information about grid load or switching conditions; this is a possible consequence, not an observed use, disclosure, or operational harm. The architecture states that access must be controlled, logged, and retained for seven years, and that an access-control or protection failure calls for an access review and client notification. This is Granite Peak's written handling rule, not a conclusion about legal duties or proof that an external notification has occurred.
