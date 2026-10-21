# 0. The Advisory Analysis

## Phase 1: Initial Access (Day 0)
Advisory Description: Exploitation of CVE-2023-27997 on FortiGate SSL-VPN to gain remote code execution and full control of the perimeter device.

MedDefense Mapping:
  Target System: FW-EDGE-01 (FortiGate VPN gateway)
  Vulnerability Reference: OSINT-1x04-FORTI-01 (unpatched FortiOS 7.2.x)
  Gap Reference: GAP-1x00-PATCH-MANAGEMENT
  Crypto Weakness: None
  Current Protection: Internet-facing firewall only, no WAF or redundancy
  Verdict: EXPOSED

---

## Phase 2: Internal Reconnaissance (Day 0-1)
Advisory Description: Attacker extracts VPN credentials and maps internal network using FortiGate access.

MedDefense Mapping:
  Target System: FW-EDGE-01 / AD authentication logs
  Vulnerability Reference: FIND-1x02-AD-02 (weak credential hygiene)
  Gap Reference: GAP-1x00-MONITORING
  Crypto Weakness: RC4 Kerberos fallback enabled
  Current Protection: Basic firewall logs only
  Verdict: EXPOSED

---

## Phase 3: Lateral Movement (Day 1-3)
Advisory Description: Attacker moves across flat network using RDP/SSH and stolen admin credentials.

MedDefense Mapping:
  Target System: DC-01, FS-01, DB-01, LAN-WKS
  Vulnerability Reference: FIND-1x02-LATERAL-01
  Gap Reference: GAP-1x03-NETWORK-SEGMENTATION (not implemented)
  Crypto Weakness: RC4 Kerberos + cached credentials exposure
  Current Protection: Single domain authentication system
  Verdict: EXPOSED

---

## Phase 4: Data Exfiltration (Day 3-5)
Advisory Description: Sensitive patient and financial data exfiltrated before encryption using cloud tools.

MedDefense Mapping:
  Target System: DB-01 (Patient database server)
  Vulnerability Reference: FIND-1x02-DATABASE-01
  Gap Reference: GAP-1x04-DATABASE-ENCRYPTION
  Crypto Weakness: No encryption at rest for patient database
  Current Protection: OS-level access control only
  Verdict: EXPOSED

---

## Phase 5: Backup Destruction (Day 5-6)
Advisory Description: Attackers delete shadow copies and destroy backups on same network.

MedDefense Mapping:
  Target System: NAS-01
  Vulnerability Reference: FIND-1x02-BACKUP-01
  Gap Reference: GAP-1x04-BACKUP-ISOLATION
  Crypto Weakness: Backups unencrypted
  Current Protection: Shared LAN access
  Verdict: EXPOSED

---

## Phase 6: Ransomware Deployment (Day 6-7)
Advisory Description: Domain-wide ransomware deployment via GPO from compromised DC.

MedDefense Mapping:
  Target System: DC-01
  Vulnerability Reference: FIND-1x02-DOMAIN-01
  Gap Reference: GAP-1x03-PRIVILEGE-ESCALATION
  Crypto Weakness: None directly
  Current Protection: Domain Admin GPO control exists
  Verdict: EXPOSED

---

## Phase 7: Extortion (Day 7+)
Advisory Description: Double extortion using encryption + threat of data publication.

MedDefense Mapping:
  Target System: CEO/CFO email + leaked DB-01 data
  Vulnerability Reference: FIND-1x02-DATA-EXFIL-01
  Gap Reference: GAP-1x04-DATA-PROTECTION
  Crypto Weakness: No encryption of sensitive data
  Current Protection: Email security only
  Verdict: EXPOSED

---

## Overall Exposure Score: 7/7 EXPOSED

## Critical Finding:
MedDefense is fully exposed across all ransomware lifecycle phases due to lack of network segmentation, unpatched perimeter systems, and absence of encryption for both backups and patient databases.
