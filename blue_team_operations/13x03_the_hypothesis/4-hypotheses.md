# Hypothesis 1: campaign persistence is present

**Statement:** During the Nimbus 30-day collection window, the actor has established persistence on one or more Nimbus endpoints by creating the same HKCU Run-key value used at the prior victims, with an unsigned payload in a user-writable AppData path.

**Derivation:** This is T1547.001. Run-key persistence was observed at Halcyon, Portway, and Ashford and Crane, including the carried value name Tavistock9. Its 3/3 recurrence makes it a strong actor constraint.

**Test:** Confirm with Sysmon Event ID 13 records across all 340 hosts where the target object is the HKCU Run path, the value name is Tavistock9, and the payload is in AppData. Refute this bounded proposition if Event ID 13 is present and active elsewhere but no matching value-name write exists in the window.

# Hypothesis 2: the actor used its PowerShell execution channel

**Statement:** During the same window, one or more Nimbus endpoints contain hidden or encoded PowerShell launched from a user process.

**Derivation:** This is T1059.001. Hidden PowerShell execution was observed at Halcyon, Portway, and Ashford and Crane, so it was present in 3/3 cases.

**Test:** Confirm with Sysmon Event ID 1 or Security 4688 process creation, using image, parent image, and command-line fields for PowerShell plus hidden, encoded, download, or execute behavior. Refute within collected process telemetry if those events are live and no matching process exists.

# Hypothesis 3: the actor staged or archived data locally

**Statement:** During the collection window, the actor has written collected data to a user-writable local staging location or created an archive before exfiltration.

**Derivation:** This targets T1074.001 and T1560.001. Local staging and archive creation were observed at all three prior victims, so both are 3/3 behaviors. The hypothesis is worth testing, but its result is uninterpretable until file telemetry exists.

**Test:** Confirm with Sysmon Event ID 11 and Security 4663, 4656, or 4660 showing file creation, object access, or archive activity in the profiled paths. A zero cannot refute this hypothesis in the current Nimbus estate because those sources are absent; the current verdict must remain unknown.

# Hypothesis 4: the actor moved laterally from a foothold

**Statement:** During the collection window, the actor used SMB, RDP, or WinRM-style remote access from one of the confirmed engineering footholds or its associated identities to another Nimbus endpoint.

**Derivation:** This targets T1021.002. Lateral movement was observed at Halcyon and Portway but not consistently across all three cases, so it is a 2/3 behavior and a plausible but weaker candidate than the 3/3 constraints.

**Test:** Confirm with Security 4624, 4648, and 4769 plus Sysmon Event ID 3, scoped to NIM-ENG-031, NIM-ENG-057, NIM-ENG-066 and NIMBUS\eli.cole, NIMBUS\avery.eaves, and NIMBUS\jude.pike. Refute within those hosts, identities, dates, and remote-service methods if those event types are demonstrably live elsewhere but the correlated query returns no match.
