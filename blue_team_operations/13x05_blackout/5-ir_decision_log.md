# IR Decision Log

| UTC timestamp | Decision | Evidence held | Unknown at decision time |
|---|---|---|---|
| 2026-09-20T09:01:34.616Z | Confirmed active ransomware | EID 11 created `obsidn64.exe` with the confirmed SHA-256 on HALC-ADM-04 | Full host scope and domain depth were not yet known |
| 2026-09-20T09:04:20.051Z | Began separating encrypted from staged | First ransom-note creation on HALC-PAY-10 | Whether all staged hosts had been found |
| 2026-09-20T10:50:00Z | Containment threshold reached; contain staged set | 53 note hosts; exact 19-host staged set; last staged logon 10:49:49.650Z; payments hosts prioritized | Historical root cause and domain-dominance proof still incomplete |
| 2026-09-20T11:00:00Z | Treat incident as contained, not eradicated | Ransomware execution stopped by isolation position | Persistence, forged tickets, and credential exposure required further investigation |
| 2026-09-20T11:30:00Z | Set eradication requirement | EID 4662 replication from HALC-ADM-04 and long-lived 4769 tickets | Exact recovery duration and business cost |

No production action was executed by this analyst; these are documented containment, eradication, and recovery positions for the frozen lab.
