Privilege That Does Not Announce Itself

Subject: A CI runner can run a workload as the platform controller in platform.

The chain, using Trellis objects:

Starting subject: ServiceAccount build/ci-runner.
Granted permission: RoleBinding ci-runner-platform-deploy (namespace platform) binds Role platform-deployer, which allows create on pods and get, list on serviceaccounts. The grant is limited to platform.
Workload transition: the pod created in platform sets spec.serviceAccountName: controller-admin. The Role does not check that field. The pod API authorises the create, not the ServiceAccount named in the spec.
Identity obtained: platform/controller-admin, the ServiceAccount already used by Deployment platform-controller. Its token is mounted unless the pod disables it, which is the default.
RBAC transition: ClusterRoleBinding platform-controller-admin binds that ServiceAccount to ClusterRole cluster-superuser.
Final effective privilege: wildcard verbs on all resources in every namespace, including reading Secrets in kube-system and prod.

Evidence and limits. Step 6 is supported by audit rows 829 and 830, which show platform/controller-admin reading Secrets. The log does not record the pod, so the link from step 3 to those reads is inferred from the manifests. The default token mount in step 4 is Kubernetes behaviour, not something the export proves.

Why nothing stopped step 3. The export's only admission policy is audit-only and covers privileged Deployments. Pod Security labels do not check ServiceAccount names.

Why it was granted. The pipeline has to deploy and inspect platform workloads, and this Role is what that takes. The ServiceAccount field is not visible from the Role itself.

A question for you. Which other namespaces have a Role allowing pod creation, where a ServiceAccount with more power sits in the same namespace? Start there.
