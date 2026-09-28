# The Privilege Abuse Map

## Scope and Evidence

This map describes the `svc-web` token observed on VRG-WEB01, rather than assuming that the account’s name or group membership determines its access. The host was Windows Server 2022, build 20348. `whoami /all` showed `svc-web` in `BUILTIN\Users`, not in `Administrators`, with High integrity. `whoami /priv` listed five privileges. Windows checks a process or thread’s access token when it accesses protected resources; the token includes the user, groups, privileges, and other security information. [Microsoft: Access Tokens (https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens>)

There is a mismatch between the lab notes and the token observed during this run. The notes describe `SeBackupPrivilege` as enabled, but `whoami /priv` showed it as Disabled. The `reg save` commands for SAM and SYSTEM reported success, but I did not extract a hash or authenticate as Administrator. PrintSpoofer did not produce a confirmed SYSTEM shell. These are limitations of the evidence, so I do not count either path as a completed escalation.

## Privileges in the Foothold Token

- **`SeImpersonatePrivilege` — Enabled.** This lets a process impersonate a client after authentication. The lab proposes using PrintSpoofer with the running Print Spooler to obtain a SYSTEM context. Its notes say JuicyPotato’s older DCOM method is unsuitable for this Windows build. I attempted the PrintSpoofer route but did not obtain a SYSTEM shell or read the SYSTEM-only proof file. The escalation was attempted, not confirmed. If process creation auditing is enabled, launching the tool may be recorded as Security event **4688**. The command line appears only if command-line auditing is also enabled. Sensitive privilege use may generate **4673**, depending on audit policy and the implementation used.
- **`SeBackupPrivilege` — Disabled in the observed token.** This privilege is intended for backup software. When enabled and used for backup operations, it can allow reads that bypass ordinary file ACL checks, including access to protected files or registry hives. I ran `reg save` for the SAM and SYSTEM hives, and both commands reported success. However, the disabled state in the observed token conflicts with the lab notes, and I did not use the resulting files to recover or verify a credential. The export is evidence to investigate, but not proof that this token used `SeBackupPrivilege`. Backup privilege auditing depends on the relevant audit policy; when configured, use may generate **4673**. Process creation may also generate **4688**.
- **`SeDebugPrivilege` — Enabled.** This permits debugging processes and may allow access to another process’s memory or token, subject to other protections and conditions. That can expose credentials or provide a route to another security context. I did not use it. If sensitive privilege auditing is enabled, use may appear as **4673**. Tools or child processes may appear as **4688** when process creation auditing is enabled. Neither event is guaranteed under default settings.
- **`SeChangeNotifyPrivilege` — Enabled.** This common privilege bypasses directory traversal checks. It does not grant permission to list a directory or read its files. It was not abused and is not a meaningful escalation route here. Routine traversal is generally not a useful detection signal.
- **`SeIncreaseWorkingSetPrivilege` — Disabled.** This allows a process to increase its working set, the memory kept resident for that process. It does not grant access to another user’s files or token, and I did not use it. Its risk here is low. If non-sensitive privilege auditing is configured, use may be recorded as **4673**; otherwise, the server may not produce a Security event for it.

## Highest-Risk Paths and Remediation

The two most serious paths are `SeImpersonatePrivilege` and `SeBackupPrivilege` if enabled. For `SeImpersonatePrivilege`, avoid granting the right broadly to the web service account. Run each IIS application pool under an isolated virtual application-pool identity or another narrowly scoped service identity. First check whether the specific application genuinely needs impersonation. If it does, isolate that application from unrelated sites and services, restrict who can connect to it, and monitor for unexpected child processes and privileged impersonation activity. This narrows the exposure while allowing a required application feature to continue working.

For `SeBackupPrivilege`, use a dedicated backup identity for the scheduled backup service, not the web application identity. If local policy grants this right to `svc-web`, remove that assignment and confirm the change in a fresh logon token. Test that the backup service still works under its dedicated identity. This protects sensitive data without breaking the platform’s backup process.

`SeDebugPrivilege` should also be removed from `svc-web` unless a documented component requires it. Debugging is not a normal IIS application requirement. If support staff need debugging, grant it to a separate, controlled support identity rather than to the continuously exposed web worker.

## Defender Visibility and Completion Status

Flag 1 was read from the VM. The SYSTEM proof file, the Administrator credential, and the final protected secret were not recovered during this run. Therefore, there is no confirmed privilege escalation to report as completed.

A normally configured server may record process starts as **4688** and audited sensitive privilege use or privileged-object operations as **4673** or **4674**. Whether these events exist depends on the audit policy. Backup and restore privilege use has a separate auditing setting, which can produce a high volume of events. PowerShell logging may create additional events, but that configuration was not checked. The absence of an event is not proof that an action did not occur; defenders should first verify the applicable audit settings and log coverage.

## References

- [Microsoft: Access Tokens (https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens>)
- [Microsoft: Privilege Constants (https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants>)
- [Microsoft: Event 4673 (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4673)](<https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4673>)
- [Microsoft: Audit Sensitive Privilege Use (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-sensitive-privilege-use)](<https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-sensitive-privilege-use>)
