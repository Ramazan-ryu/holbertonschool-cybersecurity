| ID | Asset | Threat | Vulnerability | Existing controls |
|----|-------|--------|----------------|--------------------|
| R1 | Supplier payment funds | CEO-fraud phishing | No callback verification for new/changed beneficiaries; basic email filtering | Basic email filtering |
| R2 | Claims processing platform | Ransomware | Aging Windows servers; backup restore untested | Nightly backups (restore untested) |
| R3 | Claim photos and policyholder PII on field laptops | Laptop theft or loss | Full-disk encryption on only ~half the fleet | Full-disk encryption (~50% of fleet) |
| R4 | Commercial policyholder list (CRM) | Departing-insider data exfiltration | Broad default CRM access; no DLP; offboarding delay up to 2 weeks | None identified |
| R5 | Customer self-service portal and cloud config | Portal misconfiguration exploitation | No config review since go-live | None identified |
| R6 | Cross-branch quoting capability | SaaS quoting-vendor outage | No offline fallback; single vendor dependency | None identified |
| R7 | Public marketing website | DDoS attack | Not specified | None identified |
| R8 | Archived health data (special category) | Regulatory exposure from retention non-compliance | No retention policy applied; slow subject-access request fulfillment | None identified |
