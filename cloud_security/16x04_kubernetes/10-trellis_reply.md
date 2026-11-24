Thank you for walking us through the control set. Here is what each control does today.

**Pod Security admission (baseline, 11 of 14 namespaces).** Working where applied. `media-processing` has no enforce label, so Pod Security does not apply there. That makes it effectively exempt: its transcoder can run privileged with `SYS_ADMIN`, host networking and a host-root mount, which the same admission would refuse in a labelled namespace.

**Privileged-container admission policy.** Present, but it does not block anything. Its binding uses `Audit`, so the API server records violations and still admits the workload. A policy in a repository or a bound object is a standard, not enforcement. Only an admission mechanism that rejects requests applies it.

**NetworkPolicy `orders-api-ingress`.** Working, assuming the network plugin enforces policy and the `billing-worker` label matches.

**NetworkPolicy `payments-api-isolation`.** Currently does nothing. It selects `app: payments-api`, which matches no pod, so it isolates nothing. It looks healthy in a listing, and the listing does not show whether it selects anything.

The common pattern is that a control's presence is reported and its effect is not. Nothing currently shows whether each control acts.

To make the slide accurate within a quarter:

1. Enforce baseline on every namespace, moving the transcoder off host access or documenting a time-limited exemption.
2. Test the admission policy against release workflows, then change its binding to `Deny`.
3. Correct the payments selector to the real pod labels and prove it with a connection test.
4. Add a default-deny network policy per namespace, with explicit allows for mapped traffic.
5. Report monthly on each policy: its action, the workloads it selects, and the date of its last validation.

The controls reflect real work. The gap is between their existence and their effect, and step 5 closes it.
