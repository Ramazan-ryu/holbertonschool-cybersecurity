# 5. Who Is Allowed to Become This Role

## Trust statement and admitted token set

The `ashford-deploy-pipeline` trust document contains this statement:

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

The admitted set is precisely the tokens AWS validates for the configured federated provider `token.actions.githubusercontent.example` in account `418274630117`, for which the token claim `aud` equals `sts.amazonaws.com`. The condition has one operator, `StringEquals`, one key, and one exact value. The `Principal.Federated` field restricts the issuer/provider. The trust statement adds no condition on these claims: `sub`, `repository`, `repository_owner`, `ref`, `workflow`, and `environment`. Thus any otherwise-valid token from that provider with the required audience matches, regardless of those claim values.

## Intended workload and evidence limits

The intended workload is inferred from the lab handover context to be one protected production deployment job; it is not verified from Ashford CI configuration. I checked the repository files and Git history and found no handover or workflow with the organization, repository, protected branch, or environment values. For a branch-based deployment, the assumed full subject form is `sub = "repo:" + OWNER + "/" + REPOSITORY + ":ref:refs/heads/" + PROTECTED_BRANCH`. For a GitHub environment deployment, the assumed full form is `sub = "repo:" + OWNER + "/" + REPOSITORY + ":environment:" + PRODUCTION_ENVIRONMENT`. These names denote unknown values, not verified Ashford identifiers; the available evidence cannot establish which form or values apply. I therefore do not quote the reported handover sentence as verified wording.

CloudTrail can identify the role-assumption event, target role, session, and caller fields it records. This export does not establish the complete OIDC token claims or prove which repository, ref, workflow, or environment produced the subject. Attribute those values using the issuer's token claims or the corresponding GitHub Actions workflow run; do not infer them from the role-assumption event alone.

## Role reach and durable risk

The role has the attached `AshfordBatchExecAdmin` policy. Its v1 statement is `Effect: Allow`, `Action: "*"`, `Resource: "*"`, and the role has no permissions boundary. An admitted caller therefore receives that broad role permission set, subject to the account's `AshfordGuardrails` SCP denies, including long-lived key creation and the specified organization/account actions.

Individual OIDC tokens and STS sessions expire, but the trust configuration persists and can issue new sessions to any matching token subject. Rotating a static key or offboarding an employee does not remove this admission path. The durable fix is to bind the trust to the verified repository and protected deployment context, then test both the intended subject and a disallowed subject.
