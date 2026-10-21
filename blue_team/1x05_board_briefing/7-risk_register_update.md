# 7. The Risk Register Update

---

## Part 1 - Updated Ransomware Risk Entry

### Risk ID: RISK-001 (UPDATED)

- Threat Source: Crimson Tide (CT) ransomware group
- Asset: MedDefense enterprise infrastructure
- Vulnerability Context: FortiGate VPN exposure + flat network + weak AD security
- Likelihood (ARO): 1.2 (updated from 0.25 due to active regional exploitation)
- Impact (SLE): $1,200,000
- Updated ALE: $1,440,000 annually

### Treatment Decision:
Mitigate

Justification:
The threat has transitioned from theoretical ransomware risk to an active, regionally confirmed attack campaign. Existing controls are insufficient due to lack of segmentation, missing encryption, and unpatched perimeter systems.

---

### New Key Risk Indicators (KRI):
- Suspicious FortiGate SSL-VPN authentication spikes
- Unexpected GPO creation or modification events
- Large outbound data transfers (>5GB) to external cloud services (e.g., MEGA, rclone patterns)
- vssadmin shadow copy deletion activity
- Rclone binary presence on endpoints

---

## Part 2 - New Entry: FortiGate Vulnerability Risk

### Risk ID: RISK-NEW-001

- Asset: FW-EDGE-01 (FortiGate SSL-VPN gateway)
- Threat: CVE-2023-27997 pre-auth RCE exploitation
- Vulnerability: Heap-based buffer overflow in SSL-VPN portal
- Impact: Full perimeter compromise → domain-level access
- Likelihood: Very High (active exploitation confirmed)
- SLE: $1,200,000
- ARO: 1.2
- ALE: $1,440,000 annually

### Treatment Decision:
Mitigate immediately

### Required Control:
FortiGate support contract renewal + security patch deployment

- Cost: $2,400

### Cost-Benefit Analysis:
- Control Cost: $2,400
- Expected Loss Avoided: $1,440,000

ROI: Extremely positive → immediate approval justified

---

## Part 3 - Risk Register Governance Test

### Trigger Criteria (from 1x03 Risk Governance Model):
- Emergence of active exploitation of a known vulnerability
- Material increase in likelihood (ARO change)
- Confirmation of threat actor activity targeting similar organizations in same region

---

### Assessment:
YES — this qualifies as an out-of-cycle review trigger.

---

### Explanation:
The Crimson Tide advisory confirms active exploitation of CVE-2023-27997 across multiple regional hospitals. This represents a material shift in threat likelihood and requires immediate risk register update, emergency mitigation, and Board-level escalation.

---

## Final Statement:
The risk register is no longer a static document. It is a live operational instrument that must respond in real time to threat intelligence.
