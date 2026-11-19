# 3. A Different Shape

## A service-delegation chain, structurally separate from policy rewriting

The chain in `2-first_chain.md` changes a managed policy and then uses a human-to-role `sts:AssumeRole` transition. This route does neither: `reporting-analyst` leaves its own policy unchanged and does not assume the batch role. It gives a service permission to run a newly created function as that role. The intermediate capability is a Lambda function configured with an execution role; the identity that would receive the role session is the Lambda service.

### Edge 1 — reporting user can create Lambda compute

- **Current principal:** `arn:aws:iam::418274630117:user/reporting-analyst`, verified by `aws sts get-caller-identity` immediately before the call.
- **Action/resource:** `lambda:CreateFunction` on `*`. `ReportingAnalystAccess`, `ChainA_Compute`, is `Effect:Allow`, actions `["lambda:CreateFunction","lambda:InvokeFunction","lambda:DeleteFunction"]`, `Resource:"*"`, no condition.
- **Other layers:** `ReportingAnalystBoundary`, `CapRead`, includes `lambda:*` on `*`; it does not cap this action. `AshfordGuardrails` has no Lambda deny. The user policy at the time still contained `ChainA_PassAndRun`.
- **Call/response:** `aws lambda create-function --function-name ashford-boundary-probe --runtime python3.12 --role arn:aws:iam::418274630117:role/ashford-batch-exec --handler handler.handler --zip-file fileb:///tmp/probe.zip` returned function ARN `arn:aws:lambda:eu-west-1:418274630117:function:ashford-boundary-probe`, with `Role` equal to the requested batch role. CloudTrail records success at `2026-11-19T03:47:52Z` in `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0348Z_B3feeFebAf1DbD94.json.gz`.
- **New capability:** The user has created a function whose configured execution identity is `ashford-batch-exec`. This is a service configuration transition, not a human STS session.

### Edge 2 — the user is allowed to hand the exact role to Lambda

- **Current principal:** still the reporting user; the preceding response was a Lambda resource creation and did not change `GetCallerIdentity`.
- **Action/resource:** `iam:PassRole` on `arn:aws:iam::418274630117:role/ashford-batch-exec`. `ReportingAnalystAccess`, `ChainA_PassAndRun`, is `Effect:Allow`, `Action:"iam:PassRole"`, `Resource` equal to that exact role ARN, no condition. The boundary includes `iam:*`; the SCP has no PassRole deny.
- **Receiver acceptance:** `aws iam get-role --role-name ashford-batch-exec` returned a trust statement with `Principal.Service:"lambda.amazonaws.com"`, `Action:"sts:AssumeRole"`. This is the service-side trust that accepts Lambda; it does not itself grant the reporting user PassRole.
- **Role authority:** `aws iam list-attached-role-policies --role-name ashford-batch-exec` returned `AshfordBatchExecAdmin`. `get-policy-version` for v1 returned `Effect:Allow`, `Action:"*"`, `Resource:"*"`. The role response showed no permissions boundary. Therefore, if Lambda invokes the configured function, its service-assumed execution role has broad AWS authority, subject to the organization's SCP.
- **Call/response evidence:** The successful `CreateFunction` response above names the requested role in its `Role` field, demonstrating that the caller's CreateFunction and PassRole permissions and the role's Lambda trust were accepted together.

### Runtime verification limit

I attempted `aws lambda invoke --function-name ashford-boundary-probe --payload '{}' --cli-binary-format raw-in-base64-out /tmp/ashford-invoke.json --region eu-west-1`. The endpoint returned HTTP 403 `AccessDenied`, naming `lambda:Invoke`; CloudTrail event `856cae85-1921-44d5-98e2-7954aa145d8a` at `2026-11-19T06:15:12Z` in `AWSLogs/418274630117/CloudTrail/eu-west-1/2026/11/19/418274630117_CloudTrail_eu-west-1_20261119T0615Z_31ccC2BfF5Bb20Dc.json.gz`. The current `ChainA_Compute` statement grants `lambda:InvokeFunction`, while this endpoint reports evaluating `lambda:Invoke`; the policy does not match the action string in the refusal. Earlier malformed/incomplete Invoke attempts returned `SignatureDoesNotMatch`, also without proving execution. I therefore prove accepted role assignment and show the configured escalation path, but do not claim a completed Lambda runtime execution from this emulator response.

## Why this is a different escalation shape

The first chain changes the policy of an already trusted role, then the human assumes that role. This chain combines `lambda:CreateFunction` with a role-scoped `iam:PassRole` grant; a service, rather than the user, would assume the role through the trust relationship. There is no policy-version write in this path, and no user `sts:AssumeRole` into `ashford-batch-exec`. The shared property is that a permission which appears bounded on its own creates an intermediate principal/configuration another permission can convert into broader authority. The policy documents and successful function-creation response prove that this route is configured; the invoke signing failure prevents a claim of a completed runtime escalation.
