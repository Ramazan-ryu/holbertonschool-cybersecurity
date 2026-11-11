# Investigation Report: Ransomware Incident, 20 September 2026

**Readers:** Incident responders; the incident record.
**Status:** DRAFT, revision 4. Not final. Revision 4 responds to the dev team QA review of revision 3: it resolves the scope numbers to a single 10:50Z snapshot, lays out the evidence gap for each kill-chain stage, and keeps the entry-point conflict open. No verification query has been run, so no finding is confirmed.

## Conventions

- **Observed:** the event exists in a cited record. The raw value still needs checking against the original log unless marked otherwise.
- **Inferred:** a conclusion drawn from records. Not directly logged.
- **Unverified:** a value or link not yet confirmed from source records. Each has a query ID in Section 7.
- Record IDs R01 to R11 are defined in Section 2. Hashes are given in full.

## 1. Scope snapshot at the containment decision (10:50 UTC, 20 September 2026)

This snapshot counts only what the records show up to 10:50:00Z. Activity after that time is in Section 4 and is not added to these figures.

| Category | Count | Basis | Status |
|---|---|---|---|
| Estate (total hosts) | 316 | Asset inventory | Unverified until Q10 |
| Encrypted (ransom note by 10:50Z) | 34 | R09 and the campaign extract | Observed for the set listed; host list unverified (Q9) |
| Staged only (remote logon from HALC-ADM-04, persistence, or staging; no ransom note by 10:50Z) | 18 | R10 and campaign extract | Unverified (Q8, Q16) |
| Unique affected hosts | 52 | 34 + 18 | Depends on Q9 |
| Clean | 264 | 316 − 52 | Depends on Q9 and Q10 |

**Overlap note.** HALC-PAY-10 is on the staged list (R10) and also has a ransom note (R09). It is counted once, under encrypted. If Q9 shows it was not encrypted, the figures become 35 encrypted (including HALC-PAY-10 as staged-only: no, see below) and must be recalculated; do not use this table until Q9 returns.

Earlier drafts gave 53 affected and 244 clean. Those figures double-counted HALC-PAY-10 and must not be used. Earlier drafts also gave 263 clean, which assumed the overlap was removed from the staged count without removing it from the total. The correct clean count is 264.

## 2. Record register

| ID | Record | Host | Time (UTC) | Status |
|---|---|---|---|---|
| R01 | Mailbox item PZ-0001.eml; macro-enabled attachment `Order_Confirmation_Revised_PO-48490.docm`; Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>` | Mail gateway / mailbox | Received 2026-09-18 | Observed. Attachment hash not recorded (Q2). |
| R02 | Sysmon EID 10: LSASS process access by `obsidn64_ldr.exe` | HALC-WS-050 | 2026-08-20T23:00:00Z | Observed in SIEM. Raw timestamp and timezone unverified (Q1). Conflicts with R01. |
| R03 | Process creation of `obsidn64_ldr.exe`, with parent document application | HALC-WS-050 | Unknown | Not located (Q3). |
| R04 | Repeated connections from `obsidn64_ldr.exe` to `docportal-secure-access.example` | HALC-WS-050 | Unknown; count unverified | Observed in SIEM per campaign extract. Times and count unverified (Q4). |
| R05 | Memory image artefacts: `c2client.ps1`, `c2listener.ps1`; staged loader reference `10.0.2.2:8091/updt_loader01.exe`; loader SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063` | Host of origin unverified (Q5) | Unknown | Observed in `/evidence/memory.raw`. Host identity unverified. |
| R06 | Security EID 4662: directory replication request by `adm.okonkw01` from `10.20.31.25` on object `DC=halcyon,DC=local`; DS-Replication-Get-Changes and -Get-Changes-All | HALC-DC-02 | 2026-09-11T23:20:00.246Z | Observed. Requester is a non-DC source. Replication GUIDs not yet extracted (Q14). |
| R07 | Security EID 4769: service ticket requests for `svc-vestg_1@HALCYON.LOCAL` from `10.20.31.25`; lifetime 240 hours; includes `cifs/halc-fs-01` | Issuing DC unverified (Q7) | Includes 2026-09-20T20:46:52.913Z | Observed. After the containment decision. Section 4. |
| R08 | Sysmon EID 11: creation of `C:\ProgramData\HalcyonUpdate\obsidn64.exe` | HALC-ADM-04 | 2026-09-20T09:01:34.616Z | Observed. Hash `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957` (conflict, Section 6). |
| R09 | Sysmon EID 11: creation of `RESTORE_YOUR_FILES.txt` | HALC-PAY-10 | 2026-09-20T09:04:20.051Z | Observed. First ransom note in campaign extract. |
| R10 | Security EID 4624: successful network logons from `10.20.31.25` to staged hosts | Staged set | Last: 2026-09-20T10:49:49.650Z (HALC-WS-100) | Observed. Account and destination list unverified (Q8). |
| R11 | EID 4698 (scheduled task) and EID 7045 (service install) per staged host | Staged hosts | Unknown | Not compiled (Q16). |

## 3. Kill chain by stage

Each stage gives the technique, the record that supports it, its status, and the evidence still missing. A stage is not confirmed until its missing evidence is in.

| # | Stage | Technique | Supporting record | Status | Missing evidence (query) |
|---|---|---|---|---|---|
| 1 | Initial access (phishing attachment) | T1566.001; T1204.002 | R01 | Message observed; link to execution inferred | Attachment hash; link between attachment and Message-ID (Q2) |
| 2 | Loader execution | T1059 | R03 (not located) | Inferred from R02 and R04 | Parent process, timestamp, user (Q3) |
| 3 | Credential access (LSASS) | T1003.001 | R02 | Observed in SIEM; date conflict (Section 5) | Exact EID and timestamp check; account used (Q1, Q8) |
| 4 | Command and control | T1071.001; T1105 | R04, R05 | Artefacts observed; link to portal inferred | Host of origin for memory image; network flow to portal (Q4, Q5) |
| 5 | Domain credential replication | T1003.006 | R06 | Request observed from a non-DC source | Whether secrets returned; GUIDs; sync-account approval (Q14) |
| 6 | Lateral movement | T1078.002; T1021 | R10 | Observed; accounts unverified | Account and destination per 4624 (Q8) |
| 7 | Persistence on staged hosts | T1053.005; T1543.003 | R11 (not compiled) | Unverified for every host | Per-host 4698 and 7045 (Q16) |
| 8 | Forged or long-lived ticket use | T1558 | R07 | Observed after threshold; link to stage 5 inferred | Issuing DC; whether tickets were forged (Q7, Q15) |
| 9 | Payload staging and execution on ADM host | T1486 (precursor) | R08 | Observed | Execution source of `obsidn64.exe` (Q12) |
| 10 | Encryption | T1486; T1490 unverified | R09 | Observed for HALC-PAY-10; others unverified | Encryption events on staged set before 10:50Z (Q9); shadow-copy deletion (Q11) |

## 4. Activity after the containment decision

- R07 shows ticket requests from `10.20.31.25` at 20:46:52.913Z. The campaign extract ends at 22:44:58.057Z.
- The decision log records containment at 10:50–11:00Z.
- Possible explanations: isolation did not take effect; the timestamp is wrong; or another host used that address. Q7 and Q13 test these.
- These events are reported separately. They do not change the 10:50Z snapshot in Section 1.

## 5. Entry-point conflict (open)

- **R02** puts LSASS access on 2026-08-20T23:00:00Z, about a month before the email.
- **R01** is the only phishing record, received 2026-09-18.
- An August event cannot be caused by a September email. Two hypotheses remain:
  - **H0a:** timestamp error (timezone or clock). Test: Q1.
  - **H0b:** an earlier, separate entry. Test: Q6.
- Until one is confirmed, R01 is **not** recorded as the entry point.

## 6. Conflicts

| Conflict | Records | Status |
|---|---|---|
| Entry date | R02 (2026-08-20) vs R01 (2026-09-18) | Unresolved (Section 5) |
| Ransomware hash | R08 gives `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`. An earlier draft cited another ransomware hash from an unidentified record. | Unresolved; source record not identified |
| Loader hash | `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2` (initial loader, Sysmon EID 1) vs `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063` (memory, labelled both "staged loader" and "dropper") | Unresolved; each hash needs one role |
| HALC-PAY-10 overlap | R09 (encrypted) and R10 (staged) | Counted once under encrypted (Section 1); confirm with Q9 |
| Post-threshold activity | R07 and campaign end time vs decision log | Unresolved (Section 4) |

## 7. Verification queries

Status: **Not run** / **Returned** (result received, not yet checked) / **Resolved** (applied to a section).

| ID | Query | Source | Resolves | Status |
|---|---|---|---|---|
| Q1 | Raw timestamp and timezone of R02; host time source | SIEM, HALC-WS-050 | Section 5 (H0a) | Not run |
| Q2 | Mailbox search: sender domain, attachment hash, earlier dates | Mail gateway | Stage 1 | Not run |
| Q3 | Parent-child process for `obsidn64_ldr.exe` | EID 4688 / Sysmon EID 1, HALC-WS-050 | Stage 2 | Not run |
| Q4 | Network flow to `docportal-secure-access.example`: count and timestamps | Network logs | Stage 4 | Not run |
| Q5 | Host identity of memory image; origin of `10.0.2.2:8091` | Memory image metadata; network logs | Stage 4 | Not run |
| Q6 | Earlier processes and mail on HALC-WS-050, August 2026 | SIEM; mail gateway | Section 5 (H0b) | Not run |
| Q7 | Issuing DC for R07; isolation state of `10.20.31.25` at 20:46Z | DC logs; EDR | Stage 8; Section 4 | Not run |
| Q8 | Account in each R10 logon; logon history of `adm.okonkw01` on HALC-WS-050 | Security logs | Stages 3, 6 | Not run |
| Q9 | Encryption events before 10:50Z on staged set; resolve HALC-PAY-10 | File-write and rename events; EID 11 | Section 1 | Not run |
| Q10 | Estate count against inventory; actor activity on clean hosts | Asset inventory; SIEM | Section 1 | Not run |
| Q11 | Shadow-copy deletion on encrypted hosts | Sysmon; Security | Stage 10 | Not run |
| Q12 | Execution source of `obsidn64.exe` on HALC-ADM-04 | Sysmon EID 1; file-creation source | Stage 9 | Not run |
| Q13 | Containment state of HALC-ADM-04 and staged set, hourly after 10:50Z | EDR; network | Section 4 | Not run |
| Q14 | Whether R06 returned secrets; GUIDs; whether the requesting host is on the approved sync list | DC logs; sync-account inventory | Stage 5 | Not run |
| Q15 | Use of forged or long-lived tickets across domain resources | DC and file-server logs | Stage 8 | Not run |
| Q16 | Per-host EID 4698 and 7045 | SIEM | Stage 7; R11 | Not run |

## 8. Checker status

Revision 4 addresses the QA review on scope numbers, stage-by-stage evidence, and the entry-point conflict. It does not close the entry point, the stage transitions, or the scope, because those depend on Q1–Q16 and the source records. Re-run the checker only after the queries return and the affected sections are updated. Until then, this report stays DRAFT.
