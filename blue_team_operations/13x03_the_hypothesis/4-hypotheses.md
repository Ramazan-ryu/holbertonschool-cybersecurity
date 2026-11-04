# Hypothesis 1: campaign persistence is present

**Statement:** During the Nimbus 30-day collection window, the actor has established persistence on one or more Nimbus endpoints by creating the same HKCU Run-key value used at the prior victims, with an unsigned payload in a user-writable AppData path.

**Derivation:** This is T1547.001. Run-key persistence was observed at Halcyon, Portway, and Ashford and Crane, including the carried value name Tavistock9. Its 3/3 recurrence makes it a strong actor constraint.

**Test:**
- **Confirm:** Sysmon Event ID 13 records on the 340 Nimbus hosts where the target object is the HKCU Run path, the value name is Tavistock9, and the payload data points into AppData.
- **Refute:** Sysmon Event ID 13 is demonstrably collected and searchable on all 340 hosts for the full 30-day window, and no write to the HKCU Run path with value name Tavistock9 exists on any of them.
- **Inconclusive:** Event ID 13 is not ingested from some of the 340 hosts, the window contains collection gaps, or the target object or payload fields are missing from the collected records. Absence of matches on partially covered hosts is not a refutation.

# Hypothesis 2: the actor used its PowerShell execution channel

**Statement:** During the same window, one or more Nimbus endpoints contain hidden or encoded PowerShell launched from a user process.

**Derivation:** This is T1059.001. Hidden PowerShell execution was observed at Halcyon, Portway, and Ashford and Crane, so it was present in 3/3 cases.

**Test:**
- **Confirm:** Sysmon Event ID 1 or Security 4688 process-creation records in which the image is PowerShell, the parent image is a user process, and the command line contains hidden, encoded, download, or execute behaviour.
- **Refute:** Process-creation telemetry, including image, parent-image, and command-line fields, is demonstrably collected and searchable on all Nimbus endpoints for the full window, and no PowerShell process matches the hidden, encoded, download, or execute pattern. This refutation covers only the variants visible in command-line fields; activity that is not recorded in process telemetry is not excluded by it.
- **Inconclusive:** Command-line auditing is disabled or not collected on some hosts, the parent-image field is missing, process creation is not ingested from part of the estate, or the window contains gaps. A zero result under these conditions is unknown, not negative.

# Hypothesis 3: the actor staged or archived data locally

**Statement:** During the collection window, the actor has written collected data to a user-writable local staging location or created an archive before exfiltration.

**Derivation:** This targets T1074.001 and T1560.001. Local staging and archive creation were observed at all three prior victims, so both are 3/3 behaviours. The hypothesis is worth testing, but its result is uninterpretable until file telemetry exists.

**Test:**
- **Confirm:** Sysmon Event ID 11 or Security 4663, 4656, or 4660 records showing file creation, object access, or archive creation within the profiled staging paths.
- **Refute:** Not available in the current Nimbus estate. A refutation would require Sysmon Event ID 11 and Security object-access auditing to be demonstrably collected on the relevant hosts for the full window, and even then only within the profiled paths.
- **Inconclusive:** Current verdict. File-creation and object-access telemetry are absent from the Nimbus estate, so no search result, including zero matches, can confirm or refute this hypothesis. The result remains unknown until those sources are provisioned and verified.

# Hypothesis 4: the actor moved laterally from a foothold

**Statement:** During the collection window, the actor used SMB, RDP, or WinRM-style remote access from one of the confirmed engineering footholds or its associated identities to another Nimbus endpoint.

**Derivation:** This targets T1021.002. Lateral movement was observed at Halcyon and Portway but not consistently across all three cases, so it is a 2/3 behaviour and a plausible but weaker candidate than the 3/3 constraints.

**Test:**
- **Confirm:** Security 4624, 4648, and 4769, plus Sysmon Event ID 3, showing remote logons or outbound SMB (445), RDP (3389), or WinRM (5985/5986) connections from NIM-ENG-031, NIM-ENG-057, or NIM-ENG-066, or under NIMBUS\eli.cole, NIMBUS\avery.eaves, or NIMBUS\jude.pike, to other Nimbus endpoints.
- **Refute:** Authentication and network telemetry for NIM-ENG-031, NIM-ENG-057, NIM-ENG-066, and the candidate destination hosts is demonstrably collected and searchable for the full window, and the correlated query returns no remote-access events for the three identities using those services. Negative results from hosts or identities outside this scope do not count.
- **Inconclusive:** Telemetry is missing from any scoped source host or any candidate destination, the identity mapping between accounts and hosts is incomplete, Security 4624 or 4648 logon-type fields are unavailable, or the window contains collection gaps. Results are unknown for any host, identity, or service where these conditions hold.
