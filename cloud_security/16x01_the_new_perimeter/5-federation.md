# 5. Who Is Allowed to Assume the Deploy Role

## Trust statement

`aws iam get-role --role-name ashford-deploy-pipeline` returned this trust statement:

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

## Condition analysis

| Element | Value | Claim population it constrains |
|---|---|---|
| `Principal.Federated` | OIDC provider `token.actions.githubusercontent.example` in account `418274630117` | The issuer. The token must be signed by this provider. |
| `Action` | `sts:AssumeRoleWithWebIdentity` | The entry path. Only web-identity exchange is admitted. |
| Operator | `StringEquals` | Exact, case-sensitive equality. No wildcard or pattern matching. |
| Key | `token.actions.githubusercontent.example:aud` | The `aud` claim of the presented token. |
| Value | `sts.amazonaws.com` | `aud` must equal this string exactly. |

The statement has no condition on `sub`, `repository`, `repository_owner`, `repository_id`, `ref`, `workflow`, `environment`, `actor`, `event_name`, or `job_workflow_ref`. Each of these claims is unconstrained.

## Exact admitted set

Let `P` be the provider `token.actions.githubusercontent.example` in account `418274630117`, and let `Valid_P(t)` mean that `t` is an unexpired token signed by `P`. The admitted token set is:

`A = { t : Valid_P(t) AND aud(t) = "sts.amazonaws.com" }`

A caller is admitted if and only if both conditions hold. The admitted external identities are the subjects of those tokens:

`A_ids = { sub(t) : t in A }`

Because no condition references `sub`, `repository`, `repository_owner`, `repository_id`, `ref`, `workflow`, `environment`, `actor`, `event_name`, or `job_workflow_ref`, every value of those claims that `P` issues a token for is included in `A`. This includes tokens for any repository, owner, ref, workflow, environment, and triggering event that `P` will issue under that audience. The provider restriction excludes tokens from other issuers and forged tokens.

## Intended identity (assumption)

The handover describes this role as the production deploy role. The workflow file that would confirm the subject is not among the supplied files, so the intended subject below is an assumption. It takes one of two forms, depending on how deployment is gated:

- Branch-gated: `S_branch = "repo:OWNER/REPO:ref:refs/heads/PROTECTED_BRANCH"`
- Environment-gated: `S_env = "repo:OWNER/REPO:environment:PRODUCTION_ENV"`

`OWNER`, `REPO`, `PROTECTED_BRANCH`, and `PRODUCTION_ENV` are placeholders. They are not verified values. Under the branch-gated assumption, the intended set is `I = { t in A : sub(t) = S_branch }`.

## Gap between intent and admission

The admitted identities that the intent excludes are:

`A \ I = { t : Valid_P(t) AND aud(t) = "sts.amazonaws.com" AND sub(t) != S_branch }`

This set includes tokens from every other repository, owner, branch, tag, pull-request ref, workflow file, and environment that `P` issues under that audience. None of these is excluded by the trust.

CloudTrail records the `AssumeRoleWithWebIdentity` call, the target role, and the session. The export does not contain the token claims, so it cannot show which repository, ref, workflow, or environment produced a given session. Those values come from the issuer's token claims or the GitHub Actions run record.

## Role reach

The role has one attached policy, `AshfordBatchExecAdmin`, version 1: `Effect: Allow`, `Action: "*"`, `Resource: "*"`. The role has no permissions boundary. An admitted session therefore receives full permissions in the account, limited only by the organisation SCP `AshfordGuardrails`, which denies `iam:CreateAccessKey`, `iam:CreateLoginProfile`, leaving the organisation, and closing the account. This reach comes from the attached policy and the missing boundary, not from the role name.

## Why this is more durable than a leaked key

- **Tokens and sessions expire, but the admission does not.** Each OIDC token and STS session is short-lived. The trust statement is persistent. Any valid token in `A` can mint a new session at any time.
- **There is no key to rotate.** The role has no static credential. Admission depends on which subjects the provider issues tokens to, not on a secret.
- **Offboarding does not apply.** The callers are repositories and workflows, not employees. Removing a user or reviewing human credentials does not change the trust or the provider's subject population.
- **The population grows.** A new repository under a permitted owner becomes admitted with no change to the trust.

## Remediation

1. Add a `StringEquals` condition on `token.actions.githubusercontent.example:sub` with the verified intended subject `S` from the deploy workflow. Optionally add `repository_owner` or the immutable `repository_id`.
2. Keep the `aud` check as a format requirement.
3. Replace `Action: "*"` and `Resource: "*"` with the actions the deploy needs, and attach a permissions boundary.
4. Test both directions. The protected deploy job must succeed. A job from another repository, a pull-request or fork run, and a non-deploy ref must be refused.
