# 5. Who Is Allowed to Become This Role

## Trust document and exact admitted set

`aws iam get-role --role-name ashford-deploy-pipeline` returned a trust policy whose relevant statement is:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::418274630117:oidc-provider/token.actions.githubusercontent.example"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.example:aud": "sts.amazonaws.com"
    }
  }
}
```

There is one operator: `StringEquals`. It compares the OIDC token's `aud` claim exactly with the string `sts.amazonaws.com`. It constrains the audience claim only. It does not compare `sub`, repository, owner/organization, branch/ref, workflow, environment, or any other identity claim; none of those keys appears in this statement. The `Principal.Federated` field separately restricts the issuer/provider to the registered provider `token.actions.githubusercontent.example` in account `418274630117`.

The full admissible set is therefore:

```text
{ valid OIDC tokens issued by the registered provider
  for every subject/identity that provider can issue a token to,
  where aud is exactly "sts.amazonaws.com" }
```

Equivalently, for every issuer-permitted `sub` value and every associated repo, organization/owner, ref/branch, workflow, environment, and other claim combination, the role trust admits the identity if the token is valid for that provider and `aud == "sts.amazonaws.com"`. The issuer's own token-issuance rules still constrain which tokens exist; this IAM trust adds no Ashford-specific filter over those subjects. It is not literally every internet identity or every arbitrary forged token. It is the entire population the named provider can authenticate under that one audience, including identities outside Ashford's deployment repository because no subject or repository condition excludes them.

## Intended identity versus actual trust

The handover says production deploys use an OIDC CI identity and claims “Only our deploy pipeline can use that role.” That is the documented intent. The supplied estate documents do not name the repository, branch, workflow file, or deployment environment, so an exact intended `sub` string cannot honestly be inferred. A correct remediation must obtain that value from Ashford's actual CI configuration and restrict `sub` (and any relevant repo/ref/environment claims) to the protected deployment workflow.

The current trust accepts other provider-authenticated subjects with the same audience, including tokens from other repositories, organizations, refs, workflows, or environments whenever the provider can issue them. These are the unintended identities admitted by the missing subject constraints.

## Reach and durable risk

`list-attached-role-policies --role-name ashford-deploy-pipeline` returned `AshfordBatchExecAdmin`. Its v1 policy document is `Effect:Allow`, `Action:"*"`, `Resource:"*"`; the role response showed no permissions boundary. A caller admitted by the trust receives that role's broad AWS authority, subject to the organization's `AshfordGuardrails` SCP denies (`CreateAccessKey`, `CreateLoginProfile`, organization exit, account closure). This reach follows from the attached policy, not the role name.

Each OIDC token and STS session is short-lived and expires. The durable risk is the unchanged role trust: any matching subject can obtain a fresh session repeatedly. Rotating a static key cannot close this path because the role has no static key; employee offboarding also does not alter the issuer's subject population or the trust statement. The persistent fix is to scope and maintain the trust conditions, then test allowed and disallowed subjects.
