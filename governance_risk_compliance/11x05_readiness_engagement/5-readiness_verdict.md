# Vireo Payments — Readiness Verdict
**To:** Vireo Payments Board
**Purpose:** Series C Investor Due Diligence
**Assessment window:** 90 days to close

## Executive Verdict
Vireo has several effective controls [F01]. However, Vireo is not currently ready to represent itself as fully compliant across PCI DSS, GDPR, DORA, and SOC 2 [F06]. The strongest evidence is in secrets management [F01] and ledger recovery [F04]. The most material weaknesses are the absence of risk governance [F06], an overdue penetration test [F05], missing DORA governance and register of information [F06], and inadequate third-party controls around Certeva ID [F03]. The recommended position is transparent remediation, not cosmetic compliance [F06]. Vireo can present a credible 90-day readiness programme [F06], but it should not claim that all regulatory or assurance gaps will be closed by the Series C close [F06].

## 1. Obligations
Vireo operates under four distinct obligation mechanisms [F06]:
*   **PCI DSS:** Applies through the payment-card ecosystem and contractual requirements governing the handling of cardholder data [F05].
*   **GDPR:** Directly applicable data-protection law governing Vireo's processing of personal data and creating specific obligations when personal-data breaches occur [F02].
*   **DORA:** Directly applicable EU regulation governing digital operational resilience, ICT risk management, incident management, resilience testing, third-party ICT risk, and information sharing [F06]. Vireo currently has no identified owner for this obligation [F06].
*   **SOC 2:** An independent assurance framework rather than an EU regulation [F06]. Vireo has never opened a SOC 2 engagement [F06].

The board currently has no formal risk register or appetite statement [F06]. Vireo must also establish and maintain the required DORA Register of Information [F06]. The absence of an owner and register is a material governance gap [F06].

## 2. Risk
The quantified annualised exposure is based on the current risk posture [F06]:
*   **S3 — Certeva KYC exposure:** €600,000 SLE × 0.5 ARO = €300,000 ALE [F03]
*   **S2 — Account-takeover fraud:** €120,000 SLE × 1.5 ARO = €180,000 ALE [F06]
*   **S1 — Card-data breach:** €600,000 SLE × 0.2 ARO = €120,000 ALE [F05]

S3 is therefore the highest quantified annual risk at €300,000 ALE [F03]. The proposed Certeva control package costs €45,000/year and reduces S3 ARO from 0.5 to 0.1 [F03]. Its residual ALE becomes €60,000, producing an annual risk reduction of €240,000 [F06]. The resulting net annual economic benefit is: €240,000 - €45,000 = €195,000 [F06]. The recommended treatment is therefore to treat S3 through the proposed vendor hardening package, contractual amendments, enforced SSO with MFA, and continuous monitoring [F03]. The treatment should be assigned an owner, tracked to dated milestones, and reviewed against the residual risk [F06].

## 3. Evidence and Posture
The evidence pack produces both strengths and weaknesses [F06]:
*   **[F01] Secrets management — Green:** Vireo has a central vault, MFA for all access, and signed quarterly access reviews [F01]. The latest review occurred five weeks ago [F01]. This is positive evidence of an operating control and should be certified as a strength [F01].
*   **[F04] Ledger resilience — Green:** Vireo performs daily encrypted backups and monthly restore tests using a signed runbook [F04]. The latest test, three weeks ago, was successful [F04]. This is positive operating evidence and should also be certified as a strength [F04].
*   **[F05] Security testing — Red:** Vireo's policy requires annual penetration testing, but the last recorded test was 26 months ago [F05]. This is a clear paper-compliance finding: the policy exists, but the required operating activity is overdue [F05].
*   **[F02] Incident readiness — Amber/Red:** The 24/7 rota and tested escalation phone tree provide useful operational capability, but Vireo has no incident classification procedure, reporting templates, or demonstrated awareness of the major-incident reporting process [F02].
*   **[F03] Certeva — Red:** The vendor has only a March 2024 SOC 2 Type I report, has no contractual breach-notification clause with Vireo, and is absent from the vendor register [F03]. This is a significant third-party risk gap [F03].
*   **[F06] Risk governance — Red:** There is no risk register, no appetite statement, and no board risk agenda evidence for four consecutive quarters [F06]. Risk decisions being made verbally by the CTO are insufficient evidence of formal governance [F06].

## 4. Resilience
The current ledger database is 1,080,000 MB [F04]. At 150 MB/s, restore time is 2 hours [F04]. Adding the fixed 1-hour validation period gives a total recovery time of 3 hours [F04]. The board's single-event threshold is 8 hours (€240,000 / €30,000) [F06]. Vireo's policy requires RTO to be no more than 50% of MTPD, meaning the implied maximum RTO is 4 hours [F04]. The calculated recovery time of 3 hours is below the 4-hour RTO limit [F04]. The resilience verdict is therefore Green and is supported by the successful restore evidence [F04].
The regulatory position is different [F02]. The incident process does not currently demonstrate the ability to initiate the required DORA major-incident reporting clock [F02]. Without an incident classification procedure, Vireo cannot meet the initial DORA reporting deadline of four hours after classification [F02]. Vireo's recovery mechanics can therefore be green while its regulatory incident-readiness posture is red [F02].

## 5. Vendor
The Certeva incident requires immediate escalation [F03]. Vireo must manage two distinct regulatory timelines and responsibilities [F02]:
*   **GDPR:** Certeva acts as the data processor and is obligated to notify Vireo of a breach without undue delay [F03]. Vireo, acting as the data controller, holds the responsibility to assess the breach and notify the competent supervisory authority within 72 hours of becoming aware of it [F02].
*   **DORA:** Separate from GDPR, Vireo is responsible for its own digital operational resilience [F06]. Vireo itself must independently classify the event as a major ICT-related incident [F02]. This internal classification by Vireo triggers the DORA clock, requiring Vireo to submit an initial report to its competent authority within four hours, followed by intermediate and final reports [F02].

The vendor relationship itself requires remediation [F03]. The decision is not to remove Certeva, but to apply the €45,000/year vendor hardening package [F03]. This addresses the third-party control gaps and produces a €195,000 net annual benefit [F03].

## 6. 90-Day Plan
**Month 1 — Establish and Stabilise:**
*   Appoint accountable owners for DORA, risk governance, and third-party risk [F06].
*   Create the formal enterprise risk register and record S1, S2, and S3 with treatment decisions [F06].
*   Open the Certeva incident assessment and regulatory workstreams [F03].
*   Establish DORA incident classification and reporting procedures [F02].
*   Begin the DORA Register of Information [F06].
*   Commission the overdue penetration test [F05].

**Month 2 — Remediate and Test:**
*   Implement the approved Certeva hardening package, enforce SSO and MFA, and establish continuous monitoring [F03].
*   Execute and document incident-reporting exercises [F02].
*   Establish board-level risk reporting [F06].
*   Start the SOC 2 readiness and gap-assessment programme [F06].

**Month 3 — Validate and Package:**
*   Confirm control effectiveness across Secrets [F01] and Ledger [F04].
*   Validate remediation evidence and recalculate residual risks [F06].
*   Produce the SOC 2 roadmap and engagement status [F06].
*   Assemble the final diligence package with traceable evidence [F06].

## What Will Not Be True by close
Vireo should not represent that a SOC 2 Type II report exists by the Series C close [F06]; it will only have a roadmap [F06]. DORA remediation will still be in progress [F06] where gaps require further implementation or evidence compilation [F06]. Finally, the Certeva remediation milestones will remain subject to completion and validation [F03]. The investor package should therefore present Vireo as a company with known, owned, and quantified risks on a dated remediation plan [F06].
