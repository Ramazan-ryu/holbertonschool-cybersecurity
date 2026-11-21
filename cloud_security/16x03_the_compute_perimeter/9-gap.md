# 9 — Evidence and Control Gaps

| Gap | Current evidence | What is still needed for closure |
|---|---|---|
| IMDS hardening | Validated for the tested request: under strong mode, the identical forged URL returned HTTP 502 (23 bytes), and the body contained no metadata credential fields. | Keep strong mode enabled and repeat after future service changes; this test does not prove every possible path to IMDS is blocked. |
| Function role remediation | The policy file was copied to the workstation. `iam:CreatePolicyVersion` was denied to `appsec-reviewer` and to a fresh `marlowe-web-instance-role` session obtained via IMDSv2. No change occurred. | An authorized account administrator must apply a new default managed-policy version, record its version ID, then prove the same excess call is denied and a handler-required call still succeeds. |
| Lambda configuration | `get-function-configuration` returned `403 SignatureDoesNotMatch`. | Resolve the account-endpoint/API signing issue and retrieve only redacted environment configuration. Do not infer an environment credential from the trust policy. |
| Audit reconstruction | The signed 60-event `latchkey-export` bundle is copied into `evidence/`, its SHA-256 matches the workstation copy, chain event IDs are documented, and denied policy-write event IDs are recorded. The listed S3 CloudTrail objects have not been separately decompressed and matched by ID. | Preserve the signed export unchanged; if independent S3-trail corroboration is required, match the cited event IDs to the corresponding gzipped trail records. |
| Network proof | The handover JSON lists ACLs, peerings, and an endpoint, but no route tables, ACL/security-group associations, endpoint route-table association, or S3 service CIDRs. | Obtain those configuration elements before claiming end-to-end reachability beyond the conditional verdicts in `0-reachability.md`. |
| Quiz and client reply | Quiz questions and a client response prompt were not included in the supplied material. | Add the quiz prompts and client-response requirements before preparing those deliverables. |

These gaps are intentionally explicit: a proposed policy is not an applied remediation, an allowed-looking policy is not execution proof, and an S3 log listing is not an audit-event reconstruction.
