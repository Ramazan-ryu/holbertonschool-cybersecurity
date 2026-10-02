
# Attack-Path Analysis

## Scope and result

The engagement objective was to identify the permission chain to membership of `GRP-GPO-PRODADMINS`, the group associated with Halberd’s production policy. Domain-controller takeover and access to protected accounts were outside scope. The collected graph was a time-bound hypothesis. I compared its suggested relationships with live directory queries and recorded which rights were actually present.

The chain I exercised began with `jbennett` and reached `svc-build`, which a live group-membership query showed in `GRP-GPO-PRODADMINS`. The successful path depended on distinct permissions at successive hops; none should be collapsed into a generic claim that `jbennett` had “admin access.”

## Path taken, hop by hop

**1. `jbennett` → `GRP-HELPDESK-OPS`: `WriteOwner`.** The ACL read showed a `WriteOwner` ACE for `jbennett`. That right allowed an ownership change; it did not itself grant permission to edit the group’s DACL or add a member. The owner-change operation reported that the previous owner was `Domain Admins` and that the owner SID was changed successfully. A subsequent owner read identified `jbennett` as owner. In this chain, `WriteOwner` became a way to take ownership, not a direct group-membership right.

**2. Ownership → control of the group DACL.** After taking ownership, I used `dacledit` to add a `FullControl` ACE for `jbennett`. The tool reported a successful DACL modification. A later ACL read showed both the original `WriteOwner` ACE and the new `FullControl` ACE. This was a separate permission change: the original ACE did not equal `FullControl`; the later ACE was created after ownership changed.

**3. `jbennett` → membership of `GRP-HELPDESK-OPS`: group-member write.** With the modified DACL in place, the group-add operation succeeded. A live `net rpc group members` query then listed `HALBERD\jbennett`. The new group membership was the result of the DACL change, not a right contained in the original `WriteOwner` ACE.

**4. `jbennett` → `svc-build`: effective password-reset capability.** The password-reset operation using `jbennett`’s credentials reported success for `svc-build`. This demonstrates that the reset operation was usable in the directory state at that time. The notes do not include a saved, pre-change ACL read of the `svc-build` object, so I cannot identify its exact granting ACE or claim a particular extended-right GUID from the command output alone. That ACL should be captured in a repeat assessment before the reset is attempted.

**5. `svc-build` → `GRP-GPO-PRODADMINS`: group membership.** A live group-membership query authenticated as `svc-build` listed `HALBERD\svc-build` in `GRP-GPO-PRODADMINS`. This was the objective: reaching the group that controls the production-policy path. It is not evidence that `svc-build` is a domain administrator, nor is domain-controller control part of the finding.

## Shorter-looking paths that were not supported

**Directly adding `jbennett` to `GRP-HELPDESK-OPS` from the graph’s `WriteOwner` edge.** This path treated ownership control as if it were already permission to edit membership. The live ACL read showed only `WriteOwner` for `jbennett`; it did not show `WriteDACL`, `FullControl`, or a member-write right. The direct edge therefore did not support the assumed operation. Taking ownership and then changing the DACL were additional steps, each with its own directory change.

**Using the production GPO to execute on the domain controller.** The live `gPLink` query showed `GPO-Prod-Baseline` linked to `OU=Production,OU=Servers`, while the domain controller was located in `OU=Domain Controllers`. The DC’s OU had a different linked policy. A link to the Production OU does not, by itself, apply to the sibling Domain Controllers OU. The proposed route from the production policy to DC execution therefore had no supporting OU-link relationship.

**Assuming the production GPO had an execution target.** An LDAP computer search rooted at `OU=Production,OU=Servers` returned no computer objects. The domain-wide computer search returned only `HALBERD-DC01`, under the Domain Controllers OU. Thus the captured directory state showed zero computer objects in the policy’s linked OU. The policy link alone did not establish that a production machine existed to process it.

## Policy finding and blast radius

The GPO finding is a policy-control risk, not proof that the flag-copy command executed. `GPO-Prod-Baseline` was linked to the Production OU, and the `svc-build` session successfully wrote to its SYSVOL policy path. A policy modification with a machine-side scheduled task can run with the target computer’s machine context on each eligible computer that processes that policy. That makes control of a broadly linked policy potentially more consequential than a one-host access finding: its reach follows the OU’s computer membership and can include future computers placed there.

The measured blast radius in the evidence collected here is **zero current computer objects** in `OU=Production,OU=Servers`. The only computer found domain-wide was `HALBERD-DC01`, which is not in that OU and is not shown as a target of this GPO. I therefore cannot report successful execution on a production machine or claim that the flag was delivered. The potential severity comes from the policy’s ability to execute in machine context wherever eligible computers are linked, but the present inventory makes the demonstrated blast radius zero. Before calling this the highest realized-impact finding, Halberd should confirm whether the OU is intentionally empty, whether computers are represented elsewhere, and whether additional policy links or filtering apply.

## Directory records and reversion

The DC’s directory state recorded the ownership and DACL changes in the group’s security descriptor. The owner read showed `jbennett` after the owner change; the ACL read showed the added `FullControl` ACE. The group-membership query showed `jbennett` as a member after the membership change. The password-reset tool reported success for `svc-build`, but no DC security-event export or event ID is present in my notes; I will not invent one. The policy metadata query later showed `versionNumber: 1` and `gPCMachineExtensionNames` after the GPO tooling ran. SYSVOL listings also showed the staged policy files. These are observed directory and file-state records, not a substitute for exporting the DC’s audit logs.

The reversion notes report independent confirmation that `jbennett` was removed from `GRP-HELPDESK-OPS`, `svc-build`’s password was returned to its provisioned value, `jbennett`’s group ACL was reduced to the original `WriteOwner`-only grant, and the GPO payload was removed. Those checks support restoration of membership, password, ACL rights, and payload. The notes do not show a post-reversion owner-SID read or a post-reversion LDAP read of `versionNumber` and `gPCMachineExtensionNames`; those two states should be checked before declaring the directory and policy metadata fully restored. No DC audit-log export was preserved, so the report cannot attest to specific event IDs or their retention.

## Control that breaks the chain

The single most consequential delegation to remove is `jbennett`’s `WriteOwner` right on `GRP-HELPDESK-OPS`. Without it, the demonstrated first hop—taking ownership, changing the DACL, and adding `jbennett`—would have been interrupted before the chain reached the Helpdesk group and the later `svc-build` reset capability. Halberd should validate that this delegation is still required, remove it if not, and review the group’s owner and DACL independently.
