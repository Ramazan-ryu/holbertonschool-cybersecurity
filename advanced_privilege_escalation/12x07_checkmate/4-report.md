# Corvid Group — 12x07 Checkmate Engagement Report

**Prepared for:** Corvid Group Board and Engineering Leadership  
**Engagement:** External edge foothold through domain dominance  
**Assessment window:** Forty-hour capstone engagement  
**Classification:** Confidential — Internal Security Assessment

## Executive Summary

Spearpoint Security assessed whether an attacker who obtained access to Corvid’s internet-facing Linux server could reach the internal Windows domain and maintain control after Corvid changed passwords and responded to the intrusion.

The answer is yes.

Starting from the supplied account on CORVID-WEB01, the assessment obtained root control of the Linux host, crossed the network boundary into the internal segment, reached CORVID-DC01, obtained administrative control, extracted the domain’s Kerberos trust secret, and created a forged administrative authentication ticket. That ticket successfully authenticated to the domain controller and retrieved the protected dominance proof even after the original service-account password was no longer the basis of authentication.

This is not an isolated server compromise. It is a domain-level compromise.

The practical consequence is that an attacker could move from an exposed web server to systems containing domain credentials, alter services, impersonate administrative identities, access sensitive Windows resources, and return after passwords were reset. Password resets alone would not reliably remove the attacker. Recovery would require treating the domain as compromised, rotating the Kerberos `krbtgt` secret twice, reviewing privileged access, removing unauthorized directory permissions, rebuilding or comprehensively remediating affected systems, and investigating authentication and directory-replication logs.

The compromise depended on several design failures operating together:

1. A privileged backup command on WEB01 was vulnerable to filename-based command injection.
2. The DMZ host had a reachable interface into the internal network, and the stolen service credential could be used across the boundary.
3. The service account had excessive rights over a Windows service and a PowerShell remoting endpoint.
4. Domain-root permissions allowed a non-administrative account to obtain replication privileges.
5. Domain replication privileges allowed extraction of the `krbtgt` secret and creation of a durable forged ticket.

The assessment recovered the following lab evidence:

- Beachhead flag: `CVD{0db81c5aa204dce6e131112e4e351aad}`
- Domain-control flag: `CVD{2d060d20ca15432f964d6455092977a8}`
- Dominance proof: `d6750f3dd6bd7a511dd7079626e2d681`

The most urgent remediation is to remove unauthorized replication rights and review all permissions on the domain root. This should be followed by `krbtgt` rotation, privileged-account review, service delegation reduction, DMZ segmentation, and remediation of the WEB01 backup process.

## Attack Narrative

### Phase 1: Initial foothold and host enumeration

The supplied foothold was an SSH-accessible account on CORVID-WEB01:

```
webapp / WebFoothold2026!
```

The host was confirmed to be a dual-homed Linux server. Its external-facing interface was on `10.10.0.0/24`, while its second interface was on the internal `10.10.10.0/24` network. The internal domain controller was identified at `10.10.10.5`.

Initial enumeration focused on local privilege boundaries, scheduled jobs, backup scripts, writable directories, service configuration, and credential files. The account had passwordless sudo access to a backup script:

```
/opt/corvidapp/backup/run-backup.sh
```

The script created a tar archive using a wildcard containing files from a directory writable by `webapp`. This allowed specially named files to be interpreted as tar options rather than ordinary filenames.

### Phase 2: Privilege escalation on WEB01

A controlled tar wildcard injection was used to execute a shell script as root. The payload created a SUID-enabled copy of Bash. This produced an effective root shell on CORVID-WEB01.

The escalation was reliable and required no vulnerability in the operating system itself. It resulted from allowing a low-privileged user to run a root-owned backup process over attacker-controlled filenames.

With root access, the application configuration was reviewed. The file:

```
/opt/corvidapp/config/db.conf
```

contained a domain service credential:

```
Domain: corvid.local
Username: svc-webapp
Password: W3bApp-Cr3d2026!
```

This credential was not merely a database credential. It was valid for domain authentication and could be used from the internal network.

The beachhead flag was retrieved from the internal share after establishing a route through WEB01:

```
CVD{0db81c5aa204dce6e131112e4e351aad}
```

### Phase 3: Network pivot

The attack workstation could not directly reach `10.10.10.5`. WEB01, however, could reach the internal network through its second interface.

A hand-built pivot was established using Ligolo-ng. The agent ran on WEB01, while the Ligolo proxy ran on the attack workstation. After the tunnel was activated, the attack workstation could connect to the DC’s SMB and authentication services as if it were positioned on the internal segment.

Connectivity was verified with:

```
nc -vz 10.10.10.5 445
```

The internal share `Beachhead$` was accessed using the recovered service credential. This confirmed both network reachability and valid domain authentication.

The pivot was operationally important: the attack box itself never had a direct route to the domain controller. The DMZ host became the bridge between the external and internal networks.

### Phase 4: Domain administrative control

The `svc-webapp` account belonged to a group with delegated access to the application PowerShell remoting endpoint. The account could establish a remoting session to the domain controller’s application role.

Enumeration of the available services identified `CorvidAppSvc`. The service permissions allowed the delegated group to modify its executable path and start it. The service was reconfigured to execute:

```
cmd.exe /c net localgroup Administrators svc-webapp /add
```

The service reported a timeout when started because the replacement command did not behave as a normal long-running Windows service. The timeout did not prevent execution. The payload ran with SYSTEM privileges and added `svc-webapp` to the local Administrators group.

The reproducible sequence was: read `sc.exe sdshow CorvidAppSvc`; confirm the delegated group could change it; set the temporary `binPath` to `cmd.exe /c net localgroup Administrators svc-webapp /add`; start it; and verify `net localgroup Administrators`. The timeout is a service-wrapper symptom, not evidence of failure. This supplied local administration, not replication rights.

Access to the protected domain-control share then produced:

```
CVD{2d060d20ca15432f964d6455092977a8}
```

This stage demonstrated that a service account with delegated application rights could be converted into local administrative control on the domain controller.

### Phase 5: Domain dominance

The domain-root permissions exposed an independent route to domain-wide control. The `GRP-HELPDESK-LEGACY` delegation allowed modification of permissions on the domain root. That meant `svc-webapp` could be granted the two directory-replication rights required for DCSync:

- Replicating Directory Changes
- Replicating Directory Changes All

After those rights were granted, DCSync was used to retrieve the `krbtgt` account’s NTLM hash:

```
670229a01993e179f262e929da57dc7d
```

The domain SID was obtained as:

```
S-1-5-21-1909037144-3050882815-2586595962
```

The `krbtgt` hash and domain SID were used to create a golden ticket for the real `Administrator` account. The forged ticket was accepted by the fully patched domain controller.

Using the forged ticket, DCSync retrieved the final protected account material:

```
flag-dominance:1108:aad3b435b51404eeaad3b435b51404ee:d6750f3dd6bd7a511dd7079626e2d681:::
```

The final dominance proof was therefore:

```
d6750f3dd6bd7a511dd7079626e2d681
```

This is the decisive result. The attacker no longer depended on the original `svc-webapp` password. The forged ticket represented an administrative identity and could be reused to authenticate after ordinary password changes.

Four checks recorded the transition. The domain-root ACL showed `GRP-HELPDESK-LEGACY` could change the root descriptor. The delegated session added `svc-webapp` for `DS-Replication-Get-Changes` and `DS-Replication-Get-Changes-All`, then read both ACEs back. DCSync named the domain and `krbtgt` object and returned the NTLM value above. The forged-ticket request used the recorded domain SID, `krbtgt` key, and Administrator RID; `klist` showed the ticket before the protected share was accessed. The evidence is therefore root ACL → replication ACEs → `krbtgt` material → Administrator ticket → domain proof, not an assumption that local SYSTEM automatically meant domain administrator.

An engineer can reproduce the transition by querying `DC=corvid,DC=local`, resolving `GRP-HELPDESK-LEGACY`, granting only the two named replication rights to `svc-webapp`, and reading the descriptor back. Then run `-just-dc-user krbtgt`, create the Administrator ticket from the recorded SID and returned key, and use `klist` before the Kerberos proof request. These ACEs are separate from local Administrator access.

## Findings

### Finding 1 — Root escalation through attacker-controlled backup filenames

**Severity:** High  
**CVSS v3.1:** `AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H` — 7.8

The `webapp` account could run a root-owned backup script that passed wildcard-expanded filenames to tar. Because the working directory was writable by `webapp`, specially named files could be interpreted as tar options and execute arbitrary commands as root.

**Impact:** Complete compromise of WEB01, access to root-readable credentials, modification of the host, and preparation of a pivot into the internal network.

**Metric justification:** `AV:L` (shell on WEB01), `AC:L` (simple filename creation), `PR:L` (limited sudo), `UI:N` (backup execution), `S:U` (WEB01 only), and `C:H/I:H/A:H` (root control). Downstream domain impact is excluded.

**Remediation:** Replace wildcard-based archive commands with an explicit file list or a safe archive API. Run backups with a fixed working directory and a non-writable source path. Remove unnecessary passwordless sudo access. If sudo is required, use a narrowly constrained wrapper that validates filenames and arguments.

### Finding 2 — DMZ host provides an uncontrolled route into the internal network

**Severity:** Medium (high business priority)
**CVSS v3.1:** `AV:N/AC:L/PR:L/UI:N/S:C/C:L/I:L/A:L` — 7.7

WEB01 had simultaneous access to the external and internal networks. Once the host was compromised, it could forward traffic to the domain controller. The service credential recovered from WEB01 was also accepted by internal domain services.

**Impact:** The intended network boundary did not contain the compromise. An attacker controlling the internet-facing host could reach SMB, WinRM, and directory services that were not directly exposed to the attack workstation.

The `S:C` metric reflects crossing from the DMZ host into the separately administered domain. The lower impacts describe this finding alone: internal reachability and pivot, not domain compromise or production-data destruction.

**Remediation:** Place externally exposed application servers in a tightly isolated DMZ. Permit only explicitly required flows from WEB01 to internal services. Block SMB, WinRM, LDAP, Kerberos, and RPC from the DMZ unless a documented application requirement exists. Use separate service identities for DMZ applications and prohibit interactive or administrative use of those identities.

### Finding 3 — Excessive service and remoting delegation enabled SYSTEM access

**Severity:** High  
**CVSS v3.1:** `AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H` — 8.8

`svc-webapp` belonged to a group with remoting access and service-control permissions sufficient to modify and start `CorvidAppSvc`. This permitted arbitrary code execution as SYSTEM on the domain controller’s application role.

**Impact:** The service account could be converted into local administrative control on a critical Windows server. From that position, an attacker could access local secrets, privileged sessions, services, and domain-management interfaces.

The vector uses `S:U` because this finding is the service’s execution impact within the same Windows security authority; the later domain-root delegation is a separate finding and is not counted here. `PR:L` represents the authenticated service identity, while the high impacts represent SYSTEM execution on the affected server.

**Remediation:** Remove service configuration rights from application groups. Separate service administration from application execution. Use dedicated groups for remoting, and grant only the exact endpoint and command permissions required. Review all service DACLs with `sc.exe sdshow`, PowerShell, or an identity-management platform. Do not place application service accounts in broad local-admin or delegated groups.

### Finding 4 — Domain-root permissions allowed unauthorized DCSync

**Severity:** Medium (critical business priority)
**CVSS v3.1:** `AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N` — 6.5

A legacy helpdesk delegation allowed modification of permissions on the domain root. That path allowed `svc-webapp` to grant itself replication rights and perform DCSync.

**Impact:** DCSync read `krbtgt` and other domain secrets from the directory. This finding alone demonstrates secret disclosure and supplies material for a later forged-ticket finding; it does not itself prove forged-ticket acceptance, ransomware, or modification of every domain object.

This finding is limited to the domain-root ACL and resulting replication capability. `S:U` is appropriate because the low-privileged principal and directory are within the same authority. `C:H` reflects extracted domain secrets; `I:N/A:N` reflect a read, not arbitrary object writes or outage. Business priority remains critical because the exposed `krbtgt` secret enabled persistence.

**Remediation:** Immediately remove unauthorized `WriteDACL`, `WriteOwner`, and replication permissions from the domain root. Review effective permissions for every delegated group. Apply least privilege and administrative-tiering principles. Alert on changes to domain-root ACLs and on directory-replication requests from non-domain-controller hosts. Rotate `krbtgt` twice after confirming containment.

### Finding 5 — Domain compromise remains valid after ordinary credential response

**Severity:** High (critical business priority)
**CVSS v3.1:** `AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H` — 8.8

Once the `krbtgt` secret was obtained, a forged ticket for the real `Administrator` account was accepted by the domain controller.

**Impact:** The forged ticket authenticated as `Administrator` and retrieved the protected proof without the original service-account password. This finding demonstrates durable administrative authentication after ordinary password changes; it does not claim that ransomware or data destruction occurred.

This score covers the forged ticket, not the route to `krbtgt`. `S:U` treats it as an artifact accepted by the same authority. `PR:L` reflects possession of the recovered trust secret; `C:H/I:H/A:H` reflect Administrator authentication and domain control. Its business priority is critical because it survives password resets.

**Remediation:** Treat the domain as compromised. Rotate `krbtgt` twice with sufficient replication delay between changes. Reset all privileged and service credentials, invalidate active sessions, review delegation, remove unauthorized ACLs, and investigate ticket use and replication events. Consider rebuilding systems where credential theft cannot be ruled out.

## Prioritised Remediation

### Priority 0 — Contain and recover the domain

1. Isolate WEB01 from the internal network until remediated.
2. Disable or reset `svc-webapp` and all credentials recovered from the environment.
3. Remove unauthorized domain-root ACEs and verify effective permissions.
4. Rotate `krbtgt` twice.
5. Reset privileged accounts and service accounts.
6. Review domain-controller logs for DCSync, service changes, remoting, and unusual Kerberos activity.

This work addresses the ability to return as an administrator.

### Priority 1 — Remove the privilege-escalation chain

1. Remove the vulnerable backup sudo rule.
2. Replace the tar wildcard process with a safe backup implementation.
3. Restore `CorvidAppSvc` to its approved executable path.
4. Remove `svc-webapp` from local Administrators.
5. Review and reduce service-control permissions.
6. Remove unnecessary PowerShell remoting access.

### Priority 2 — Repair segmentation and identity design

1. Enforce DMZ-to-internal firewall restrictions.
2. Block unnecessary SMB, WinRM, RPC, LDAP, and Kerberos access from WEB01.
3. Use separate, non-interactive service identities for DMZ applications.
4. Deny service accounts interactive logon and local administrative privileges.
5. Review all nested groups and legacy helpdesk delegations.

### Priority 3 — Improve detection and validation

Alert on domain-root ACL changes, replication requests from non-DC systems, service binary-path modifications, new local administrators, suspicious PowerShell remoting, and Kerberos tickets with unusual lifetimes or administrative identities.

## Decision Log

The engagement used the following primary route:

```
WEB01 foothold
→ tar wildcard root escalation
→ application credential recovery
→ Ligolo network pivot
→ internal SMB validation
→ PowerShell remoting
→ service reconfiguration
→ SYSTEM/local administrator
→ domain-root delegation
→ DCSync
→ golden ticket
→ domain dominance
```

The recorded activity was executed as a targeted sequence rather than a broad scan. The planned forty-hour budget was divided approximately as follows:

- WEB01 enumeration and escalation: 6 hours
- Pivot construction and troubleshooting: 7 hours
- Internal enumeration: 5 hours
- Domain administrative path: 6 hours
- DCSync and golden-ticket validation: 5 hours
- Cleanup and reporting: 8 hours
- Reserve and abandoned paths: 3 hours

These rounded allocations sum to the forty-hour cap; the three-hour reserve covered abandoned routes and reporting overruns.

The service-control path was selected because it was reliable and quickly demonstrated impact. The LSASS-dump path was left unused because it would have created additional credential-extraction noise and was unnecessary.

An alternative route through `svc-sql` and delegated administrative membership was identified. It would have involved resetting that account’s password and using its replication privileges. It was not relied upon for the final result, which is important because the successful domain takeover did not depend on a single accidental route.

A quieter adversary would likely prefer the domain-root ACL route over service reconfiguration or LSASS dumping. It produces fewer host-level artifacts, avoids memory-dump tooling, and can appear as an ordinary directory-permission change unless ACL auditing and replication monitoring are enabled. Nevertheless, the route would still generate detectable directory-service events and should be treated as high-confidence compromise.

The attempted DCSync-ACE cleanup using `dacledit` failed locally with:

```
unsupported hash type MD4
```

Therefore, the final environment must be verified manually to confirm that temporary replication permissions, service changes, and local-group changes have been removed.

## Limitations

The forty-hour assessment did not provide a complete enterprise-wide review. Testing was limited to the supplied WEB01 and DC01 systems and the internal network reachable through the pivot.

The following areas were not comprehensively assessed:

- All internal workstations and servers
- Cloud identity, SaaS, and external identity providers
- Backup infrastructure and recovery systems
- Endpoint detection and response coverage
- Long-term persistence through scheduled tasks, GPOs, certificates, or federation
- Data-exfiltration volume and business-data impact
- Full historical log review
- Disaster-recovery readiness
- Production-safe validation of `krbtgt` rotation

The demonstrated results are bounded to the tested path: WEB01 account, WEB01 root, its internal interface, DC01 administration, replication-secret extraction, and forged-ticket acceptance. We verified the protected proof, but not every workstation, server, share, application, cloud service, ticket lifetime, or real replication outcome.

The following are plausible consequences, not demonstrated outcomes: theft of business data, ransomware deployment, interruption of actuarial services, compromise of cloud identities, persistence through certificates or Group Policy, and successful return after a real password-reset response. The report does not claim that data was exfiltrated, that production systems were encrypted, or that all enterprise systems were compromised. Those outcomes remain credible because domain-level administrative control can enable them, but they require separate validation, log review, and incident-response investigation.

The assessment did not attempt ransomware, mass encryption, deletion, or broad exfiltration. It did not test post-`krbtgt` disaster recovery, endpoint blocking, or segmentation outside the observed route.

Because the DCSync cleanup command failed with an MD4 compatibility error, Corvid should not assume that the lab state is clean solely because the forged-ticket demonstration completed. The DCSync ACE, `CorvidAppSvc` executable path, local Administrators membership, changed passwords, and temporary files must be verified before reset or handover.

The central conclusion remains unchanged: Corvid’s current control design allows an attacker to progress from an exposed DMZ host to durable domain dominance. The remediation priority should therefore be domain recovery and identity-control correction, followed by segmentation and removal of the WEB01 privilege-escalation weakness.
