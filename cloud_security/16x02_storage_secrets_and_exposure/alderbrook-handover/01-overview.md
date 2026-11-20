# Alderbrook Health — cloud account handover

Prepared by: Priya Natarajan, Platform Engineering
For: Latchkey Security — storage & secrets review
Status: current as of this quarter

## The account

| | |
|---|---|
| Account alias | `alderbrook-health` |
| Account ID | 734112396500 |
| Region | eu-west-1 |
| Partner account | Northmoor Labs (external), for the shared results feed |

## What the board has been told

Patient data is encrypted at rest with our own KMS key (`alias/alderbrook-phi`). On that basis the board
has signed off that patient data is protected. Our monthly cloud security scan has come back clean for
over a year.

## Storage

See `02-buckets.md`. In short: a records bucket (encrypted), an exports bucket, a partner share, an ops
bucket, and the CloudTrail bucket. Public access is blocked at the account level.

## Scope for Latchkey

Credentials for a read-only security-review identity are provided, along with our application repository
and infrastructure code. Tell us whether anything reachable here needs attention, and — the board will
ask — whether the encryption actually protects the records.
