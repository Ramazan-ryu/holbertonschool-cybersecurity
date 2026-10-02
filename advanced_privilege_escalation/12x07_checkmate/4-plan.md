# Engagement Report Submission

The board-grade engagement report is provided in [4-report.md](4-report.md). It documents the route from the CORVID-WEB01 edge foothold to durable domain dominance, the business consequences, reproducible attack narrative, CVSS-rated findings, prioritized remediation, decision and noise logs, and the assessment limitations.

The report’s central conclusion is that Corvid must treat the domain as compromised: ordinary password resets are insufficient after `krbtgt` material has been recovered and a forged administrative ticket has been accepted. The recommended response begins with containment, removal of unauthorized domain-root replication rights, two-stage `krbtgt` rotation, privileged credential resets, and validation that temporary service and directory changes are gone.
