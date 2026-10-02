The Privilege Abuse Map
Scope and Evidence

This map describes the svc-web token observed on VRG-WEB01, rather than assuming that the account's name or group membership determines its access. The host was Windows Server 2022, build 20348. whoami /all showed svc-web in BUILTIN\Users, not in Administrators, with High integrity. whoami /priv listed five privileges. Windows checks a process or thread's access token when it accesses protected resources; the token includes the user, groups, privileges, and other security information.

The lab notes describe SeBackupPrivilege as enabled, but whoami /priv showed it as Disabled. The reg save commands for SAM and SYSTEM reported success, but I did not extract a hash or authenticate as Administrator. PrintSpoofer did not produce a confirmed SYSTEM shell. These are limitations of the evidence, so neither path is counted as a completed escalation.

Privileges in the Foothold Token

SeImpersonatePrivilege — Enabled. This privilege allows a process to impersonate a client after authentication. The lab proposed using PrintSpoofer with the Print Spooler service to obtain a SYSTEM-level context. I attempted the PrintSpoofer route but did not obtain a SYSTEM shell or read the SYSTEM-only proof file. The escalation was attempted, not confirmed. This is the highest-risk privilege in the observed token.

SeBackupPrivilege — Disabled in the observed token. This privilege is intended for backup software. When enabled, it can allow reads that bypass ordinary file ACL checks, including access to protected registry hives (SAM, SYSTEM, SECURITY). I ran reg save for the SAM and SYSTEM hives, and both commands reported success. However, the disabled state in the observed token conflicts with the lab notes, and I did not use the resulting files to recover or verify a credential. When enabled, this would be the second-highest risk.

SeDebugPrivilege — Enabled. This privilege permits debugging processes and may allow access to another process's memory or token, exposing credentials or providing a route to another security context. I did not use it; debugging is not a normal IIS requirement.

SeChangeNotifyPrivilege — Enabled. This privilege bypasses directory traversal checks but does not grant permission to list directories or read files. It was not abused and is not a meaningful escalation route here.

SeIncreaseWorkingSetPrivilege — Disabled. This allows a process to increase its working set. It does not grant access to another user's files or token, and its risk here is low.

Highest-Risk Paths and Remediation

The two most serious paths are SeImpersonatePrivilege and SeBackupPrivilege when enabled. Careless fixes break legitimate application functionality, so remediation must account for load-bearing features.

For SeImpersonatePrivilege: Run each IIS application pool under an isolated virtual application-pool identity. First check whether the specific application genuinely needs impersonation. If it does, isolate that application from unrelated sites and services, restrict who can connect to it, and monitor for unexpected child processes and privileged impersonation activity. This narrows the exposure while allowing required features to continue working.

For SeBackupPrivilege if enabled: Use a dedicated backup identity for the scheduled backup service, not the web application identity. If local policy grants this right to svc-web, remove that assignment and confirm the change in a fresh logon token. Test that the backup service still works under its dedicated identity. This protects sensitive data without breaking the platform's backup process.

For SeDebugPrivilege: Remove from svc-web unless a documented component requires it. If support staff need debugging, grant it to a separate, controlled support identity rather than to the continuously exposed web worker.

Defender Visibility and Completion Status

Flag 1 was read from the VM. The SYSTEM proof file, the Administrator credential, and the final protected secret were not recovered during this run. Therefore, there is no confirmed privilege escalation to report as completed.

Vantage Audit Configuration

Audit policy on VRG-WEB01 was verified using auditpol /get /category:*. Key findings:

Audit Process Creation: Enabled → 4688 logged for all process launches.
Command-line Auditing: Disabled → Process names logged; arguments not visible.
Sensitive Privilege Use (4673): Disabled → Privilege invocations not logged.
File System/Object Access: Disabled → Registry hive access not audited.
Event Log: Local only, 20 MB circular buffer (2–3 days retention); not forwarded to SIEM.
Escalation Activities and Visibility

PrintSpoofer (SeImpersonatePrivilege): Event logged: 4688 shows "PrintSpoofer.exe started by svc-web." Visible: process name and launch time. Hidden: command-line arguments and impersonation operation (4673 disabled). Unless reviewed within 2–3 days and specifically hunting for PrintSpoofer.exe, the event is overwritten. No SIEM correlation. Conclusion: Event recorded but likely undetected due to minimal logging and no central monitoring.

Registry Hive Export (reg save): Event logged: 4688 shows "reg.exe started by svc-web." Visible: process name. Hidden: which hive was saved and backup privilege invocation (4673 disabled). Vantage's routine backups also use reg.exe, so this activity blends with legitimate operations unless the defender detects the export file in a non-standard location or outside scheduled backup windows. Conclusion: Event recorded but masked as routine backup activity; defender would not distinguish escalation without baselines and alerting rules.

Debug and Other Privileges: SeDebugPrivilege would generate 4688 for tool launch but no 4673. SeChangeNotifyPrivilege and SeIncreaseWorkingSetPrivilege generate no distinct log events.

Detection Gap

The escalation attempts generate 4688 process-creation events in Vantage's local Security log, but are only partially visible. Command-line auditing is disabled, sensitive privilege auditing is disabled, and logs are not forwarded to a SIEM. Unless the administrator reviews the local log within 2–3 days, entries are overwritten. Without command-line logging, the defender cannot distinguish "PrintSpoofer targeting SYSTEM" from routine activity. Without SIEM alerting or baseline rules, events are noise. Vantage's audit posture records the attempts but does not detect them as escalation. This gap is not evidence the activities did not occur; it is evidence that logging infrastructure must be enhanced to generate alerts, not merely records.

## References

- [Microsoft: Access Tokens (https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens>)
- [Microsoft: Privilege Constants (https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants>)
- [Microsoft: Event 4673 (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4673)](<https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4673>)
- [Microsoft: Audit Sensitive Privilege Use (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-sensitive-privilege-use)](<https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-sensitive-privilege-use>)
