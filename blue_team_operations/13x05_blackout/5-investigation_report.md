# Investigation Report

## Executive finding

Halcyon experienced an active ransomware campaign on 2026-09-20. The confirmed ransomware SHA-256 is `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`. Fifty-three hosts created the ransom note and are treated as encrypted. Nineteen hosts were staged but had not yet created the ransom note at the containment threshold; those hosts were the savable set, with the six payments hosts prioritized.

## Kill chain

Patient zero is mailbox message `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>` with a macro-enabled purchase-order attachment. HALC-WS-050 then contacted the external-looking document portal as `obsidn64_ldr.exe` and read LSASS at 2026-08-20T23:00:00Z. Memory contains the C2 scripts and loader `updt_loader01.exe`, SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063`.

The campaign used compromised administrative access from HALC-ADM-04. The SIEM shows the ransomware file creation, scheduled-task persistence, and ransom-note creation. Domain evidence shows replication rights used from the non-DC source HALC-ADM-04 and long-lived service tickets, establishing domain-level control.

## Containment and eradication position

Contain the 19 staged hosts and the 53 encrypted hosts with payments-first handling and preserve evidence. Do not over-contain the 244 clean hosts. Eradication requires domain recovery, credential rotation, removal/rebuild of persistence, validation of both domain controllers, and a controlled krbtgt double reset.
