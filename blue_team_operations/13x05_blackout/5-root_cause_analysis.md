# Root Cause Analysis

The causal chain begins with the patient-zero email identified by Message-ID `<0025e2e3bbf6e32.harrowfield-metalworks.example@mail.harrowfield-metalworks.example>`. Its macro-enabled attachment delivered the initial loader. The pivot memory image contains the C2 client/listener scripts and the loader `updt_loader01.exe` with SHA-256 `cb4eee1bced77b05b896cae15cfcb5b3083c2f47b54d2b72f1628c9591713063`.

SIEM evidence connects the loader activity to HALC-WS-050, including repeated portal connections as `obsidn64_ldr.exe` and an LSASS read. The later campaign uses administrative access from HALC-ADM-04, creates the ransomware with SHA-256 `e7c189efd70aa01d5735246ae70908953e4e1797f88614bf5fd8311334663957`, establishes persistence, and creates ransom notes.

The causal gap is not only email filtering. Halcyon must block macro-enabled untrusted attachments and the document-portal path, enforce application control and constrained PowerShell, protect LSASS, restrict administrative logons, monitor replication rights, remove unauthorized service/ticket paths, and rotate all credentials exposed before domain recovery.
