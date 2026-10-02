# Verify the Path

The BloodHound collection is a snapshot, not the current directory. I treated its edges as hypotheses and compared them with live LDAP, ACL, and group-membership results before taking any further action.

## Attractive paths that fail as shortcuts

The apparent shortcut from `jbennett` to membership of `GRP-HELPDESK-OPS` was not a direct membership-write right. The ACL read showed only `WriteOwner` for `jbennett`, not `FullControl`, `WriteDACL`, or a member-write right. `WriteOwner` permits an ownership change; it does not itself permit adding a group member. The later `owneredit` and `dacledit` output showed that ownership and the DACL had been changed, after which the group-membership query showed `jbennett` as a member. The evidence supports a multi-step route, not the graph’s presumed direct write edge.

The production-GPO route to a startup-script execution target also lacked a verified production computer. A live LDAP search below `OU=Production,OU=Servers,DC=halberd,DC=local` returned no computer objects. A domain-wide computer search returned only `HALBERD-DC01`, under `OU=Domain Controllers`. Therefore, the linked production policy did not establish that a production computer existed to process the startup script. This is a separate failure from the missing direct group-write permission.

## Route supported by current evidence

The remaining route toward the bounded objective is through `svc-build`. The password-reset command using `jbennett` credentials reported success. A subsequent live group-membership query showed `HALBERD\svc-build` in `GRP-GPO-PRODADMINS`. That membership identifies the relevant group for the objective: membership in the group controlling the production policy, not control of the domain controller.

I distinguish the confirmed results from the earlier graph: the reset result supports the usable `jbennett`-to-`svc-build` relationship, and the live group-membership result supports the `svc-build`-to-`GRP-GPO-PRODADMINS` relationship. The group-membership query was recorded after the password reset, so the chronology is a verification gap in my process; I will not claim it was checked beforehand. Before any further change, I would re-read the current `svc-build` ACL and `memberOf` value and stop if either no longer supports this route. Domain-controller control remains out of scope.
