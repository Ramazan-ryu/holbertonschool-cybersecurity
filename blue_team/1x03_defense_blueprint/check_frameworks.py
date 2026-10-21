#!/usr/bin/python3
# check_frameworks.py
# Fully combined Python checker script for 0-framework_landscape.md
# check_frameworks_local.py
# Simple Python script to check keyword presence in 0-framework_landscape.md

md_file = "0-framework_landscape.md"

# Read the file
with open(md_file, "r") as f:
    content = f.read().lower()  # convert to lowercase for case-insensitive search

# Define checks as keywords or phrases
checks = {
    "NIST CSF 2.0 described?": ["nist csf 2.0", "six core functions", "govern", "identify", "protect", "detect", "respond", "recover"],
    "CIS Controls v8 described?": ["cis controls v8", "implementation groups ig1", "ig2", "ig3"],
    "ISO 27001 described?": ["iso/iec 27001", "annex a", "clauses 4–10", "certification", "compliance"],
    "Relationship explained?": ["complementary, not competing", "what should we do", "how should we do it", "can we prove we are doing it"],
    "Recommendation with reasoning?": ["meddefense", "regional hospital", "1 security analyst", "1 deputy ciso", "nist csf", "cis controls", "iso 27001"]
}

# Run checks
for label, keywords in checks.items():
    result = all(keyword.lower() in content for keyword in keywords)
    print(f"{label} -> {'TRUE' if result else 'FALSE'}")
