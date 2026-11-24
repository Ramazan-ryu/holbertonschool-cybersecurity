# Assessment Approach

## Timing and basis

This approach is being recorded after an initial exploratory viewing of portions of the estate. It is not represented as a contemporaneous, pre-inspection plan. The sequence below records the prioritisation I will use for the remaining assessment and the checks against which I will judge that prioritisation.

## Order of work

1. **Establish the reachable identities and trust paths.** Start with the repository history and identity exports to locate how access is obtained. For every identity used, verify it with `aws sts get-caller-identity`. Trace any cross-account trust and confirm consequential permissions with the live account API. This comes first because the effective exposure depends on who can act, how that identity is reached, and which account it can affect.
2. **Trace sensitive data paths across domains.** Identify data stores and keys from the architecture and infrastructure, then follow access from workload identity through cluster configuration and cloud permissions to the data. Execute identity and storage checks against the local account API wherever supported. This is the highest-value use of time because a material exposure may require several individually plausible controls to fail together.
3. **Use activity records to test the access model.** Compare the fortnight of account activity with the documented purpose of workload and service identities. Prioritise unusual identity actions that occur amid otherwise routine operations; use them as leads to test against permissions and deployed configuration, not as findings by themselves.
4. **Reconcile intended and deployed controls.** Compare architecture claims with infrastructure code and exported cluster state. Record each material and immaterial divergence, then verify consequential identity or storage conclusions against the account API.
5. **Check remaining domains proportionately.** Review compute, network, cluster admission and access control, storage encryption and access logging, and repository history for evidence that changes the end-to-end risk or validates that a worrying-looking control is safe. Use the available offline tools only where their output answers a specific question; independently verify any result that affects a rating.
6. **Rate and report only after tracing impact.** Separate sound controls, genuine lower-consequence weaknesses, and any demonstrated path with material business impact. Tie each claim to a concrete artefact or an executed API response.

## Deliberate limits on effort

I will not begin by running every scanner over every directory or enumerating every low-level configuration difference. That would produce a large volume of weak leads before establishing the identity and data paths that determine consequence. I will not treat scanner counts, wildcard-looking strings, names such as “admin,” or policy labels as proof of impact. I will not spend substantial time on repository code that has no bearing on deployment, identity, secrets, or the data path. I will not test external connectivity: the engagement is confined to the supplied workstation and its local account audit endpoint. For each line of enquiry, I will spend further time only when a concrete artefact or account API response confirms a chain transition, changes the likely impact, or rules out a material path. If a lead cannot be tied to such evidence after checking its relevant source, I will record it as unsubstantiated and move on.

## Change-of-course trigger

I will change the ordering if the first identity and data-path checks show that the candidate workload identities cannot reach the sensitive store or its key, and that no trust or cluster path can bridge the gap. I will then redirect effort toward the activity records and other deployed domains to find a different supported route. I will also change course if activity evidence identifies an unexpected identity or action with a stronger, independently verifiable route to consequential data or control; that signal takes priority over the initial hypothesis.
