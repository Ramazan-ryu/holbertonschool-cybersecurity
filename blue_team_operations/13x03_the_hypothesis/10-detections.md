# Durable coverage

## Detection for confirmed persistence

I authored and tested a behavior-based Wazuh rule narrower than any Run-key write. It matches Sysmon Event ID 13, a Run-key target, a user-writable AppData or Public path, and a script-capable writer such as PowerShell, WScript, Rundll32, Regsvr32, or Mshta. The production rule should add signer or inventory context to exclude legitimate signed updaters. Tavistock9 is a campaign pivot, not the sole condition.

Test result: ordinary updater writes were present, but the full condition did not fire on benign writers. Confirmed candidates were NIM-ENG-031, NIM-ENG-057, and NIM-ENG-066.

## Remedy for the blind spot

I recommend collection rather than a live staging rule. Enable Sysmon Event ID 11 FileCreate and Windows Object Access auditing with Security Event ID 4663; collect 4656 and 4660 as supporting events. Start with user-writable staging locations, temporary directories, archive extensions, and sensitive paths, then tune high-volume applications. After collection exists, add a rule for archive creation or repeated writes into a staging directory correlated with process and destination. Until then, an empty result means the sensor could not see the operation.
