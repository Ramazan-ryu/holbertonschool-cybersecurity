# 16x01 — The New Perimeter

Ashford Financial cloud privilege escalation and governance review. The analysis files document the observed calls, policy statements, responses, and limits of the verification. `evidence/audit-export.json` is the original signed activity bundle produced by `latchkey-export`; it has not been edited. `evidence/audit-export-replay.json` is the later signed bundle for the fresh prediction replay and remediation verification; it is also unedited.

The lab was accessed as `reporting-analyst` in account `418274630117`. A narrow remediation removed the `iam:PassRole` grant for `ashford-batch-exec` from `ReportingAnalystAccess`; it refused a repeat Lambda creation while S3 report listing continued to work. The managed policy test version on `AshfordCrossAcctReaderAccess` was restored to its original `v1` and the test `v2` deleted. After exporting the signed evidence bundle, I ran `sudo ashford-reset`; the lab reported that the account was restored to its handover state and trail activity cleared. The exported bundle is the signed pre-reset record.

See `0-evaluation.md` through `9-refusal.md` and `6-remediation/README.md`. The supplied task descriptions in this engagement covered tasks 0–9.
