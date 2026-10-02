# Attack and Detection Report

## Executive finding

Thornbury’s assumption that an administrator password is the only route to the actuarial server was false. Starting with the phished domain user `THORNBURY\jdoe`, I used the domain’s own identity mechanisms to obtain service-account access, authenticate with material for which no plaintext password existed, and finally obtain an administrative Kerberos service ticket for the SQL service. The important finding is not any individual tool; it is the sequence of directory permissions, ticket requests, and authentication fields that made the chain possible.

## Ledger and attack chain

The initial foothold was `jdoe`, whose password was supplied by the laboratory as the phishing result. I did not crack that password. From that authenticated user, I requested a TGS for the SPN belonging to `svc_reports`. The returned RC4 TGS material was worth cracking because `svc_reports` was both a usable service identity and the account that had `GenericAll` over the later SQL-related computer object. The targeted wordlist recovered the plaintext password for `svc_reports`; I used it to authenticate to its hidden SMB home and to operate as that domain identity. The password itself is omitted from this report.

I also selected `mreynolds` because the account was configured with `DoesNotRequirePreAuth`. Its AS-REP could be requested without first authenticating as that user, and the recovered plaintext password allowed access to the corresponding hidden home share. This was a separate useful finding and a direct example of configuration turning authentication material into access. It was not necessary for the final SQL path, so it received less strategic priority than `svc_reports`; its plaintext password is also intentionally not reproduced here.

The third ledger line was deliberately different. A public migration note exposed the NT hash for `d.langford`. I never learned `d.langford`’s plaintext password and did not spend compute trying to crack it, because the hash was already usable as the RC4 key for an overpass-the-hash request. I requested a TGT for `d.langford`, passed the ticket into the current session, and accessed the `ITAdmin$` share. The local process could still display `jdoe`; the proof was the Kerberos ticket in `klist` and successful access as the ticket identity, not a misleading change to the process username.

The administrative path used `svc_reports`’s directory rights rather than another password. Before changing anything, I recorded the existing value of `msDS-AllowedToActOnBehalfOfOtherIdentity` on the `svc_sql01` computer object. Because `svc_reports` had `GenericAll` over that object, I wrote a resource-based constrained delegation entry allowing `svc_reports` to act to it. I then requested an S4U service ticket for `MSSQLSvc/thornbury-sql01.thornbury.local:1433`, impersonating Administrator, and used the resulting Kerberos credential to reach the actuarial SQL service. The temporary delegation entry was removed and read back after the proof was obtained.

## Compute triage and deliberate non-actions

Compute went first to the `svc_reports` TGS because its SPN made the material crackable offline and its account had a confirmed path to the SQL computer object. `mreynolds` was tested because the no-preauthentication setting made collection cheap, but it was a secondary path with no demonstrated administrative relationship to SQL. I used a short, targeted dictionary and stopped when the evidence justified the next identity step; I did not launch an unrestricted attack against every recovered hash.

I deliberately did not crack `d.langford`, because the NT hash was already actionable for TGT acquisition. I also did not attack `svc_sql01` or unrelated service accounts. The configuration fact made that unnecessary: the path depended on `svc_reports`’s `GenericAll` permission and the writable RBCD attribute, not on knowing the SQL service account’s password. Cracking service accounts without an SPN, useful group membership, or a direct relationship to the database would have consumed time and increased risk without improving the objective.

## What the Thornbury SOC should find

The initial domain authentication for `jdoe` can produce a successful logon record and a 4768 TGT request, depending on where auditing is enabled. The Kerberoasting step should produce Security event **4769**, a service-ticket request. The useful correlation fields are the requesting account, `Account Name=jdoe`, the requested `Service Name` containing the `svc_reports` SPN, `Client Address`, and the ticket encryption type. The cheapest form of this attack is betrayed by **Ticket Encryption Type = 0x17 (RC4)**: an ordinary user requesting RC4 service tickets for service-account SPNs is a stronger lead than a normal AES request. The event does not contain the plaintext password, but it identifies exactly which account and service were targeted.

The AS-REP request for `mreynolds` should appear as **4768**, with `Target User Name=mreynolds`, the requesting client address, and a pre-authentication field showing that pre-authentication was not required. RC4 encryption is another useful correlation field. The subsequent share access can produce **4769** for a CIFS service and a successful logon on the file server; the SOC should correlate those records with the newly used account rather than treating the share read as an isolated file event.

The overpass-the-hash step should produce a **4768** TGT request for `d.langford`, followed by **4769** service-ticket requests for the CIFS service hosting `ITAdmin$`. The revealing fields are the target account, client address, service name, and RC4 ticket encryption type. A successful ticket request followed by access from the original `jdoe` workstation, without a normal interactive logon for `d.langford`, is suspicious. The absence of a plaintext password does not make this invisible; the DC records the identity represented in the ticket.

The most important directory change is a **5136 Directory Service Object Modified** event, if auditing and an appropriate SACL are enabled. The SOC should search for the computer object `svc_sql01`, the changed attribute `msDS-AllowedToActOnBehalfOfOtherIdentity`, the subject `svc_reports`, and the new security descriptor containing the delegation relationship. A related **4662** object-access event may also exist where directory-service auditing is configured. Subsequent **4769** events should show S4U/delegation activity involving the SQL SPN, the service account, the target service, and delegation-related ticket options; the final SQL server can additionally record a successful logon as Administrator.

## Earliest prevention and detection

The single missing detection that would have caught this chain earliest is a targeted 4769 analytic for a normal user requesting RC4 service tickets for service-account SPNs, enriched with the requester, SPN, client address, and ticket encryption type. That alert would have fired at the first Kerberoasting request, before the later pass-the-ticket and RBCD activity. It is a detection gap, not the same thing as changing the configuration.

The single configuration change that would have broken the demonstrated administrative chain earliest is removing `GenericAll` from `svc_reports` on the `svc_sql01` computer object and granting only the narrowly required rights. Without the ability to modify `msDS-AllowedToActOnBehalfOfOtherIdentity`, the cracked `svc_reports` password could still access its share, but it could not write the RBCD trust or obtain the Administrator ticket for SQL. The service account’s legitimate reporting function can remain in place while the dangerous object-control permission is removed.

## References

- [Microsoft: Event 4768](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/event-4768)
- [Microsoft: Event 4769](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/event-4769)
- [Microsoft: Event 5136](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/event-5136)
- [MITRE ATT&CK: Kerberoasting](https://attack.mitre.org/techniques/T1558/003/)
