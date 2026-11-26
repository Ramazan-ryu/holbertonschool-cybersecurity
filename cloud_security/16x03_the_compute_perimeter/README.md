# Marlowe Commerce — compute perimeter review

This directory contains the analysis deliverables for the Marlowe Commerce lab. Findings below use the account responses and configuration excerpts supplied during the review. Temporary credentials and secret values are intentionally omitted.

## Evidence status

The instance-role chain and function-role chain were exercised against the configured lab account endpoint. The attached function policy and package source were inspected. The exact forged metadata request was retested under strong mode and returned HTTP 502 without credential fields. The proposed least-privilege policy update was denied to both `appsec-reviewer` and a fresh `marlowe-web-instance-role` session (`iam:CreatePolicyVersion`), so the role remains unremediated pending an authorized account administrator. The 93-event audit export is present in `evidence/audit-export.json`; the local report records its SHA-256 and notes that its HMAC signing key is not available for independent verification. Lambda environment configuration and quiz prompts remain unavailable; these items are marked as unverified rather than inferred.

## Files

- `0-reachability.md` — network configuration analysis
- `1-door.md`, `2-instance_chain.md` — storefront-to-instance identity chain
- `3-needed_calls.md`, `4-function_chain.md`, `5-package.md` — function requirements, effective role access, and package review
- `6-remediation/` — proposed least-privilege policy and validation status
- `7-audit_trail.md`, `8-severity.md`, `9-gap.md`, `11-marlowe_reply.md` — audit, severity, evidence gaps, and client reply
- `10-compute_quiz/` — the quiz prompts were not included in the supplied material; no answers have been invented
