# Investigation Report: Halcyon Payments Ransomware Incident

**Audience:** Incident responders and the incident record
**Assessment time:** 20 September 2026, 10:50 UTC
**Status:** Evidence-based reconstruction from the campaign records, supplied Wazuh Discover results, memory findings, and mailbox findings. The containment actions described here were decisions in a frozen lab; no production systems were changed.

## Executive finding

The incident was a staged intrusion ending in ransomware deployment. The confirmed chain is a macro-enabled business document, execution of `obsidn64_ldr.exe`, command-and-control activity, credential access on HALC-WS-050, domain replication activity from HALC-ADM-04, remote logons and persistence across a selected host set, then deployment of ransomware. The ransomware file SHA-256 is `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`.

At the 10:50Z decision point, the working scope was 34 encrypted hosts, 19 staged and savable hosts, and 263 hosts without matching evidence in the campaign records (316 total). Six staged hosts are in the payment tier. The set and count are a snapshot: later activity must not be added to that decision-time count. A ransom-note event for HALC-WS-100 appears at 10:53:31.279Z, after the threshold, and shows why the decision must be assessed separately from whether isolation actually took effect. In this lab, no production isolation occurred.

## 1. Scope at the 10:50Z decision point

| Population | Count | Decision-time basis |
|---|---:|---|
| Encrypted | 34 | Ransomware deployment and file-impact evidence in the campaign records, through 10:50Z |
| Staged and savable | 19 | Successful network logons from HALC-ADM-04 (10.20.31.25), plus staging/persistence evidence, with no confirmed encryption at the threshold |
| No matching actor evidence in the available records | 263 | 316-host inventory less the two disjoint populations; monitoring coverage still requires validation |

The staged set, with the six payment hosts first, is: `HALC-PAY-01`, `HALC-PAY-03`, `HALC-PAY-04`, `HALC-PAY-06`, `HALC-PAY-08`, `HALC-PAY-10`, `HALC-ADM-04`, `HALC-WS-050`, `HALC-WS-077`, `HALC-WS-100`, `HALC-WS-109`, `HALC-WS-135`, `HALC-WS-145`, `HALC-WS-146`, `HALC-WS-192`, `HALC-WS-213`, `HALC-WS-243`, `HALC-WS-264`, and `HALC-WS-271`.

The last observed staged network logon was to HALC-WS-100 at 10:49:49.650Z. The decision threshold was 10:50:00Z. Wazuh Discover later showed `RESTORE_YOUR_FILES.txt` created on HALC-WS-100 at 10:53:31.279Z. This later event is reported as post-threshold activity, not folded into the 10:50Z snapshot.

The supplied Discover rows also show note-name creations attributed to `svchost.exe` on payment hosts. A filename-only match is not enough to overrule the decision-time classification: correlate the note with the ransomware process/hash and encrypted-file evidence. These rows are retained as a discrepancy to validate against the full host aggregation and original events.

## 2. Evidence register

| ID | Evidence | Host / source | Time | What it establishes |
|---|---|---|---|---|
| E01 | `PZ-0001.eml`, attachment `Order_Confirmation_Revised_PO-48490.docm`, Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>` | Mailbox | Initial-entry message; see campaign correlation below | Patient-zero document identifier; no regulated record content is reproduced here |
| E02 | Sysmon EID 1: `obsidn64_ldr.exe`, parent `WINWORD.EXE`, document command line; SHA-256 `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2` | HALC-WS-050 | Campaign file `campaign-2026-08-13.jsonl` | Word opened the identified document and spawned the loader; records the initial execution link |
| E03 | Sysmon EID 3: repeated connections by `obsidn64_ldr.exe` to `docportal-secure-access.example` | HALC-WS-050 | Campaign records | Loader network activity consistent with command and control; supports correlation to the memory artefacts |
| E04 | Sysmon EID 10: `obsidn64_ldr.exe` accessed LSASS | HALC-WS-050 | 2026-08-20T23:00:00Z | Credential-access activity; subsequent DC activity is consistent with credential abuse |
| E05 | Memory artefacts `c2client.ps1`, `c2listener.ps1`, and `10.0.2.2:8091/updt_loader01.exe`; SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063` | `/evidence/memory.raw` | Acquired during the lab investigation | C2 scripts and staged loader; same intrusion chain is supported by the SIEM loader/C2 indicators |
| E06 | Security EID 4662: `adm.okonkw01`, source `10.20.31.25` (HALC-ADM-04), domain object `DC=halcyon,DC=local`, replication GUIDs `1131f6aa-9c07-11d1-f79f-00c04fc2dcd2` and `1131f6ad-9c07-11d1-f79f-00c04fc2dcd2` | HALC-DC-02 | 2026-09-11T23:20:00.246Z | A non-DC host requested directory replication rights associated with DCSync; the event records the request, not the returned secrets |
| E07 | Security EID 4769: `svc-vestg_1@HALCYON.LOCAL`, 240-hour ticket lifetime, service `cifs/halc-fs-01`, source `10.20.31.25` | Domain controller (issuer to confirm) | 2026-09-20T20:46:52.913Z | Long-lived service-ticket use after the 10:50Z decision; supports continuing domain-level access, but alone does not prove a forged ticket |
| E08 | Sysmon EID 11: `C:\ProgramData\HalcyonUpdate\obsidn64.exe`, SHA-256 `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957` | HALC-ADM-04 | 2026-09-20T09:01:34.616Z | Ransomware payload staged on an administrative host; EID 11 records file creation, not execution by itself |
| E09 | Sysmon EID 1: `obsidn64.exe` and its `vssadmin.exe` child; `vssadmin.exe delete shadows /all /quiet` | Multiple hosts | 20 September campaign | Ransomware execution and attempted removal of recovery copies; corroborates E08 and impact records |
| E10 | Sysmon EID 11: `RESTORE_YOUR_FILES.txt`; additional output files ending `.obsidn64` | Multiple hosts | First campaign note: 2026-09-20T09:04:20.051Z on HALC-PAY-10; continuing through campaign | File-impact evidence when correlated with E08/E09; the latest event shown in the supplied Discover rows is HALC-WS-100 at 10:53:31.279Z |
| E11 | Security EID 4624: successful network logons from HALC-ADM-04 (`10.20.31.25`) to the staged set; last listed logon HALC-WS-100 | 19 staged hosts | Last: 2026-09-20T10:49:49.650Z | Lateral movement and the decision-time staged population |
| E12 | EID 4698 scheduled-task and EID 7045 service-creation activity | Staged hosts | 20 September campaign | Persistence/staging evidence used with E11; per-host event IDs and timestamps belong in the SIEM export |

## 3. Chronological kill-chain reconstruction

1. **Initial access — spearphishing attachment (ATT&CK T1566.001).** The mailbox record `PZ-0001.eml` identifies the macro-enabled document and its Message-ID (E01). The campaign SIEM record then shows Microsoft Word opening that same document and spawning `obsidn64_ldr.exe` (E02). The exact attachment-to-process link is the document name and parent/command-line relationship; the loader hash is `d13e0265…a88c6b2`.
2. **User execution and loader activity (T1204.002, T1059).** The EID 1 parent-child record establishes execution from Word rather than merely file delivery (E02). The loader's repeated EID 3 connections to `docportal-secure-access.example` establish outbound activity from the same process and host (E03).
3. **Command and control / staging (T1071.001, T1105).** Volatility artefacts in the memory image include `c2client.ps1`, `c2listener.ps1`, and a staged-loader reference at `10.0.2.2:8091/updt_loader01.exe` (E05). The memory loader hash `cb4eee1b…a88c6b2` differs from the initial Word-spawned loader hash; the report keeps these roles separate. The matching C2 script names and loader/campaign context link memory to the SIEM chain.
4. **Credential access (T1003.001).** On HALC-WS-050, `obsidn64_ldr.exe` accessed LSASS in Sysmon EID 10 at 2026-08-20T23:00:00Z (E04). This is a confirmed credential-access event. The mailbox-to-loader execution is independently established by E01/E02; the EID 10 timestamp is kept in UTC and ordered at its recorded date.
5. **Domain credential replication (T1003.006).** On 11 September, HALC-ADM-04 (`10.20.31.25`) used `adm.okonkw01` to request replication against the domain partition on HALC-DC-02. EID 4662 records both replication-right GUIDs (E06). This is evidence of a DCSync request from a non-DC; do not claim the event proves secrets were returned.
6. **Lateral movement and persistence (T1021, T1078, T1053.005, T1543.003).** On 20 September, successful network logons from HALC-ADM-04 reached the staged set, ending with HALC-WS-100 at 10:49:49.650Z (E11). EID 4698 and 7045 records show scheduled-task/service staging on the set (E12). These records distinguish actor-controlled but not yet confirmed encrypted hosts from clean/distractor hosts.
7. **Ransomware staging and execution (T1486 precursor).** At 09:01:34.616Z, Sysmon EID 11 recorded creation of `obsidn64.exe` on HALC-ADM-04 with hash `e7c189…4663957` (E08). This is staging, not execution. EID 1 process records then show the payload active and invoking `vssadmin.exe` to delete shadow copies (E09), which confirms execution and recovery inhibition (T1490).
8. **Encryption and impact (T1486).** EID 11 records the ransom-note name and files with `.obsidn64` on affected systems (E10). In conjunction with the payload hash/process lineage, these records establish encryption. The 10:50Z count remains 34 encrypted; later events, including the 10:53:31.279Z HALC-WS-100 note row, are post-threshold activity.

## 4. Containment and post-threshold activity

The evidence-based decision threshold was 10:50:00Z, immediately after the last listed staged logon at 10:49:49.650Z. The decision was to isolate the 34 already-encrypting hosts and the 19 staged hosts, with payment systems first. This is the lab's recorded decision and not a claim that production isolation was performed.

A subsequent note event on HALC-WS-100 at 10:53:31.279Z indicates that the host later reached the encryption stage or that the simulated isolation did not take effect before that event. The record does not establish which. EID 4769 activity from `10.20.31.25` at 20:46:52.913Z further shows domain activity after the threshold. Validate the actual isolation state before asserting containment; classify the incident as contained only in the decision-log sense, not eradicated.

## 5. Domain impact and eviction position

EID 4662 from HALC-ADM-04 requested domain replication using both replication rights (E06). EID 4769 later shows unusual 240-hour service-ticket use by `svc-vestg_1` to `cifs/halc-fs-01` (E07). Together these make domain-level credential compromise a high-confidence assessment. The 4769 record is consistent with forged or long-lived ticket use; it does not alone prove a Golden Ticket.

Host cleaning and ordinary password resets are insufficient if the `krbtgt` key was exposed. Eviction requires removing unauthorized persistence and replication rights, rotating privileged/service credentials, and a controlled `krbtgt` double reset with replication convergence and a wait through the maximum ticket lifetime between resets. Confirm old tickets fail before reconnecting rebuilt systems.

## 6. Evidence limits

- The campaign records and flags identify the mailbox item, process tree, C2, memory artefacts, DCSync request, lateral logons, ransomware hash, and file impact. The report does not reproduce mailbox record content.
- The Wazuh Discover result supplied during the investigation is a partial view. It shows note-name events, including rows attributed to `svchost.exe` on payment hosts and a post-threshold row on HALC-WS-100. Resolve these against full search totals, host-level process/file correlations, and the `.obsidn64` events before changing the 10:50Z disjoint population.
- EID 4662 proves a replication request with the relevant rights, not successful return of password material. EID 4769 alone does not prove ticket forgery.
- The 263-host population means no matching actor evidence in the available records, not proof of complete telemetry coverage or absolute cleanliness.
