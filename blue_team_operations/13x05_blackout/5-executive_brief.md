# Board Brief: Halcyon Payments Incident

*Confidential. Prepared for the recovery-budget and disclosure decision.*

## What happened

On 20 September, a macro-enabled business document was opened on a workstation. It let an attacker move from one computer into the company’s central access systems and spread to other computers. The attacker then locked files and tried to remove recovery copies.

At the 10:50 UTC decision point, records showed **34 computers already locked** and **19 more under the attacker’s control but not yet confirmed locked**. Six of those 19 support payments. The other 263 computers had no matching signs in the records reviewed; coverage still needs checking. A later record shows activity on one of the 19 after the decision time. These figures describe the 10:50 snapshot, not everything that happened later.

The containment and recovery steps recorded for this exercise are decisions in a frozen simulation. No production computers were actually disconnected or changed.

## What it may cost

The full cost is not yet known. It will include investigation, rebuilding computers from trusted copies, restoring payment services, replacing access credentials, and staff time. No reliable total is available yet, and no customer-data theft has been confirmed in the evidence reviewed.

## What we have decided

The response plan is to disconnect the 34 locked computers and the 19 computers the attacker had reached, starting with the six payment systems. The remaining computers should stay available while monitoring is checked and any new evidence is reviewed. Payment service restoration comes first, but only after each rebuilt system passes security checks.

The board is asked to approve an emergency recovery budget and confirm that payment operations take priority over less critical services.

## The hard truth about removing the attacker

Changing ordinary passwords and cleaning individual computers may not be enough. The attacker requested access to copy the company’s central login secrets. If that access was abused, the company must rebuild trusted login systems, replace privileged and service credentials, and reset the master login key twice with time for the changes to reach every login server. Until those steps are checked, reconnecting rebuilt computers could let the attacker return.

## Disclosure

The records reviewed do not establish that customer or employee information was taken. Legal and regulatory advisers should decide whether notice is required using confirmed evidence; this brief makes no claim that data was exposed.
