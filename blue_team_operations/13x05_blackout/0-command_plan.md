# Command Plan

## Order of work and why

Hosts are encrypting now, so the order is set by one principle: every action must either reduce ongoing encryption or tell me which hosts it applies to. Nothing else goes first.

1. **Confirm the active event (minutes).** I will run one narrow query in the Kestrel Console over the final campaign window for the ransomware hash, ransom-note creation, and the encryption process. I need this to establish that the Sunday activity is real encryption and not a false alarm, and I need the first decisive timestamp.
2. **Scope the encrypted set and the staged set (minutes).** Hosts with the ransomware hash and `RESTORE_YOUR_FILES.txt` are already encrypted. Hosts showing the actor's successful remote logon, staging, persistence, or service installation without a ransom note are savable if isolated. Everything else is treated as clean until a decisive event says otherwise.
3. **Contain (immediately after scoping).** I isolate the already-encrypting population to stop spread, and the staged set to stop detonation. Payments hosts go first among the staged set because they carry the highest business cost.
4. **Preserve evidence (during and after containment).** Before any reimaging or rebooting, I capture memory and disk snapshots of isolated hosts, keep the ransomware sample unexecuted, and log the isolation timestamps. Containment comes before preservation whenever the two conflict, because a snapshot of a host that is still encrypting protects no one.
5. **Investigate root cause and domain exposure (after containment).** I inspect the mailbox for patient zero, extract the attachment without running it, and use Volatility 3 on the memory image for the dropper. I then test the domain-level hypothesis using 4662 replication events, forged-ticket use, and the non-DC source.
6. **Recover and communicate (ongoing).** Recovery is coordinated with the incident lead and business owners. Restoration is not started on any host until the investigation confirms the actor no longer has access.

## The rule for acting under uncertainty

I will not wait for a perfect kill chain. I will choose containment once all three conditions hold:

- The ransomware hash is confirmed in active process creation.
- The encrypted set has stopped growing across two consecutive queries.
- Every remaining suspicious host has been classified as staged or clean, with the evidence recorded.

Confidence, blast radius, and reversibility decide how far containment reaches. Isolating a host is reversible and cheap, so a single strong indicator on a host justifies isolating that host. Shutting down a shared service or the domain controllers is irreversible in effect and costly, so it requires confirmed propagation through that service, not a suspicion. Unknowns go into the decision log; they do not hold up action.

## The decision point

The expected threshold is after I correlate the 4624 remote logons from `HALC-ADM-04` with the staging, persistence, and ransom-note events. In this instance that is 2026-09-20T10:50:00Z, immediately after the last staged-host logon at 10:49:49.650Z.

At that moment, further analysis competes directly with preventing detonation. I will contain first, preserve the snapshot, and continue root-cause work afterward. The consequence is accepted in advance: isolating the staged hosts may alter live memory or network state that could have revealed more about the actor's tooling, and some of that visibility will be lost.

## Eradication

Containment and eradication are recorded separately. Password resets and host cleaning do not evict an actor who has obtained domain dominance. The remediation position must therefore include a controlled, double reset of `krbtgt`, scheduled only after the domain-level investigation confirms the scope of forged-ticket use.
