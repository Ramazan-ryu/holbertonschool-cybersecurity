# Remediation Programme

The order assumes limited engineering capacity. Complete item 1 first. If capacity stops there, the repository-exposed credential is disabled and the production trust is reviewed before deployment resumes. Continue in sequence so the next completed work removes workload access to classified data before addressing bounded read-only and segmentation issues.

## 1. Contain the material build-to-platform path

Deactivate the history-exposed access key that the account API confirmed authenticates as `user/ci-runner`; remove it from current source and history, review repository access, rotate any dependent credentials, and preserve audit records. Reconcile why the live caller is an IAM user while the trust export names a role. Keep the production deployment path suspended until a short-lived federated identity constrained to the intended repository and workflow is approved. Remove `eks:*` and wildcard S3 actions in favor of the deployment actions and resources actually required. Verify the retired key fails `get-caller-identity`, and test that the replacement can update only the approved workload.

**Cost/dependency:** deployment pauses during identity replacement; requires CI and IAM/cloud-platform owners to reconcile the caller principal and coordinate the replacement. The assessment identity was denied both `iam:UpdateAccessKey` and `iam:UpdateAssumeRolePolicy`, so an authorized IAM administrator must apply containment.

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
