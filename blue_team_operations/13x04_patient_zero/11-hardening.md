# Hardening recommendations

1. Apply supplier-aware anomaly detection. Alert or hold high-risk mail when a known supplier sends an unusual file type, new recipient pattern, unusual link destination, new sending account, or atypical relay path. Baseline legitimate supplier behaviour and make exceptions reviewable.

2. Detonate and block macro-enabled documents received from external senders when static or behavioural analysis identifies macro execution, encoded payloads, or network indicators. Quarantine `docm` mail from suppliers until it passes risk-based inspection.

3. Inspect and rewrite inbound URLs through a controlled proxy or detonation service. Block links to newly observed destinations and threat-intelligence matches, including `198.51.100.47`; keep an allow-list process for legitimate supplier portals.

4. Restrict Office macro execution through Microsoft policy: block macros from Internet-origin documents, limit trusted locations, and permit signed macros only from approved publishers. Monitor child processes and unusual document-update handlers.

5. Maintain detections for the campaign indicators: decoded payload hash `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2`, C2 `198.51.100.47`, and persistence value `Tavistock9`. Correlate mail delivery, attachment disposition, endpoint execution, registry changes, and network beacons.

6. Keep SPF, DKIM, and DMARC enforcement in place. They blocked spoofing risk correctly here, but they cannot identify authorised malicious mail. Document that limitation in supplier-risk and incident-response processes.

7. Notify Harrowfield Metalworks through the established incident-contact channel with the sending account, relay, delivery time, and relevant message identifier. Ask it to investigate `dana.berglund`, revoke active sessions, reset credentials, review forwarding rules, and rotate compromised credentials or keys as warranted.

## Operating changes

The first recommendation is a supplier-account-abuse control, not another sender-authentication record. Corvan should maintain a baseline for each important supplier: normal sending volume, recipients, subjects, attachment types, link domains, sending geography, and usual delivery times. A message from an authenticated supplier should receive additional review when it is a sharp departure from that baseline, such as a first-time macro-enabled document, an unusual payment or purchase-order request, a new URL domain, or delivery to an executive who does not normally work with that supplier. This costs money for mail-security analytics and tuning, and it costs analysts time because some legitimate supplier changes will be quarantined. The tradeoff is worthwhile because it evaluates intent and context after authentication has already succeeded.

Corvan should add attachment and URL detonation at the mail boundary. Office documents with macros, embedded objects, external relationships, and script-like content should be converted or quarantined for analysis, while links should be expanded and checked against reputation, registration age, destination changes, and sandbox behaviour. The control should inspect the decoded content rather than trusting the filename or displayed link text. This introduces delivery delay and can disrupt legitimate purchase orders, shared documents, and supplier portals. Corvan will also pay for sandbox capacity and analysts to review false positives, but it directly addresses the weaponised document and callback path seen here.

High-risk supplier requests should use an out-of-band confirmation process. A purchase-order change, bank-detail change, urgent document request, or unexpected attachment should be confirmed using a phone number or portal already held in Corvan's supplier records, never a number or link supplied by the message. This is comparatively inexpensive, but it adds friction and can slow urgent business. The process should be risk-based so routine correspondence is not blocked while unusual requests require a second person or a verified callback.

Identity protection should cover supplier users as well as Corvan employees. Corvan can require stronger assurance for supplier portals, monitor anomalous sign-ins where the supplier provides those signals, and ask strategic suppliers to enforce phishing-resistant MFA, session revocation, mailbox-rule monitoring, and rapid incident notification. Corvan cannot configure the supplier's tenant directly, so this has contractual and coordination cost; it may also exclude smaller suppliers that cannot meet the requirement. Nonetheless, supplier security attestations, incident contacts, and minimum controls make account takeover less likely and shorten the time to containment.

## What will not fix this incident

Turning on SPF, DKIM, DMARC, or a stricter DMARC policy is not the remedy. Corvan already published these records, enforced DMARC reject, and recorded SPF, DKIM, and DMARC passes for the patient-zero message. The attacker used an authentic supplier account, authorised relay, and valid signing key, so a configuration change to those same domain-authentication controls would still have produced a pass. They remain valuable against spoofing and should stay enabled, but they cannot determine that a trusted account has been taken over or that an authenticated message is malicious.

The handoff to Dana is: “It got in because the attacker used a compromised Harrowfield supplier account to send a correctly authenticated, weaponised document through the supplier’s authorised mail infrastructure; Corvan’s authentication controls worked, but they do not measure account integrity or intent.”
