# Root Cause Analysis

## Causal line

1. **Entry:** A macro-enabled purchase-order email (`<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>`) reached a user. The macro was permitted to run.
   - *Enabling condition:* Macros from untrusted attachments were not blocked by policy.
2. **Foothold:** The macro launched `obsidn64_ldr.exe` on HALC-WS-050, which reached an external document portal and read LSASS.
   - *Enabling condition:* Untrusted binaries could execute from the user context, and LSASS was readable by that context.
3. **Credential reuse:** Credentials obtained from LSASS were used to reach administrative access on HALC-ADM-04. **[Inference]** This link is not directly logged.
   - *Enabling condition:* Administrative logons were not restricted to privileged workstations, so a credential from a standard workstation could be used on an admin host.
4. **Lateral movement and persistence:** The actor logged on remotely (EID 4624) to staged hosts and created scheduled tasks and services.
   - *Enabling condition:* Remote administrative logons were permitted broadly, and persistence creation was not monitored or blocked.
5. **Domain control:** Directory replication rights were exercised from a non-domain-controller source (EID 4662), and long-lived service tickets appeared (EID 4769).
   - *Enabling condition:* Replication rights were granted to a non-DC source, and ticket lifetimes were not constrained.
6. **Impact:** Ransomware (SHA-256 `e7c189…3957`) was deployed, encrypting 53 hosts and staging 19 more.

## Symptom versus cause

The ransomware and the compromised account are symptoms. The causes are the enabling conditions above: untrusted macros, unrestricted LSASS access, unrestricted administrative logons, and unmonitored replication rights.

## Control gaps that break the chain

| Gap | Stage it breaks | Corrective action | Owner | Validation |
|---|---|---|---|---|
| Macros from untrusted attachments run | 1 | Block macros in internet-sourced Office files via policy | Endpoint engineering | Test macro-enabled attachment in a canary mailbox; confirm blocked |
| Untrusted binaries execute from user context | 2 | Enforce application control (allow-listing) on workstations | Endpoint engineering | Attempt execution of `obsidn64_ldr.exe` from a standard user; confirm denial |
| LSASS readable by user processes | 2 | Enable LSA protection (RunAsPPL) and Credential Guard | Identity engineering | Confirm LSA protection state on a sample of workstations; attempt LSASS read from a test process |
| Admin logons allowed from any workstation | 3 | Restrict privileged logons to admin workstations via logon restrictions | Identity engineering | Attempt admin logon from a standard workstation; confirm denial |
| Persistence and remote logon not restricted | 4 | Alert on new scheduled tasks and services; restrict remote logon rights | Detection engineering | Simulate task creation on a test host; confirm alert fires |
| Replication rights granted to non-DC source | 5 | Remove replication rights from non-DC accounts; audit EID 4662 | Identity engineering | Enumerate replication-rights holders; confirm only DCs hold them |
| Long ticket lifetimes | 5 | Reduce Kerberos ticket lifetime policy | Identity engineering | Confirm policy value via domain GPO report |

## Recurrence test

Recurrence is prevented only if the email path, LSASS path, admin logon path, and replication path are all closed. Closing the email filter alone would leave stages 2 through 6 open.
