# 8 — Severity Assessment

## Finding 1: instance identity exposed through the storefront fetch

**Severity: High.** A request to the catalog image-import feature returned an instance metadata credential document. STS confirmed the principal as `marlowe-web-instance-role`. Calls using that identity successfully read an order document, received a customer-events message, and retrieved the Stripe webhook-signing secret. This rating is based on the exposed identity and proven data reach, not on the URL-fetch weakness in isolation. `iam:ListUsers` was denied, and no write or account-administration capability was demonstrated for this identity.

The exposure depended on the metadata service accepting the tokenless metadata path. The exact same forged request was replayed after `imds-mode strong`; it returned HTTP 502 with no credential fields. This validates the hardened posture for that request. The SSRF primitive remains and requires application-level remediation (see `6-remediation/README.md`).

## Finding 2: function execution role broader than the handler's API needs

**Severity: High.** The handler has seven code-observed API actions across four services. Under a tested function-role session, six additional actions outside that set succeeded: `s3:ListAllMyBuckets`, `secretsmanager:ListSecrets`, `sqs:ListQueues`, `iam:ListUsers`, `iam:GetAccountAuthorizationDetails`, and `dynamodb:ListTables`. The last returned an empty list; the successful response still demonstrates acceptance of that action. These six actions span five service families. This measured set is not a complete inventory of effective permissions; untested policy grants are not counted as demonstrated reach.

The risk is the reach of code executing under `marlowe-order-processor-role`, including any compromised dependency or function path. The proposed narrowing policy exists in the repository, but it was not applied or verified; the current severity therefore receives no remediation credit.

## Rating limits

No CVSS score is assigned because the supplied evidence does not establish all scoring inputs, including external authentication boundaries and full business impact. The ratings should be revisited after the metadata after-test, role policy update, and audit reconstruction are complete.
