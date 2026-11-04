# Investigation Report

## Scope and evidence basis

This report reconstructs the intrusion from initial entry to encryption on 2026-09-20. Each stage cites the record that establishes it. Items marked **[Inference]** are conclusions drawn from the evidence rather than directly observed.

## Confirmed impact

- **Encrypted:** 53 hosts created `RESTORE_YOUR_FILES.txt`.
- **Staged, not encrypted:** 19 hosts showed actor activity (remote logon, staging, persistence, or service creation) but had not created a ransom note at the containment threshold. Six are payments hosts.
- **Clean:** 244 hosts show no confirmed actor activity. This is a classification, not a guarantee; see Open Questions.

## Kill chain

### Stage 1: Initial access (email, macro-enabled attachment)
- **Record:** Mailbox message `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>` carrying a macro-enabled purchase-order attachment.
- **Technique:** T1566.001 Spearphishing Attachment; T1204.002 User Execution (Malicious File).
- **Status:** Confirmed that the message exists. **[Inference]** that it is the first-delivered message; mailbox review for earlier messages is not documented.

### Stage 2: Loader execution and credential access on HALC-WS-050
- **Record:** HALC-WS-050 made repeated connections to the document portal as `obsidn64_ldr.exe`, and an LSASS read is logged at 2026-08-20T23:00:00Z.
- **Technique:** T1059 Command and Scripting Interpreter (inferred from macro execution); T1003.001 OS Credential Dumping: LSASS Memory.
- **Status:** Confirmed process and LSASS access events. **[Inference]** that the LSASS read yielded credentials used later, because the link is not directly logged.
- **Timing note:** The LSASS read predates the 2026-09-20 encryption by about one month. Confirm the timestamp and timezone before relying on the interval.

### Stage 3: Command and control and loader staging
- **Record:** Memory image contains C2 client/listener scripts and loader `updt_loader01.exe` (SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063`).
- **Technique:** T1071.001 Application Layer Protocol: Web Protocols; T1105 Ingress Tool Transfer.
- **Status:** Confirmed in memory analysis. **[Inference]** that the C2 channel is the same as the document-portal connections; this needs network-flow confirmation.

### Stage 4: Lateral movement via administrative access (HALC-ADM-04)
- **Record:** Successful remote logons (EID 4624) from HALC-ADM-04 to staged hosts, the last at 2026-09-20T10:49:49.650Z.
- **Technique:** T1078.002 Valid Accounts: Domain Accounts; T1021 Remote Services.
- **Status:** Confirmed logon events. **[Inference]** that the account was compromised rather than misused by an insider; the source of the credential is not established.

### Stage 5: Persistence and staging
- **Record:** Scheduled-task creation and service installation on staged hosts, correlated with the 4624 logons.
- **Technique:** T1053.005 Scheduled Task; T1543.003 Windows Service.
- **Status:** Confirmed in SIEM. Per-host mapping to the 19-host set is in the appendix.

### Stage 6: Domain-level access
- **Record:** EID 4662 directory replication rights exercised from HALC-ADM-04, a non-domain-controller source. Long-lived service tickets appear in EID 4769.
- **Technique:** T1003.006 DCSync; T1558 Steal or Forge Kerberos Tickets.
- **Status:** Replication activity is confirmed. **[Inference]** that the actor holds domain dominance and has forged tickets. Forged-ticket use is not yet proven, and this is the largest open question for eradication.

### Stage 7: Ransomware deployment and encryption
- **Record:** EID 11 file creation of the ransomware (confirmed SHA-256 `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`) on HALC-ADM-04 at 2026-09-20T09:01:34.616Z. Ransom-note creation begins at 09:04:20.051Z on HALC-PAY-10.
- **Technique:** T1486 Data Encrypted for Impact; T1490 Inhibit System Recovery (not yet verified; check shadow-copy deletion events).
- **Status:** Confirmed file creation and ransom notes.

## Open questions

- Whether the ransomware was deployed from HALC-ADM-04 or pushed from another source.
- Whether forged tickets were used, and how far the domain compromise extends.
- The gap between the 2026-08-20 LSASS read and the 2026-09-20 deployment, which is not yet explained.
- Whether any of the 244 "clean" hosts were touched by the actor without generating logged evidence.
