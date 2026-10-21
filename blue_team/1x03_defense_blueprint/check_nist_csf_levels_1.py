#!/usr/bin/env python3
# check_nist_csf_levels.py
# Checks that all six NIST CSF functions have Current Level and Target Level defined

md_file = "1-nist_csf_mapping.md"

# Read the Markdown content
with open(md_file, "r") as f:
    content = f.read().lower()  # lowercase for case-insensitive matching

# List of NIST CSF functions
csf_functions = ["govern", "identify", "protect", "detect", "respond", "recover"]

# Levels to check
levels = ["current level", "target level"]

# Function to check presence of level for each CSF function
def check_levels(content, functions, levels):
    results = {}
    for func in functions:
        func_results = {}
        for level in levels:
            # Look for the function name + level in the content
            search_string = f"{func}.*{level}"
            func_results[level] = search_string in content
        results[func] = func_results
    return results

# Run the check
results = check_levels(content, csf_functions, levels)

# Print results
for func, func_results in results.items():
    current_ok = "TRUE" if func_results["current level"] else "FALSE"
    target_ok = "TRUE" if func_results["target level"] else "FALSE"
    print(f"{func.title():<10} | Current Level: {current_ok} | Target Level: {target_ok}")
