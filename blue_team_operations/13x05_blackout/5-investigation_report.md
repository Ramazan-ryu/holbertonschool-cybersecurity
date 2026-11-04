# Investigation Report: Ransomware Incident, 2026-09-20

**Status: DRAFT.** [VERIFY] = not yet confirmed against source records. [INFERENCE] = a conclusion drawn from the evidence, not directly observed. Each stage lists the records a responder should pull to confirm it.

## 1. Impact

| Category | Hosts | Basis |
|---|---|---|
| Encrypted (ransom note present) | 34 | [VERIFY host list against SIEM] |
| Staged (actor activity, no ransom note at 10:50Z) | 19 | [VERIFY host list; see Section 4, item B] |
| Affected total | 53 | 34 + 19 |
| Clean | 263 | 316 − 53 [VERIFY estate count against inventory] |

Six of the 19 staged hosts are payments hosts [VERIFY].

Earlier drafts gave 53 as the encrypted count and 244 as the clean count. Those figures were wrong.

## 2. Kill chain

### Stage 1: Initial access (phishing, macro-enabled attachment)

- **Record:** Mail message, Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>`. Date: 2026-09-18 [VERIFY]. Attachment: macro-enabled purchase-order document [VERIFY file name and hash].
- **Technique:** T1566.001 Spearphishing Attachment; T1204.002 User Execution: Malicious File.
- **Status:** Message confirmed as recorded [VERIFY]. [INFERENCE] that it is the first delivery; earlier mailbox messages have not been reviewed.

**Handoff to Stage 2:** [INFERENCE] The macro launched the loader. Verify with parent-child process events on HALC-WS-050 (Security EID 4688 or Sysmon EID 1) showing the document application as parent of `obsidn64_ldr.exe` [VERIFY].

### Stage 2: Loader execution and credential access on HALC-WS-050

- **Record:**
  - Process creation of `obsidn64_ldr.exe` on HALC-WS-050 [VERIFY timestamp and user].
  - Repeated network connections from that process to the document portal [VERIFY destination and count].
  - LSASS access event on HALC-WS-050, recorded at 2026-08-20T23:00:00Z [VERIFY timestamp and timezone].
- **Technique:** T1059 Command and Scripting Interpreter; T1003.001 OS Credential Dumping: LSASS Memory.
- **Status:** Process and LSASS events as recorded [VERIFY].
- **Timing conflict:** The LSASS event is dated about one month before the phishing message in Stage 1, so Stage 1 cannot have caused it. Either the timestamp is wrong, or there was an earlier and separate entry. This must be resolved before Stage 2 is treated as following Stage 1.

**Handoff to Stage 3:** [INFERENCE] The portal connections and the C2 traffic in Stage 3 are the same channel. Needs network-flow evidence [VERIFY].

**Handoff to Stage 4:** [INFERENCE] Credentials taken from LSASS were later used on HALC-ADM-04. This link is not directly logged, and the source of the credential is not established.

### Stage 3: Command and control and loader staging

- **Record:** Memory image of [VERIFY host] contains C2 client and listener scripts and the loader `updt_loader01.exe`, SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063`.
- **Technique:** T1071.001 Application Layer Protocol: Web Protocols; T1105 Ingress Tool Transfer.
- **Status:** Artefacts confirmed in memory analysis. [INFERENCE] that this C2 is the portal channel from Stage 2. Not yet confirmed by network records.

### Stage 4: Administrative access and lateral movement from HALC-ADM-04

- **Record:** Successful remote logons (Security EID 4624) with source HALC-ADM-04 to staged hosts. Account: [VERIFY]. Last staged-host logon: 2026-09-20T10:49:49.650Z [VERIFY].
- **Technique:** T1078.002 Valid Accounts: Domain Accounts; T1021 Remote Services.
- **Status:** Logon events as recorded [VERIFY]. [INFERENCE] that the account was compromised rather than misused by an insider.
- **Note:** Logons continued until 10:49Z, after encryption had begun at 09:04Z (Stage 7). The actor was still active during encryption.

### Stage 5: Persistence

- **Record:** Scheduled-task creation (EID 4698) and service installation (EID 7045) on staged hosts [VERIFY]. A per-host list has not yet been produced and should be attached as Appendix A.
- **Technique:** T1053.005 Scheduled Task; T1543.003 Windows Service.
- **Status:** Not yet confirmed. The correlation with Stage 4 logons is a working hypothesis.

### Stage 6: Domain-level access

- **Record:** Directory replication activity (EID 4662) with source HALC-ADM-04, a non-domain-controller host. Account: [VERIFY]. The record must show the replication extended-right GUIDs (DS-Replication-Get-Changes and DS-Replication-Get-Changes-All) to count as DCSync evidence [VERIFY]. Long-lived service tickets (EID 4769): [VERIFY account and ticket lifetime].
- **Technique:** T1003.006 OS Credential Dumping: DCSync; T1558 Steal or Forge Kerberos Tickets.
- **Status:** Replication activity as recorded [VERIFY GUIDs]. [INFERENCE] domain-level control. Forged-ticket use is not proven.

### Stage 7: Ransomware execution and encryption

- **Record:**
  - EID 11 file creation of the ransomware binary on HALC-ADM-04 at 2026-09-20T09:01:34.616Z. SHA-256 recorded as `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`.
  - First ransom note (`RESTORE_YOUR_FILES.txt`) on HALC-PAY-10 at 09:04:20.051Z.
- **Conflict:** The Task 2 record gives a different ransomware hash [VERIFY which is correct].
- **Technique:** T1486 Data Encrypted for Impact. T1490 Inhibit System Recovery is not yet verified; check for shadow-copy deletion events [VERIFY].
- **Status:** File creation and ransom-note creation as recorded [VERIFY].

## 3. Confirmed, inferred, and unknown

- **Recorded, still to verify:** the phishing message; the LSASS event (timestamp disputed); the portal connections; the loader artefacts in memory; the 4624 logons; the 4662 replication events; the EID 11 creation; the first ransom note.
- **Inferred:** that Stage 1 led to Stage 2; that LSASS credentials were used in Stage 4; that Stage 3 C2 is the Stage 2 channel; that the Stage 4 account was compromised; domain-level control; forged-ticket use; the scope of the estate.
- **Not established:** whether the ransomware was launched locally on HALC-ADM-04 or pushed from elsewhere; the earliest point of entry; whether persistence (Stage 5) exists on every staged host.

## 4. Timeline conflicts to resolve before this report is final

- **A. Entry date.** The LSASS event (2026-08-20) predates the phishing message (2026-09-18). Check the SIEM timestamp and timezone. If the date is correct, there was an earlier entry and the start of the chain moves back.
- **B. Encryption before containment.** Ransom-note creation began on HALC-PAY-10 at 09:04Z, about 106 minutes before the 10:50Z containment threshold. Check every staged host for file-write, rename, or ransom-note events before 10:50Z. Any staged host with encryption activity before then moves to the encrypted set, and the counts in Section 1 change.
- **C. Logons after encryption began.** The last staged-host logon (10:49:49Z) is after the first ransom note (09:04Z). Some hosts may have been reached after encryption had started.

## 5. Open questions

- Whether the earliest entry predates the phishing message (A).
- Whether any staged host was encrypting before 10:50Z (B).
- Whether the ransomware was launched on HALC-ADM-04 locally or pushed from another host.
- How the Stage 2 credential reached the Stage 4 account.
- Whether forged tickets were used, and how far domain control extends.
- Which ransomware hash is correct.
- Whether any of the 263 clean hosts showed actor activity without logged evidence.
