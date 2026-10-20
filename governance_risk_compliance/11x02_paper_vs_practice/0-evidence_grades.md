# Evidence Grades — NIST CSF 2.0 Mapping

E01 — category: GV.PO · status: Partial
Justification: A security policy exists, but Section 1.2 requires annual review and re-approval, and no review record exists for three years. The named owner (former CTO) no longer works at the company. A policy that is not maintained is a governance artifact with a material hole, not a working control.

E02 — category: PR.AA · status: Partial
Justification: MFA is enforced for all SSO-integrated applications, which is real and demonstrated. However, six external contractors access the build system via SSH using a shared credential outside SSO/MFA scope. Identity and access management is not applied organization-wide.

E03 — category: ID.AM · status: Partial
Justification: The asset register accurately tracks company laptops, but contains zero cloud assets despite three AWS accounts existing, one with no identified owner. Under the "evidence is exhaustive" rule, untracked cloud assets are effectively unmanaged.

E04 — category: PR.AA · status: Absent
Justification: No documented offboarding procedure exists; tickets are raised "when HR remembers." The one observed case took 11 days to revoke access. An undocumented, inconsistently-triggered process is not a defensible control, regardless of one eventual correct outcome.

E05 — category: PR.DS · status: Implemented
Justification: Nightly snapshots with 35-day retention, plus a quarterly restore test with a signed runbook and a successful, timed result. This is the full lifecycle — created, protected, maintained, and tested — with evidence, not just a policy claim.

E06 — category: DE.AE · status: Partial
Justification: Cloud audit logging is technically enabled organization-wide, but the core failure is on the analysis side: alerts route to a Slack channel with no on-call ownership, and two high-severity alerts from last month remain unacknowledged. The gap is in recognizing and characterizing adverse events, not in the logging mechanism itself.

E07 — category: RS.MA · status: Absent
Justification: A phishing incident was handled informally by "whoever was around," with no ticket, no timeline, and no post-incident review. There is no repeatable or defensible incident management process — only ad hoc, undocumented action.

E08 — category: GV.SC · status: Partial
Justification: One vendor contract includes strong terms (72-hour breach notification, annual SOC 2 requirement), but this was negotiated for a single vendor by legal, with no vendor inventory or standard supply-chain security requirements applied across vendors. The organization-wide supply chain risk management program this category calls for does not exist; only an isolated exception does.

E09 — category: GV.RM · status: Absent
Justification: Risk discussion was deferred for three consecutive board quarters, and no risk register exists anywhere in the company. There is no evidence of an operating risk management process, only repeated deferral.

E10 — category: PR.AT · status: Partial
Justification: One all-hands security session occurred 14 months ago with 60% attendance and no completion tracking, and new joiners receive no training at all. Some awareness activity exists, but it is stale, unmeasured, and not onboarded into the employee lifecycle.

E11 — category: PR.PS · status: Partial
Justification: Full-disk encryption is at 100% on laptops and object storage has default encryption enabled, which is a strong baseline. But the defining finding is that two buckets were previously found publicly readable and were fixed reactively with no configuration-review process created afterward — a platform security-configuration governance gap, not an encryption gap, and one that remains exposed to recurrence.

E12 — category: GV.RR · status: Absent
Justification: There is no CISO, and security responsibility is informally split between the DevOps lead (an estimated 10% of their time) and the CTO, with nothing about this arrangement documented anywhere. No defensible structure for cybersecurity roles, responsibilities, and authorities exists (cf. GV.RR-02).
