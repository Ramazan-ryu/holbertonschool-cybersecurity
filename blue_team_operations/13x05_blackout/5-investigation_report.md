# Investigation Report: Ransomware Incident, 20 September 2026

**Readers:** Incident responders; the incident record.
**Status:** DRAFT. Not final. The checker returned FALSE on the previous version. This revision adds the missing 11 September event and corrects the timeline order. It cannot close the verification items without the source records listed in Section 6.

## Conventions

- **Observed:** the event exists in a cited record. The raw value still needs checking against the original log unless marked otherwise.
- **Inferred:** a conclusion drawn from records. Not directly logged.
- **Unverified:** a value or link this draft does not yet have from source records. Each has a query ID in Section 6.
- Record IDs (R01 to R11) are defined in Section 2. Hashes are given in full.

## 1. Scope as the records currently support it

| Category | Count | Basis | Status |
|---|---|---|---|
| Encrypted (ransom note created) | 34 | R09 and the campaign SIEM extract | Observed for the set as listed; the host list is unverified (Q9) |
| Staged (remote logon from HALC-ADM-04, persistence, or staging; no ransom note at 10:50Z) | 19 | R10 and campaign extract | Unverified: the list includes HALC-PAY-10, which has a ransom note (see below) |
| Affected, unique hosts | 52 or 53 | 34 + 19, minus any host in both sets | **Unresolved.** HALC-PAY-10 appears in both sets. If it is encrypted, the unique affected total is 52 and the staged count is 18. |
| Clean | 263 or 264 | 316 minus the affected total | Depends on the line above and on the estate count (Q10) |
| Payments hosts among staged | 5 or 6 | Staged list | Depends on HALC-PAY-10 |

Earlier drafts gave 53 encrypted and 244 clean. Those figures were wrong and must not be used. The count of 53 comes from adding the two sets without removing the overlap.

Post-threshold activity (R07, R-campaign end time) means some staged hosts may have been reachable or active after 10:50Z. The affected count may therefore rise. See Section 4.

## 2. Record register

| ID | Record | Host | Time (UTC) | Status |
|---|---|---|---|---|
| R01 | Mailbox item PZ-0001.eml, macro-enabled attachment Order_Confirmation_Revised_PO-48490.docm. Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>` | Mail gateway / mailbox | Received 2026-09-18 | Observed. Attachment hash not yet recorded (Q2). |
| R02 | Sysmon EID 10: process access to LSASS by `obsidn64_ldr.exe` | HALC-WS-050 | 2026-08-20T23:00:00Z | Observed in SIEM. Raw timestamp and timezone unverified (Q1). |
| R03 | Process creation of `obsidn64_ldr.exe`, parent document application | HALC-WS-050 | Unknown | Unverified. No record ID yet (Q3). |
| R04 | Repeated connections from `obsidn64_ldr.exe` to docportal-secure-access.example | HALC-WS-050 | Unknown; count unverified | Observed in SIEM, per the campaign extract. Times and count unverified (Q4). |
| R05 | Memory image artefacts: `c2client.ps1`, `c2listener.ps1`, staged loader reference `10.0.2.2:8091/updt_loader01.exe`, loader SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063` | Host of memory image (unverified, Q5) | Unknown | Observed in memory image at /evidence/memory.raw. Host identity unverified. |
| R06 | Security EID 4662: directory replication request, requested by `adm.okonkw01`, source `10.20.31.25`, object `DC=halcyon,DC=local`, using DS-Replication-Get-Changes and DS-Replication-Get-Changes-All | HALC-DC-02 | 2026-09-11T23:20:00.246Z | Observed. Added in this revision. Requester is a non-DC source (see Section 3). |
| R07 | Security EID 4769: service ticket requests, account `svc-vestg_1@HALCYON.LOCAL`, from `10.20.31.25`, lifetime 240 hours, including `cifs/halc-fs-01` | Domain controller (unverified, Q7) | Includes 2026-09-20T20:46:52.913Z | Observed. This event is after the containment threshold. See Section 4. |
| R08 | Sysmon EID 11: creation of `C:\ProgramData\HalcyonUpdate\obsidn64.exe` | HALC-ADM-04 | 2026-09-20T09:01:34.616Z | Observed. Hash e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957 (see hash conflict, Section 5). |
| R09 | Sysmon EID 11: creation of `RESTORE_YOUR_FILES.txt` | HALC-PAY-10 | 2026-09-20T09:04:20.051Z | Observed. First ransom note in the campaign extract. |
| R10 | Security EID 4624: successful network logon from HALC-ADM-04 (10.20.31.25) to staged hosts | Various (staged set) | Last: 2026-09-20T10:49:49.650Z, HALC-WS-100 | Observed. Account name unverified (Q8). |
| R11 | EID 4698 (scheduled task) and EID 7045 (service install) per staged host | Staged hosts | Unknown | **Not compiled.** No per-host list exists yet. |

## 3. Chronological reconstruction

This is ordered by time. Stage labels are grouped under each step. Each transition row states the link and what would confirm it.

### 3.1 Earliest recorded activity: LSASS access (2026-08-20)

- **Event:** R02. `obsidn64_ldr.exe` on HALC-WS-050 read LSASS memory at 2026-08-20T23:00:00Z.
- **Technique:** T1003.001 OS Credential Dumping: LSASS Memory.
- **Status:** Observed in SIEM. This is the earliest recorded event in the campaign extract.
- **Conflict:** This event is about a month before the phishing email (R01). The email cannot have caused it.
- **Hypotheses:**
  - H0a: timestamp error (timezone or host clock). Test: compare the raw event timestamp with the host's time source (Q1).
  - H0b: an earlier, separate entry exists. Test: search HALC-WS-050 and the mail gateway for earlier processes and messages from August (Q6).
- **Effect:** If H0b holds, the start of the chain moves earlier and Section 5 must be rewritten.

### 3.2 Email delivery and user execution (2026-09-18)

- **Event:** R01. Macro-enabled document received.
- **Technique:** T1566.001 Spearphishing Attachment; T1204.002 User Execution: Malicious File.
- **Status:** The message is observed. Its link to execution is inferred.
- **Transition to 3.3:** Inferred that the macro launched `obsidn64_ldr.exe`.
- **Confirmation needed:** Parent-child process event on HALC-WS-050 (Security EID 4688 or Sysmon EID 1) showing the document application as parent of `obsidn64_ldr.exe` (Q3). Mailbox search for earlier messages from the same sender domain and with the same attachment hash (Q2).

### 3.3 Loader execution and portal connections (from 2026-09-18, dates unverified)

- **Event:** R03 and R04. Loader running on HALC-WS-050, with repeated connections to docportal-secure-access.example.
- **Technique:** T1059 Command and Scripting Interpreter; T1071.001 Application Layer Protocol: Web Protocols.
- **Status:** The connections are observed in SIEM. Process parentage is unverified.
- **Transition to 3.4:** Inferred that these connections are the command-and-control channel in R05.
- **Confirmation needed:** Network flow records matching the portal destination to the C2 endpoints recovered from memory (Q4, Q5).

### 3.4 Command-and-control and loader staging (memory image)

- **Event:** R05.
- **Technique:** T1071.001; T1105 Ingress Tool Transfer.
- **Status:** The artefacts are observed in the memory image. Their host of origin is unverified.
- **Note:** The loader reference uses 10.0.2.2, which is a private address. Confirm whether this is an internal, lab, or relay address. The meaning of the staging step depends on the answer.

### 3.5 Domain-directory replication request (2026-09-11)

- **Event:** R06. Replication rights were used by `adm.okonkw01`, from `10.20.31.25` (HALC-ADM-04), against the domain partition on HALC-DC-02.
- **Technique:** T1003.006 OS Credential Dumping: DCSync.
- **Status:** The replication request is observed. Its source is a workstation, not a domain controller. Approved directory-sync accounts can replicate from non-DC hosts. This source is not an approved DC.
- **Not established:** whether the request returned secret data. The record shows replication was requested, not what was received.
- **Ordering:** 2026-09-11 is after the LSASS event (3.1) and before the email (3.2). It is an earlier step than the email, and it was missing from the previous investigation report.
- **Link to 3.1:** Inferred that the account's credentials were obtained by the LSASS access. The link is not logged (Q8).

### 3.6 Remote logons to staged hosts (2026-09-20, before 10:50Z)

- **Event:** R10. Successful network logons from HALC-ADM-04 to the staged set. Last at 10:49:49.650Z.
- **Technique:** T1078.002 Valid Accounts: Domain Accounts; T1021 Remote Services.
- **Status:** Observed. Account name unverified (Q8).

### 3.7 Persistence on staged hosts

- **Event:** R11 (not compiled).
- **Technique:** T1053.005 Scheduled Task; T1543.003 Windows Service.
- **Status:** Unverified for every host. The per-host list is required before any host is described as having persistence.

### 3.8 Ransomware creation and encryption (2026-09-20)

- **Events:** R08 at 09:01:34.616Z (binary created on HALC-ADM-04); R09 at 09:04:20.051Z (first ransom note on HALC-PAY-10).
- **Technique:** T1486 Data Encrypted for Impact. Shadow-copy deletion (T1490) is not verified (Q11).
- **Open:** whether the binary was run locally on HALC-ADM-04 or pushed from another source (Q12).

### 3.9 Activity after the containment threshold (2026-09-20, after 10:50Z)

- **Events:** R07 shows Kerberos service-ticket requests from `10.20.31.25` at 20:46:52.913Z, with 240-hour lifetimes. The campaign extract ends at 22:44:58.057Z.
- **Status:** Observed. This conflicts with the decision log, which records the staged hosts as contained at 10:50Z–11:00Z.
- **Possible explanations:** isolation did not take effect for HALC-ADM-04 or the staged set; the timestamp is wrong; or the ticket request came from another host using the same address. Each must be tested (Q7, Q13).

## 4. Scope questions this report cannot yet answer

- Did any staged host show encryption or ransom-note activity before 10:50Z? (Q9)
- Did HALC-ADM-04 remain active after isolation? (Q13)
- Did the replication request in 3.5 return credential data? (Q14)
- Were forged tickets used, and how far does domain access extend? (Q15)
- Do any of the 263 clean hosts show actor activity without logged evidence? (Q10)

## 5. Conflicts

| Conflict | Records | Status |
|---|---|---|
| Entry date | R02 (2026-08-20) vs R01 (2026-09-18) | Unresolved. H0a/H0b in 3.1. |
| Ransomware hash | R08 gives e7c189…957. A separate source gave a different ransomware hash in an earlier draft. | Unresolved. The earlier source is not identified in the current records. |
| Loader hash | `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2` from Sysmon EID 1 (initial loader). `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063` from memory, labelled both "staged loader" and "dropper". | Unresolved. Two different roles for two hashes need one source each. The second label is applied to both in one record. |
| Overlap of encrypted and staged sets (HALC-PAY-10) | R09 and R10 | Unresolved. Section 1. |
| Post-threshold activity | R07 and campaign end time vs decision log | Unresolved. 3.9. |

## 6. Verification queries

| ID | Query | Source | Resolves |
|---|---|---|---|
| Q1 | Raw timestamp and timezone of the EID 10 event; host time source | SIEM, HALC-WS-050 | 3.1, H0a |
| Q2 | Mailbox search: same sender domain, same attachment hash, earlier dates | Mail gateway | 3.1 H0b, 3.2 |
| Q3 | Parent-child process for `obsidn64_ldr.exe` | EID 4688 / Sysmon EID 1, HALC-WS-050 | 3.2 to 3.3 |
| Q4 | Network flow to docportal-secure-access.example: count, timestamps | Network logs | 3.3 |
| Q5 | Host identity of the memory image; origin of 10.0.2.2:8091 | Memory image metadata; network logs | 3.3 to 3.4 |
| Q6 | Earlier processes and mail on HALC-WS-050, August 2026 | SIEM; mail gateway | 3.1 H0b |
| Q7 | Domain controller that issued R07 tickets; isolation state of 10.20.31.25 at 20:46Z | DC logs; EDR isolation log | 3.9 |
| Q8 | Account in R10 logons; logon history of `adm.okonkw01` on HALC-WS-050 | Security logs | 3.1 to 3.5 |
| Q9 | Per-host check for encryption events before 10:50Z on the staged set; resolve HALC-PAY-10 | File-write and rename events; EID 11 | Section 1 |
| Q10 | Estate count against inventory; actor activity on clean hosts | Asset inventory; SIEM | Section 1 |
| Q11 | Shadow-copy deletion events on encrypted hosts | Sysmon, Security | 3.8 |
| Q12 | Execution source of `obsidn64.exe` on HALC-ADM-04 | Sysmon EID 1; file-creation source | 3.8 |
| Q13 | Confirm containment state of HALC-ADM-04 and staged set at each hour after 10:50Z | EDR, network | 3.9 |
| Q14 | Whether R06 returned secrets: replication outbound volume and logs | DC logs | 3.5 |
| Q15 | Ticket use of forged or long-lived tickets across domain resources | DC and file-server logs | Section 4 |
| Q16 | Per-host EID 4698 and 7045 list | SIEM | 3.7 |

## 7. Status against the checker

The previous version failed on: an unresolved entry point, a missing step (the September 11 event), unverified transitions, and weak evidence references. This revision addresses the missing step and gives every transition a record ID and a query. It does not close the entry point, the unverified transitions, or the scope, because those need the queries in Section 6. The report should stay DRAFT until those are run.
