# 16x02 — Storage, Secrets and Exposure · lab workstation

Holberton School · Cybersecurity · M16 Cloud Security

A Latchkey Security analysis workstation for the **Alderbrook Health** engagement. The account is
reachable **only** through its API at the local endpoint; there is no route to anything else, and the
scanners run offline.

## What is set up

| | |
|---|---|
| `aws` CLI v2, `boto3` | pre-configured, profile `default`, region `eu-west-1` |
| `cloudsplaining` | policy unpacking |
| `trufflehog`, `gitleaks` | secret discovery over repository history |
| `checkov`, `trivy` | infrastructure-code / manifest scanning (offline) |
| `~/alderbrook-handover/` | the client's description of the estate (read-only) |
| `~/alderbrook-app/` | Alderbrook's application repository, with history (read-only) |

Do not change `endpoint_url` in `~/.aws/config`. That endpoint is the account.

## The engagement (what Whitfield wants)

- **Compute effective access, don't read it off the console.** Three permission systems overlap on these
  buckets and disagree. The only answer accepted is the one you computed and proved by making the call.
- **A thing that is private only because a switch is flipped is a finding**, reported against the policy,
  with the control named as a mitigating factor.
- **A scanner hit is not a finding.** Most committed credentials are dead. For anything you report, know
  it is live and know what it opens.
- **If something is genuinely fine, say so.**
- **Derive, never assert.** Every access you claim carries the call and the response.

## Audit trail

CloudTrail is enabled; events land in the trail bucket about once a minute, as gzipped JSON under
`AWSLogs/`. Your own calls appear there too. The **key-usage (Decrypt) event** is the one a defender
should alert on — note where it is.

## Evidence for grading

```
mkdir -p evidence
sudo latchkey-export > evidence/audit-export.json
```

The bundle is signed; do not edit it. Grading cross-checks the access you claim against it.

## Reset

`sudo alderbrook-reset` restores the account to its handover state — policies, key policies, and the
account public-access control you may have toggled — and clears your activity. Your files in `~` are
untouched. A reboot does **not** reset.
