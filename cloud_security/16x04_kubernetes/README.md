# Trellis Software Kubernetes access review

This directory contains the requested deliverables for the offline review of Trellis Software's exported Kubernetes state.

The source snapshot and audit log are preserved under `latchkey/`. RBAC findings are derived from the source manifests and cross-referenced by object name and namespace. The map covers all 14 namespaces, every ServiceAccount, Role, ClusterRole, RoleBinding, and ClusterRoleBinding in the snapshot; effective privileges are summarized per subject in `1-effective_privilege.md`.

Deliverables 7, 8, and 10 are draft text inputs under their requested filenames and are within the supplied word limits. The `9-cluster_quiz/` directory contains a concise answer sheet because no separate quiz prompts were included with the handover.

`5-remediation/5-fixed_manifests.yaml` is a complete multi-document copy of the exported manifest set with the proposed workload, admission-binding, and Role changes. `5-remediation/5-rescan.txt` records the required Kubescape invocation and the execution limitation: this workspace did not have Kubescape installed and could not reach the lab workstation. It does not claim the corrected scan is clean. Run the documented command on the supplied workstation and save its JSON output there to complete scan validation.

The original cluster export and audit log have not been modified.
