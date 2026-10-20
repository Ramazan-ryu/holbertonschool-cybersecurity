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

**Run-key persistence:** DQL query:

    data.win.system.eventID:13 AND data.win.eventdata.targetObject:*CurrentVersion* AND data.win.eventdata.targetObject:*Run* AND data.win.eventdata.details:*Tavistock9*

Review all returned hosts, then require the unsigned writer and AppData target.

**PowerShell execution:** DQL query:

    data.win.system.eventID:(1 OR 4688) AND data.win.eventdata.image:(*powershell* OR *pwsh*) AND data.win.eventdata.commandLine:(*hidden* OR *encoded* OR *download* OR *invoke*)

Review parent process and the full candidate set.

**Lateral movement:** DQL query:

    data.win.system.eventID:(4624 OR 4648 OR 4769 OR 3) AND data.win.agent.name:(NIM-ENG-031 OR NIM-ENG-057 OR NIM-ENG-066)

Correlate timestamps, identity, source host, destination host, and remote-service fields.

## Why each declined candidate lost

Staging, archive creation, and deletion have high actor reliability but coverage 0, so they become collection recommendations. HTTPS beaconing is reliable and partly visible, but it is broad and less discriminating than the Run-key pivot. Valid accounts are visible but common administrative activity and do not identify this campaign without the carried mechanism. Scheduled-task persistence was seen once and is weaker than the three repeated constraints. Attachment delivery was seen once and has no mailbox data source in this endpoint hunt.
