# Remediation Programme

The order assumes limited engineering capacity. Complete item 1 first. If capacity stops there, the build-to-production trust edge is removed. Continue in sequence so the next completed work reduces access to the classified data before addressing bounded read-only and segmentation issues.

## 1. Contain the material build-to-platform path

Revoke the history-exposed CI key; remove build-account `ci-runner` trust from `gp-deploy` until a short-lived replacement is approved. Review the commit and repository access history, rotate any dependent credentials, and preserve relevant audit records. Then implement a federated pipeline identity constrained to the intended repository and deployment workflow. Replace `eks:*` and wildcard S3 access with only the actions and resources required for deployment. Validate the trust with `get-caller-identity` and an expected denied assume-role attempt for the retired principal before enabling the new pipeline.

**Cost/dependency:** deployment pauses during identity replacement; requires CI and cloud-platform owners to coordinate.

## 2. Remove workload access to node credentials and isolate telemetry access

Give `telemetry-ingest` a dedicated workload identity with only the required bucket and key permissions. Block pod access to node instance credentials, and ensure the node role does not carry telemetry permissions. Verify a representative pod cannot obtain node credentials and that the intended telemetry workload can read only its required objects.

**Cost/dependency:** workload identity rollout and credential endpoint changes require cluster testing; a mis-scoped policy can interrupt ingestion.

## 3. Replace the shared KMS key and narrow key policy

Use a dedicated customer-managed key for `gp-grid-telemetry`; grant decrypt only to the approved workload identity and key administrators. Remove account-wide effective use, assess re-encryption and object access, and test recovery and rotation. Keep audit logging for key use and review historical decrypt events.

**Cost/dependency:** re-encryption, key migration, and recovery testing require a planned maintenance window; preserve access to historical objects.

## 4. Reduce reporting-role read scope

Replace `gp-reporting-broad` wildcard `Get`/`List`/`Describe` actions with service-specific read actions on reporting resources. Review activity to identify actual needs and test the reports before removing permissions.

**Cost/dependency:** access analysis and owner testing; reduced discovery may require reporting configuration changes.

## 5. Correct the lower-impact network and ingress divergences

Confirm analytics dashboard and pipeline dependencies, then remove or constrain the `rtb-app` route to `10.3.0.0/24`. Narrow app HTTPS source CIDRs from `10.0.0.0/8` to approved callers where feasible. Update the architecture document to the approved state.

**Cost/dependency:** application owners must test dashboard and pipeline flows before route changes; ingress narrowing requires identifying all callers.

## 6. Verify admission, logging, and retention controls

Inspect the complete admission binding and confirm the intended enforcement mode with representative workloads. Verify deployed bucket access logging, seven-year retention/lifecycle controls, endpoint policy, and actual key policy through the account API. Update architecture and data-handling records from verified state.

**Cost/dependency:** requires platform and governance owners and access to the complete deployed state; do not label unverified controls safe.
