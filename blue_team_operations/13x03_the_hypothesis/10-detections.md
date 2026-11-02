# Durable coverage: detections for T1547.001 and the staging blind spot

## 1. Detection for confirmed persistence (T1547.001)

Behaviour: a script-capable interpreter writes a value under the per-user Run key, and the value points into a user-writable path.

This rule is keyed on the behaviour, not on the host, the hash, or the Tavistock9 indicator. Tavistock9 is a campaign pivot for hunting, not a condition of the rule.

```xml
<group name="kestrel_hunt,windows,persistence,">
  <rule id="100310" level="12">
    <if_group>sysmon_event13</if_group>
    <field name="win.eventdata.targetObject">(?i)\\Software\\Microsoft\\Windows\\CurrentVersion\\Run</field>
    <field name="win.eventdata.details">(?i)(AppData\\Roaming|AppData\\Local|Users\\Public)</field>
    <field name="win.eventdata.image">(?i)(powershell|wscript|cscript|rundll32|regsvr32|mshta)\.exe</field>
    <description>Script-backed writer creates Run-key persistence in a user-writable path</description>
    <mitre><id>T1547.001</id></mitre>
  </rule>
</group>
```

### Precision controls

- Three conditions must hold together: the Run-key target, a user-writable value path, and a script-capable writer. Any one alone matches normal software installs, so none is used alone.
- The writer list is limited to interpreters and script hosts. It does not include general installers.
- Signer context is not in this rule yet. Sysmon Event ID 13 does not carry the signature of the writing binary. Known signed enterprise updaters should be excluded with a Wazuh CDB allowlist, built from the software inventory, keyed on the image path and signer. This allowlist does not exist yet and must be built before the rule goes to production.

### Known weakness

`rundll32` and `regsvr32` are used by some legitimate installers. Until the allowlist exists, these two are the most likely source of false positives. If the test in section 1.1 shows noise from them, drop them first and keep the three conditions.

### 1.1 Test against ordinary fleet activity

Status: NOT RUN. The result recorded in the earlier draft is not verified and is not reported here.

Required test parameters:
- Window: 2026-09-01T00:22:54.128Z to 2026-10-13T04:56:17.155Z, the same window as the hunt.
- Population: all 340 Windows endpoints in the Nimbus estate, all Sysmon Event ID 13 events in the window.
- Run the full rule, with all three conditions, unmodified.

Report in this form, with every field filled from the run:

| Class | Count | Hosts | Notes |
|---|---|---|---|
| Matched, classified suspicious | | | |
| Matched, classified legitimate (with the reason) | | | |
| Matched, unresolved | | | |
| Not matched | | | |

Hosts NIM-ENG-031, NIM-ENG-057 and NIM-ENG-066 must be stated explicitly as matched or not matched by the full rule. They are not to be listed as matches unless the full rule fired on them.

Until this table is filled, the rule must not be deployed as a live alert. A rule that fires on normal operations gets turned off.

## 2. Remedy for the blind spot: collection, not a rule yet

Choice: a data-source recommendation, not an immediate rule.

Reason: local staging and archive creation were not observable during the hunt. Without file-creation telemetry, no rule can match the operation. A rule written now would only match what the sensor happens to see, which is nothing for staging.

### What to enable

- Sysmon Event ID 11 (FileCreate), with a configuration limited to user-writable staging locations, temporary directories, and archive extensions. Starting configuration:

```xml
<FileCreate onmatch="include">
  <TargetFilename condition="contains">\AppData\Local\Temp\</TargetFilename>
  <TargetFilename condition="contains">\Users\Public\</TargetFilename>
  <TargetFilename condition="end with">.zip</TargetFilename>
  <TargetFilename condition="end with">.rar</TargetFilename>
  <TargetFilename condition="end with">.7z</TargetFilename>
</FileCreate>
```

- Windows Object Access auditing with Security Event ID 4663 on the sensitive paths only, not the whole disk, to avoid flooding.
- Security Event IDs 4656 and 4660 as supporting events for handle and delete context.

Tune by adding exclusions for high-volume applications after a baseline is collected. Do not disable the staging paths to reduce volume.

### What it lets Nimbus detect

Archive creation or repeated writes into a staging directory, correlated with the writing process and its destination. This is the staging step that the current telemetry cannot see.

### Rule to write once collection exists

Not yet tested. It must be written and tested only after at least two weeks of Event ID 11 data is confirmed as collected. Sketch of the logic:
- Match Sysmon Event ID 11 where the target is an archive extension in a staging path.
- Use a frequency condition: several such writes from one process within a short window.
- Test against the baseline before deployment, with the same reporting table as section 1.1.

Until collection exists, an empty result for staging means the sensor could not see the operation. It does not mean staging did not happen.
