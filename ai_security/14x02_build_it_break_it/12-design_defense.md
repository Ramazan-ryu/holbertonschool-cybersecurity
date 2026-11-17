# Design Defense

Controls sit at separate boundaries because the model is an unreliable decision maker. Each section states the targeted class, the mechanism, what that control alone does not cover, and its standalone residual from the Task 10 retests. No control provides a complete block, and no section relies on another layer's coverage.

## Owned system prompt

**Class:** Instruction-data confusion and prompt disclosure (LLM01, LLM07).

**Mechanism:** Sets the support role, restricts discussion to the signed-in account, and labels retrieved chunks as untrusted reference text.

**Does not cover:** Model-visible text cannot enforce authorization or secret confidentiality, nor stop adversarial prompts from overriding instructions or extracting context. In Task 10 retests, prompt extraction (LLM07) returned `upstream_error_502`, leaving resistance unmeasured.

**Residual:** LLM07 remains open and unquantified at the prompt boundary: successful extraction exposes system instructions and context secrets, and model updates can shift compliance.

## Parameterized tool output

**Class:** Executable-output injection at the database interface (LLM05).

**Mechanism:** Restricts `db_query` so the model supplies typed parameters to registered SQL templates rather than raw SQL, binding values as literal data.

**Does not cover:** Parameter binding prevents syntax injection inside a query. It does not limit which registered statements exist, which columns they return, or whether the model selects an over-broad statement with valid parameters. In Task 10 retests, LLM05 remained partial because no live model-directed exploit completed.

**Residual:** LLM05 remains partially open at the database boundary: steering parameters still allows over-broad permitted reads across the rows and columns exposed by registered templates.

## Per-tool authorization

**Class:** Broken object-level authorization and excessive agency (LLM06).

**Mechanism:** Verifies the authenticated session identity on the server against the target account owner before executing a tool call.

**Does not cover:** Ownership checks block cross-account access only. They do not evaluate whether an action on the user's own account is coerced, harmful, or excessive. New tools are not wrapped automatically, and the Task 10 denial retests ran only in plan mode, not live mutation.

**Residual:** LLM06 remains partial at this boundary: state changes targeting the signed-in customer's own records pass ownership checks, and live mutation enforcement remains unverified outside plan mode.

## Human approval

**Class:** Unverified execution of high-consequence mutations (LLM06).

**Mechanism:** Queues `issue_refund` and `delete_record` calls until a human reviewer approves execution.

**Does not cover:** The queue covers only those two tools, so harmful actions through any other tool are not queued. The approval screen shows the requester's stated reason, and a reviewer who accepts a plausible but false reason approves the harm. Reviewer error rates were not measured. In Task 10 retests, queued calls changed no state, but one own-order deletion remained pending, so the approve-and-execute path is unverified end to end.

**Residual:** A plausible but false refund or deletion request, approved by a reviewer, executes as a real transfer or permanent record loss. Approval volume per reviewer is unmeasured, so the number of such approvals the process can absorb is unknown.

## Retrieval provenance and ingestion restriction

**Class:** Untrusted ingestion and cross-boundary retrieval leakage (LLM04, LLM08).

**Mechanism:** Rejects public ticket ingestion with HTTP 403 and checks provenance tags during document writes.

**Does not cover:** Write-time checks do not filter read-time vector search or enforce segmentation (`segment_internal=false`). In Task 10 retests, restricted chunks were returned in 3 of 3 local searches and 3 of 3 peer searches (LLM08 failed). The FAQ-suggestion path bypassed write blocks into retrieval (LLM04 failed), and republishing untrusted text launders its provenance.

**Residual:** LLM04 and LLM08 remain fully open at the retrieval boundary: any user can retrieve internal pricing memos, including the $321-per-seat floor, and poisoned FAQ entries remain retrievable across sessions.

## Resource caps

**Class:** Unbounded token and compute consumption (LLM10).

**Mechanism:** Enforces numeric limits on session tokens, request rate, tool iterations, and output length.

**Does not cover:** The token cap is per session. It does not bound aggregate spend across concurrent or repeated sessions, and no global ceiling was tested. Caps also do not inspect content: one request within the token cap can disclose whatever retrieval supplies. `avg_tokens_per_request` is null, so the thresholds are uncalibrated, and the LLM10 result holds only under the 1,500-tokens-per-call assumption.

**Residual:** Provider cost grows with the number of sessions, not with the 8,000-token cap, and the dollar exposure is unmeasured. Legitimate long sessions can be cut off at the threshold.

## Input guardrail and output filtering

**Class:** Direct adversarial phrasing (LLM01) and pattern-matched secret leakage (LLM02).

**Mechanism:** Blocks literal or encoded injection strings in chat messages, and redacts regex-matched secrets or invalid schemas in replies.

**Does not cover:** In Task 10 retests, 47 of 60 mutated prompts (78.3%) bypassed the input filter, including all semantic, indirect, multilingual, fake-delimiter, and benign-lookalike variants. Input scanning ignores retrieved text and tickets. Output filtering runs after retrieval and tool execution, so it cannot stop data from being fetched or an action from executing.

**Residual:** LLM01 remains open at the filter boundary with a 78.3% bypass rate. Secrets that do not match the static regexes pass unredacted. This control raises attacker effort and removes no class.

## Removal order under a two-control reduction

**First removed: input guardrail.** It has the lowest measured coverage: it blocked 13 of 60 mutated prompts (about one in five) and ignores retrieval and tickets. Removal leaves LLM01 with no message-channel screening. The cost is that the marginal screening it provided is lost. It adds no residual to other controls, because it never covered retrieval or tool calls.

**Second removed: owned system prompt secrecy wording.** It is non-enforceable text with unmeasured resistance (`upstream_error_502` on LLM07). Removal leaves the LLM07 prompt-disclosure residual fully open at the prompt boundary, and no other control covers that gap.

**Preserved longest:** per-tool authorization, which is the only control that decides whether a session may act on a target; human approval, for refunds and deletions the model cannot reverse; and parameterized tool output, which removes executable SQL injection at the database boundary, while over-broad template reads remain open.

**Weakest kept control:** retrieval provenance and ingestion restriction. Task 10 retests showed restricted pricing returned in 3 of 3 local and 3 of 3 peer searches (LLM08) and FAQ poisoning reaching retrieval (LLM04). Segmentation and FAQ-source fixes are required before this control can be approved.
