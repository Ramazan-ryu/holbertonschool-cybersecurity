# Nimbus hypothesis hunt report

## Scope and hypotheses

Kestrel Defense was asked to test whether the actor previously seen at Halcyon, Portway, and Ashford and Crane was present at Nimbus. There was no alert or complaint, so the actor profile was used as a targeting map. Behaviors seen at all three victims were hidden PowerShell execution, HKCU Run-key persistence, local staging, archive creation, and HTTPS beaconing. Valid-account use and SMB movement appeared twice. Attachment delivery, scheduled-task persistence, and deletion were weaker or environment-dependent.

The first hypothesis was that the actor would create Run-key persistence with the same campaign value name and an unsigned payload in a user-writable AppData path. The second was hidden or encoded PowerShell from a user process. The third was SMB, RDP, or WinRM-style lateral movement. Staging and archive creation were also hypothesized, but could not be funded because the required file telemetry was absent. These hypotheses trace to observed behavior rather than a generic technique list.

## Budget and coverage

Dana funded Run-key persistence, PowerShell execution, and lateral movement. Staging and archive hunts were declined because Sysmon Event ID 11 and Security 4663, 4656, and 4660 are not collected. HTTPS beaconing was visible but less discriminating than the persistence pivot. Valid-account use is common administrative activity and does not identify the campaign without mechanism continuity. Scheduled-task persistence appeared once. Attachment delivery is outside the endpoint estate, and deletion depends on the missing file channel.

Coverage was checked first. Sysmon Event IDs 1, 3, and 13, Security 4624, 4648, and 4769, and directory telemetry are present and returned ordinary records elsewhere in the fleet. A zero in the lateral-movement hunt is meaningful within scope. A zero for Event ID 11 or 4663, 4656, and 4660 proves only that those channels are not subscribed.

## Hunt one: persistence found

The Run-key hunt searched the complete fleet for HKCU/Software/Microsoft/Windows/CurrentVersion/Run, then filtered for value name Tavistock9, an unsigned PowerShell-backed writer, and a user-writable AppData/Roaming target. It returned NIM-ENG-031, NIM-ENG-057, and NIM-ENG-066. Sysmon Event ID 13 showed the same value name and mechanism on all three. The payload names differed: sedgwyn.exe, gullivane.exe, and pellmoor.exe. The stable value name and behavior were more useful than a filename.

Verdict: confirmed campaign-linked persistence on three engineering endpoints. Confidence is high because the registry channel is collected and active, the complete host set was enumerated, and the mechanism is directly observed. Attribution is strong, though attribution remains a claim: Tavistock9 was carried unchanged across all three previous cases and now appears on all three Nimbus footholds with the same unsigned, user-writable payload behavior. This is continuity across four client environments. The evidence supports a foothold and persistence, not yet the full attack lifecycle.

## Hunt two: lateral movement ruled out

I correlated Security 4624, 4648, and 4769 with Sysmon Event ID 3 and searched for SMB, RDP, and WinRM-style access from the three footholds and associated identities. The search covered 2026-09-01T00:22:54.128Z through 2026-10-13T04:56:17.155Z. No matching events were found in that scope, while comparable authentication and network events were present elsewhere.

Verdict: proven absent within the searched hosts, identities, dates, techniques, and collected sources. Confidence is high for that bounded statement because the required channels are live. This does not rule out movement outside the period, from another identity, or through an unsearched method. The correct sentence is not that the actor did not move anywhere; it is that the searched forms were not observed where live telemetry could have shown them.

## Hunt three: staging unanswered

Staging and archive creation were expected because both recurred across all three prior cases. The coverage check found zero documents for Sysmon Event ID 11 and Security file-audit events 4663, 4656, and 4660. These sources would expose file creation, object access, and deletion in local staging paths. The hunt therefore cannot distinguish no staging from staging that was invisible.

Verdict: unknown. Nimbus should enable Sysmon FileCreate and focused Windows Object Access auditing, then rerun the hypothesis. The client-facing sentence is: Nimbus could not determine whether the actor staged or archived data because current collection cannot see the required file activity; the result is unanswered, not clean. This is a visibility gap, not a clean bill of health.

## Incidental finding

The scheduled task MediaConvUpdate on NIM-SAL-054 and NIM-SAL-063 launches C:/Program Files/MediaConv/mcsvc.exe with worker and thread arguments and connects to mining pool 203.0.113.58:3333. This is a real commodity cryptominer and should be handled separately. It is not attributed to the actor: it uses scheduled-task rather than Run-key persistence, has a different destination, began on 2026-01-14, and behaves as a sustained mining worker rather than a periodic beacon. The finding matters because it consumes resources and creates unapproved external traffic, but attaching it to this campaign would create a tidy wrong picture.

## Bottom line and handoff

The actor is present on three Nimbus engineering endpoints and has established persistence. The evidence supports foothold and persistence, but does not establish lateral movement or local staging. Registry, process, and network activity are visible; file staging is not. Before morning, preserve the three engineering endpoints, identify associated users and payloads, and review process and outbound network timelines. Do not delete the Run-key artifacts before collection. Remediate the two miner hosts separately.

The next hunt should test staging and archive creation after FileCreate and focused file-object auditing are deployed. That is the unanswered question most likely to change the containment decision. A second follow-up should review outbound HTTPS beacon behavior from the three footholds, using destination and timing as corroboration rather than as the sole attribution key.