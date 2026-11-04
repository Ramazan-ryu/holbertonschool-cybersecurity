# Investigation Report: Ransomware Incident, 2026-09-20

**Status: DRAFT, pending record verification.**
- **Confirmed as recorded** = the source record exists and is cited. Its value still needs to be checked against the original log before final sign-off.
- **[VERIFY]** = a value this draft does not have from source records.
- **[INFERENCE]** = a conclusion drawn from records, not directly observed.

## 1. Scope and impact

| Category | Hosts | Basis | Status |
|---|---|---|---|
| Encrypted (ransom note present) | 34 | Ransom-note creation records | [VERIFY host list against SIEM] |
| Staged (actor activity, no ransom note at 10:50Z) | 19 | Remote logon, persistence, or staging records | [VERIFY host list and check for encryption events before 10:50Z] |
| Affected total | 53 | 34 + 19 | Depends on the two lines above |
| Clean | 263 | 316 − 53 | [VERIFY estate count against inventory] |

Six of the 19 staged hosts are payments hosts [VERIFY].

Earlier drafts gave 53 as the encrypted count and 244 as the clean count. Those figures were wrong and should not be used.

## 2. Timeline

| Time (UTC) | Event | Host | Source record | Status |
|---|---|---|---|---|
| 2026-08-20T23:00:00Z | LSASS access event | HALC-WS-050 | Security or Sysmon log [VERIFY EID and timezone] | Disputed; see Stage 0 |
| 2026-09-18 | Phishing message received | Mail gateway | Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>` [VERIFY date] | Recorded |
| 2026-09-20T09:01:34.616Z | Ransomware binary created | HALC-ADM-04 | Sysmon EID 11 [VERIFY hash] | Recorded |
| 2026-09-20T09:04:20.051Z | First ransom note created | HALC-PAY-10 | Sysmon EID 11 for `RESTORE_YOUR_FILES.txt` [VERIFY] | Recorded |
| 2026-09-20T10:49:49.650Z | Last staged-host logon from HALC-ADM-04 | Staged host [VERIFY] | Security EID 4624 [VERIFY] | Recorded |

## 3. Kill chain

### Stage 0: Pre-phishing credential access (dating conflict)

- **Record:** LSASS access on HALC-WS-050 at 2026-08-20T23:00:00Z [VERIFY].
- **Technique:** T1003.001 OS Credential Dumping: LSASS Memory.
- **Conflict:** This event is about a month before the phishing message in Stage 1. Stage 1 cannot have caused it.
- **Hypotheses:**
  - H0a: The timestamp is wrong (timezone or clock error). Check: confirm the event's raw timestamp and the host's time source.
  - H0b: There was an earlier, separate entry. Check: search HALC-WS-050 and the mail gateway for earlier messages and processes from August.
- **Effect:** If H0b is confirmed, the report's start point moves back to August and the causal summary in Section 6 must be rewritten.

### Stage 1: Initial access (phishing, macro-enabled attachment)

- **Record:** Mail message, Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>`, dated 2026-09-18 [VERIFY]. Attachment: macro-enabled purchase-order document [VERIFY file name and hash].
- **Technique:** T1566.001 Spearphishing Attachment; T1204.002 User Execution: Malicious File.
- **Confirmed as recorded:** The message exists in the mailbox.
- **[INFERENCE]:** This is the first delivery. Earlier mailbox messages have not been reviewed.
- **Check to confirm:** Mailbox search for earlier messages with the same sender domain and the same attachment hash.

**Handoff to Stage 2:** [INFERENCE] The macro launched `obsidn64_ldr.exe`.
- **Check to confirm:** Process creation events on HALC-WS-050 (Security EID 4688 or Sysmon EID 1) showing the document application as parent of `obsidn64_ldr.exe` [VERIFY timestamp and user].

### Stage 2: Loader execution and portal connections on HALC-WS-050

- **Record:**
  - Process creation of `obsidn64_ldr.exe` [VERIFY timestamp and user].
  - Repeated network connections from that process to the document portal [VERIFY destination, count, and timestamps].
- **Technique:** T1059 Command and Scripting Interpreter (macro execution); T1071.001 Application Layer Protocol: Web Protocols.
- **Confirmed as recorded:** the process and connections, pending the checks above.

**Handoff to Stage 3:** [INFERENCE] The portal connections are the C2 channel found in Stage 3.
- **Check to confirm:** Network flow records matching the portal destination and the C2 endpoints recovered from memory.

### Stage 3: Command and control and loader staging

- **Record:** Memory image of [VERIFY host] contains C2 client and listener scripts and loader `updt_loader01.exe`, SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063`.
- **Technique:** T1071.001; T1105 Ingress Tool Transfer.
- **Confirmed as recorded:** the artefacts in the memory image.
- **[INFERENCE]:** This C2 is the portal channel from Stage 2 (see the check above).

### Stage 4: Credential use and lateral movement from HALC-ADM-04

- **Record:** Successful remote logons (Security EID 4624) with source HALC-ADM-04 to staged hosts. Account: [VERIFY]. Last staged-host logon: 2026-09-20T10:49:49.650Z [VERIFY].
- **Technique:** T1078.002 Valid Accounts: Domain Accounts; T1021 Remote Services.
- **Confirmed as recorded:** the logon events, pending verification.
- **[INFERENCE]:** The account was compromised, not misused by an insider. The source of the credential is not established. A link from the Stage 0 or Stage 2 credential to this account is not directly logged.
- **Check to confirm:** Compare the account's logon history on HALC-WS-050 with its use on HALC-ADM-04.
- **Note:** Logons continued until 10:49Z, after encryption had begun at 09:04Z (Stage 7).

### Stage 5: Persistence on staged hosts

- **Record:** Scheduled-task creation (EID 4698) and service installation (EID 7045) [VERIFY per host].
- **Technique:** T1053.005 Scheduled Task; T1543.003 Windows Service.
- **Status:** Not yet confirmed for every staged host. The per-host list is required and must be attached as Appendix A.

### Stage 6: Domain-level access

- **Record:** Directory replication (EID 4662) from HALC-ADM-04, a non-domain-controller host. Account: [VERIFY]. Replication GUIDs: [VERIFY that DS-Replication-Get-Changes and DS-Replication-Get-Changes-All appear]. Long-lived service tickets (EID 4769): [VERIFY account and lifetime].
- **Technique:** T1003.006 OS Credential Dumping: DCSync; T1558 Steal or Forge Kerberos Tickets.
- **Confirmed as recorded:** replication activity, pending GUID verification.
- **[INFERENCE]:** Domain-level control. Forged-ticket use is not proven.

### Stage 7: Ransomware execution and encryption

- **Record:**
  - EID 11 creation of the ransomware binary on HALC-ADM-04 at 2026-09-20T09:01:34.616Z. SHA-256 as recorded: `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`.
  - First ransom note on HALC-PAY-10 at 09:04:20.051Z.
- **Conflict:** The Task 2 record gives a different ransomware hash [VERIFY which is correct].
- **Technique:** T1486 Data Encrypted for Impact. T1490 Inhibit System Recovery: not verified; check for shadow-copy deletion events [VERIFY].
- **Open:** Whether the binary was run locally on HALC-ADM-04 or pushed from another source.

## 4. Confirmed, inferred, and unknown

- **Confirmed as recorded (pending verification):** the phishing message; the LSASS event (dating disputed); the portal connections; the memory artefacts; the 4624 logons; the 4662 replication events; the ransomware file creation; the first ransom note.
- **Inferred:** Stage 1 led to Stage 2; the Stage 2 channel is the Stage 3 C2; the LSASS credential was used in Stage 4; the account was compromised; domain-level control; forged-ticket use.
- **Not established:** the earliest point of entry; whether persistence exists on every staged host; the ransomware's delivery path on HALC-ADM-04; whether any clean host was touched without logged evidence.

## 5. Timeline conflicts to resolve before this report is final

- **A. Entry date.** The LSASS event (2026-08-20) predates the phishing message (2026-09-18). Resolve through H0a or H0b in Stage 0.
- **B. Encryption before containment.** Ransom-note creation began at 09:04Z, about 106 minutes before the 10:50Z containment threshold. Each staged host must be checked for file-write, rename, or ransom-note events before 10:50Z. Any host with encryption before then moves to the encrypted set, and the counts in Section 1 change.
- **C. Logons after encryption began.** Some staged hosts were reached after the first ransom note. The staged set may therefore include hosts where encryption had already started.

## 6. Causal summary

Pending resolution of Conflict A, the chain runs: phishing message (Stage 1) → macro execution and loader on HALC-WS-050 (Stage 2) → C2 (Stage 3) → credential use on HALC-ADM-04 (Stage 4) → persistence (Stage 5) → domain replication (Stage 6) → ransomware and encryption (Stage 7). If Conflict A resolves to an earlier entry, Stage 0 becomes the start of the chain, and the summary is rewritten from there.

## 7. Open questions

- Whether the earliest entry predates the phishing message (A).
- Whether any staged host was encrypting before 10:50Z (B).
- Whether the ransomware was run locally on HALC-ADM-04 or pushed from elsewhere.
- How the LSASS credential reached the Stage 4 account.
- Whether forged tickets were used, and how far domain control extends.
- Which ransomware hash is correct.
- Whether any of the 263 clean hosts showed actor activity without logged evidence.
