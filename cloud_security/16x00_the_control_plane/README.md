# Copperline Logistics Control Plane Review

This directory contains the deliverables for the Copperline Logistics cloud identity and access review. Evidence files preserve API responses supplied or collected from the disposable lab workstation. Claims are limited to what those responses establish; open validation steps are called out in the relevant analysis files.

The review concerns the account identity and its API permissions. It does not include network scanning or access to Copperline hosts.

## Remediation status

The least-privilege change to `CopperlineOpsLogsReadOnly` is complete: v2 is the default and contains only the ops-logs bucket read/list statement. Post-change checks confirmed ops-log listing succeeds and migration-scratch listing is denied. Operator-provided results are recorded in `evidence/remediation-v2-session.txt`.

The review is not a complete account-wide closure. Remaining follow-up items are recorded in `8-evaluation.md`, including review of the inline policy's ability to create and switch managed policy versions, owner validation of the undocumented scratch bucket, and resolution of inconsistent S3 object-size responses. No object body was retrieved as part of the remediation.
