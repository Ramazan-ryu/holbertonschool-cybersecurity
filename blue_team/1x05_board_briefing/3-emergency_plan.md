# 3. The 72-Hour Emergency Response Plan

---

## Tier 1 — Tonight (0–12 Hours)

---

### Action: Disconnect Backup NAS from Network
- Phase Blocked: Phase 5 (Backup Destruction)
- Owner: Sarah / IT Staff
- Prerequisites: Physical access to NAS-01
- Risk of Action: Temporary disruption of backup availability
- Risk of Inaction: Permanent loss of backups via ransomware or deletion

---

### Action: Disable External VPN Access (Temporary Shutdown)
- Phase Blocked: Phase 1 (Initial Access)
- Owner: James
- Prerequisites: Board notification (informal)
- Risk of Action: Remote staff cannot access systems
- Risk of Inaction: Active exploitation via CVE-2023-27997 continues

---

### Action: Isolate Critical Servers (DB-01, DC-01)
- Phase Blocked: Phase 3 (Lateral Movement)
- Owner: IT Staff
- Prerequisites: Network switch access
- Risk of Action: Service disruption for clinical systems
- Risk of Inaction: Domain-wide compromise

---

### Action: Collect and Preserve Logs from FortiGate
- Phase Blocked: Phase 2 (Reconnaissance visibility loss)
- Owner: You
- Prerequisites: Admin access to FW-EDGE-01
- Risk of Action: No operational risk
- Risk of Inaction: Loss of forensic evidence

---

## Tier 2 — Tomorrow (12–36 Hours)

---

### Action: Emergency Patch FortiGate (CVE-2023-27997)
- Phase Blocked: Phase 1
- Owner: External Vendor / Fortinet Support
- Prerequisites: $2,400 emergency support renewal
- Risk of Action: Temporary VPN instability
- Risk of Inaction: Full perimeter compromise

---

### Action: Enable MFA on VPN Accounts
- Phase Blocked: Phase 2 / Phase 3
- Owner: IT Security Team
- Prerequisites: Identity provider configuration
- Risk of Action: User login disruption
- Risk of Inaction: Credential replay attacks succeed

---

### Action: Implement Emergency Network Segmentation (Partial VLAN Isolation)
- Phase Blocked: Phase 3
- Owner: Network Engineer
- Prerequisites: Switch configuration access
- Risk of Action: Misrouting internal traffic
- Risk of Inaction: Full lateral movement across network

---

### Action: Disable RC4 in Kerberos
- Phase Blocked: Phase 3 (Credential attacks)
- Owner: Active Directory Admin
- Prerequisites: Testing window approval
- Risk of Action: Legacy system authentication failure
- Risk of Inaction: Kerberoasting attacks succeed

---

## Tier 3 — This Week (36–72 Hours)

---

### Action: Encrypt Patient Database (DB-01)
- Phase Blocked: Phase 4 (Data Exfiltration value reduction)
- Owner: Database Administrator
- Prerequisites: Key management system
- Risk of Action: Performance overhead
- Risk of Inaction: Full data theft exposure

---

### Action: Deploy EDR on All Systems
- Phase Blocked: Phase 6 (Ransomware execution detection)
- Owner: Security Team
- Prerequisites: Licensing approval
- Risk of Action: Endpoint performance degradation
- Risk of Inaction: Undetected ransomware deployment

---

### Action: Establish SIEM Monitoring
- Phase Blocked: Phase 2–6 detection gaps
- Owner: Security Operations Team
- Prerequisites: Log ingestion setup
- Risk of Action: Initial alert fatigue
- Risk of Inaction: No detection of intrusion activity

---

### Action: Offline Backup Strategy Implementation
- Phase Blocked: Phase 5
- Owner: IT Infrastructure Team
- Prerequisites: Storage procurement
- Risk of Action: Increased backup restore time
- Risk of Inaction: Total backup destruction risk

---

## Resource Conflict Assessment

### Conflict 1: IT Staff Overload
- Sarah and 2 IT staff are required for:
  - NAS isolation
  - server isolation
  - VLAN changes

**Resolution:** Prioritize backup isolation first, then server segmentation.

---

### Conflict 2: Network vs AD Changes
- VLAN segmentation and Kerberos changes both require downtime windows

**Resolution:**  
- VLAN segmentation performed first (physical containment priority)
- AD changes scheduled immediately after stabilization

---

### Conflict 3: Vendor Dependency
- FortiGate patch depends on paid support renewal

**Resolution:**  
- Approve emergency budget immediately
- Parallelize renewal + patch download process

---

## Final Summary

The 72-hour response prioritizes containment over optimization. The goal is not full remediation but to:

- Stop active exploitation (Phase 1–2)
- Prevent lateral movement (Phase 3)
- Protect data and backups (Phase 4–5)

Without Tier 1 execution, MedDefense will likely suffer full ransomware compromise within days.
