# Four-Framework Comparison Matrix

Compiled: 2026 (see Status as of 2026 section for current versions and figures)

| Framework | Enforced by | Who must comply | What it protects | Max realistic consequence | Proof artifact |
|---|---|---|---|---|---|
| GDPR | EU/EEA national supervisory authorities, coordinated through the EDPB's cooperation mechanism | Any controller or processor established in the EU, plus non-EU organizations that offer goods/services to, or monitor the behavior of, people located in the EU (Art. 3) | Personal data of identifiable individuals ("data subjects") | Administrative fines up to €20M or 4% of global annual turnover, whichever is higher | Records of Processing Activities (ROPA) and Data Processing Agreements (DPAs) |
| HIPAA | HHS Office for Civil Rights (civil enforcement); DOJ (criminal enforcement) | Covered entities (health plans, providers, clearinghouses) and their business associates that handle PHI | Protected Health Information (PHI) | Civil penalties up to roughly $2.1M per violation category per year (highest, uncorrected willful-neglect tier, inflation-adjusted annually); criminal cases can add fines up to $250K and up to 10 years imprisonment | Executed Business Associate Agreements (BAAs) and a documented Security Rule risk analysis |
| PCI DSS | The card brands (Visa, Mastercard, etc.), enforced contractually through acquiring banks — not a government body | Any merchant or service provider that stores, processes, or transmits cardholder data | Cardholder data (PAN and related account data) | Acquirer-imposed non-compliance penalties, commonly in the $5,000–$100,000/month range, plus the real risk of losing card-processing privileges entirely | Report on Compliance (ROC) or Self-Assessment Questionnaire (SAQ), plus an Attestation of Compliance (AOC) |
| SOC 2 | Market and contract pressure — no regulator, no certifying body; enforced by customers and procurement teams who require the report | No one is legally required to comply; organizations pursue it because enterprise buyers demand it as a sales condition | The trustworthiness of a service organization's systems: security, availability, processing integrity, confidentiality, and/or privacy of customer data | No fine — the honest answer is lost revenue: blocked or delayed deals, failed procurement/vendor-risk reviews | The SOC 2 report itself (Type I or Type II) |

## Status as of 2026

- **PCI DSS**: Version 4.0.1 (published June 2024) is the only active version. All of its requirements — including those that had a future-dated transition — became mandatory as of March 31, 2025.
- **HIPAA**: The Security Rule update proposed by HHS OCR (NPRM, December 27, 2024 / published January 6, 2025) remains a proposed rule, not finalized. The current, still-binding Security Rule is the one last substantively updated in 2013.
- **GDPR**: Enforcement is active and cumulative, not slowing down. Regulators have issued roughly €7.1 billion in fines since GDPR took effect in May 2018, with about €1.2 billion issued in 2025 alone — including a €530M fine against TikTok, the largest single fine of that year.
- **SOC 2**: Reports are issued against the AICPA's 2017 Trust Services Criteria for Security, Availability, Processing Integrity, Confidentiality, and Privacy (with Revised Points of Focus — 2022), the current criteria set.
