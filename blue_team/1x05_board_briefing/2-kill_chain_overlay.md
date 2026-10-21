# 2. The Kill Chain Overlay — Crimson Tide vs MedDefense

---

## Part 1 - Kill Chain Overlay Analysis

### Phase 1: Initial Access
**Crimson Tide Step:** Exploits CVE-2023-27997 on FortiGate SSL-VPN

**MedDefense Kill Chain Match:**
- Match: YES (Kill Chain #1 - External Perimeter Breach)
- Accuracy: High — predicted VPN exploitation as entry vector
- Missed Element: Severity underestimated (pre-auth RCE at scale, not credential phishing)

---

### Phase 2: Internal Reconnaissance
**Crimson Tide Step:** Extracts VPN credentials and maps internal network via FortiGate

**MedDefense Kill Chain Match:**
- Match: YES (Kill Chain #2 - Internal Enumeration)
- Accuracy: Partial — credential reuse predicted
- Missed Element: Firewall device itself used as credential harvesting platform

---

### Phase 3: Lateral Movement
**Crimson Tide Step:** Uses RDP/SSH + stolen privileged credentials to move across flat network

**MedDefense Kill Chain Match:**
- Match: YES (Kill Chain #3 - Lateral Movement Phase)
- Accuracy: High — lateral movement expected
- Missed Element: Scale of impact due to zero segmentation (entire domain exposed instantly)

---

### Phase 4: Data Exfiltration
**Crimson Tide Step:** Exfiltrates patient and financial data before encryption

**MedDefense Kill Chain Match:**
- Match: YES (Kill Chain #4 - Data Exfiltration)
- Accuracy: Partial — exfiltration predicted but not “pre-encryption bulk scraping”
- Missed Element: No authentication needed due to unencrypted DB files

---

### Phase 5: Backup Destruction
**Crimson Tide Step:** Deletes backups, shadow copies, and NAS data

**MedDefense Kill Chain Match:**
- Match: PARTIAL (Kill Chain #4 overlap)
- Accuracy: Low — backup targeting underestimated as a dedicated phase
- Missed Element: Backup destruction as a primary strategic phase

---

### Phase 6: Ransomware Deployment
**Crimson Tide Step:** GPO-based domain-wide ransomware execution

**MedDefense Kill Chain Match:**
- Match: YES (Kill Chain #5 - System-wide Encryption Phase)
- Accuracy: High — domain-level propagation correctly modeled
- Missed Element: Use of legitimate GPO infrastructure for deployment (living-off-the-land)

---

### Phase 7: Extortion
**Crimson Tide Step:** Double extortion (encryption + data leak threats)

**MedDefense Kill Chain Match:**
- Match: YES (Kill Chain #5 - Post-Compromise Impact)
- Accuracy: Partial — data leak extortion underestimated in severity
- Missed Element: Psychological pressure via CEO/CFO direct targeting

---

## Part 2 - Control Interception Map

| Phase | Planned Control (1x03) | Status | Would It Stop Phase? |
|------|------------------------|--------|----------------------|
| Phase 1 | FortiGate Patch Management Program | Not Deployed | YES |
| Phase 2 | SIEM Monitoring + AD Audit Logging | Not Deployed | PARTIALLY |
| Phase 3 | Network Segmentation (VLAN isolation) | Not Funded | YES |
| Phase 4 | Database Encryption at Rest | Not Funded | YES |
| Phase 5 | Backup Isolation + Offline Storage | Not Funded | YES |
| Phase 6 | Privileged Access Management (PAM) | Not Deployed | PARTIALLY |
| Phase 7 | Data Loss Prevention (DLP) + Incident Comms Plan | Not Deployed | PARTIALLY |

---

## Part 3 - Gap Between Plan and Reality

If MedDefense had fully implemented the 1x03 Security Strategy, it would have blocked approximately **4 to 5 out of 7 phases completely**, specifically:
- Initial Access (patching)
- Lateral Movement (segmentation)
- Data Exfiltration (encryption)
- Backup Destruction (isolation)

However, ransomware deployment and extortion would still partially succeed due to:
- Compromised credentials already being valid
- Lack of real-time behavioral detection maturity
- Human-factor exposure via executive targeting

### Conclusion:
Even with full implementation of the 1x03 strategy, MedDefense would remain partially exposed to advanced ransomware operations. This demonstrates that defense-in-depth reduces blast radius but does not eliminate systemic risk when identity and perimeter controls are compromised.

Residual risk remains due to:
- Credential compromise
- Identity trust exploitation
- Delayed detection capability
