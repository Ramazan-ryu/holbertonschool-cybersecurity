# Investigation Report: Ransomware Incident, 20 September 2026

**Readers:** Incident responders; the incident record.
**Status:** DRAFT, revision 3. Not final. Checker result on revision 2: FALSE. Revision 3 adds the checker findings and their responses (Section 0), a status column on every verification query (Section 6), and corrects two errors from revision 2. No verification query has been run in this revision, so no conclusion has changed from revision 2.

## Conventions

- **Observed:** the event exists in a cited record. The raw value still needs checking against the original log unless marked otherwise.
- **Inferred:** a conclusion drawn from records. Not directly logged.
- **Unverified:** a value or link this draft does not yet have from source records. Each has a query ID in Section 6.
- Record IDs (R01 to R11) are defined in Section 2. Hashes are given in full.

## 0. Checker findings and where each is addressed

| Checker finding | Response in this revision | Still open |
|---|---|---|
| Entry point unresolved (LSASS 2026-08-20 vs email 2026-09-18) | Section 3.1, hypotheses H0a and H0b, queries Q1 and Q6 | Yes. Blocks a TRUE verdict. |
| Execution chain (`obsidn64_ldr.exe`) not directly proven | Section 3.2 and 3.3, queries Q3 and Q4 | Yes |
| Staging-to-encryption link, including HALC-PAY-10 overlap | Section 1 (count range), Section 5 (conflict), Q9 | Yes |
| Scope and impact not fully established | Section 1 gives a range, not a single number | Yes |
| Claims marked unverified rather than confirmed | Every such claim carries a query ID | Yes until queries return |
| Missing step (September 11 replication event) | Added in revision 2 as R06 and Section 3.5 | Interpretation open (Q14) |

## 1. Scope as the records currently support it

| Category | Count | Basis | Status |
|---|---|---|---|
| Encrypted (ransom note created) | 34 | R09 and the campaign extract | Observed for the set as listed; host list unverified (Q9) |
| Staged (remote logon from HALC-ADM-04, persistence, or staging; no ransom note at 10:50Z) | 19 | R10 and campaign extract | Unverified: the list includes HALC-PAY-10, which has a ransom note |
| Affected, unique hosts | 52 or 53 | 34 + 19, minus any host in both sets | **Unresolved.** If HALC-PAY-10 is encrypted, the unique total is 52 and the staged count is 18. |
| Clean | 263 or 264 | 316 minus the affected total | Depends on the line above and the estate count (Q10) |
| Payments hosts among staged | 5 or 6 | Staged list | Depends on HALC-PAY-10 |

Earlier drafts gave 53 encrypted and 244 clean. Those figures were wrong and must not be used. The 53 came from adding the two sets without removing the overlap.

Activity after 10:50Z (R07, and the campaign extract ending at 2026-09-20T22:44:58.057Z) means the affected count may rise. See Section 4.

## 2. Record register

| ID | Record | Host | Time (UTC) | Status |
|---|---|---|---|---|
| R01 | Mailbox item PZ-0001.eml, macro-enabled attachment Order_Confirmation_Revised_PO-48490.docm. Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>` | Mail gateway / mailbox | Received 2026-09-18 | Observed. Attachment hash not yet recorded (Q2). |
| R02 | Sysmon EID 10: process access to LSASS by `obsidn64_ldr.exe` | HALC-WS-050 | 2026-08-20T23:00:00Z | Observed in SIEM. Raw timestamp and timezone unverified (Q1). |
| R03 | Process creation of `obsidn64_ldr.exe`, parent document application | HALC-WS-050 | Unknown | **Not located.** No record ID exists yet (Q3). |
| R04 | Repeated connections from `obsidn64_ldr.exe` to docportal-secure-access.example | HALC-WS-050 | Unknown; count unverified | Observed in SIEM per the campaign extract. Times and count unverified (Q4). |
| R05 | Memory image artefacts: `c2client.ps1`, `c2listener.ps1`, staged loader reference `10.0.2.2:8091/updt_loader01.exe`, loader SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063` | Host of memory image unverified (Q5) | Unknown | Observed in /evidence/memory.raw. Host identity unverified. |
| R06 | Security EID 4662: directory replication request by `adm.okonkw01`, source `10.20.31.25`, object `DC=halcyon,DC=local`, using DS-Replication-Get-Changes and DS-Replication-Get-Changes-All | HALC-DC-02 | 2026-09-11T23:20:00.246Z | Observed. Requester is a non-DC source (Section 3.5). |
| R07 | Security EID 4769: service ticket requests, account `svc-vestg_1@HALCYON.LOCAL`, from `10.20.31.25`, lifetime 240 hours, including `cifs/halc-fs-01` | Domain controller unverified (Q7) | Includes 2026-09-20T20:46:52.913Z | Observed. After the containment threshold. See Section 3.9. |
| R08 | Sysmon EID 11: creation of `C:\ProgramData\HalcyonUpdate\obsidn64.exe` | HALC-ADM-04 | 2026-09-20T09:01:34.616Z | Observed. Hash e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957 (conflict, Section 5). |
| R09 | Sysmon EID 11: creation of `RESTORE_YOUR_FILES.txt` | HALC-PAY-10 | 2026-09-20T09:04:20.051Z | Observed. First ransom note in the campaign extract. |
| R10 | Security EID 4624: successful network logon from HALC-ADM-04 (10.20.31.25) to staged hosts | Various (staged set) | Last: 2026-09-20T10:49:49.650Z, HALC-WS-100 | Observed. Account name unverified (Q8). |
| R11 | EID 4698 (scheduled task) and EID 7045 (service install) per staged host | Staged hosts | Unknown | **Not compiled.** |

## 3. Chronological reconstruction

### 3.1 Earliest recorded activity: LSASS access (2026-08-20)

- **Event:** R02. `obsidn64_ldr.exe` on HALC-WS-050 read LSASS memory at 2026-08-20T23:00:00Z.
- **Technique:** T1003.001 OS Credential Dumping: LSASS Memory.
- **Status:** Observed in SIEM. Earliest event in the campaign extract.
- **Conflict:** about a month before the phishing email (R01). The email cannot have caused it.
- **Hypotheses:**
  - H0a: timestamp error (timezone or host clock). Test: compare the raw event timestamp with the host's time source (Q1).
  - H0b: an earlier, separate entry exists. Test: search HALC-WS-050 and the mail gateway for August processes and messages (Q6).
- **Effect:** If H0b holds, the chain starts earlier and Section 5 must be rewritten.

### 3.2 Email delivery and user execution (2026-09-18)

- **Event:** R01.
- **Technique:** T1566.001 Spearphishing Attachment; T1204.002 User Execution: Malicious File.
- **Status:** Message observed. Link to execution inferred.
- **Transition to 3.3:** inferred that the macro launched `obsidn64_ldr.exe`.
- **Confirmation needed:** parent-child process record on HALC-WS-050 (Q3). Mailbox search for the same sender domain and attachment hash (Q2).

### 3.3 Loader execution and portal connections (dates unverified)

- **Events:** R03 (not located) and R04.
- **Technique:** T1059 Command and Scripting Interpreter; T1071.001 Application Layer Protocol: Web Protocols.
- **Status:** Connections observed in SIEM. Process parentage not located.
- **Transition to 3.4:** inferred that these connections are the C2 channel in R05.
- **Confirmation needed:** network flow matching the portal destination to the C2 endpoints in memory (Q4, Q5).

### 3.4 Command-and-control and loader staging (memory image)

- **Event:** R05.
- **Technique:** T1071.001; T1105 Ingress Tool Transfer.
- **Status:** Artefacts observed. Host of origin unverified (Q5).
- **Note:** the loader reference uses 10.0.2.2, a private address. Confirm whether it is internal, lab, or relay. The meaning of this step depends on the answer.

### 3.5 Directory replication request (2026-09-11)

- **Event:** R06. Replication rights were used by `adm.okonkw01` from `10.20.31.25` (HALC-ADM-04) against the domain partition on HALC-DC-02.
- **Technique:** T1003.006 OS Credential Dumping: DCSync.
- **Status:** Request observed. The source is a workstation, not a domain controller. Approved directory-sync accounts can replicate from non-DC hosts, so the source must be checked against the approved list (Q14).
- **Not established:** whether the request returned secret data. The record shows the request, not the response.
- **Ordering:** after the LSASS event (3.1) and before the email (3.2). Missing from revision 1.
- **Link to 3.1:** inferred that the account's credential came from the LSASS access. Not logged (Q8).

### 3.6 Remote logons to staged hosts (2026-09-20, before 10:50Z)

- **Event:** R10. Last logon at 10:49:49.650Z.
- **Technique:** T1078.002 Valid Accounts: Domain Accounts; T1021 Remote Services.
- **Status:** Observed. Account name unverified (Q8).

### 3.7 Persistence on staged hosts

- **Event:** R11 (not compiled).
- **Technique:** T1053.005 Scheduled Task; T1543.003 Windows Service.
- **Status:** Unverified for every host. No host is described as persistent until R11 is compiled.

### 3.8 Ransomware creation and encryption (2026-09-20)

- **Events:** R08 (09:01:34.616Z, HALC-ADM-04); R09 (09:04:20.051Z, HALC-PAY-10).
- **Technique:** T1486 Data Encrypted for Impact. T1490 Inhibit System Recovery not verified (Q11).
- **Open:** whether the binary ran locally on HALC-ADM-04 or was pushed from elsewhere (Q12).

### 3.9 Activity after the containment threshold (2026-09-20, after 10:50Z)

- **Events:** R07 shows ticket requests from `10.20.31.25` at 20:46:52.913Z. The campaign extract ends at 22:44:58.057Z.
- **Conflict:** the decision log records containment at 10:50–11:00Z.
- **Possible explanations:** isolation did not take effect; the timestamp is wrong; or another host used the same address. Each is tested by Q7 and Q13.

## 4. Questions this report cannot yet answer

- Did any staged host show encryption before 10:50Z? (Q9)
- Did HALC-ADM-04 stay active after isolation? (Q13)
- Did the replication request in 3.5 return credential data? (Q14)
- Were forged tickets used, and how far does domain access extend? (Q15)
- Do any clean hosts show actor activity without logged evidence? (Q10)

## 5. Conflicts

| Conflict | Records | Status |
|---|---|---|
| Entry date | R02 (2026-08-20) vs R01 (2026-09-18) | Unresolved. H0a/H0b in 3.1. |
| Ransomware hash | R08 gives e7c189…957. An earlier draft cited a different ransomware hash from another record. | Unresolved. That record is not identified in the current source set. |
| Loader hash | `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2` (initial loader, Sysmon EID 1). `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063` (memory, labelled both "staged loader" and "dropper"). | Unresolved. One hash needs one role. |
| Encrypted/staged overlap (HALC-PAY-10) | R09 and R10 | Unresolved. Section 1. |
| Post-threshold activity | R07 and campaign end time vs decision log | Unresolved. 3.9. |

## 6. Verification queries

Status values: **Not run** (no result yet), **Returned** (result received, check pending), **Resolved** (result checked and applied to a section).

| ID | Query | Source | Resolves | Status |
|---|---|---|---|---|
| Q1 | Raw timestamp and timezone of the EID 10 event; host time source | SIEM, HALC-WS-050 | 3.1, H0a | Not run |
| Q2 | Mailbox search: same sender domain, same attachment hash, earlier dates | Mail gateway | 3.1 H0b; 3.2 | Not run |
| Q3 | Parent-child process for `obsidn64_ldr.exe` | EID 4688 / Sysmon EID 1, HALC-WS-050 | 3.2 to 3.3; R03 | Not run |
| Q4 | Network flow to docportal-secure-access.example: count and timestamps | Network logs | 3.3 | Not run |
| Q5 | Host identity of the memory image; origin of 10.0.2.2:8091 | Memory image metadata; network logs | 3.3 to 3.4 | Not run |
| Q6 | Earlier processes and mail on HALC-WS-050, August 2026 | SIEM; mail gateway | 3.1 H0b | Not run |
| Q7 | Domain controller that issued R07 tickets; isolation state of 10.20.31.25 at 20:46Z | DC logs; EDR isolation log | 3.9 | Not run |
| Q8 | Account in R10 logons; logon history of `adm.okonkw01` on HALC-WS-050 | Security logs | 3.1 to 3.5 | Not run |
| Q9 | Encryption events before 10:50Z on the staged set; resolve HALC-PAY-10 | File-write and rename events; EID 11 | Section 1 | Not run |
| Q10 | Estate count against inventory; actor activity on clean hosts | Asset inventory; SIEM | Section 1, Section 4 | Not run |
| Q11 | Shadow-copy deletion events on encrypted hosts | Sysmon; Security | 3.8 | Not run |
| Q12 | Execution source of `obsidn64.exe` on HALC-ADM-04 | Sysmon EID 1; file-creation source | 3.8 | Not run |
| Q13 | Containment state of HALC-ADM-04 and staged set at each hour after 10:50Z | EDR; network | 3.9 | Not run |
| Q14 | Whether R06 returned secrets; whether the requesting host is on the approved sync list | DC logs; sync-account inventory | 3.5 | Not run |
| Q15 | Use of forged or long-lived tickets across domain resources | DC and file-server logs | Section 4 | Not run |
| Q16 | Per-host EID 4698 and 7045 list | SIEM | 3.7; R11 | Not run |

## 7. Checker status

Revision 2 failed on: the unresolved entry point, the missing September 11 step, unverified transitions, and weak evidence references. Revision 3 addresses the missing step and gives every claim a query. It does not close the entry point, the unverified transitions, or the scope, because those depend on Q1–Q16. Re-run the checker only after the queries return and the affected sections are updated. Until then the report stays DRAFT.
