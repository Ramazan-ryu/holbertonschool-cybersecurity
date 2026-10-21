#!/usr/bin/env python3
# check_cis_controls.py
# Checks CIS Controls audit Markdown for completeness

md_file = "2-cis_controls_audit.md"

# Read the file
with open(md_file, "r") as f:
    content = f.read().lower()  # lowercase for case-insensitive matching

# CIS Controls names (1–18)
cis_controls = [
    "inventory and control of enterprise assets",
    "inventory and control of software assets",
    "data protection",
    "secure configuration of enterprise assets and software",
    "account management",
    "access control management",
    "continuous vulnerability management",
    "audit log management",
    "email and web browser protections",
    "malware defenses",
    "data recovery",
    "network infrastructure management",
    "security awareness and skills training",
    "service provider management",
    "application software security",
    "incident response management",
    "penetration testing",
    "security management controls"
]

# Valid score values
valid_scores = ["implemented", "partial", "not implemented"]

# Function to check each control
def check_controls(content, controls, valid_scores):
    scored_count = 0
    evidence_count = 0
    missing_controls = []

    for ctrl in controls:
        # Check if control is mentioned
        if ctrl in content:
            # Check if a score exists near the control name
            found_score = any(f"{ctrl}.*{score}" in content for score in valid_scores)
            if found_score:
                scored_count += 1
            else:
                missing_controls.append(ctrl)

            # Check if evidence is provided
            if "evidence" in content[content.find(ctrl):content.find(ctrl)+500]:
                evidence_count += 1
        else:
            missing_controls.append(ctrl)

    return scored_count, evidence_count, missing_controls

# Check top 5 priority controls presence
def check_top5(content):
    return "top 5 priority controls" in content

# Run checks
scored, evidence, missing = check_controls(content, cis_controls, valid_scores)
top5_present = check_top5(content)

# Print results
print(f"CIS Controls Scored: {scored}/18")
print(f"Evidence Present: {evidence}/18")
print(f"Top 5 Priority Controls Listed: {'TRUE' if top5_present else 'FALSE'}")
if missing:
    print("Controls missing score/evidence or not found:")
    for ctrl in missing:
        print(f" - {ctrl.title()}")

# Summary result
all_ok = scored == 18 and evidence >= 16 and top5_present
print(f"\nOverall CIS Controls Audit Complete: {'TRUE' if all_ok else 'FALSE'}")
