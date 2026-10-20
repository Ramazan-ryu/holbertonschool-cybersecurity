# Blackout Flag-Finding Notes

## FLAG 1 — `1-flag.txt`

Find the ransomware confirmation:

```bash
grep -F 'obsidn64.exe' /index/campaign-2026-09-20.jsonl | head -5
```

Ransomware SHA256:

`e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`

The confirming event is Sysmon EID 11 on `HALC-ADM-04` at `2026-09-20T09:01:34.616Z`.

Check the ransom note:

```bash
grep -F 'RESTORE_YOUR_FILES.txt' /index/campaign-2026-09-20.jsonl | head
```

Put the following in `1-flag.txt`:

```text
FLAG_DETECT=e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957

Evidence:
Sysmon EID 11 on HALC-ADM-04 created
C:\\ProgramData\\HalcyonUpdate\\obsidn64.exe
with SHA256=e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957.

Detection timestamp:
2026-09-20T09:01:34.616Z

Additional confirmation:
RESTORE_YOUR_FILES.txt was created on HALC-PAY-10 at
2026-09-20T09:04:20.051Z.

Source:
Kestrel SIEM, campaign-2026-09-20.jsonl, Sysmon EID 11.
```

## FLAG 2 — `2-flag.txt`

Count encrypted hosts:

```bash
grep -F 'RESTORE_YOUR_FILES.txt' /index/campaign-2026-09-20.jsonl |
sed -n 's/.*"agent":{"id":"[^"]*","name":"\([^"]*\)".*/\1/p' |
sort -u |
wc -l
```

Expected encrypted count: `53`.

Find staged/savable hosts:

```bash
grep -F '"eventID":"4624"' /index/campaign-2026-09-20.jsonl |
grep -F '10.20.31.25'
```

Exact savable set, with payments hosts first:

```text
HALC-PAY-01
HALC-PAY-03
HALC-PAY-04
HALC-PAY-06
HALC-PAY-08
HALC-PAY-10
HALC-ADM-04
HALC-WS-050
HALC-WS-077
HALC-WS-100
HALC-WS-109
HALC-WS-135
HALC-WS-145
HALC-WS-146
HALC-WS-192
HALC-WS-213
HALC-WS-243
HALC-WS-264
HALC-WS-271
```

Savable count: `19`. Clean count: `316 - 53 - 19 = 244`.

The savable hosts had successful Kerberos network logons from `10.20.31.25`, associated with `HALC-ADM-04`, but had no ransom-note creation at the containment decision point. Last staged-host evidence: `2026-09-20T10:49:49.650Z`. Good-enough-to-act timestamp: `2026-09-20T10:50:00Z`. Sources: Kestrel SIEM EID 4624, EID 1, EID 11, and EID 7045.

## FLAG 3 — `3-flag.txt`

Find the patient-zero Message-ID:

```bash
grep -i -E 'Message-ID|Subject|Date|From|To' /mailbox/PZ-0001.eml
```

Message-ID:

`<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>`

Extract the attachment:

```bash
mkdir -p /tmp/pz
python3 /opt/halcyon-mail/console/extract_attachments.py \
  /mailbox/PZ-0001.eml \
  --out /tmp/pz
```

Examine the memory image:

```bash
/opt/volatility3/venv/bin/vol -q -f /evidence/memory.raw windows.pslist
/opt/volatility3/venv/bin/vol -q -f /evidence/memory.raw windows.cmdline
```

Look for `c2client.ps1`, `c2listener.ps1`, `updt_loader01.exe`, and `obsidn64_ldr.exe`.

Dropper hash:

`cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063`

The entry point is mailbox message `PZ-0001.eml` with the macro-enabled attachment `Order_Confirmation_Revised_PO-48490.docm`.

Linkage: the patient-zero email delivered the initial document. The memory image contains `c2client.ps1`, `c2listener.ps1`, and `updt_loader01.exe`. SIEM telemetry then shows `HALC-WS-050` using `obsidn64_ldr.exe` and reading LSASS in Sysmon EID 10 at `2026-08-20T23:00:00Z`. The same intrusion later deployed the ransomware hash recorded in FLAG_DETECT.

Sources: `PZ-0001.eml`, `/evidence/memory.raw`, Volatility 3, and SIEM Sysmon EID 3, EID 10, EID 11, and EID 1.
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

In your evidence, Sysmon EID 1 recorded:

- Executable: obsidn64_ldr.exe
- Parent: Microsoft Word
- Document: Order_Confirmation_Revised_PO-48490.docm
- Field: hashes
- Hash value: the text after SHA256=

You found it with:

grep -F '"eventID":"1"' /index/campaign-2026-08-13.jsonl |
grep -F 'obsidn64_ldr.exe'

The relevant part is:

"hashes":"SHA256=d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2"

Therefore, the loader/dropper hash from this event is:

d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2

Why this is the dropper:

Word document → obsidn64_ldr.exe → C2 activity → LSASS access → later ransomware
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
## FLAG 4 — `4-flag.txt`

Find DCSync:

```bash
grep -F '"eventID":"4662"' /index/domain-2026-09-11.jsonl |
grep -E '1131f6aa|1131f6ad|10.20.31.25'
```

Decisive event:

```text
Time: 2026-09-11T23:20:00.246Z
Event: EID 4662
Host: HALC-DC-02
Account: adm.okonkw01
Source IP: 10.20.31.25
Source host: HALC-ADM-04
Object: DC=halcyon,DC=local
```

Replication GUIDs:

```text
1131f6aa-9c07-11d1-f79f-00c04fc2dcd2
1131f6ad-9c07-11d1-f79f-00c04fc2dcd2
```

Check forged tickets:

```bash
grep -F '"eventID":"4769"' /index/domain-2026-09-20.jsonl |
grep -E 'svc-vestg_1|10.20.31.25|240'
```

Look for `svc-vestg_1@HALCYON.LOCAL` and `ticketLifetimeHours: 240`.

Conclusion: the actor achieved domain-level dominance through replication access. Containment is to isolate affected hosts and stop active encryption. Host cleanup and ordinary user-password resets are insufficient for eradication. Eviction requires credential rotation, rebuilding affected systems, validation of both domain controllers, and a controlled `krbtgt` double reset with ticket-expiry validation.

Source: Kestrel SIEM, EID 4662 and EID 4769.

## Final validation

```bash
ls -l 1-flag.txt 2-flag.txt 3-flag.txt 4-flag.txt
for f in 1-flag.txt 2-flag.txt 3-flag.txt 4-flag.txt; do
  printf '%s: ' "$f"
  tail -c 1 "$f" | od -An -t x1
done
```

The final byte of every file must be `0a`, the newline character.

## Student Hints — No Direct Answers

### Task 1: Detect and Confirm

Start with the campaign data from the final incident date and look for a suspicious executable being created by Sysmon file-creation events. Confirm that the same activity is followed by a ransom-note filename; one artifact alone may be a distractor. Record the earliest decisive timestamp and the evidence source.

### Task 2: Scope the Incident

Build host populations from evidence, rather than treating every related event as encryption. Separate hosts with the ransom note from hosts that show access or staging but no detonation, then calculate the remaining clean population from the stated estate size. Preserve the payments-tier hosts at the front of the savable priority list and record what was still unknown when you acted.

### Task 3: Prove Root Cause

The mailbox identifies the entry point, while the memory image identifies what ran on the pivot host. Do not stop at finding a suspicious email and a suspicious binary: connect them through the execution chain and matching SIEM activity. Your conclusion should contain one mail identifier and one forensic hash, supported by timestamps and artifacts.

### Task 4: Understand Domain Dominance

Search directory-service events for replication-rights identifiers and check whether the source is a normal domain controller or another host. Then correlate the same source with unusually long-lived Kerberos service tickets. Explain why isolating hosts and resetting ordinary user passwords does not evict an actor with domain-level credential material.
