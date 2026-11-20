# 3 — Secret candidate triage

## Scan results

- `trufflehog git file://$HOME/alderbrook-app --results=verified,unknown`: the supplied terminal transcript shows no findings printed. This is evidence of no tool output in that run, not proof that the repository contains no usable credentials.
- `gitleaks detect --source ~/alderbrook-app --no-banner`: the supplied output reports three leaks across five commits. The per-finding report was not retained, so two candidate locations and their fingerprints are unavailable here.
- `checkov` over the Terraform directory: one infrastructure check passed and one secret check failed. The secret candidate is `infra/terraform/variables.tf`, the `grafana_api_token` default (reported as `CKV_SECRET_2`, “AWS Access Key”). The secret value is intentionally omitted.
- The checked-in application history also contains credential-bearing files in historical revisions (`.env.local` and `infra/staging.env` appear in the five-commit history). The supplied scanner summary does not map the other two gitleaks hits to exact revisions or lines.

## Candidate disposition

| Candidate | Scanner evidence | Live? | What it opens | Disposition |
|---|---|---|---|---|
| Terraform `grafana_api_token` default in `infra/terraform/variables.tf` | Checkov `CKV_SECRET_2`; the file is in the current tree | **Unknown**: no authentication attempt or service response supplied | **Unknown**: no target service was queried | Do not report as a confirmed credential finding yet |
| Gitleaks hit 2 | Included in count of three; location/fingerprint not retained | **Unknown** | **Unknown** | Untriaged; cannot honestly classify live or dead |
| Gitleaks hit 3 | Included in count of three; location/fingerprint not retained | **Unknown** | **Unknown** | Untriaged; cannot honestly classify live or dead |

The historical files `.env.local` and `infra/staging.env` are candidate sources, but the evidence does not map each scanner record to a particular file. No credential value is reproduced. No candidate can be called live, dead, or low-value from a scanner match alone.

## Findings actually reported

**None confirmed from the evidence supplied.** The required credential-by-credential authentication and reach tests were not captured. Treating any of these scanner hits as a live finding would overstate the evidence. Re-run the scanners with a local report file, retain only sanitized path/commit/rule identifiers, then validate each candidate against its intended service without pasting secrets into this report.
