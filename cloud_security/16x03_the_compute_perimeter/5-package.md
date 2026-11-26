# 5 — Deployment Configuration and Dependencies

## Configuration-held credentials: status and safe evidence

I attempted to retrieve `marlowe-order-processor` configuration first with:

```sh
aws lambda get-function-configuration --function-name marlowe-order-processor
```

The account endpoint returned HTTP 403 `SignatureDoesNotMatch`. I retried with the profile, region, and endpoint explicitly selected while removing any exported credential variables:

```sh
env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN \
  aws --profile default --region eu-west-1 lambda get-function-configuration \
  --function-name marlowe-order-processor --output json
```

It returned the same HTTP 403 `SignatureDoesNotMatch` before returning configuration. This response is a request-signature failure, not an IAM `AccessDenied` decision, and it does not establish whether environment variables or credential material are present. I will not infer a secret from the IAM user's name or from the role trust policy. No configuration credential is claimed as an independently verified finding until Lambda configuration can be retrieved, its values handled without disclosure, and any credential's STS identity and reachable permissions tested.

A later retry used the same `default` profile and `eu-west-1` while projecting only `Role`, `Runtime`, and environment-variable key names. It returned the same `SignatureDoesNotMatch` response before the projection could be applied. No environment value was requested or received, and this retry adds no evidence for credential presence or absence.

The signed audit export independently records the failed configuration lookup as `lambda.amazonaws.com` `GetFunction` at `2026-11-21T21:16:03Z`: event ID `43676767-a28f-4638-94b6-5b50afe1fe8d`, request ID `bVCVQp8PeUohtAyGOHe4MSSLAyZmtIyoS8PVHETH9cEtuOBQX3Hk`, function name `marlowe-order-processor`, caller `arn:aws:iam::500100200300:user/appsec-reviewer`, source `127.0.0.1`, result `SignatureDoesNotMatch`. This corroborates the API failure; it still does not disclose configuration values.

The verified trust-policy result is separate: the IAM role trust document names `arn:aws:iam::500100200300:user/function-role-key` and `arn:aws:iam::500100200300:role/marlowe-web-instance-role` as principals permitted to call `sts:AssumeRole`. Trust is not proof that either principal's credentials are embedded in the function configuration. If arbitrary code runs in the function, the expected workload identity is the execution role `marlowe-order-processor-role`; its tested role-session identity and demonstrated reach are documented in `4-function_chain.md`.

An execution-role session also retrieved the IAM record for `function-role-key`. The provider response identified `arn:aws:iam::500100200300:user/function-role-key`, no permissions boundary, no attached managed policies, and one inline policy: `sts:AssumeRole` on `arn:aws:iam::500100200300:role/marlowe-order-processor-role`. The retrieval was made by `key-policy-review`; the signed export records IAM `GetAccountAuthorizationDetails` with filter `User` at `2026-11-22T13:04:40Z`, event ID `eba35594-ceff-4c04-abe0-fd379489fb76`, request ID `FoljXsbuED3G12MrHx5BMzfuBQKLb754blQ6ellvjkYplUuIabTg`, and success. This confirms what that IAM user is authorized to do if valid credentials for it are used; it does not reveal an access-key secret or establish that the function configuration contains one. The Lambda configuration call still fails with `SignatureDoesNotMatch`, so credential presence, validity, and configuration storage remain unverified.

## Dependency inventory and runtime triage

The package at `~/marlowe-package/order_processor/requirements.txt` pins `boto3==1.34.69`, `PyYAML==5.3.1`, and `requests==2.31.0`. Offline `trivy fs ~/marlowe-package` reported:

The operator's file inventory returned only `order_processor/handler.py` and `order_processor/requirements.txt` under the package directory. It did not show a separate credential file. The attempted filename-only search could not run because `rg` is not installed on the workstation; no credential scan result is claimed. Lambda configuration remains unavailable as described above, so this package listing does not settle whether an environment variable contains a credential.

| Installed component | Trivy identifier and rating | Scanner fix version | Source/runtime assessment |
|---|---|---|---|
| PyYAML 5.3.1 | CVE-2020-14343, CRITICAL | 5.4 | `handler.py` imports neither YAML nor a YAML loader; it parses queue bodies using Python's `json.loads` at line 28. No vulnerable YAML parse path is present in the supplied handler, so exploitability through this function's demonstrated flow is not established. |
| requests 2.31.0 | CVE-2024-35195, MEDIUM | 2.32.0 | The handler does not import or call `requests`; no HTTP client path reaches this package in the supplied source. |
| requests 2.31.0 | CVE-2024-47081, MEDIUM | 2.32.4 | No `.netrc` or requests URL handling appears in the supplied handler. The affected code path is not demonstrated. |
| requests 2.31.0 | CVE-2026-25645, MEDIUM | 2.33.0 | The handler contains no requests temporary-file code path. The affected code path is not demonstrated. |

The scanner ratings describe components in isolation; they do not prove remote exploitability of this handler. The supplied function code uses `boto3` and JSON, and the Trivy hits are on dependencies not used by the shown execution path. If a separate input path later invokes vulnerable dependency behavior or arbitrary code, the relevant cloud impact is the execution role's empirically demonstrated permissions and limits in `4-function_chain.md`, not account-wide administration. Remove unused dependencies and upgrade retained packages to maintained fixed releases as ordinary package hygiene; do not present the scanner score as demonstrated Marlowe impact.

## Workload identity consequence of code execution

The handler's `boto3` clients (`sm`, `sqs`, `s3`, and `ddb`) make the SDK provider calls listed in `3-needed_calls.md`. If arbitrary code executes in a deployed function attached to `marlowe-order-processor-role`, that code can use the function runtime's temporary execution-role credentials. The tested `fn-review` role session in `4-function_chain.md` identifies the principal as `arn:aws:sts::500100200300:assumed-role/marlowe-order-processor-role/fn-review` and demonstrates six accepted calls outside the handler's seven source operations: S3 `ListAllMyBuckets`, Secrets Manager `ListSecrets`, SQS `ListQueues`, IAM `ListUsers`, IAM `GetAccountAuthorizationDetails`, and DynamoDB `ListTables` (empty result). Those are inventory calls, not handler-path operations. The separate `fn-review2` artifacts confirm only that session's role identity; no permission-call result from it is used here. The deployed role attachment remains unverified because Lambda configuration retrieval failed.

This is a conditional impact statement, not proof that a vulnerable dependency was exploited. The Lambda configuration retrieval failed before returning its role attachment or environment, so the deployed attachment is not independently verified here. The execution-role linkage and credentials-in-configuration question must remain qualified by that limitation.

## Verdict and evidence needed to close the configuration question

Dependency presence and the function role's identity consequence are documented. A configuration credential's existence, validity, principal, and scope are **unverified** because both Lambda configuration requests failed before returning a configuration. The exact next evidence is a successful configuration response with all values kept on the workstation and redacted from the report, followed by STS `GetCallerIdentity` and minimally invasive calls made with any discovered credential; the actual responses must be recorded before claiming what it opens.
