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
- Signer context is not implemented in this rule. Sysmon Event ID 13 does not carry the signature of the writing binary. Known signed enterprise updaters should be excluded with a Wazuh CDB allowlist, built from the software inventory, keyed on the image path and signer. This allowlist does not exist yet. Until it does, the rule is not production-ready, and this is stated as a gap, not a control.

### Known weakness

`rundll32` and `regsvr32` are used by some legitimate installers. Until the allowlist exists, these two are the most likely source of false positives. If the test in section 1.1 shows noise from them, drop them first and keep the three conditions.

### What this rule deliberately does not cover

The rule is narrow on purpose, so that its first run produces a reviewable result. It will miss:

- Run-key writes by a non-script executable, for example a compiled binary dropped by the actor. These are covered by the candidate rule in section 1.2, not by this one.
- Run-key writes to a user-writable path that is outside AppData, Users\Public and Temp.
- Persistence through other autostart locations, such as RunOnce, scheduled tasks and services. These are separate techniques and are not part of this detection.

A missed case is not evidence of absence. It is a case the rule was not built to see.

### 1.1 Test against ordinary fleet activity

Status: NOT RUN. No test result is reported in this file.

Required test parameters:
- Window: 2026-09-01T00:22:54.128Z to 2026-10-13T04:56:17.155Z, the same window as the hunt.
- Population: all 340 Windows endpoints in the Nimbus estate, all Sysmon Event ID 13 events in the window.
- Run the full rule, with all three conditions, unmodified.

Control check, run first: confirm the field names work by running a query known to return results, such as `data.win.system.eventID:13` over the window. If it returns zero, fix the field names before reading any other result. A zero from a broken query is not a zero from the fleet.

Queries to run in the Wazuh/OpenSearch dashboard over the window above. Copy them as raw text. Adjust backslash and wildcard escaping for your indexer if needed.

Query A, full rule (all three conditions):
```
data.win.system.eventID:13 AND data.win.eventdata.targetObject:*CurrentVersion\\Run* AND data.win.eventdata.details:(*AppData\\Roaming* OR *AppData\\Local* OR *Users\\Public*) AND data.win.eventdata.image:(*powershell.exe OR *wscript.exe OR *cscript.exe OR *rundll32.exe OR *regsvr32.exe OR *mshta.exe)
```

Query B, all Run-key writes (benign baseline):
```
data.win.system.eventID:13 AND data.win.eventdata.targetObject:*CurrentVersion\\Run*
```

Query C, the three named hosts:
```
data.win.agent.name:(NIM-ENG-031 OR NIM-ENG-057 OR NIM-ENG-066) AND data.win.system.eventID:13 AND data.win.eventdata.targetObject:*CurrentVersion\\Run*
```

Query D, fleet-wide discovery from the hunt budget (broader path filter, for comparison only; not the rule):
```
data.win.system.eventID:13 AND data.win.eventdata.targetObject:*CurrentVersion\\Run* AND (data.win.eventdata.details:*\\AppData\\* OR data.win.eventdata.details:*\\Users\\Public\\* OR data.win.eventdata.details:*\\Temp\\*)
```

Precision check, run after A and B: the NIM-SAL-054 and NIM-SAL-063 cryptominer (scheduled task `MediaConvUpdate`, not a Run-key write) is expected not to match Query A. If it appears in Query A, the rule is too broad, and that must be recorded in the table.

For each Query B hit that is not returned by Query A: record the image path and the value written, and classify it as legitimate (with the reason) or unresolved.

Report in this form, with every field filled from the run:

| Class | Count | Hosts | Notes |
|---|---|---|---|
| Matched, classified suspicious | | | |
| Matched, classified legitimate (with the reason) | | | |
| Matched, unresolved | | | |
| Not matched | | | |

Hosts NIM-ENG-031, NIM-ENG-057 and NIM-ENG-066 must be stated explicitly as matched or not matched by Query A. They are not to be listed as matches unless Query A returned them. Query D results are reviewed as candidates only and do not count as matches of the final rule.

Until this table is filled, the rule must not be deployed as a live alert. A rule that fires on normal operations gets turned off.

### 1.2 Candidate second rule (not tested, not deployable)

Purpose: cover Run-key writes by a non-script executable into a user-writable path, which rule 100310 does not see.

```xml
<rule id="100311" level="10">
  <if_group>sysmon_event13</if_group>
  <field name="win.eventdata.targetObject">(?i)\\Software\\Microsoft\\Windows\\CurrentVersion\\Run</field>
  <field name="win.eventdata.details">(?i)(AppData\\Roaming|AppData\\Local|Users\\Public|\\Temp\\)</field>
  <description>Run-key value points into a user-writable path (candidate, pending allowlist and test)</description>
  <mitre><id>T1547.001</id></mitre>
</rule>
```

Why this is only a candidate: without an allowlist of known per-user installers, this condition will match many legitimate applications that register Run-key entries under AppData. It must not be deployed until the allowlist exists and section 1.1 has been run for it, with its own results table. It is recorded here so the gap is visible, not so that it is treated as a control.

## 2. Remedy for the blind spot: collection, not a rule yet

Choice: a data-source recommendation, not an immediate rule.

Reason: local staging and archive creation cannot be observed with the current collection. Without file-creation telemetry, no rule can match the operation. A rule written now would only match what the sensor happens to see, which is nothing for staging.

Evidence for the gap: queries for `data.win.system.eventID:11`, `data.win.system.eventID:4663`, and `data.win.system.eventID:(4656 OR 4660)` returned zero documents across the Nimbus fleet for the available time range. Zero documents only shows the gap if the field name works. Confirm with the same control query used in section 1.1 before relying on this.

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

Cost: this increases endpoint event volume, storage and retention requirements, and analyst review workload. Start with high-value paths and tune exclusions for known high-volume applications after a baseline is collected. Do not disable the staging paths to reduce volume.

### What it lets Nimbus detect

Archive creation or repeated writes into a staging directory, correlated with the writing process and its destination. This is the staging step that the current telemetry cannot see.

### Rule to write once collection exists

Not yet tested. It must be written and tested only after at least two weeks of Event ID 11 data is confirmed as collected. Sketch of the logic:
- Match Sysmon Event ID 11 where the target is an archive extension in a staging path.
- Use a frequency condition: several such writes from one process within a short window.
- Test against the baseline before deployment, with the same reporting table as section 1.1.

Until collection exists, an empty result for staging means the sensor could not see the operation. It does not mean staging did not happen. Nimbus cannot determine whether the actor staged or archived data; the result is unanswered, not clean.
