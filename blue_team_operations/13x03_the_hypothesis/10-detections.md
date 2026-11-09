# 10 Close the Gaps: durable coverage for T1547.001 and the staging blind spot

Status summary

| Part | Status |
|---|---|
| 1. Detection for confirmed persistence (rule 100310) | Written. **Not tested. Not deployable.** |
| 1.2 Candidate rule 100311 | Written. Not tested. Not deployable. |
| 2. Remedy for the staging blind spot | Written: data-source recommendation (Sysmon Event ID 11). No rule yet. |
| 3. Test against ordinary fleet activity | **NOT RUN.** The environment used to write this file had no access to the Wazuh/OpenSearch indexer and no fleet event data. No results are reported below. |

Nothing in this file should be read as a test result. Until section 3 is filled from a real run, rule 100310 must not be enabled as a live alert.

---

## 1. Detection for confirmed persistence (T1547.001)

Behaviour: a script-capable interpreter writes a value under the per-user Run key, and the value points into a user-writable path.

The rule is keyed on that behaviour, not on the host, the hash, or the Tavistock9 indicator. Tavistock9 is a campaign pivot for hunting, not a condition of the rule.

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
- **Signer context is not implemented.** Sysmon Event ID 13 does not carry the signature of the writing binary. Known signed enterprise updaters should be excluded with a Wazuh CDB allowlist, built from the software inventory and keyed on image path and signer. **That allowlist does not exist yet.** Until it does, the rule is not production-ready. This is a stated gap, not a control.

### Known weakness

`rundll32` and `regsvr32` are used by some legitimate installers and are the most likely source of false positives until the allowlist exists. If section 3 shows noise from them, drop them first and keep the three conditions.

### What this rule deliberately does not cover

The rule is narrow on purpose, so that its first run produces a reviewable result. It will miss:

- Run-key writes by a non-script executable, such as a compiled binary dropped by the actor. Covered only by the candidate in 1.2, which is not deployable.
- Run-key writes to a user-writable path outside AppData, Users\Public and Temp.
- Persistence through other autostart locations (RunOnce, scheduled tasks, services). These are separate techniques.

A missed case is not evidence of absence. It is a case the rule was not built to see.

### 1.2 Candidate second rule (not tested, not deployable)

Purpose: cover Run-key writes by a non-script executable into a user-writable path.

```xml
<rule id="100311" level="10">
  <if_group>sysmon_event13</if_group>
  <field name="win.eventdata.targetObject">(?i)\\Software\\Microsoft\\Windows\\CurrentVersion\\Run</field>
  <field name="win.eventdata.details">(?i)(AppData\\Roaming|AppData\\Local|Users\\Public|\\Temp\\)</field>
  <description>Run-key value points into a user-writable path (candidate, pending allowlist and test)</description>
  <mitre><id>T1547.001</id></mitre>
</rule>
```

Without an allowlist of known per-user installers, this condition will match many legitimate applications that register Run-key entries under AppData. It must not be deployed until the allowlist exists and it has its own results table from section 3.

---

## 2. Remedy for the blind spot: collection, not a rule yet

**Choice: a data-source recommendation.** Not a rule.

**Reason:** local staging and archive creation cannot be observed with the current collection. Without file-creation telemetry no rule can match the operation. A rule written now would only match what the sensor happens to see, which for staging is nothing.

**Evidence for the gap (as reported in the source hunt notes; not re-verified here):** queries for `data.win.system.eventID:11`, `:4663`, and `:(4656 OR 4660)` returned zero documents across the Nimbus fleet for the available time range. A zero only shows a gap if the field name works, so the control query from section 3 must be run first to confirm it.

### What to enable

- **Sysmon Event ID 11 (FileCreate)**, limited to user-writable staging locations, temp directories and archive extensions. Starting configuration:

```xml
<FileCreate onmatch="include">
  <TargetFilename condition="contains">\AppData\Local\Temp\</TargetFilename>
  <TargetFilename condition="contains">\Users\Public\</TargetFilename>
  <TargetFilename condition="end with">.zip</TargetFilename>
  <TargetFilename condition="end with">.rar</TargetFilename>
  <TargetFilename condition="end with">.7z</TargetFilename>
</FileCreate>
```

- **Security Event ID 4663** (Object Access) on sensitive paths only, not the whole disk, to avoid flooding.
- **Security Event IDs 4656 and 4660** as supporting context for handle and delete activity.

**Cost:** more endpoint event volume, storage and retention, and analyst review workload. Start with high-value paths, collect a baseline, then tune exclusions for known high-volume applications. Do not disable the staging paths to reduce volume.

### What it lets Nimbus detect

Archive creation or repeated writes into a staging directory, correlated with the writing process and its destination. This is the staging step the current telemetry cannot see.

### Rule to write once collection exists

Not yet written or tested. Write and test it only after at least two weeks of Event ID 11 data are confirmed as collected. Outline:
- Match Sysmon Event ID 11 where the target is an archive extension in a staging path.
- Use a frequency condition: several such writes from one process within a short window.
- Test against the baseline before deployment, using the section 3 reporting table.

Until collection exists, an empty result for staging means the sensor could not see the operation. It does not mean staging did not happen. Nimbus cannot determine from current data whether the actor staged or archived data. The result is **unanswered, not clean.**

---

## 3. Test against ordinary fleet activity

**Status: NOT RUN.**

Reason: no Wazuh/OpenSearch indexer was reachable from the environment in which this file was prepared (connection to the default indexer endpoint refused), and no exported fleet event data was supplied. No counts, hosts or classifications are reported here, because any would be invented.

### Required test parameters

- Window: 2026-09-01T00:22:54.128Z to 2026-10-13T04:56:17.155Z (same as the hunt).
- Population: all 340 Windows endpoints in the Nimbus estate; all Sysmon Event ID 13 events in the window.
- Run rule 100310 with all three conditions, unmodified. If the rule is changed (for example, dropping `rundll32`/`regsvr32` after noise), record the initial and final versions separately and report the final version's result.

### Control check (run first)

Run `data.win.system.eventID:13` over the window. If it returns zero, fix the field names before reading any other result. A zero from a broken query is not a zero from the fleet.

### Queries (copy as raw text; adjust escaping for your indexer if needed)

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

Query D, broader discovery for comparison only (not the rule):
```
data.win.system.eventID:13 AND data.win.eventdata.targetObject:*CurrentVersion\\Run* AND (data.win.eventdata.details:*\\AppData\\* OR data.win.eventdata.details:*\\Users\\Public\\* OR data.win.eventdata.details:*\\Temp\\*)
```

### Checks to perform after running A and B

- **Precision check:** the NIM-SAL-054 / NIM-SAL-063 cryptominer (scheduled task `MediaConvUpdate`, not a Run-key write) is expected not to match Query A. If it does, the rule is too broad and that must be recorded in the table.
- For each Query B hit not returned by Query A: record the image path and value written, and classify as legitimate (with reason) or unresolved.
- Hosts NIM-ENG-031, NIM-ENG-057 and NIM-ENG-066 must each be stated explicitly as matched or not matched by Query A. Query D results are candidates only and do not count as matches.

### Results table (to be filled from the run)

| Class | Count | Hosts | Notes |
|---|---|---|---|
| Matched, classified suspicious | _not run_ | _not run_ | _not run_ |
| Matched, classified legitimate (with reason) | _not run_ | _not run_ | _not run_ |
| Matched, unresolved | _not run_ | _not run_ | _not run_ |
| Not matched | _not run_ | _not run_ | _not run_ |

Host dispositions: NIM-ENG-031 _not run_; NIM-ENG-057 _not run_; NIM-ENG-066 _not run_.

Until this table is filled from a real run, rule 100310 must not be deployed as a live alert. A rule that fires on normal operations gets turned off.
