# 10 Close the Gaps: durable coverage for T1547.001 and the staging blind spot

## Status

| Part | Status |
|---|---|
| 1. Detection for confirmed persistence (rule 100310, final version v2) | Written. **Not tested. Not deployable.** |
| 1.2 Candidate rule 100311 | Written. Not tested. Not deployable. |
| 2. Remedy for the staging blind spot | Written: data-source recommendation (Sysmon Event ID 11). No rule yet. |
| 3. Test against ordinary fleet activity | **INCOMPLETE. The test has not been run. No results are reported.** |

This submission does not yet contain a test result. Section 3 gives the procedure and an empty results form. It must be completed from a real run before rule 100310 can be treated as tested. Until then, rule 100310 must not be enabled as a live alert.

---

## 1. Detection for confirmed persistence (T1547.001)

Behaviour: a script-capable interpreter writes a value under the per-user Run key, and the value points into a user-writable path.

The rule is keyed on that behaviour, not on the host, the hash, or the Tavistock9 indicator. Tavistock9 is a campaign pivot for hunting, not a condition of the rule.

### Final rule (v2)

```xml
<group name="kestrel_hunt,windows,persistence,">
  <rule id="100310" level="12">
    <if_group>sysmon_event13</if_group>
    <field name="win.eventdata.targetObject">(?i)\\Software\\Microsoft\\Windows\\CurrentVersion\\Run</field>
    <field name="win.eventdata.details">(?i)(AppData\\Roaming|AppData\\Local|Users\\Public)</field>
    <field name="win.eventdata.image">(?i)(powershell|wscript|cscript|mshta)\.exe</field>
    <description>Script-host writer creates Run-key persistence in a user-writable path</description>
    <mitre><id>T1547.001</id></mitre>
  </rule>
</group>
```

### Version history

- **v1** included `rundll32` and `regsvr32` in the writer list.
- **v2 (final)** removes them. Both are general-purpose loaders that legitimate installers use to register DLLs and COM components. They are the least constrained writers in the list, so they add the most predictable noise while adding no script-host behaviour, which is what this rule is about. Their Run-key writes are not covered by v2. They are covered only by the candidate in 1.2, which is not deployable.

The change was made on reasoning before any test. Section 3 must report the result for v2, the final version.

### Precision controls (as implemented in v2)

Each condition removes a class of ordinary activity:

- **Run-key target** restricts the rule to autostart persistence. Ordinary writes elsewhere in the registry do not match.
- **User-writable value path** (AppData\Roaming, AppData\Local, Users\Public) restricts the match to locations an unprivileged user or actor can write. Program Files and system directories do not match.
- **Script-host writer** (powershell, wscript, cscript, mshta) restricts the match to interpreters and script hosts. A general installer writing a Run key does not match.

Together, these three conditions mean the rule fires only when a script host writes an autostart entry that points into a user-writable path. That combination is the behaviour the hunt confirmed.

**Limitations that remain in v2:**
- Some installers and administration scripts legitimately use powershell, wscript or cscript and may write Run keys under AppData. v2 does not exclude them, because signer context is not available.
- **Signer context is not implemented.** Sysmon Event ID 13 does not carry the signature of the writing binary. Known signed enterprise updaters should be excluded with a Wazuh CDB allowlist, built from the software inventory and keyed on image path and signer. **That allowlist does not exist yet.** Until it does, the rule is not production-ready. This is a stated gap, not a control.

### Known weakness

The script-host writers (powershell, wscript, cscript, mshta) are the remaining likely source of false positives. If section 3 shows noise from a specific writer or path, the next step is an allowlist entry for that software, recorded as a new rule version. Do not widen the path or writer conditions to make the test look cleaner.

### What this rule deliberately does not cover

The rule is narrow on purpose, so that its first run produces a reviewable result. It will miss:

- **Run-key writes by `rundll32.exe` or `regsvr32.exe`** (removed in v2 for precision). Covered only by the candidate in 1.2, which is not deployable.
- **Run-key writes by a non-script executable**, such as a compiled binary dropped by the actor. Also covered only by the candidate in 1.2.
- **Run-key writes to a user-writable path outside AppData, Users\Public and Temp.**
- **Persistence through other autostart locations** (RunOnce, scheduled tasks, services). These are separate techniques.

A missed case is not evidence of absence. It is a case the rule was not built to see.

### 1.2 Candidate second rule (not tested, not deployable)

Purpose: cover Run-key writes by non-script executables, including `rundll32.exe` and `regsvr32.exe`, into a user-writable path.

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

**Evidence for the gap (from the source hunt notes; not re-verified in this file):** queries for `data.win.system.eventID:11`, `:4663`, and `:(4656 OR 4660)` returned zero documents across the Nimbus fleet for the available time range. A zero only shows a gap if the field name works, so the control query in section 3 must be run first to confirm it.

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
- Test against the baseline before deployment, using the section 3 reporting form.

Until collection exists, an empty result for staging means the sensor could not see the operation. It does not mean staging did not happen. Nimbus cannot determine from current data whether the actor staged or archived data. The result is **unanswered, not clean.**

---

## 3. Test against ordinary fleet activity

**Status: INCOMPLETE. Not run.**

No indexer endpoint or fleet event export was available when this section was prepared. It must be run by someone with access to the Nimbus Wazuh/OpenSearch dashboard. Until it is, this section reports no results, and no counts, hosts or classifications should be read into it.

### Prior hunt result (reference only; not a test of rule v2)

The Kestrel hypothesis hunt ran over the same window and population with a different filter. Its results are recorded here as context for the test, not as its result.

- **Filter used by the hunt:** Run-key writes filtered for value name `Tavistock9`, an unsigned PowerShell-backed writer, and a user-writable AppData/Roaming target. The hunt's filter is not the same as rule v2: it adds a value-name condition, which v2 deliberately does not use, and an "unsigned" condition, which Sysmon Event ID 13 cannot evaluate.
- **Hosts returned by the hunt:** NIM-ENG-031, NIM-ENG-057 and NIM-ENG-066, each with the same value name and mechanism. Payload names differed (sedgwyn.exe, gullivane.exe, pellmoor.exe).
- **Incidental finding:** the scheduled task `MediaConvUpdate` on NIM-SAL-054 and NIM-SAL-063 is a commodity cryptominer. It uses scheduled-task persistence rather than a Run-key write, and the hunt did not classify it as campaign activity.
- **Not reported by the hunt:** the count of ordinary Run-key writes in the window, and any review of benign Run-key events. Those are what Query B and the results form must supply.

Whether rule v2 matches the three hosts is **not established** by the hunt. The hunt describes the writer as PowerShell-backed, which suggests Query A may match them, but that must be confirmed by running Query A and recording the result in the form below.

### Test parameters

- Window: 2026-09-01T00:22:54.128Z to 2026-10-13T04:56:17.155Z (same as the hunt).
- Population: all 340 Windows endpoints in the Nimbus estate; all Sysmon Event ID 13 events in the window.
- Rule under test: **rule 100310 v2 (final)**, all three conditions, unmodified during the run. If the rule is changed after the run (for example, an allowlist entry), record the change as a new version and re-run.

### Procedure

1. **Control check first.** Run `data.win.system.eventID:13` over the window. If it returns zero, fix the field names before reading any other result. A zero from a broken query is not a zero from the fleet.
2. Run Query A (final rule v2) and Query B (all Run-key writes) over the window.
3. For each Query B hit not returned by Query A, record the image path and value written, and classify it as legitimate (with reason) or unresolved.
4. Run Query C for the three named hosts and state each host explicitly as matched or not matched by Query A.
5. Run the precision check (below).
6. Complete the results form.

### Queries (copy as raw text; adjust escaping for your indexer if needed)

Query A, final rule v2 (all three conditions):
```
data.win.system.eventID:13 AND data.win.eventdata.targetObject:*CurrentVersion\\Run* AND data.win.eventdata.details:(*AppData\\Roaming* OR *AppData\\Local* OR *Users\\Public*) AND data.win.eventdata.image:(*powershell.exe OR *wscript.exe OR *cscript.exe OR *mshta.exe)
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

### Precision check

The NIM-SAL-054 / NIM-SAL-063 cryptominer (scheduled task `MediaConvUpdate`, not a Run-key write) is expected not to match Query A. If it does, the rule is too broad, and that must be recorded in the form below and the rule revised.

### Results form (to be completed from the run)

Final rule version tested: **v2**
Test run by: _to be entered_
Date and time of run: _to be entered_

| Class | Count | Hosts | Notes |
|---|---|---|---|
| Matched, classified suspicious | | | |
| Matched, classified legitimate (with reason) | | | |
| Matched, unresolved | | | |
| Not matched | | | |

Host dispositions by Query A:
- NIM-ENG-031: _to be entered (matched / not matched)_
- NIM-ENG-057: _to be entered (matched / not matched)_
- NIM-ENG-066: _to be entered (matched / not matched)_

Query D results are candidates only and do not count as matches of the final rule.

Until this form is completed from a real run, rule 100310 must not be deployed as a live alert. A rule that fires on normal operations gets turned off.
