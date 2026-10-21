# 5. The ALE Update — Crimson Tide Intelligence Impact

---

## Part 1 - Original vs Updated ALE

---

### Original ALE (from 1x03 T6)

- Estimated ARO (Annual Rate of Occurrence): 0.25  
  (1 ransomware event every ~4 years based on sector averages)

- Estimated SLE (Single Loss Expectancy): $1,200,000  
  (based on downtime, recovery, legal exposure, and data loss)

- Original ALE Calculation:
  ALE = SLE × ARO  
  ALE = 1,200,000 × 0.25 = **$300,000 per year**

---

### Updated Threat Intelligence (Crimson Tide)

New intelligence:
- 5 confirmed attacks in 10 days on similar hospitals
- 3 in same geographic region
- Active exploitation campaign (not theoretical risk)

---

### Updated ARO Calculation

5 attacks / 10 days → extrapolated:

- ~0.5 attacks per day (campaign intensity)
- ~182 attacks per year (theoretical upper bound)
- Adjusted conservative operational ARO for MedDefense exposure:

👉 **ARO = 1.2 (high likelihood per year)**  
(Meaning: at least 1 full compromise expected annually under current exposure)

---

### Updated ALE Calculation

- SLE remains: $1,200,000

ALE = 1,200,000 × 1.2  
👉 **Updated ALE = $1,440,000 per year**

---

### Comparison Summary

| Metric | Original | Updated |
|--------|----------|---------|
| ARO | 0.25 | 1.2 |
| ALE | $300,000 | $1,440,000 |

---

### What Changed and Why

- Threat shifted from probabilistic risk to **active campaign**
- Regional targeting confirmed (not generic healthcare risk)
- Exploitation window is currently active (0-day operational relevance)
- MedDefense matches victim profile exactly

---

## Part 2 - Budget Impact

---

### Are previously “Not Justified” controls now justified?

YES.

Controls now justified due to updated ALE:

- Network Segmentation (previously deferred)
- Database Encryption at Rest
- SIEM / 24/7 Monitoring
- Backup Isolation (offline/immutable)
- MFA enforcement across VPN and AD

These controls now have clear ROI because expected annual loss exceeds implementation costs.

---

### FortiGate Emergency Support ($2,400) ROI

- Cost: $2,400
- Risk prevented: Perimeter compromise leading to $1.4M annual expected loss

👉 ROI is EXTREMELY positive

Conclusion:
Emergency renewal is **mandatory and immediately justified**

---

### Should the Board approve emergency spending beyond $120,000?

YES.

Justification:
- Updated ALE: $1,440,000/year
- Even partial mitigation reduces expected loss by 60–80%
- Preventing a single incident offsets entire annual security budget

---

## Final Conclusion

The Crimson Tide intelligence completely invalidates prior risk assumptions. MedDefense is no longer in a low-probability risk state — it is in an **active high-frequency threat environment**.

Security investment is no longer optional; it is cost avoidance.
