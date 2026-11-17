# Design Defense

Controls sit at separate boundaries because the model is an unreliable decision maker. Each section states the targeted class, mechanism, what that control alone does not cover, and its standalone residual risk from Task 10 self-attack and peer-exchange retests. No control provides a complete block or borrows coverage from another layer.

## Owned system prompt

**Class:** Instruction-data confusion and prompt disclosure (LLM01, LLM07).

**Mechanism:** Sets the support role, restricts discussion to the signed-in account, and labels retrieved chunks as untrusted reference text.

**Does not cover:** Model-visible text cannot enforce authorization or secret confidentiality, nor stop adversarial prompts from overriding instructions or extracting context. In Task 10 retests, prompt extraction (LLM07) returned `upstream_error_502`, leaving resistance unmeasured.

**Residual:** LLM07 remains open and unquantified at the prompt boundary: successful extraction exposes system instructions and context secrets, and model updates can shift compliance.

## Parameterized tool output

**Class:** Executable-output injection at the database interface (LLM05).

**Mechanism:** Restricts `db_query` so the model supplies typed parameters to registered SQL templates rather than raw SQL syntax, binding output as literal data.

**Does not cover:** Parameter binding prevents syntax injection inside a query but does not limit which registered statements exist, which columns they return, or whether the model chooses an over-broad statement with valid parameters. In Task 10 retests, LLM05 remained partial because no live model-directed exploit completed.

**Residual:** LLM05 remains partially open at the database boundary: steering parameters still allows over-broad permitted reads across rows and columns exposed by registered templates.

## Per-tool authorization

**Class:** Broken object-level authorization and excessive agency (LLM06).

**Mechanism:** Verifies authenticated session identity on the server against the target account owner before executing a tool call.

**Does not cover:** Ownership checks block only cross-account access; they do not evaluate whether an action on the user's own account is coerced, harmful, or excessive. New tools are not wrapped automatically, and Task 10 denial retests ran only in plan mode rather than live mutation.

**Residual:** LLM06 remains partial at this boundary: state changes targeting the signed-in customer's own records pass ownership checks, and live mutation enforcement remains unverified outside plan mode.

## Human approval

**Class:** Unverified execution of high-consequence mutations (LLM06).

**Mechanism:** Queues `issue_refund` and `delete_record` calls until a human reviewer approves execution.

**Does not cover:** The queue covers only those two tools, leaving read tools untouched, and cannot prevent reviewer error when context is incomplete. In Task 10 retests, queued calls changed no state, but one own-order deletion remained pending, leaving the approve-and-execute path unverified end to end.

**Residual:** High-consequence mutation risk remains open at the approval boundary due to unmeasured reviewer error rates and an unverified post-approval execution path.

## Retrieval provenance and ingestion restriction

**Class:** Untrusted ingestion and cross-boundary retrieval leakage (LLM04, LLM08).

**Mechanism:** Rejects public ticket ingestion with HTTP 403 and checks provenance tags during document writes.

**Does not cover:** Write-time checks do not filter read-time vector search or enforce segmentation (`segment_internal=false`). In Task 10 retests, restricted chunks returned in 3 of 3 local searches and 3 of 3 peer searches (LLM08 failed). The FAQ-suggestion path bypassed write blocks into retrieval (LLM04 failed), and republishing untrusted text launders provenance.

**Residual:** LLM04 and LLM08 remain fully open at the retrieval boundary: any user can retrieve internal pricing memos ($321-per-seat floor), and poisoned FAQ entries remain retrievable across sessions.

## Resource caps

**Class:** Unbounded token and compute consumption (LLM10).

**Mechanism:** Enforces numeric limits on session tokens, request rates, tool iterations, and output length.

**Does not cover:** Volume caps do not inspect content or stop data leakage within one allowed request. Task 10 metrics reported `avg_tokens_per_request` as null, leaving thresholds uncalibrated against real traffic and dependent on a 1,500-tokens-per-call assumption.

**Residual:** Uncalibrated consumption risk remains open at the resource boundary: repeated calls below the ceiling generate unmeasured provider spend, while legitimate long sessions risk premature cutoff.

## Input guardrail and output filtering

**Class:** Direct adversarial phrasing (LLM01) and pattern-matched secret leakage (LLM02).

**Mechanism:** Blocks literal or encoded injection strings in chat messages and redacts regex-matched secrets or invalid schemas in replies.

**Does not cover:** In Task 10 retests, 47 of 60 mutated prompts (78.3%) bypassed the input filter, including all semantic, indirect, multilingual, fake-delimiter, and benign-lookalike variants. Input scanning ignores retrieved text and tickets, while output filtering runs after retrieval and tool execution.

**Residual:** LLM01 remains open at the filter boundary with a 78.3% bypass rate, and sensitive leaks not matching static secret regexes pass unredacted.

## Removal order under a two-control reduction

**First removed: Input guardrail.** Lowest measured coverage (47 of 60 mutated prompts bypassed, 78.3%) and ignores retrieval and tickets. Removal raises the LLM01 bypass residual at this boundary from 78.3% to 100% without changing any other layer's standalone residual.

**Second removed: Owned system prompt secrecy wording.** Non-enforceable text with unmeasured resistance (`upstream_error_502` on LLM07). Removal leaves the LLM07 prompt-disclosure residual completely open at the prompt boundary.

**Preserved longest:** Per-tool authorization (server-side account ownership checks), human approval (pausing irreversible refunds and deletions), and parameterized tool output (binding SQL parameters as literal data, though over-broad template reads remain open).

**Weakest kept control:** Retrieval provenance and ingestion restriction. Task 10 retests showed `segment_internal=false` leaked internal pricing in 3 of 3 local and 3 of 3 peer searches (LLM08) and left FAQ poisoning open (LLM04), requiring segmentation and FAQ fixes before approval.
