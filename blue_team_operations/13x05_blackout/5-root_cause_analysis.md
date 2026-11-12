# Root Cause Analysis: Halcyon Payments Ransomware

**Audience:** Endpoint, identity, and detection engineers
**Status:** Causal assessment based on the campaign, mailbox, and memory evidence supplied for the lab. This is a simulated incident; actions below are proposed engineering changes.

## Root cause

A macro-enabled business document from the patient-zero mailbox was opened in Microsoft Word. Sysmon EID 1 links the document `Order_Confirmation_Revised_PO-48490.docm` to `obsidn64_ldr.exe` as a Word child process on HALC-WS-050. The mailbox item is `PZ-0001.eml`, Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>`. The initial loader SHA-256 is `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2`.

The loader contacted `docportal-secure-access.example` (Sysmon EID 3), and the memory image contains `c2client.ps1`, `c2listener.ps1`, and the staged loader `updt_loader01.exe` (SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063`). On HALC-WS-050 the loader accessed LSASS (EID 10). The operator then used `adm.okonkw01` from HALC-ADM-04 (`10.20.31.25`) to request domain replication on HALC-DC-02 (EID 4662), and used that admin host for remote logons and persistence staging. On 20 September the ransomware payload `obsidn64.exe` (SHA-256 `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`) was staged on HALC-ADM-04; EID 1 execution and its `vssadmin` child, followed by ransom-note and `.obsidn64` file events, establish the final impact.

This is a causal chain supported by process parentage, matching document identity, network activity, memory artefacts, identity events, and file-impact telemetry. The memory loader hash, initial loader hash, and ransomware hash are distinct artifacts and must not be conflated.

## Conditions that let one stage lead to the next

| Link | Enabling condition | Evidence | Engineering consequence |
|---|---|---|---|
| Document to loader | Office macro execution was permitted for the delivered document | Mailbox PZ-0001 and Word → `obsidn64_ldr.exe` EID 1 parent/command-line record | Block macros in internet-origin Office files and enforce application control |
| Loader to credential theft | User-context execution could access LSASS | EID 10 on HALC-WS-050 | Enable Credential Guard and LSA protection; alert on LSASS access |
| Credential theft to admin tier | Recovered or otherwise obtained credentials could be used from an endpoint with administrative reach | EID 4624 remote logons from HALC-ADM-04; precise credential provenance is inferred, not directly logged | Tier accounts and restrict remote logons to privileged access workstations |
| Admin host to directory secrets | A non-DC principal/source could make a replication-right request | EID 4662 on HALC-DC-02, `adm.okonkw01`, source 10.20.31.25, both replication GUIDs | Remove unauthorized replication rights and alert on any non-DC replication request |
| Admin host to persistent access | Remote logon and service/task staging reached the 19-host set | EID 4624, EID 4698, EID 7045 | Alert and require approval for new services/tasks outside change windows |
| Persistence to impact | Ransomware could run as SYSTEM, remove recovery copies, and encrypt user data | EID 1 `obsidn64.exe` → `vssadmin.exe`; EID 11 note and `.obsidn64` outputs | Application allowlisting, tamper-protected recovery copies, and rapid isolation of staged hosts |
| Domain access to re-entry | Long-lived tickets and potential `krbtgt` exposure outlast ordinary password resets | EID 4769, 240-hour service tickets; EID 4662 replication request | Domain recovery must include credential rotation and controlled `krbtgt` double reset |

## Corrective actions and validation

| Action | Owner | Validation criterion |
|---|---|---|
| Block macros in internet-origin Office files; enforce WDAC/AppLocker for unapproved binaries in user-writable paths | Endpoint engineering | Test document cannot launch a child executable; an unapproved copy of `obsidn64_ldr.exe` is blocked and logged |
| Enable Credential Guard and LSA protection on workstations and admin hosts | Identity / endpoint engineering | Configuration is present on all target systems; controlled LSASS read test is denied and generates an alert |
| Separate Tier 0 accounts from user workstations; permit remote admin logons only from managed privileged access workstations | Identity engineering | Network/remote logon from a standard workstation is denied (EID 4625); approved PAW path still works |
| Remove domain replication rights from every non-DC and explicitly approved synchronization principal; alert on EID 4662 with either replication GUID from a non-DC | Active Directory engineering | ACL inventory contains only approved principals; a controlled test request from an unapproved host is blocked or alerted |
| Reduce service-ticket lifetime from the observed 240 hours and monitor anomalous requests | Active Directory engineering | Domain policy reflects the approved shorter lifetime; new test tickets expire accordingly |
| Alert on EID 4698 and 7045 outside approved change windows, correlated with source host and account | Detection engineering | Test service/task creation fires a host-attributed alert within the response SLA |
| Protect recovery copies from endpoint deletion and require an isolated, immutable recovery tier | Backup engineering | A test SYSTEM process cannot delete isolated recovery copies; restore test meets recovery objectives |
| During eradication, rotate privileged/service credentials and perform a controlled `krbtgt` double reset, waiting for replication convergence and the maximum ticket lifetime between resets | Identity recovery lead | Both DCs converge after each reset; pre-reset tickets are rejected; recovery validation is recorded before reconnection |

## Recurrence test

The attacker’s path is interrupted only when **all** of these paths are closed: macro/binary execution, LSASS access, credential reuse into the admin tier, unrestricted remote administration, directory replication abuse, persistence creation, and ransomware execution against recoverable data. E4 (remote logon restrictions) is essential; it cannot be omitted from the recurrence test. A mail control alone does not evict credentials already stolen, and host cleaning alone does not invalidate domain tickets.
