# Blast-radius assessment

## Measured reach per consequential tool

**issue_refund.** Accepts a target email and an amount in cents. In the tested configuration `per_tool_authz` and `human_approval` were both false, so no ownership check or approval gate ran. Observed: zero refunds and $0 transferred. The call failed upstream, and the `BLOCKED_TARGET` audit query returned no events for the $150 request to `victim@larkspur-lab.example`. Unmeasured: per-refund ceiling, eligible-order count, aggregate daily limit. Reach is not limited to the signed-in customer; it extends to any account email the model can be persuaded to supply, and only one target was tested. A completed refund would leave Larkspur through the payment processor. Recovery and fees were not tested, so reversibility is unknown. The customer might notice on their statement; Finance would likely notice at reconciliation. Detection timing is unknown.

**delete_record.** The tool is registered, but observed deletions were zero. Accepted record types, identifier formats, per-call count, account scope, and aggregate cap are unmeasured, so no larger reachable count is claimed. No soft-delete or backup restore was tested, so reversibility is unestablished. No alert or audit event was observed. An affected customer might notice on the next lookup or through a support report; operator detection latency is unknown.

**db_query.** The initial setting was `raw_passthrough`; a later setting used `parameterized`. The attempted `SELECT k,v FROM _secrets` produced no captured result or canary, so observed rows returned or modified: zero. Reach is bounded only by the service account's database grants, which were not enumerated. Any disclosed row would be visible to the requesting customer at once and could not be recalled. Database-alert coverage and security-team detection time were not tested. Whether parameterized handling blocks attacker-controlled query structure remains unverified.

**Resource use (not a tool).** `/metrics` showed a 150,000-token proxy ceiling with session caps disabled. Usage was zero because model calls failed; no charge or denial was observed. Cost per token and reset behavior are unmeasured.

## Ranking by business impact

Six findings, each listed once. Excessive agency covers two tools; their internal order is stated in item 1.

1. **Excessive agency: issue_refund, then delete_record.** These are the only findings that change business assets directly: money can leave and records can disappear. Refund ranks above delete because it moves money through a path that accepts any account email, while delete_record's reach is unmeasured and no deletion occurred. Observed loss is $0 and zero records; upper bounds are unmeasured.

2. **Improper output handling: db_query.** Raw SQL can reach whatever the service account can read, including the secrets table. No rows were observed, so breadth is unmeasured, but a successful disclosure is immediate and unrecallable.

3. **Unbounded consumption.** One session could exhaust the 150,000-token ceiling, blocking other sessions and generating spend. Nothing was consumed in captured attempts; cost is unknown, and recovery requires resetting the ceiling.

4. **Embedding weakness.** A routine customer query retrieved internal pricing memo kb-900, including a $321-per-seat floor and escalation reference. This is a confirmed disclosure that may affect Enterprise negotiations; deal count and revenue impact are unknown, and no money moved.

5. **Indirect injection.** One customer-submitted chunk was retrieved at score 0.7582 in a victim session. The model call failed before any tool action, so impact is retrieval only.

6. **Data poisoning.** Two chunks were accepted and indexed, but no fresh-session answer containing the seeded assertion was captured. Closing ingestion returned HTTP 403; existing entries remain. Impact is stored untrusted content only.

## First remediation priority

Fix excessive agency first. The boundary that must change is the authority the model holds to call `issue_refund` and `delete_record` directly. Each call must be bound to server-verified customer ownership, with amount, count, and approval limits enforced before execution.

The most interesting finding is the embedding weakness. The internal memo reached a routine query with no adversarial input, exposing a gap in `segment_internal`: kb-900 was hidden for the tested query while kb-901 stayed retrievable. Its novelty does not outweigh Larkspur's exposure. A successful refund or deletion changes money or records on every call and can repeat in every session until rate-limited. The memo gap is serious but has so far exposed one document. Difficulty is a property of the attacker; severity is a property of Larkspur's losses. The segmentation gap still needs a fix, but second.
