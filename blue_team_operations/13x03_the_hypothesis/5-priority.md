# Hunt budget

Ranked candidates by actor reliability, Nimbus exposure, and live coverage (1 weak, 3 strong).

| Candidate | Reliability | Exposure | Coverage | Decision |
|---|---:|---:|---:|---|
| T1547.001 Run-key persistence | 3 | 3 | 3 | Fund |
| T1059.001 PowerShell | 3 | 3 | 3 | Fund |
| T1021.002 lateral movement | 2 | 3 | 3 | Fund |
| T1074.001 staging | 3 | 3 | 0 | Recommend collection |
| T1560.001 archive | 3 | 3 | 0 | Recommend collection |
| T1071.001 HTTPS beacon | 3 | 2 | 2 | Decline |
| T1078 valid accounts | 2 | 3 | 3 | Decline |
| T1070.004 deletion | 2 | 2 | 0 | Decline |
| T1053.005 scheduled task | 1 | 2 | 3 | Decline |
| T1566.001 attachment | 1 | 1 | 0 | Decline |

## Funded hunts

1. Run-key: search Sysmon Event ID 13 across the fleet for HKCU/Software/Microsoft/Windows/CurrentVersion/Run and value name Tavistock9, then require an unsigned writer and user-writable AppData target.
2. PowerShell: search Sysmon Event ID 1 and Security 4688 for PowerShell launched by a user process with hidden, encoded, or download-and-execute command-line behavior.
3. Lateral movement: correlate Security 4624, 4648, and 4769 with Sysmon Event ID 3 for SMB, RDP, and WinRM-style remote access.

## Omissions

Staging, archive creation, and deletion lost because Event ID 11 and Security 4663, 4656, and 4660 file telemetry are absent; these are collection recommendations, not clean results. HTTPS beaconing was less discriminating than persistence. Valid-account use is common and lacks the campaign mechanism. Scheduled-task persistence appeared once. Attachment delivery is outside the endpoint estate.
