# 5 — Deployment Package Review

## Source and dependencies

`handler.py` imports `json` and `boto3`; it does not import `PyYAML` or `requests`. The supplied `requirements.txt` pins `boto3==1.34.69`, `PyYAML==5.3.1`, and `requests==2.31.0`. The offline `trivy fs ~/marlowe-package` output reported:

| Component | Finding reported by Trivy | Fixed version shown by scanner |
|---|---|---|
| PyYAML 5.3.1 | CVE-2020-14343, CRITICAL | 5.4 |
| requests 2.31.0 | CVE-2024-35195, MEDIUM | 2.32.0 |
| requests 2.31.0 | CVE-2024-47081, MEDIUM | 2.32.4 |
| requests 2.31.0 | CVE-2026-25645, MEDIUM | 2.33.0 |

These are inherited package findings, not proof that the handler exercises the vulnerable code paths. The source does not use YAML or `requests`, and the transcript contains no exploitability test. If attacker-controlled code were executed in this function runtime, it would run with the function role identity `marlowe-order-processor-role`; its proven and policy-described reach is recorded in `4-function_chain.md`. Upgrade and remove unused dependencies, then validate package behavior before deployment.

## Function configuration

`aws lambda get-function-configuration --function-name marlowe-order-processor` returned HTTP 403 with `SignatureDoesNotMatch` from the configured account endpoint. The environment variable names and values therefore were not obtained. The IAM trust document did show that `arn:aws:iam::500100200300:user/function-role-key` and `marlowe-web-instance-role` are trusted to assume the function role. That trust relationship does not, by itself, prove where any static credentials are stored or that a credential is present in the function environment.

**Verdict:** the dependency inventory is established, and the identity consequence is the function execution role. Configuration-held credentials or other environment values remain unverified because the configuration API call failed; no claim about an environment secret is made.
