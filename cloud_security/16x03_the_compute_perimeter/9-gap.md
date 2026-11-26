# 9 — The Measured Permission Gap

## Measurement

The handler source contains **7** distinct provider actions across **4** services: Secrets Manager `GetSecretValue`; SQS `ReceiveMessage` and `DeleteMessage`; S3 `GetObject` and `PutObject`; DynamoDB `GetItem` and `PutItem`. A separate `fn-review` assumed-role session, confirmed by STS as `marlowe-order-processor-role`, successfully made **6** additional manual inventory calls across **5** service families: S3 `ListAllMyBuckets`, Secrets Manager `ListSecrets`, SQS `ListQueues`, IAM `ListUsers`, IAM `GetAccountAuthorizationDetails`, and DynamoDB `ListTables`. The table-list result was empty, but the action was accepted. The two sets do not overlap. This is a measured lower bound; untested permissions and write actions are excluded.

## How the gap forms and stays quiet

Under delivery deadlines, teams may add permissions so a release can proceed. Later, code and dependencies change, while the role grants remain. Cloud providers do not remove permissions just because code stops using them. During normal work, unused permissions create no calls, failures, alerts, performance symptoms, or user complaints. Successful application requests therefore give no warning. The gap appears when effective role permissions are deliberately compared with a code-usage baseline derived independently from the handler.

## Repeatable prevention and cost

Before each deployment, application and platform owners should derive the required actions and resource ARNs from code, while security reviews the metadata posture and effective role access. Compare the role's effective permissions with that baseline; block extra grants unless an owner approves a documented exception. Test a required call as allowed and an unnecessary call as denied, then repeat the review when code, dependencies, configuration, or roles change.

This process takes engineering time to maintain the baseline, tests, and exceptions. Build checks can delay releases, and tighter resource scopes can expose assumptions that require code changes. Teams must budget time for regression testing and review; there is no measured false-positive or failure rate for this lab.
