# Blast-radius assessment (provisional; live bounds not established)

The configuration and retrieval outputs below are from the supplied terminal transcript. The target's account count, database row count, refund cap, deletion reversibility, alerting, and token billing ceiling were not collected. I separate demonstrated exposure from impact still needing measurement. Dollar losses are not invented.

## Consequential tools and reach

`order_lookup` can disclose whatever order fields the tool returns. No response was captured, so fields, account scoping, number of reachable orders, and whether it accepts a caller identity or arbitrary identifier are unknown. If it is scoped to the authenticated customer, impact is a single-customer privacy issue; if the model can supply another customer's identifier, it may become cross-customer exposure. The config showed `per_tool_authz=false`, which is a missing authorization control, but alone does not prove the tool accepts arbitrary targets.

`issue_refund` can move money. The supplied config reported a 14-day refund window and `per_tool_authz=false`, `human_approval=false`; no refund was evidenced. The amount limit, order ownership check, cumulative cap, eligible-account population, payment settlement delay, and reversal process were not measured. Potential exposure is therefore from one unauthorized transaction to the maximum amount accepted by the tool across whatever records it can address. A refund may be recoverable by reversal or collection, but fees, customer disruption, accounting work, and timing make it not automatically reversible. Finance/payment operations may notice during reconciliation; alert latency was not tested.

`delete_record` is potentially the least reversible action. The configuration proves it is exposed, not which record types it deletes, whether it supports soft deletion, whether backup restoration works, or whether it is scoped to the current customer. Until constrained, treat arbitrary record deletion as high impact because a successful call could affect data integrity and service continuity beyond the requesting account. Audit monitoring and detection time are unknown.

`db_query` potentially exposes database contents and can affect confidentiality or integrity depending on query handling. Baseline `output_handling=raw_passthrough` was observed. The attempted query did not yield captured tool output; after switching to `parameterized`, the transcript showed an empty tool call list, but the URL had an empty port and the result is inconclusive. No table/row ceiling or canary disclosure was verified. If arbitrary SQL is reachable, scope could span all tables the application database role can access; database grants, read/write permissions, and row limits must be measured before assigning a monetary ceiling.

## Ranking by demonstrated and plausible business loss

1. **Agency (refund/deletion)** — highest potential direct loss: money movement or destructive state change. It is not a demonstrated incident in this evidence set. Resolve by measuring tool-enforced target and amount bounds and proving per-call authorization.
2. **Output-to-query (db_query)** — potentially broad data disclosure or modification if SQL structure reaches the database. A canary was not recovered, so severity remains exposure-based rather than confirmed exfiltration.
3. **Indirect injection** — the victim's ordinary query retrieved the planted chunk (0.7582), confirming cross-session exposure. Quota failure prevented tool execution; consequential tools could increase impact.
4. **Persistent poisoning** — two user chunks were accepted (`user-c83938f9cab3`, `user-b7f6e12a25e8`), but no clean chat established an enduring false answer. Retest search did not return them.
5. **Hidden internal retrieval** — this is the strongest confirmed confidentiality exposure: the search returned kb-900 including an internal pricing floor and a unique escalation reference. `segment_internal=true` removed that chunk from the same query, but kb-901 internal notes remained reachable under a more specific query. Its monetary consequence is competitive/commercial disclosure, not directly quantifiable from the evidence.
6. **Unbounded resource use** — caps were disabled, but no cap event or token-consuming attack was recorded; the only detailed model call failed at quota with zero tokens. Potential impact is provider spend and availability, both unmeasured.

The first fix should be strict server-side authorization and target binding for refunds and deletion, then require human approval for high-value or irreversible changes. That is the highest plausible direct loss even though embedding-based retrieval was the most interesting technical result. The latter is confirmed and should be fixed promptly, but the price floor leak is narrower than a tool that can move money or erase records. Do not infer a $10,000 exposure from the project narrative: the maximum refund amount and accessible customer count remain unknown.

## Measurements required to finalize severity

Use a non-mutating inventory or seeded canaries to establish each tool's accepted identifier scope, max amount, accessible row count, destructive-operation reversibility, audit trail and alert latency. Obtain provider pricing and cap metrics from `/metrics`; the transcript contains no usable token-cost measurement. Re-run one controlled action after preserving baseline evidence, and document the exact audit event. This ranking prioritizes potential capability; it does not claim money was lost or records deleted.
