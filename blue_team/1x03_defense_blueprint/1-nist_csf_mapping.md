# MedDefense NIST CSF 2.0 Current Profile

This profile assesses MedDefense's current security maturity against the six NIST CSF 2.0 core functions. Ratings use a 4-level scale: Not Implemented, Partial, Managed, Optimized.

---

## 1. Govern
**Current Level:** Partial  
**Evidence:** Security policies are informal; no dedicated security strategy exists. Project 1x00 showed inconsistent risk management practices.  
**Key Gaps:** No formal security governance or regular board reporting.  
**Target Level:** Managed in 6 months; implement formal security strategy, document responsibilities, and schedule regular board updates.

---

## 2. Identify
**Current Level:** Managed  
**Evidence:** Asset inventory from Project 1x00 covers most critical systems and data.  
**Key Gaps:** Some assets outside the main inventory; incomplete mapping of third-party services.  
**Target Level:** Optimized; maintain continuous asset discovery and classification, including third-party systems.

---

## 3. Protect
**Current Level:** Partial  
**Evidence:** Vulnerability scan from Project 1x02 revealed some outdated patches, weak password policies, and limited endpoint controls.  
**Key Gaps:** Lack of full coverage for critical systems and automated enforcement of protective measures.  
**Target Level:** Managed; deploy automated patch management, enforce strong authentication, and implement full endpoint controls.

---

## 4. Detect
**Current Level:** Not Implemented  
**Evidence:** Marcus's notes indicate zero monitoring capability—no IDS/IPS or SIEM deployment.  
**Key Gaps:** Cannot detect or correlate incidents; blind to ongoing threats.  
**Target Level:** Managed; deploy basic logging, monitoring, and alerting across all critical systems.

---

## 5. Respond
**Current Level:** Not Implemented  
**Evidence:** No formal incident response plan; ad-hoc response during Project 1x01 exercises.  
**Key Gaps:** Staff untrained, no documented playbooks, no communication plan.  
**Target Level:** Managed; create and test incident response plan with roles, communication, and playbooks.

---

## 6. Recover
**Current Level:** Partial  
**Evidence:** Backup procedures exist but are inconsistent; no disaster recovery tests conducted.  
**Key Gaps:** Recovery is manual, untested, and slow for critical systems.  
**Target Level:** Managed; implement regular backup validation, test disaster recovery plans, and define recovery time objectives.

---

**Summary:**  
MedDefense shows **strongest maturity in Identify**, but **Detect and Respond are critical gaps**. Over the next 6 months, the focus should be on implementing monitoring, response planning, and improving protective measures to move most functions to **Managed** or **Optimized** levels.
