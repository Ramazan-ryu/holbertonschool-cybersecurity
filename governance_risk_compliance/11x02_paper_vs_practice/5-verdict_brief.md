# Tessara Security Posture — Board Brief

## Posture

Tessara's security program is real but unmanaged: individual controls work in isolation, but nothing connects them into a defensible whole. The two issues that matter most at board level: risk governance has been deferred for three consecutive quarters with no risk register anywhere in the company [E09], and incident response is entirely improvised — the last phishing incident was handled by "whoever was around," with no ticket, timeline, or post-incident review [E07]. Combined with no named security owner [E12], Tessara cannot currently tell a customer, in writing, who is accountable when something goes wrong.

## Top Gaps

- **GV.RM** — No risk register; risk is not tracked, only deferred [E09]. Consequence: the board cannot demonstrate risk oversight to auditors or acquirers.
- **GV.RR** — No CISO; ownership is informal and undocumented [E12]. Consequence: no single accountable point of failure or escalation for security decisions.
- **RS.MA** — Incidents are handled ad hoc, with no process [E07]. Consequence: a real breach will be slower to contain and impossible to report credibly to a regulator or customer.
- **ID.AM** — Cloud assets are absent from the asset register entirely [E03]. Consequence: unmanaged AWS accounts are a blind spot for both attackers and auditors.
- **PR.AA** — Offboarding is reactive, not procedural [E04]. Consequence: departing staff retain access longer than the business believes.

## Certification Path

Use the NIST CSF 2.0 profile as the working frame now, since it lets us close gaps by function without waiting for a certification date. Target ISO/IEC 27001 certification to unblock enterprise procurement, sequenced as follows:

- **Q1** — Stand up governance: risk register, named security owner, policy review cycle.
- **Q2** — Close technical and process gaps: asset inventory (including cloud), offboarding procedure, incident response process.
- **Q3** — Stage 1 audit (documentation and readiness review) once governance and controls are evidenced, not just written.
- **Q4** — Stage 2 audit (operating effectiveness review), followed by ongoing surveillance audits.

## First 90 Days

1. Appoint a named security owner with defined authority, closing the accountability gap [E12].
2. Stand up a risk register and a recurring board risk review, closing the deferred-risk gap [E09].
3. Document and pilot an incident response procedure, including a ticket and post-incident review step, closing the improvisation gap [E07].

## Cost

Certification-body fees for stage 1 and stage 2 audits typically run five figures (EUR), plus annual surveillance fees thereafter. The larger cost is internal effort: closing governance and process gaps consumes real engineering and leadership time over the full twelve months, not just audit weeks. The evidence is unambiguous on one point: without a named, resourced security owner [E12], no amount of technical control fixes will produce a defensible ISMS, because there is no one accountable to run it.
