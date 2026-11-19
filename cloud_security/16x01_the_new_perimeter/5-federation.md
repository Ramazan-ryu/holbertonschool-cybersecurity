# 5. Who Is Allowed to Assume the Deploy Role

## Trust statement and exact admitted set

The trust statement for `ashford-deploy-pipeline` is:

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

Let `P` be the registered provider `token.actions.githubusercontent.example` in account `418274630117`. A caller is admitted if and only if AWS validates the presented token as unexpired and signed by `P`, and `aud(t) = "sts.amazonaws.com"`.

```text
A = { t | Valid_P(t) AND aud(t) = "sts.amazonaws.com" }
A_ids = { sub(t) | t in A }
```

This is the full admitted set: every subject to which `P` issues a valid token with that audience is admitted. The federated principal fixes the provider; the audience condition fixes the only token claim value checked by the trust.

## Condition analysis

| Element | Value | What it constrains |
|---|---|---|
| `Principal.Federated` | Provider ARN above | The token issuer/provider. |
| `Action` | `sts:AssumeRoleWithWebIdentity` | The web-identity role-assumption operation. |
| Operator | `StringEquals` | Exact equality. |
| Key | `token.actions.githubusercontent.example:aud` | The token's `aud` claim. |
| Value | `sts.amazonaws.com` | Requires `aud` to equal this value. |

There is no trust condition on `sub`, `repository`, `repository_owner`, `repository_id`, `ref`, `workflow`, `environment`, `actor`, `event_name`, or `job_workflow_ref`. These claims are unconstrained. Thus any provider-issued subject with the required audience is admitted, regardless of repository, owner, ref, workflow, or environment.

## Intended identity (assumption) and gap

The handover context identifies this as the production deploy role. The intended workload is assumed to be the protected production deploy job. Its subject takes one of these forms, according to how the job is gated:

```text
S_branch = "repo:OWNER/REPO:ref:refs/heads/PROTECTED_BRANCH"
S_environment = "repo:OWNER/REPO:environment:PRODUCTION_ENV"
```

`OWNER`, `REPO`, `PROTECTED_BRANCH`, and `PRODUCTION_ENV` are explicitly assumed values, not extracted CI configuration. Let `S` be `S_branch` for branch gating or `S_environment` for environment gating. The intended set is `I = { t in A : sub(t) = S }`. The excess admitted set is:

```text
A \ I = { t | Valid_P(t) AND aud(t) = "sts.amazonaws.com" AND sub(t) != S }
```

This excess set contains all other subjects to which `P` issues a valid token with that audience, including other repositories, owners, refs, workflows, and environments. The repository copy contains no deploy workflow or handover document with the literal values, so the subject forms above are assumptions.

CloudTrail can record the role-assumption event, target role, session, and caller fields. The available export does not provide the full OIDC token claims; use the issuer token claims or the matching GitHub Actions run to attribute the subject, repository, ref, workflow, and environment.

## Role reach

The role has the attached managed policy `AshfordBatchExecAdmin` v1: `Effect: Allow`, `Action: "*"`, `Resource: "*"`. It has no permissions boundary. An admitted session receives that broad permission set, subject to SCP `AshfordGuardrails`, which denies `iam:CreateAccessKey`, `iam:CreateLoginProfile`, leaving the organization, and closing the account. This reach follows from the attached policy and missing boundary, not from the role name.

## Why the risk persists

OIDC tokens and STS sessions expire, but the trust statement persists and can admit new matching tokens repeatedly. There is no static key on the role to rotate, and employee offboarding does not change the provider's repository subjects or the trust.

## Fix

Add a `StringEquals` condition for `token.actions.githubusercontent.example:sub` with the intended subject after replacing the labeled assumption values with the deploy workflow's actual values. Optionally constrain `repository_owner` or immutable `repository_id`. Replace `Action: "*"` and `Resource: "*"` with the deploy job's required permissions and add a permissions boundary. Test that the intended deploy job succeeds and that another repository, a pull-request or fork run, and a non-deploy ref are refused.
