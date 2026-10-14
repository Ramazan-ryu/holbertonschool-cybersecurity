## Hypothesis 1: campaign persistence is present

The actor has established persistence on Nimbus endpoints by writing the same HKCU Run-key value used at prior victims, with an unsigned payload in a user-writable AppData path.

Derivation: this mechanism appeared at all three prior victims, and the carried value name was identical across those cases.

Test: confirm with Sysmon Event ID 13 registry telemetry showing the value name, Run-key path, writer, and payload path. Refute within coverage if no matching value-name writes exist while ordinary Event ID 13 records are present.

## Hypothesis 2: the actor has used the same execution channel

The actor has executed hidden or encoded PowerShell from a user process on Nimbus endpoints.

Derivation: PowerShell execution was observed at all three prior victims.

Test: confirm with Sysmon Event ID 1 or Security 4688 process creation, including PowerShell command-line and parent process fields. Refute for the collected process telemetry and search period if comparable process events are present but no matching behavior exists.

## Hypothesis 3: the actor has staged or archived collected data locally

The actor has created a local staging directory or archive in a user-writable location before exfiltration.

Derivation: local staging and archive creation were observed across all three prior cases.

Test: confirm with file-creation and file-object auditing. The current estate cannot produce an interpretable refutation if Sysmon Event ID 11 and Security 4663/4656/4660 are absent.

## Hypothesis 4: the actor has moved laterally from a foothold

The actor has used SMB, RDP, or WinRM-style remote access from a compromised Nimbus endpoint or identity.

Derivation: lateral movement was observed at two of the three prior victims, so it is plausible but less reliable than the three behaviors seen at every victim.
