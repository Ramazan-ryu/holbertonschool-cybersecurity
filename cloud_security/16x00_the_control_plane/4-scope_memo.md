# 4 — Scope Memo

This memo separates Copperline's configuration and data from the provider's infrastructure using the specific estate visible to `svc-audit-intake`. It records what this identity observed; it does not assume that an uninspected service is correctly configured.

## Copperline-owned and assessable

- **IAM identity and policies.** The user `svc-audit-intake`, its attached `CopperlineOpsLogsReadOnly` policy, inline `intake-ops-access` policy, and `migration-readers` group policy are Copperline account configuration. The broad S3 statement and the inline policy-version management permissions are therefore within Copperline's control and review scope.
- **S3 buckets, data, and bucket configuration.** The freight-manifest, operations-log, CloudTrail, and undocumented migration-scratch buckets and their objects belong to Copperline's account. Their names, object metadata, bucket policies, ACLs, encryption defaults, and Public Access Block are customer-side controls. Ops logs and CloudTrail showed SSE-S3 and all four public-access-block flags enabled. Scratch had no bucket-level encryption configuration or Public Access Block; the inspected ACL and absent bucket policy did not demonstrate public access. Its object listing and later `HeadObject` lengths conflict, so content and encryption conclusions must remain open.
- **SQS dispatch queue.** The queue and its access policy are Copperline's application configuration. The service is managed, but queue permissions, producers/consumers, message retention, and data classification remain customer responsibilities. The current identity's visibility is limited to the calls it can make.
- **Secrets Manager entries and KMS migration key.** Secret values, descriptions, who may retrieve them, key policy, aliases, and customer-selected key configuration are Copperline-controlled. The provider operates the managed service and key hardware, but does not decide whether Copperline's IAM principals should access a carrier token or mail relay credential.
- **Resilience and copies.** Whether manifests need a second copy, cross-account protection, or tested recovery is a Copperline business and architecture decision. Provider durability controls do not establish that the customer has a recoverable independent copy.
- **CloudTrail use.** The account's choice to enable trails, the destination bucket, access to the records, retention, and monitoring are Copperline responsibilities. The provider supplies the logging service; the customer must use and protect the resulting records.

## Provider-operated boundary

- **Physical security of Ireland data centres, underlying hardware, media handling, and isolation between provider customers** are provider responsibilities. They are not controls this identity can inspect or test through Copperline's account APIs. The board's multi-tenancy concern belongs in the provider assurance and contractual review, not as a finding against Copperline's bucket or IAM configuration.
- **Patching servers and infrastructure that implement Secrets Manager, SQS, S3, and KMS** is provider-operated for the managed service layer. Copperline does not patch those hosts. Copperline still owns its own container workload, runtime image, application dependencies, and service configuration; no claim about those workloads is made from this inventory.

The practical boundary is not “managed means secure”: provider operation covers the service infrastructure, while Copperline remains accountable for identities, access policies, data, service settings, workload code, and recovery choices. Where the evidence is missing or the identity was refused, this memo records a visibility limit rather than a conclusion about provider or customer controls.
