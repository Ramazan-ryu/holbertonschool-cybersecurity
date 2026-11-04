# Root Cause Analysis

**Status: DRAFT.** [VERIFY] marks items to confirm against source records. [INFERENCE] marks links that are not directly logged.

## 1. Root cause

An untrusted macro-enabled attachment was allowed to run on HALC-WS-050. This is the first confirmed execution step in the chain.

- **Evidence:** Phishing message with macro-enabled attachment (Message-ID in the investigation report); process creation of `obsidn64_ldr.exe` [VERIFY parent process]; repeated portal connections from that process [VERIFY].
- **Open:** The date conflict in the investigation report (LSASS event dated before the phishing message). If the earlier date is correct, the root cause is an earlier entry, and this section must be rewritten.

## 2. Enabling conditions, in order

Each condition is a reason the next stage was possible. A symptom is not a cause: the ransomware, the staged hosts, and the compromised account are symptoms of the conditions below.

| # | Stage | Condition that allowed the next step | Evidence | Confidence |
|---|---|---|---|---|
| E1 | 1 to 2 | Macros in an externally sourced Office document could run | Parent-child process events [VERIFY] | Confirmed as recorded |
| E2 | 2 | A user-context process could read LSASS memory | LSASS access event [VERIFY] | Confirmed as recorded |
| E3 | 2 to 4 | A credential obtained on a standard workstation was accepted for administrative logon on HALC-ADM-04 | 4624 from HALC-ADM-04 [VERIFY account] | [INFERENCE] The credential link is not logged |
| E4 | 4 | Remote administrative logons from HALC-ADM-04 to other hosts were not restricted | 4624 pattern [VERIFY] | Condition inferred from the logon pattern |
| E5 | 5 | Scheduled-task and service creation on staged hosts did not generate an alert | SIEM coverage and alert history [VERIFY] | To verify |
| E6 | 6 | A non-DC host held directory replication rights, and service ticket lifetimes were long enough to be reused | EID 4662 and 4769 [VERIFY GUIDs and lifetimes] | Events recorded; forged-ticket use inferred |

## 3. Control gaps and corrective actions

Each gap is closed by one action. Each action interrupts the path shown above. Validation is a test an engineer can run and record.

| Gap (enabling condition) | Stage broken | Corrective action | Owner | Validation |
|---|---|---|---|---|
| E1: Macros in external Office files run | 1 | Block macros in internet-origin Office documents by policy (Group Policy or Intune "Block macros from running in Office files from the Internet") | Endpoint engineering | Send a test macro-enabled document from an external address to a canary mailbox. Confirm the macro does not run and the blocked execution is logged. |
| E2: User-context processes can read LSASS | 2 | Enable LSA protection (`RunAsPPL`) and Credential Guard | Identity engineering | On a sample of workstations, confirm `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL` = 1. Run a test process that attempts to open LSASS with read access and confirm it fails. |
| E1 and E2 (execution of untrusted binaries) | 2 | Enforce application control (WDAC or AppLocker) on workstations, allowing only approved publishers | Endpoint engineering | Run a copy of `obsidn64_ldr.exe` as a standard user from a user-writable folder. Confirm it is blocked and the event is logged. |
| E3: Standard-workstation credentials accepted on admin hosts | 2 to 4 | Restrict Tier 0 administrative accounts from logging on to lower-tier systems (deny network and remote interactive logon rights via GPO); allow admin logons only from privileged access workstations | Identity engineering | Attempt a network logon as a Tier 0 account from a standard workstation. Confirm it is denied (Security EID 4625). |
| E4: Remote admin logons not restricted | 4 | Restrict remote logon rights for administrative accounts to the management network and privileged workstations | Identity engineering | From a standard workstation, attempt remote logon to a server as an admin account. Confirm it fails. |
| E5: Persistence not alerted | 5 | Alert on EID 4698 (scheduled task created) and EID 7045 (service installed) outside approved change windows | Detection engineering | Create a test scheduled task and a test service on a test host. Confirm both alerts fire within the agreed time. |
| E6a: Non-DC replication rights | 6 | Remove directory replication rights from every principal that is not a domain controller or approved sync account | AD team | Enumerate replication-right holders on the domain partition (for example, `Get-ADObject` with an ACL check for the two replication GUIDs). Confirm only DCs and approved accounts are listed. Test that an EID 4662 alert fires when a test non-DC account attempts replication. |
| E6b: Long-lived service tickets | 6 | Reduce the maximum service ticket lifetime in the domain Kerberos policy | AD team | Confirm the policy value in the domain GPO report. Confirm a newly issued ticket expires within the new limit. |
| E6c: Forged or long-lived credentials may persist after a password reset | 6 | Perform a controlled double reset of `krbtgt`, following the vendor procedure: reset once, wait for replication convergence and for the maximum ticket lifetime to pass, then reset again | AD team, with incident lead approval | After each reset, confirm replication has converged on both DCs. Confirm a test account can authenticate. Confirm tickets issued before the reset are rejected. |

## 4. Recurrence test

Recurrence is prevented only if the paths through E1, E2, E3, E5 and E6 are all closed. Closing E1 alone (email or macro filtering) leaves the attacker able to proceed from a user-context loader through credential theft and domain replication.

## 5. Open items

- Confirm the entry date (investigation report, Conflict A). If it changes, E1 changes.
- Confirm the ransomware hash.
- Confirm that the Tier 0 account used in Stage 4 is the account in the 4624 records.
- Confirm the per-host persistence list (Stage 5) so that E5 can be tested against real events.
