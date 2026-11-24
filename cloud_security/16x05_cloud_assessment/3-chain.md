Finding: Exposed CI Credential and Over-Broad Cross-Account Access

Severity: Critical. Immediate response required.

Summary

A long-lived AWS access key for CI is stored in the history of the granite-peak-platform repository (commit dated 2026-10-28). The account accepted the key during validation. Whether the key was used to access data on 2026-10-19 must be confirmed from CloudTrail.

Immediate actions
Revoke and reissue the key. Treat it as compromised.
Review CloudTrail for all use of the key and any sessions derived from it since 2026-10-28, and re-review account activity for 2026-10-19.
Remove the secret from repository history, clones, forks, and CI caches.
Add secret scanning to the build pipeline to block commits containing keys.
Structural issues
The build account is trusted to assume a deployment role in the platform account. The account boundary functions as a trust relationship, not an isolation control.
The deployment role has broad permissions (eks:*, and S3 object actions on *).
A node role associated with the telemetry workload can read resources classified as operationally restricted. Its trust policy names EC2, although documentation says only the telemetry service should have access.
The KMS key protecting telemetry is shared at platform scope rather than dedicated, and its decrypt grants are broader than the architecture describes.

Each team owning one of these parts may have reviewed it and found it reasonable. The risk comes from how the parts combine, which no single review would reveal. This is a structural gap, not an individual failure.

Recommendations
Rotate and retire all long-lived CI keys. Move to short-lived credentials through OIDC federation.
Review cross-account trust policies. Restrict sts:AssumeRole to specific principals and conditions.
Create a dedicated KMS key for telemetry with explicit grants.
Scope node and workload roles to the minimum actions and resources required.
Include a check of architectural requirements against deployed configuration in the change pipeline.
Business impact

Operations, safety, regulatory reporting, and recovery impact should be assessed by Granite Peak's operations, legal, and compliance teams using confirmed facts. This report does not determine their obligations.
