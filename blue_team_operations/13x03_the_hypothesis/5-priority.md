# Hunt budget

## Scoring method

Each candidate is scored from 1 (weak) to 3 (strong) on three separate factors: actor reliability, Nimbus exposure, and usable telemetry coverage. The score is not severity. A zero coverage score is a recommendation to collect data, not an executable hunt.

| Candidate | Reliability | Nimbus exposure | Coverage | Decision |
|---|---:|---:|---:|---|
| T1547.001 Run-key persistence | 3: Halcyon, Portway, Ashford and Crane | 3: Windows endpoint fleet | 3: Sysmon 13 live | Fund |
| T1059.001 PowerShell | 3: Halcyon, Portway, Ashford and Crane | 3: process telemetry on fleet | 3: Sysmon 1/4688 live | Fund |
| T1021.002 lateral movement | 2: Halcyon and Portway | 3: domain fleet exposed | 3: 4624/4648/4769 + Sysmon 3 live | Fund |
| T1074.001 local staging | 3: all three prior victims | 3: endpoints can stage locally | 0: no Sysmon 11/file audit | Collection recommendation |
| T1560.001 archive via utility | 3: all three prior victims | 3: endpoints can create archives | 0: no file-create/object audit | Collection recommendation |
| T1071.001 HTTPS beaconing | 3: all three prior victims | 2: outbound traffic is visible but broad | 2: Sysmon 3 is available, URI fields are incomplete | Decline this round |
| T1078 valid accounts | 2: Halcyon and Portway | 3: domain authentication is common | 3: 4624/4648/4769 live | Decline: weak attribution |
| T1053.005 scheduled task | 1: Portway only | 2: possible on endpoints | 3: process and persistence telemetry exists | Decline: one-off behavior |
| T1070.004 file deletion | 2: Halcyon and Ashford and Crane | 2: possible on endpoints | 0: file deletion audit absent | Collection recommendation |
| T1566.001 malicious attachment | 1: Ashford and Crane only | 1: mail telemetry is not in this endpoint estate | 0: no mailbox/attachment source | Decline: cannot hunt here |

## Three funded hunts

**Run-key persistence (T1547.001):** fleet-wide discovery of Run-key writes that point to user-writable locations. The filter is the behaviour, not the campaign value name. DQL query:

    data.win.system.eventID:13 AND data.win.eventdata.targetObject:*CurrentVersion\\Run* AND (data.win.eventdata.details:*\\AppData\\* OR data.win.eventdata.details:*\\Users\\Public\\* OR data.win.eventdata.details:*\\Temp\\*)

Review every returned host and writer process. Then mark any result whose value name is Tavistock9 as a campaign pivot, and require an unsigned writer to confirm it.

**PowerShell execution (T1059.001):** fleet-wide discovery of hidden or encoded PowerShell started from a user process, not from management tooling. DQL query:

    data.win.system.eventID:(1 OR 4688) AND data.win.eventdata.image:(*\\powershell.exe OR *\\pwsh.exe) AND data.win.eventdata.commandLine:(*WindowStyle*Hidden* OR *-w*hidden* OR *EncodedCommand* OR *-enc *)

Group results by parent process. Keep parents that are user applications (for example explorer.exe, winword.exe, excel.exe, outlook.exe) and review them first. Exclude parents that are known admin tooling only after they have been reviewed once.

**Lateral movement over SMB (T1021.002):** fleet-wide discovery of network logons and SMB connections to port 445 from non-system processes. The hunt does not name hosts, so it covers the whole domain fleet. DQL query:

    (data.win.system.eventID:(4624 OR 4648 OR 4769) OR (data.win.system.eventID:3 AND data.win.eventdata.destinationPort:445)) AND NOT data.win.eventdata.processName:*\\System*

Correlate by account, source host, destination host, and timestamp. Rank source-destination pairs that appear across many hosts in a short window, and review them first.

## Why each declined candidate lost

Staging, archive creation, and deletion have high actor reliability but coverage 0, so they become collection recommendations: the endpoints can perform these actions, but no file-create or deletion audit exists to see them. HTTPS beaconing is reliable and partly visible, but the outbound traffic it uses is broad, and the URI fields needed to tell this actor's beacon from ordinary HTTPS are incomplete, so it cannot separate the campaign from normal traffic this round. Valid accounts are visible in the same logs as lateral movement, but domain authentication is routine on this fleet, so a valid-account hit does not identify this campaign without the Run-key or PowerShell context. Scheduled-task persistence was seen in one case only, so it is weaker than the three repeated constraints. Attachment delivery was seen in one case only, and the endpoint estate has no mailbox or attachment source, so it cannot be hunted here at all.
