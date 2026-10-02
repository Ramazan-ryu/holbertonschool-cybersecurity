## Defender Visibility and Completion Status

Flag 1 was read from the VM. The SYSTEM proof file, the Administrator credential, and the final protected secret were not recovered during this run. Therefore, there is no confirmed privilege escalation to report as completed.

### Observable Activity vs. Defender Detection

The activities attempted on VRG-WEB01 (PrintSpooler impersonation via PrintSpoofer, `reg save` for SAM and SYSTEM hives) would generate Windows Security events *if* the relevant audit policies are enabled. However, Vantage's specific audit configuration was not enumerated; the following analysis assumes a normally configured Windows Server 2022 baseline, not Vantage's actual settings.

**PrintSpooler activity (SeImpersonatePrivilege + PrintSpoofer):**
- *Recorded event:* **4688** (process creation) if command-line auditing is enabled; the tool invocation would appear.
- *Detector visibility:* Only if Vantage monitors the Security log or has a SIEM collecting **4688** events. Manual log review would surface the event; passive log storage without alerting rules leaves the activity undetected.
- *Sensitive privilege use:* **4673** would be generated *if* sensitive privilege auditing is enabled and if the impersonation itself (not merely process creation) is instrumented. This depends on the specific audit policy configuration and is not guaranteed under default settings.

**Registry hive export (SeBackupPrivilege):**
- *Recorded event:* Backup privilege use may generate **4673** if backup auditing is configured separately; process creation via `reg save` would trigger **4688** if command-line auditing is on.
- *Detector visibility:* Vantage's backup operations naturally trigger these events, so a **4673** or **4688** for a `reg save` command must be distinguished from legitimate backup activity. Without a baseline of expected backup events and anomaly rules, the activity blends into normal operations.

**Debug privilege (SeDebugPrivilege):**
- Unused in this assessment; if used via tools like Process Hacker or `windbg`, process creation (**4688**) would appear, but sensitive privilege use (**4673**) may not unless debug-operation auditing is explicitly enabled (uncommon on production IIS hosts).

**Other privileges:**
- `SeChangeNotifyPrivilege` and `SeIncreaseWorkingSetPrivilege` generate minimal or no log activity under default settings and are not actionable alerts.

### Why Absence of Logs Does Not Confirm Absence of Activity

Vantage may not see a **4688** event for PrintSpooler or `reg save` for several reasons:
- Audit policy does not enable command-line logging.
- The security log is not collected by Vantage's central logging or SIEM.
- The log exists but no alerting rule flags process creation from the `svc-web` context.
- The log was overwritten before manual review.

The conversely, the presence of a **4688** or **4673** does not guarantee the defender noticed; it must be actively monitored. Verify Vantage's audit policy (`auditpol` on the host) and log collection pipeline to determine actual coverage.

## References

- [Microsoft: Access Tokens (https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens>)
- [Microsoft: Privilege Constants (https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants)](<https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants>)
- [Microsoft: Event 4673 (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4673)](<https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4673>)
- [Microsoft: Audit Sensitive Privilege Use (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-sensitive-privilege-use)](<https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-sensitive-privilege-use>)
