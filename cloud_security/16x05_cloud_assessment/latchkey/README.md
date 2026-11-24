# 16x05 — Cloud Assessment · lab workstation (capstone)

Holberton School · Cybersecurity · M16 Cloud Security

A Latchkey Security assessment workstation for the **Granite Peak Energy** engagement. This is the capstone:
one estate, every domain you have worked in across M16 — identity, storage and keys, compute, and the
cluster — in a single environment, exactly as a real cloud assessment arrives. Most of it is sound. Your job
is to find the few things that are not, prove them, and rate them by what they actually cost the client.

## What is here

| | |
|---|---|
| `~/granite-peak/architecture/` | the platform overview Granite Peak's architects wrote — what they *intend* |
| `~/granite-peak/infrastructure/` | the infrastructure-as-code that was actually applied — what they *built* |
| `~/granite-peak/identity-export/` | the IAM export for **both** accounts (build and platform) |
| `~/granite-peak/cluster-export/` | the platform cluster's exported state (16x04 shape) |
| `~/granite-peak/activity/` | a fortnight of account activity, as delivered by the log pipeline |
| `~/granite-peak/repo/` | the platform repository, with its history |
| `http://127.0.0.1:4566` | Granite Peak's **live account API** — identity and storage findings you can *execute*, not just assert |

The account API answers only through the audit endpoint on this box; there is no route off the machine, and
every scanner runs offline.

## Credentials

You are **not** handed a key. A cloud assessment begins by establishing what you can act as, and from where.
Everything you need to reach the live account is discoverable within the estate above. When you have found a
credential, configure a named profile for it and verify it with `aws sts get-caller-identity`. The account
API honours the same identity rules AWS does: a call you are not authorised to make is refused.

## How Whitfield wants it

- **Proportion first.** The great majority of this estate is correct. An assessment that raises everything is
  as useless to the client as one that raises nothing. Separate the sound from the consequential before you
  write a word.
- **Rate by consequence, not alarm.** Some of what looks frightening is fine under inspection; some of what
  looks routine is the whole engagement. **Do not inflate a lesser finding, and do not bury the one that
  matters.** Either one fails the assessment.
- **Derive, never assert.** Every claim carries its evidence: a cited artefact, or — for an identity or
  storage conclusion — the result of actually executing it against the account API.
- **Reconcile intent against reality.** The architecture document and the deployed infrastructure do not
  everywhere agree. Some divergences change the client's exposure; some do not. Rate each.
- **Say what is fine.** Where something alarming turns out to be sound, report it as sound and say why.
- **A finding ends in a decision.** If the client's data is in scope of an obligation, say so from the
  evidence in the estate — classification, retention, handling — and state the action it compels. Name no
  statute you cannot ground in what is in front of you.
- **Your fix must not break the platform.** Breaking the material issue is the point; state what each break
  costs operationally, and sequence the rest for a team with finite capacity.

## Tools (all offline)

`aws` · `boto3` · `cloudsplaining` · `pmapper` · `checkov` · `trivy` · `kubescape`
(frameworks pre-fetched at `/opt/kubescape/frameworks/`) · `trufflehog` · `gitleaks` · `jq` · `yq` · `git`.
No tool is prescribed; choosing the right instrument for each question is part of the work.

## Deliverables

Under `cloud_security/16x05_cloud_assessment/`:

- `0-assessment_approach.md` — your plan of work **before** you open the estate: order, what you will *not*
  spend time on, and the trigger that would change your course.
- `1-reconciliation.md` — document-versus-reality, each divergence rated.
- `2-findings.md` — every finding with a discriminating rating and its evidence; the sound-but-alarming
  components cleared explicitly.
- `3-chain.md` — the material issue, end to end, each step evidenced or executed.
- `4-remediation/` — `4-fix.md`, `4-chain_broken.txt` (the chain re-walked from the fixed state, showing it
  stops), `4-programme.md` (the sequenced plan).
- `5-assessment_report.md` — the client-facing report, leading with an executive summary a board can act on.

## Reset

`sudo granite-reset` restores the live account to its handover state if you have changed it while working.
Your deliverables and the `~/granite-peak/` files are untouched.
