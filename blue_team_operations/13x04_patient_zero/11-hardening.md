# Hardening recommendations

1. Apply supplier-aware anomaly detection. Alert or hold high-risk mail when a known supplier sends an unusual file type, new recipient pattern, unusual link destination, new sending account, or atypical relay path. Baseline legitimate supplier behaviour and make exceptions reviewable.

2. Detonate and block macro-enabled documents received from external senders when static or behavioural analysis identifies macro execution, encoded payloads, or network indicators. Quarantine `docm` mail from suppliers until it passes risk-based inspection.

3. Inspect and rewrite inbound URLs through a controlled proxy or detonation service. Block links to newly observed destinations and threat-intelligence matches, including `198.51.100.47`; keep an allow-list process for legitimate supplier portals.

4. Restrict Office macro execution through Microsoft policy: block macros from Internet-origin documents, limit trusted locations, and permit signed macros only from approved publishers. Monitor child processes and unusual document-update handlers.

5. Maintain detections for the campaign indicators: decoded payload hash `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2`, C2 `198.51.100.47`, and persistence value `Tavistock9`. Correlate mail delivery, attachment disposition, endpoint execution, registry changes, and network beacons.

6. Keep SPF, DKIM, and DMARC enforcement in place. They blocked spoofing risk correctly here, but they cannot identify authorised malicious mail. Document that limitation in supplier-risk and incident-response processes.

7. Notify Harrowfield Metalworks through the established incident-contact channel with the sending account, relay, delivery time, and relevant message identifier. Ask it to investigate `dana.berglund`, revoke active sessions, reset credentials, review forwarding rules, and rotate compromised credentials or keys as warranted.
