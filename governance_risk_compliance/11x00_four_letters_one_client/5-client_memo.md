**To:** CEO, Nordwell Technologies
**From:** Northbridge Risk Advisory
**Re:** Compliance triage on Hartwell, Brightpath, and the Q4 EU launch

## The three events, mapped

**Hartwell Insurance ($1.2M ARR, 6 weeks).** Triggers SOC 2, and only SOC 2. This is not law — no regulator, no penalty. It is a **market/contract** demand: Hartwell's procurement will not sign without proof of controls. A Type I plus a credible roadmap satisfies their stated minimum.

**Brightpath Health (signed, BAA due before an 8-week go-live).** Triggers HIPAA. Brightpath is a covered entity; the moment Nordwell processes their staff's occupational-health data (medical-note metadata included), Nordwell becomes a **business associate by law**. The BAA is not a formality to route to legal for a quick signature — it is the contract HIPAA requires to exist before that data flows.

**Q4 EU launch + in-app card payments.** Triggers two frameworks at once. The EU pilot customers trigger **GDPR** — a law that applies because Nordwell is targeting people in France and Germany, not because Nordwell has an EU office. The embedded checkout triggers **PCI DSS** — a card-brand contract enforced through the acquiring bank, not a statute.

## Correcting one assumption

The CPO is right that a payment provider reduces PCI DSS scope, but wrong that it removes it: Nordwell remains a merchant and will still need to complete the applicable SAQ. Separately, and independent of any payment processor, offering the product to individuals in France and Germany brings GDPR into play on its own.

## Priority order

1. **Brightpath BAA — first.** The contract is already signed and PHI-adjacent data is already committed to flow. This is a live legal obligation today, not a future one, and HIPAA exposure is the most severe category on the table.
2. **Hartwell SOC 2 — second.** Nearest deadline (6 weeks) and $1.2M ARR on the line, but the fallback (Type I + roadmap) is already accepted, so the downside of a short delay is commercial, not legal.
3. **EU launch — third, start now in parallel.** Longest runway (Q4), but it carries two frameworks and needs foundational work (data mapping, lawful basis, SAQ scoping) that takes real time to do properly.

## One current fact per framework

- **HIPAA:** the Security Rule update HHS proposed in January 2025 is still a proposed rule, not finalized — the 2013 rule is what currently binds Brightpath's BAA today.
- **SOC 2:** reports are issued against the AICPA's 2017 Trust Services Criteria, with 2022 revised points of focus.
- **PCI DSS:** v4.0.1 is the only active version; all its requirements have been mandatory since March 31, 2025.
- **GDPR:** EU regulators issued roughly €1.2 billion in fines in 2025 alone. Enforcement is not slowing down.

## Monday morning

- **Brightpath:** route the BAA to legal for execution today; no occupational-health data moves before it is countersigned.
- **Hartwell:** kick off a SOC 2 readiness gap assessment this week and send Hartwell a dated Type II roadmap.
- **EU launch:** open parallel workstreams — GDPR data mapping and lawful-basis review, plus PCI SAQ scoping with the payment provider.
