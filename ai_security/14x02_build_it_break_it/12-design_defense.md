# Design Defense

Controls sit at separate boundaries because the model is an unreliable decision maker. Each section states the targeted class, the mechanism, what that control alone does not cover, and its standalone residual from the Task 10 retests. No control provides a complete block, and no section relies on another layer's coverage.

## Owned system prompt

**Class:** Instruction-data confusion and prompt disclosure (LLM01, LLM07).

**Mechanism:** Sets the support role, restricts discussion to the signed-in account, and labels retrieved chunks as untrusted reference text.

**Does not cover:** Model-visible text cannot enforce authorization or secret confidentiality, nor stop adversarial prompts from overriding instructions. Prompt extraction (LLM07) returned `upstream_error_502` in Task 10, so resistance is unmeasured.

**Residual:** LLM07 remains open and unquantified at the prompt boundary. Successful extraction exposes system instructions and any secret in context.

## Parameterized tool output

**Class:** Executable-output injection at the database interface (LLM05).

**Mechanism:** The model supplies typed parameters to registered SQL templates, not raw SQL. Values are bound as literal data.

**Does not cover:** Binding prevents syntax injection inside a query. It does not limit which registered statements exist, which columns they return, or whether the model selects an over-broad statement with valid parameters. LLM05 stayed partial in Task 10 because no live model-directed exploit completed.

**Residual:** Over-broad permitted reads across the rows and columns exposed by registered templates remain possible.

## Per-tool authorization

**Class:** Broken object-level authorization and excessive agency (LLM06).

**Mechanism:** The server verifies the authenticated session identity against the target account owner before executing a tool call.

**Does not cover:** Ownership checks block cross-account access only. They do not judge whether an action on the user's own account is coerced, harmful, or excessive. New tools are not wrapped automatically. The Task 10 denial retests ran in plan mode, not live mutation.

**Residual:** LLM06 remains partial. State changes to the signed-in customer's own records pass ownership checks, and live mutation enforcement is unverified.

## Human approval

**Class:** Unverified execution of high-consequence mutations (LLM06).

**Mechanism:** Queues `issue_refund` and `delete_record` until a human reviewer approves execution.

**Does not cover:** The queue covers only those two tools. A reviewer who accepts a plausible but false reason approves the harm, and reviewer error rates were not measured. In Task 10, queued calls changed no state, but one own-order deletion remained pending, so the approve-and-execute path is unverified end to end.

**Residual:** A false refund or deletion request approved by a reviewer executes as a real transfer or permanent record loss. The approval volume a reviewer can absorb is unmeasured.

## Retrieval provenance and ingestion restriction

**Class:** Untrusted ingestion and cross-boundary retrieval leakage (LLM04, LLM08).

**Mechanism:** Rejects public ticket ingestion with HTTP 403 and checks provenance tags at document write time.

**Does not cover:** Write-time checks do not filter read-time vector search or enforce segmentation (`segment_internal=false`). In Task 10, restricted chunks were returned in 3 of 3 local and 3 of 3 peer searches (LLM08 failed). The FAQ-suggestion path reached retrieval (LLM04 failed), and republishing untrusted text launders its provenance.

**Residual:** Any user can retrieve internal pricing memos, including the $321-per-seat floor, and poisoned FAQ entries remain retrievable across sessions.

## Resource caps

**Class:** Unbounded token and compute consumption (LLM10).

**Mechanism:** Numeric limits on session tokens, request rate, tool iterations, and output length.

**Does not cover:** The token cap is per session. It does not bound aggregate spend across repeated or concurrent sessions, and no global ceiling was tested. Caps do not inspect content, so one request within the cap can disclose whatever retrieval supplies. `avg_tokens_per_request` is null, so the thresholds are uncalibrated.

**Residual:** Provider cost grows with session count, and the dollar exposure is unmeasured. Legitimate long sessions can be cut off at the threshold.

## Input guardrail and output filtering

**Class:** Direct adversarial phrasing (LLM01) and pattern-matched secret leakage (LLM02).

**Mechanism:** Blocks literal or encoded injection strings in chat messages, and redacts regex-matched secrets or invalid schemas in replies.

**Does not cover:** In Task 10, 47 of 60 mutated prompts (78.3%) bypassed the input filter, including every semantic, indirect, multilingual, fake-delimiter, and benign-lookalike variant. Input scanning ignores retrieved text and tickets. Output filtering runs after retrieval and tool execution, so it cannot stop data being fetched or an action executing.

**Residual:** LLM01 remains open at the filter boundary. Secrets that do not match the static regexes pass unredacted. This control raises attacker effort and removes no class.

## Removal order under a two-control reduction

**First removed: input guardrail.** It blocked 13 of 60 mutated prompts and ignores retrieval and tickets. Removal leaves LLM01 with no message-channel screening, and the lost screening is a real cost. It adds no residual to other controls, because it never covered retrieval or tool calls.

**Second removed: owned system prompt secrecy wording.** It is non-enforceable text with unmeasured resistance. Removal leaves the LLM07 prompt-disclosure residual fully open, and no other control covers that gap.

**Preserved longest:** per-tool authorization, the only control deciding whether a session may act on a target; human approval, for refunds and deletions the model cannot reverse; and parameterized output, which removes executable SQL injection at the database boundary.

**Weakest kept control:** retrieval provenance and ingestion restriction. Restricted pricing and poisoned FAQ content both reached retrieval in Task 10. Segmentation and FAQ-source fixes are required before this control can be approved.
