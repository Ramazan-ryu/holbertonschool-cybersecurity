# 3 — Secret candidate triage

## Scan coverage

- Gitleaks scanned five commits and returned three findings.
- Checkov's local Terraform secrets scan returned one `CKV_SECRET_2` result. It points to the same Terraform default as Gitleaks G1; it is a second scanner finding for the same underlying credential, not a fourth distinct credential value.
- Trufflehog ran with `--results=verified,unknown` and printed no findings. No conclusion about credential validity is drawn from that absence.
- Scanner reports contained secret material. This report keeps only file, commit, rule, safe fingerprint, principal, and result; no raw key or secret value is reproduced.

## Individual scanner findings and verdicts

### Gitleaks G1 — Terraform dashboard variable

- **Reference:** `infra/terraform/variables.tf:7`, commit `67469e180285aa5848e2a50bfb307fbf27dc5c70`, rule `aws-access-token`, fingerprint `67469e180285aa5848e2a50bfb307fbf27dc5c70:infra/terraform/variables.tf:aws-access-token:7`.
- **Candidate context:** Terraform variable `grafana_api_token`; the value was formatted as an AWS access-key pair. Grafana authentication was not tested.
- **Authentication test/result:** the pair was used for `GetCallerIdentity` against the lab STS endpoint. STS succeeded and returned `arn:aws:iam::734112396500:user/dashboards-ro`. **Verdict: live AWS credentials in the lab.**
- **Reach test/result:** a body-discarding S3 `GetObject` test against the lab PHI record succeeded under this identity. No response body or patient data is reproduced here.
- **Disposition:** **reportable exposed AWS credential** because it retrieves the PHI object. Its intended Grafana use remains unresolved.

### Gitleaks G2 — historical reporting credential

- **Reference:** `.env.local:2`, commit `c7066ad89e6d8a2d902f70c917bc4bb500e332b1`, rule `aws-access-token`, fingerprint `c7066ad89e6d8a2d902f70c917bc4bb500e332b1:.env.local:aws-access-token:2`. The paired secret assignment is on line 3 of the same revision.
- **Candidate context:** variables are named `REPORTING_AWS_ACCESS_KEY_ID` and `REPORTING_AWS_SECRET_ACCESS_KEY`.
- **Authentication test/result:** `GetCallerIdentity` succeeded and returned `arn:aws:iam::734112396500:user/reporting-role-key`. **Verdict: live AWS credentials in the lab.**
- **Reach test/result:** a body-discarding S3 `GetObject` test against the lab PHI record succeeded under this identity. No response body or patient data is reproduced here.
- **Disposition:** **reportable exposed AWS credential** because it retrieves the PHI object.

### Gitleaks G3 — historical clinic-sync credential

- **Reference:** `sync/clinic_sync.py:4`, commit `5ff242361b1842a0816c145988542a76a2142b95`, rule `aws-access-token`, fingerprint `5ff242361b1842a0816c145988542a76a2142b95:sync/clinic_sync.py:aws-access-token:4`. The paired secret assignment is on line 5.
- **Candidate context:** hard-coded AWS key variables; the script calls `s3.list_buckets()`.
- **Authentication test/result:** the pair was tested with STS against the lab endpoint. STS returned `InvalidClientTokenId`. **Verdict: invalid for this lab endpoint at test time.**
- **Reach test/result:** none; authentication failed before scope testing.
- **Disposition:** **not a confirmed live finding**. This result does not establish validity against any service other than the tested lab STS endpoint.

### Checkov C1 — overlapping Terraform secret finding

- **Reference:** `CKV_SECRET_2`, resource `e744855f8d65578630ac18183df4516b07d4350a`, `infra/terraform/variables.tf:7–8` (`variables.tf:7–8` in the scan output). Checkov labels the finding “AWS Access Key.”
- **Candidate identity:** the same Terraform default and same secret fingerprint as Gitleaks G1, rather than a separate credential.
- **Authentication test/result:** the candidate was validated through the G1 STS test, which returned `arn:aws:iam::734112396500:user/dashboards-ro`. **Verdict: live as AWS credentials in the lab.**
- **Reach test/result:** the G1 scope tests apply: PHI `GetObject` succeeded; exports object `HeadObject` succeeded; tested partner, ops, and CloudTrail reads were denied.
- **Disposition:** **reportable under G1; duplicate scanner detection, not a fourth distinct secret.**

## Findings set

- **G1 — live:** AWS principal `dashboards-ro`; PHI object retrieval proven; reportable.
- **G2 — live:** AWS principal `reporting-role-key`; PHI object retrieval proven; reportable.
- **G3 — invalid at test time:** lab STS returned `InvalidClientTokenId`; not reported as live exposure.
- **C1 — live duplicate detection of G1:** same Terraform candidate, authentication, scope, and disposition as G1; not counted as an additional credential.
