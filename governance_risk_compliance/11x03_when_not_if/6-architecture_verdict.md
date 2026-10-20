# Architecture Verdict: ERP Recovery Readiness

**To:** Copeland Foods Board of Directors
**From:** Northbridge Risk Advisory — BIA/DR Engagement Team
**Re:** Can the current architecture meet Copeland's own tolerances?

## How long can Copeland afford to be down?

The ERP (P3) bleeds €9,000/hour from hour 0, and past hour 4 it drags
Production Scheduling (P2) down with it at an additional €15,000/hour,
since P2 cannot run without ERP data. Modeling that cascade against the
board's €324,000 cumulative-loss threshold gives an **MTPD of 16 hours**
for the ERP. The resilience policy (RTO no more than 50% of MTPD) sets
the ERP's **RTO at 8 hours**. Past hour 16, losses cross the line the
board itself defined as escalation-to-existential.

## Where the current architecture fails

**Recovery time.** The 4.32 TB ERP database, restored at 120 MB/s, takes
10 hours plus a mandatory 2-hour integrity validation: **12 hours total**
— 4 hours past the 8-hour RTO.

**Recovery point.** The nightly full backup sits on the same directory
infrastructure as production, so it is not a copy the attacker cannot
reach and does not count toward RPO. The only qualifying copy is the
weekly offline immutable backup, 26 hours old at incident start — the
**achieved RPO is 26 hours**, against an **EDI-imposed RPO target of 4
hours**: a 22-hour miss. Order traffic beyond the 4-hour replay window
would need manual re-keying from paper. Both the RTO and the RPO
equations fail.

## The fix

Shorten the offline immutable snapshot cycle from weekly to every 4
hours, so RPO tracks the EDI replay window, paired with parallelized
restore streams sized to bring total recovery under 8 hours.

The cheaper alternative — backing up more often to the existing online
repository — was rejected: those copies stay on attacker-reachable,
same-directory infrastructure, so no frequency makes them a copy the
attacker cannot reach. It fixes nothing on the RPO equation and leaves
the RTO equation untouched.

## Activation

The Incident Commander (Head of IT/CISO) declares a disaster the moment
confirmed downtime is projected to exceed the affected process's MTPD,
or the instant ransomware/data destruction is confirmed on the ERP.

## Ransom position, from T+24h

Copeland does not negotiate or pay directly. The cyber-insurer must be
notified before any contact with the threat actor, and OFAC sanctions
screening is completed before any payment is considered — paying a
sanctioned actor carries federal exposure regardless of ransom size.
