# 5. Who Is Allowed to Assume the Deploy Role

## Exact admitted set

The role trust statement is:

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

Let P be the registered OIDC provider `arn:aws:iam::418274630117:oidc-provider/token.actions.githubusercontent.example`. Let Valid_P(t) mean AWS validates t as an unexpired token signed by registered provider `token.actions.githubusercontent.example`. The exact admitted token set is:

```text
A = { t | Valid_P(t) AND aud(t) = "sts.amazonaws.com" }

A caller is admitted if and only if its token belongs to A.
```

Equivalently, the admitted external identities are the subjects of those tokens:

```text
A_ids = { sub(t) | t in A }
```

The provider field fixes the issuer; the predicate fixes the only claim value tested by the condition. Every other subject value issued by P is admitted when the token satisfies the predicate.

## Condition analysis

The trust statement has one condition operator and one key/value pair:

| Operator | Key | Value | What it constrains |
|---|---|---|---|
| `StringEquals` | `token.actions.githubusercontent.example:aud` | `sts.amazonaws.com` | Requires the token's audience claim to equal this exact value. |

`Principal.Federated` separately limits the trusted issuer to the registered provider in account `418274630117`. The statement has no condition on `sub`, `repository`, `repository_owner`, `repository_id`, `ref`, `workflow`, or `environment`. Those claims do not narrow this admitted set.

## Intended identity and gap

**Intended identity (assumption):** the handover context identifies this as the production deploy role. The intended subject S is assumed to be one of the following full forms, depending on whether Ashford gates deployment by branch or environment:

```text
S_branch = "repo:OWNER/REPO:ref:refs/heads/PROTECTED_BRANCH"
S_environment = "repo:OWNER/REPO:environment:PRODUCTION_ENV"
```

`OWNER`, `REPO`, `PROTECTED_BRANCH`, and `PRODUCTION_ENV` are assumption placeholders, not values asserted to be Ashford configuration. Let S be the selected intended subject: S_branch for branch-gated deployment or S_environment for environment-gated deployment. Then I = {t in A : sub(t) = S}, and the excess admitted set is:

```text
A \ I = { t | Valid_P(t) AND aud(t) = "sts.amazonaws.com" AND sub(t) != S }
```

This includes every otherwise-valid token with the required audience whose subject is not the intended deploy subject: other repositories, owners, branches/refs, workflows, environments, and any other subject value issued by P.

## Role reach

The role has the attached managed policy `AshfordBatchExecAdmin` v1: `Effect: Allow`, `Action: "*"`, `Resource: "*"`. The role has no permissions boundary. An admitted session therefore receives that broad role permission set, subject to the account SCP `AshfordGuardrails`, which denies `iam:CreateAccessKey`, `iam:CreateLoginProfile`, organization exit, and account closure. The reach comes from the attached policy and the lack of a boundary, not from the role name.

## Why the exposure persists

OIDC tokens and STS sessions expire, but the trust statement remains and can admit new matching tokens repeatedly. This is more durable than one leaked static key: there is no key on this role to rotate, and employee offboarding does not change which repository subjects the provider can issue tokens to or alter the trust.

## Fix

Add a `StringEquals` condition for `token.actions.githubusercontent.example:sub` using the verified deploy subject (S); optionally constrain `repository_owner` or the immutable `repository_id` as well. Replace `Action: "*"` with the deploy job's required actions and add a permissions boundary. Test that the intended protected deploy job succeeds and that another repository, a pull request/fork, and a non-deploy ref are refused.
