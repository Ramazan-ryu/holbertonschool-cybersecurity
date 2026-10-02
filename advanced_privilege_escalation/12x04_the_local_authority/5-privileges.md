The Privilege Abuse Map
Scope and Evidence

This map describes the svc-web token observed on VRG-WEB01, rather than assuming that the account's name or group membership determines its access. The host was Windows Server 2022, build 20348. whoami /all showed svc-web in BUILTIN\Users, not in Administrators, with High integrity. whoami /priv listed five privileges. Windows checks a process or thread's access token when it accesses protected resources; the token includes the user, groups, privileges, and other security information. Microsoft: Access Tokens

There is a mismatch between the lab notes and the token observed during this run. The notes describe SeBackupPrivilege as enabled, but whoami /priv showed it as Disabled. The reg save commands for SAM and SYSTEM reported success, but I did not extract a hash or authenticate as Administrator. PrintSpoofer did not produce a confirmed SYSTEM shell. These are limitations of the evidence, so I do not count either path as a completed escalation.

Privileges in the Foothold Token

SeImpersonatePrivilege — Enabled. This privilege allows a process to impersonate a client after authentication, creating a new token in the client's security context. The lab proposed using PrintSpoofer with the running Print Spooler service to obtain a SYSTEM-level context. JuicyPotato's older DCOM method is unsuitable for Windows Server 2022, so PrintSpoofer is the modern equivalent. I attempted the PrintSpoofer route but did not obtain a SYSTEM shell or read the SYSTEM-only proof file. The escalation was attempted, not confirmed. This is the highest-risk privilege in the observed token for this host.

SeBackupPrivilege — Disabled in the observed token. This privilege is intended for backup software. When enabled and used for backup operations, it can allow reads that bypass ordinary file ACL checks, including access to protected files or registry hives (SAM, SYSTEM, SECURITY). I ran reg save for the SAM and SYSTEM hives, and both commands reported success. However, the disabled state in the observed token conflicts with the lab notes, and I did not use the resulting files to recover or verify a credential. The export is evidence to investigate, but not proof that this token used SeBackupPrivilege. When enabled, this would be the second-highest risk.

SeDebugPrivilege — Enabled. This privilege permits debugging processes and may allow access to another process's memory or token, subject to other protections and conditions. That can expose credentials or provide a route to another security context. I did not use it; debugging is not a normal IIS application requirement and should not be granted to the web service account.

SeChangeNotifyPrivilege — Enabled. This common privilege bypasses directory traversal checks. It does not grant permission to list a directory or read its files. It was not abused and is not a meaningful escalation route here. Routine traversal is generally not a useful detection signal.

SeIncreaseWorkingSetPrivilege — Disabled. This allows a process to increase its working set, the memory kept resident for that process. It does not grant access to another user's files or token, and I did not use it. Its risk here is low.

Highest-Risk Paths and Remediation

The two most serious paths are SeImpersonatePrivilege and SeBackupPrivilege when enabled. These warrant specific remediation because they can lead to data breach or privilege escalation, and because careless fixes break legitimate application functionality.

For SeImpersonatePrivilege: Avoid granting this right broadly to the web service account. Run each IIS application pool under an isolated virtual application-pool identity or another narrowly scoped service identity. First check whether the specific application genuinely needs impersonation. If it does, isolate that application from unrelated sites and services, restrict who can connect to it, and monitor for unexpected child processes and privileged impersonation activity. This narrows the exposure while allowing a required application feature to continue working. If the web platform does not require impersonation, remove svc-web from the group or policy that grants SeImpersonatePrivilege and test the application in a staging environment.

For SeBackupPrivilege if enabled: Use a dedicated backup identity for the scheduled backup service, not the web application identity. If local policy grants this right to svc-web, remove that assignment and confirm the change in a fresh logon token. Test that the backup service still works under its dedicated identity and that incremental backups still function. This protects sensitive data (credential hives, application secrets) without breaking the platform's backup process. Document the dedicated backup account's credentials separately from the web service account.

For SeDebugPrivilege: This should also be removed from svc-web unless a documented component requires it. Debugging is not a normal IIS application requirement. If support staff need debugging, grant it to a separate, controlled support identity rather than to the continuously exposed web worker. Verify that removal does not break application diagnostics; most modern applications use ETW (Event Tracing for Windows) or log files instead of direct debugging.

Defender Visibility and Completion Status

Flag 1 was read from the VM. The SYSTEM proof file, the Administrator credential, and the final protected secret were not recovered during this run. Therefore, there is no confirmed privilege escalation to report as completed.

Observable Activity and Logging Surface

The activities attempted on VRG-WEB01 (PrintSpooler impersonation via PrintSpoofer, reg save for SAM and SYSTEM hives) would generate Windows Security events if the relevant audit policies are enabled and if those events are collected. However, Vantage's specific audit configuration was not enumerated during this assessment. The following analysis assumes a normally configured Windows Server 2022 baseline with standard audit policy, not Vantage's actual settings.

PrintSpooler activity (SeImpersonatePrivilege + PrintSpoofer attempt):

Event recorded: If command-line auditing is enabled, launching PrintSpoofer generates Security event 4688 (process creation). The command line appears only if command-line auditing is also enabled.
Defender visibility: Vantage must actively collect the Security log or send it to a SIEM. If logs are collected but not monitored by alerting rules, the event sits unreviewed. If command-line auditing is disabled, the process creation may still generate 4688, but the tool name and arguments are not logged.
Privilege auditing: Sensitive privilege use may generate 4673 (Sensitive Privilege Use) if sensitive privilege auditing is enabled and the impersonation operation is instrumented. This depends on audit policy and is not guaranteed under default IIS settings.

Registry hive export (reg save for SAM and SYSTEM):

Event recorded: Backup privilege use, when enabled and used, can generate 4673 if backup/restore auditing is configured separately. Process creation via reg save generates 4688 if command-line auditing is on.
Defender visibility: Vantage's normal backup operations naturally trigger these events, so a 4673 or 4688 for a reg save command must be distinguished from legitimate backup activity. Without a baseline of expected backup events and specific alerting rules for unexpected command-line invocation of reg save from the web service account, the activity blends into normal operations. Defenders need a rule like "reg save from svc-web context = anomalous," not just log collection.

Debug privilege (SeDebugPrivilege, unused here):

If used via tools like Process Hacker or windbg, process creation (4688) would appear. Sensitive privilege use (4673) may not be logged unless debug-operation auditing is explicitly enabled, which is uncommon on production IIS hosts.

Other privileges (SeChangeNotifyPrivilege, SeIncreaseWorkingSetPrivilege):

These generate minimal or no log activity under default settings and are not actionable alerts.
Why Absence of Logs Does Not Confirm Absence of Activity

Vantage may not see a 4688 event for PrintSpooler or reg save for several reasons:

Audit policy does not enable command-line logging.
The security log is not forwarded to Vantage's central logging or SIEM.
The log exists but no alerting rule flags process creation from the svc-web context.
The log was overwritten before manual review (Security log default retention on Windows Server is event-count-based, often 20–30 MB, and older events are deleted).
Event log service was stopped, clearing in-memory events.

Conversely, the presence of a 4688 or 4673 does not guarantee the defender noticed; it must be actively monitored and correlated. To determine actual coverage on VRG-WEB01, verify Vantage's audit policy using auditpol /get /category:* and check whether event logs are forwarded to a SIEM or reviewed regularly.

## References

- [Microsoft: Access Tokens (https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens>)
- [Microsoft: Privilege Constants (https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants>)
- [Microsoft: Event 4673 (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4673)](<https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4673>)
- [Microsoft: Audit Sensitive Privilege Use (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-sensitive-privilege-use)](<https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-sensitive-privilege-use>)
