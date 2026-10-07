12x07 Checkmate — Engagement Plan
Scope and objective

I will assess the estate from the supplied foothold on CORVID-WEB01 and progress toward durable domain dominance of corvid.local. I will record all commands, credentials, timestamps, network paths, and changes to permit clean restoration.

Planned phases and time allocation

Phase 1 — Establish foothold (2 hours). Enumerate the host identity, interfaces, routes, users, sudo rights, services, scheduled tasks, local secrets, and capture original state. Two hours is sufficient for single-host enumeration; if I exceed this, I have either found an unplanned escalation path (continue) or become stuck (move to Phase 2 with available data).

Phase 2 — Escalate and pivot (4 hours). Gain root on WEB01, remove escalation artifacts, build a SOCKS tunnel through it to the internal segment, and validate connectivity to the DC. Allocate 90 minutes per privilege-escalation route; if neither route yields root, pivot with available access. Tunnel validation is 30 minutes; if unreachable, boundary is intact and exploitation is limited.

Phase 3 — Enumerate internal estate (6 hours). Identify the domain controller, DNS, SMB, WinRM, domain users, groups, delegated rights, and service accounts. Prioritize identity relationships over broad scanning. Enumeration is bounded: DC discovery (30 min), users and groups (60 min), delegation (90 min), sessions (30 min), ranking (30 min). If repetitive after four hours, stop and rank existing candidates.

Phase 4 — Obtain domain admin control (10 hours). Execute the strongest defensible route first, likely a delegated service or remoting path. Apply the 90-minute rule per route: if no new privilege, credential, or confirmed authorization emerges, abandon and switch to the next candidate. Test at least two independent routes. Ten hours covers four complete 90-minute attempts plus overhead.

Phase 5 — Prove durable dominance (12 hours). The deepest objective: acquire the krbtgt secret via DCSync, forge a valid ticket for an existing admin, remove all temporary changes, re-authenticate using only the forged ticket and original foothold, and retrieve the protected flag. This demonstrates domain re-entry without new credentials or persistence.

Phase 6 — Cleanup and reporting (6 hours). Restore all modified state, re-test original conditions, and produce route diagram, command timeline, noise assessment, and flag values. Cleanup is methodical reversal (1 hour per change class), validation (1 hour), and reporting (1 hour).

Abandonment rule: 90-minute threshold

Any investigation without a new privilege, credential, or confirmed authorization path is abandoned after 90 minutes. A confirmed relationship means evidence of a trust, delegation, or authorization link; routine enumeration does not count. Abandoned time is reallocated to the next ranked candidate or documentation.

Noise posture and quiet-work cost

The lab permits monitoring; I accept visible authentication, SMB, WinRM, and replication events when necessary. Example trade-off: a quiet credential dump via LOLBin (30 min, low visibility) is worth choosing over a password spray (15 min, high visibility) only if the spray is unreliable or creates unacceptable noise. A quiet incremental delegation route (4 hours, moderate visibility) is justified only if the loud token-impersonation path (1 hour, high visibility) is unreliable. Decision criterion: does quiet work reach the same objective with fewer logon events, service control events, or replication triggers within acceptable phase time? If not, use the reliable visible route and document its indicators.

Success criterion and proof

Success is durable dominance proved by: (1) retrieval of krbtgt via DCSync; (2) creation of a valid ticket for an existing domain admin; (3) removal of all temporary changes (group membership, ACLs, passwords, artifacts); (4) re-authentication to the DC using only the forged ticket and original foothold; (5) retrieval of the protected flag. This demonstrates domain re-entry without new credentials or persistence.
