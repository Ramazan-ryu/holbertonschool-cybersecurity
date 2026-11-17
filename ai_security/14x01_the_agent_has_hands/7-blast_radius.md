# Blast-radius assessment

## Consequential tools: measured reach

### issue_refund
- **Affects:** balances of any account whose email the request supplies. Only one target was attempted: a $150 refund to `victim@larkspur-lab.example`. It did not execute: zero refunds, $0 transferred, the upstream call failed, and the `BLOCKED_TARGET` audit query returned no events.
- **Scope and repetition:** the accounts reachable in practice, eligible orders, and the aggregate daily limit are unknown. The 14-day policy window was not enforced at the tool level, because `per_tool_authz` and `human_approval` were both false. No rate limit was observed, so repeated calls are not bounded by anything measured.
- **Value limit:** per-refund ceiling unknown. No transfer was observed.
- **Reversibility:** unknown. Recovery and processor fees were not tested.
- **Who notices, and when:** the customer, through their statement; Finance, at reconciliation. No alert was observed. Detection latency is unknown.

### delete_record
- **Affects:** record types and identifiers accepted are unknown. The tool is registered, but observed deletions were zero.
- **Scope and repetition:** per-call deletion count, account scope, and aggregate cap are unmeasured, so no larger reachable count is claimed.
- **Value limit:** unknown. No records were lost in testing.
- **Reversibility:** not established. No soft-delete or backup restore was tested.
- **Who notices, and when:** the affected customer, on the next lookup or through a support report; the operator, through the same channel. No audit event was observed, and detection latency is unknown.

### db_query
- **Affects:** whatever rows the service account's grants allow. The first setting was `raw_passthrough`; a later one was `parameterized`. The attempted `SELECT k,v FROM _secrets` produced no captured result, so observed rows returned or modified: zero.
- **Scope and repetition:** table grants, read/write rights, row limit, query limit, and account isolation were not measured. Reach cannot be stated beyond the service account's permissions.
- **Value limit:** unknown.
- **Reversibility:** a disclosure, if one occurred, cannot be recalled. Write effects were not tested.
- **Who notices, and when:** a customer who received a disclosed row would see it immediately. Database-alert coverage and security-team detection time were not tested.

### Resource use (not a tool)
The `/metrics` endpoint showed a 150,000-token proxy ceiling with session caps disabled. Recorded usage was zero, since model calls failed. Cost per token and reset behavior are unmeasured.

## Ranking by business impact

Each finding appears once. Excessive agency covers two tools, and item 1 orders them.

1. **Excessive agency: `issue_refund`, then `delete_record`.** These are the only findings that directly change business assets. Refund ranks above delete because it moves money through a path with no ownership check, and its value limit is unknown. Delete's reach is unmeasured and no deletion occurred. Observed loss is $0 and zero records.
2. **Improper output handling: `db_query`.** Raw SQL could reach whatever the service account can read. No rows were observed, so breadth is unmeasured. A disclosure would be immediate and unrecallable.
3. **Unbounded consumption.** One session could exhaust the 150,000-token ceiling and block other sessions while generating spend. Nothing was consumed in captured attempts, and cost is unknown.
4. **Embedding weakness.** A routine customer query retrieved internal pricing memo kb-900, which includes a $321-per-seat floor and an escalation reference. This is a confirmed disclosure that may affect Enterprise negotiations. Deal count and revenue impact are unknown.
5. **Indirect injection.** One customer-submitted chunk was retrieved at score 0.7582 in a victim session. The model call failed before any tool action, so impact is retrieval only.
6. **Data poisoning.** Two chunks were accepted and indexed. No fresh-session answer containing the seeded assertion was captured, and closing ingestion returned HTTP 403. Impact is stored untrusted content.

## First remediation priority

Fix excessive agency first. The boundary to change is the authority the model holds to call `issue_refund` and `delete_record` directly. Each call must be bound to server-verified customer ownership, with amount, count, and approval limits enforced before execution.

The most interesting finding is the embedding weakness. The internal memo reached a routine query with no adversarial input, which exposes a gap in `segment_internal`: kb-900 was hidden for the tested query, but kb-901 stayed retrievable. Its novelty does not outweigh Larkspur's exposure. A successful refund or deletion changes money or records on each call and can repeat in every session until rate-limited. The memo disclosure is serious but has so far exposed one document. Difficulty is a property of the attacker; severity is a property of Larkspur's losses. The segmentation gap still needs a fix, but second.
