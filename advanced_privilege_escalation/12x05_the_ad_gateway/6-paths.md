
# 6\. Attack-Path Analysis

## Evidence and scope

This analysis uses the command output and LDAP results saved during the Halberd lab. The notes contain several DC addresses: `10.10.0.100`, `10.10.0.140`, and `10.10.0.149`. They should not be treated as one consistent capture. In particular, the `.149` SMB connection timed out, while LDAP and SMB operations against `.140` succeeded in other captures. The findings below identify the observed state where that distinction matters.

The directory permissions are recorded on object security descriptors as owners and ACEs; group membership is recorded on the group object. These are distinct records, not a general indication that an account had administrator access. Microsoft describes the AD security descriptor as carrying the object owner and DACL/ACE access information. [Microsoft’s MS-ADTS specification (https://learn.microsoft.com/en-us/openspecs/windows\_protocols/ms-adts/2f146d9e-393d-4c90-a9c7-780b73884a60)](<https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/2f146d9e-393d-4c90-a9c7-780b73884a60>)

## Path exercised

1. **`jbennett` → `GRP-HELPDESK-OPS`: `WriteOwner`.** The ACL read showed a `WriteOwner` ACE for `jbennett`. `owneredit.py` reported that the owner changed from Domain Admins (SID ending in `-512`) to `jbennett` (SID ending in `-1103`). A subsequent owner read confirmed `jbennett` as owner. `WriteOwner` enabled the ownership change; it did not directly grant the right to add group members.
2. **Ownership → DACL control.** After the ownership change, `dacledit.py` added a `FullControl` ACE for `jbennett`. A later ACL read showed that ACE as well as the original `WriteOwner` ACE. This was a new DACL change, separate from changing the owner.
3. **`jbennett` → membership of `GRP-HELPDESK-OPS`.** The group-add operation succeeded after the DACL change. A live `net rpc group members` query listed `HALBERD\jbennett`. The membership resulted from the new DACL permission, not from `WriteOwner` alone.
4. **`jbennett` → effective password-reset operation on `svc-build`.** `changepasswd.py` reported that the password set succeeded. The saved notes do not include a pre-change ACL read identifying the exact ACE that granted this operation, so the specific granting right cannot be attributed from the available evidence. Later authentication results also differ between DC addresses; the reset result and its final state need to be tied to the same DC before claiming a fully verified credential path.
5. **`svc-build` → `GRP-GPO-PRODADMINS`: group membership.** A live membership query authenticated as `svc-build` listed `HALBERD\svc-build` in this group. This established the policy-control path. It does not show that `svc-build` was a Domain Admin.

## Shorter-looking paths that failed

**Directly adding `jbennett` to `GRP-HELPDESK-OPS` from the original ACE.** The observed right was `WriteOwner`; the ACL read did not show `WriteDACL`, `FullControl`, or a member-write permission. Those are different access-mask capabilities. The direct membership operation therefore lacked a supporting permission until ownership was changed and the DACL was edited.

**Using `dcarter` as a shortcut.** The account had `adminCount=1`, and the saved ACL review found no effective working permission for `jbennett` on that user. A suspected inherited delegation was not present as an effective ACE on the protected object. The shortcut was not supported by the object’s current security descriptor.

**Using the `mflores` property-write edge for a certificate route.** `GenericWrite` was observed, but that alone did not establish a working PKINIT path. The notes report no AD CS Enrollment Services and do not record successful use of a key credential or a PKINIT ticket. This route remained unproven; the report should not describe it as a successful conversion.

**Running the Production GPO on the DC.** The observed GPO link was on `OU=Production,OU=Servers`; the DC computer object was in `OU=Domain Controllers`. A link on the Production OU does not establish that the sibling Domain Controllers OU processes the GPO. GPO scope follows the relevant site, domain, and OU links and target objects. [Microsoft’s Group Policy scope documentation (https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/group-policy/group-policy-scope)](<https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/group-policy/group-policy-scope>)

## Policy blast radius

The LDAP query against `OU=Production,OU=Servers,DC=halberd,DC=local` returned no computer objects in the `.140` capture. The domain-wide computer query in that same capture returned only `HALBERD-DC01`, located in `OU=Domain Controllers`. Thus the **measured current blast radius in that snapshot was zero Production computers**; the DC was not shown as a target of this link.

The policy delegation is potentially the broadest finding because a computer-side task in a GPO can execute as SYSTEM on each eligible computer that processes it. The pyGPOAbuse project describes its computer-GPO immediate task as running as SYSTEM on the remote computer. [pyGPOAbuse README (https://github.com/Hackndo/pyGPOAbuse)](<https://github.com/Hackndo/pyGPOAbuse>) The GPO’s reach is determined by its link and the actual target computers, not by the number of users in the domain. Microsoft’s GPO metadata specification identifies `versionNumber` and `gPCMachineExtensionNames` as part of that policy state. [MS-GPOD (https://learn.microsoft.com/en-us/openspecs/windows\_protocols/ms-gpod/d360d288-d7d5-49a9-83be-603805da1379)](<https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpod/d360d288-d7d5-49a9-83be-603805da1379>)

The notes later show a local `cat pwned-flag.txt` result, but the pasted SMB attempt to `.149` timed out. They do not include a successful transfer from `Drop$`, the contents of `whoami.txt`, or a matching Production computer inventory from that same endpoint. Therefore the flag content is recorded, but the supplied evidence does not independently identify which host produced it or prove SYSTEM execution there. The `.140` zero-computer result and the later flag result must be reconciled before claiming a nonzero machine count.

## Directory change record and rollback status

The rollback was checked with post-reversion reads, not inferred from the cleanup commands. For `GRP-HELPDESK-OPS`, the before/after record was: owner `Domain Admins` → `jbennett` → `Domain Admins`; ACL gained `FullControl` for `jbennett` → lost that ACE while the original `WriteOwner` ACE remained; and `member` gained `HALBERD\\jbennett` → final `MEMBERS=` was empty. Those object states match each write and its reversal.

For `CN=svc-build`, `changepasswd.py` first reported the reset success. Cleanup then restored the provisioned credential: authentication with the restored credential succeeded against the assessment DC, while the temporary reset credential failed. This is the concrete post-reversion check for the password change; the password itself is not expected to appear in an LDAP read.

The GPO rollback also has a before/after record. After the policy write, the directory read showed `GPT.INI Version=3`, LDAP `versionNumber=3`, and populated `gPCMachineExtensionNames`; SYSVOL contained the staged task files. The cleanup read against `.140` showed `GPT.INI Version=1`, LDAP `versionNumber=0`, no `gPCMachineExtensionNames`, and no `ScheduledTasks.xml`. The later `.149` Startup-folder payload was removed and a final directory listing showed that `payload.ps1` was absent. Therefore the owner, DACL, membership, password, GPO metadata, and payload changes are all documented with a post-reversion observation.

## Conclusion

The evidence supports a successful path to `GRP-GPO-PRODADMINS`, but the final audit record still needs same-DC verification of the `svc-build` credential state, the group owner, the current SYSVOL files, and the actual computer list in Production. The single delegation whose removal breaks the demonstrated path at its first edge is `jbennett`’s **`WriteOwner` ACE on `GRP-HELPDESK-OPS`**.
