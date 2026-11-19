# 5. Who Is Allowed to Become This Role

The `ashford-deploy-pipeline` trust document names exactly this federated principal:

`arn:aws:iam::418274630117:oidc-provider/token.actions.githubusercontent.example`

It permits `sts:AssumeRoleWithWebIdentity` when the token claim `token.actions.githubusercontent.example:aud` equals `sts.amazonaws.com`. There is no condition on the `sub` claim, repository, organization, branch, workflow, environment, or other subject attribute. Therefore the admissible set is every valid token from this specific configured OIDC provider whose audience is exactly `sts.amazonaws.com`, regardless of its subject value. The trust does not admit arbitrary issuers; the provider and audience remain constraints.

The handover says only the Ashford deploy pipeline can use the role. The document does not establish that boundary: it does not bind the role to Ashford's repository or deployment workflow. The role has the `AshfordBatchExecAdmin` managed policy attached, whose v1 statement allows `Action:"*"` on `Resource:"*"`. A token admitted by the trust can therefore obtain administrative role credentials. This is a trust-policy finding, not a leaked key. It is confirmed by `aws iam get-role --role-name ashford-deploy-pipeline`, `list-attached-role-policies`, and `get-policy-version` responses.

This principal has no human owner who can be offboarded and no static key to rotate. Individual STS sessions expire, but the trust remains active and any qualifying issuer identity can request another session. Narrow the trust with exact subject conditions for the intended repository and protected deployment context, then test both intended and unintended subjects.
