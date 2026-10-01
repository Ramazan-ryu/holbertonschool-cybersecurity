# 12x07 Checkmate — Engagement Plan

## Scope and objective

I will assess the estate from the supplied foothold on CORVID-WEB01 and progress toward the deepest objective the network permits: durable domain dominance of `corvid.local`. The assessment will remain inside the two lab systems and the routes exposed by them. I will record commands, credentials, timestamps, network paths, detections, and every change made so the environment can be restored cleanly.

## Planned phases and order

**Phase 1 — Establish and preserve the foothold (2 hours).** I will confirm the host identity, interfaces, routes, users, sudo rights, running services, scheduled tasks, application files, backups, and locally stored secrets. I will avoid broad destructive testing and first identify a controlled privilege-escalation path. I will capture the original state before changing anything.

**Phase 2 — Own WEB01 and cross the boundary (4 hours).** After gaining root on the DMZ host, I will validate the privilege level, collect only the credentials and configuration required for the assessment, and remove temporary escalation artifacts before pivoting. I will confirm that the attack workstation cannot reach the internal segment directly, then build a hand-operated SSH SOCKS tunnel or equivalent transport through WEB01. I will test the route against the internal DC and document the exact listener, tunnel, interface, and destination details.

**Phase 3 — Enumerate the internal estate (6 hours).** From the pivot, I will identify the domain controller, DNS and authentication services, SMB shares, WinRM/PowerShell remoting, domain users and groups, delegated rights, service accounts, sessions, and exposed application roles. I will prioritize identity relationships and authorization paths over indiscriminate scanning. Each candidate path will be ranked by required privilege, reliability, noise, and reversibility.

**Phase 4 — Obtain domain administrative control (10 hours).** I will execute the strongest defensible route first, likely a delegated service or remoting path that can be converted into SYSTEM or domain-administrator-equivalent access. I will separately test at least one independent route, such as credential material from a privileged session or an authorization weakness on the domain root. I will stop a line after 90 minutes without a new privilege, credential, or confirmed relationship unless it provides unique evidence.

**Phase 5 — Prove durable dominance (12 hours).** The deepest objective is control that survives password resets: acquiring the `krbtgt` secret through DCSync, forging a valid ticket for an existing administrative identity, and using that ticket to authenticate and retrieve the protected dominance proof. I will verify access after removing temporary group membership, resetting changed passwords, and removing temporary ACLs. A successful post-cleanup authentication demonstrates that the domain can be re-entered without the original account credentials.

**Phase 6 — Cleanup and reporting (6 hours).** I will restore service paths, group membership, passwords, ACLs, SUID bits, payloads, tunnels, and temporary files. I will re-test the original state where possible and produce a route diagram, command timeline, noise assessment, alternative paths, limitations, and the three flag values.

## Noise posture

The lab permits monitoring, so I will accept visible authentication, SMB, WinRM, service-control, and directory-replication events when necessary to prove impact. I will prefer targeted enumeration and one controlled execution over repeated spraying or broad scans. A quieter route is worth extra time when it reaches the same objective with fewer logons, service changes, or credential accesses; otherwise I will use the reliable route and document its indicators.

## Success criterion

Success is not merely being an administrator today. It is demonstrating repeatable administrative access after the client’s response, with the original foothold credentials and temporary changes no longer sufficient or necessary, while leaving no persistence behind.
