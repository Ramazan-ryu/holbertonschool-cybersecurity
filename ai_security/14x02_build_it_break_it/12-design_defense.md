# Design Defense

Controls sit at separate architectural boundaries because the model is an unreliable decision maker. Each section names the vulnerability class, the boundary mechanism, what that control alone does not cover, and its standalone residual risk from the Task 10 self-attack and peer-exchange retests. No control provides a complete block or borrows coverage from another layer.

## Owned system prompt

**Class:** Instruction-data confusion and prompt disclosure (LLM01, LLM07).

**Mechanism:** Defines the support role, restricts discussion to the signed-in account, and labels retrieved text as untrusted reference data.

**Does not cover:** Model-visible text cannot enforce authorization or confidentiality. It does not stop adversarial prompts from overriding instructions or extracting context. In Task 10 retesting, prompt extraction (LLM07) returned `upstream_error_502`, leaving extraction resistance unmeasured.

**Residual:** LLM07 remains open and unquantified at the prompt boundary: a successful override or extraction exposes the system prompt and any secrets in context, and model updates can shift compliance unexpectedly.

## Parameterized tool output

**Class:** Executable-output injection at the database interface (LLM05).

**Mechanism:** Restricts `db_query` so the model supplies typed parameter values to pre-registered SQL templates rather than raw SQL syntax, binding output strictly as literal data.

**Does not cover:** Parameter binding stops syntax injection inside a statement but does not limit which registered statements exist, which columns they return, or whether the model chooses an over-broad statement with valid parameters. In Task 10 retesting, LLM05 remained partial because no live model-directed exploit completed end to end.

**Residual:** LLM05 remains partially open at the database boundary: an attacker steering parameter values can still trigger over-broad permitted reads across any tables and columns exposed by registered templates.

## Per-tool authorization

**Class:** Broken object-level authorization and excessive agency (LLM06).

**Mechanism:** Verifies the authenticated session identity on the server against the target account owner before executing a tool call.

**Does not cover:** Server ownership checks only block cross-account access; they do not judge whether an action on the user's own account is coerced, harmful, or excessive. New tools are not covered automatically, and Task 10 denial retests ran only in plan mode rather than live mutation.

**Residual:** LLM06 remains partial at this boundary: any state change targeting the signed-in customer's own records passes ownership checks, and live mutation blocking remains unverified outside plan mode.

## Human approval

**Class:** Unverified execution of high-consequence mutations (LLM06).

**Mechanism:** Queues `issue_refund` and `delete_record` calls until a human reviewer approves execution.

**Does not cover:** The queue covers only those two tools, leaving read tools and other endpoints untouched, and does not prevent reviewer error when context is incomplete. In Task 10 self-attack and peer retests, queued calls changed no state, but one own-order deletion remained pending, leaving the approve-and-execute path unverified end to end.

**Residual:** High-consequence mutation risk remains open at the approval boundary due to unmeasured human reviewer error rates and an unverified post-approval execution path.

## Retrieval provenance and ingestion restriction

**Class:** Untrusted ingestion and cross-boundary retrieval leakage (LLM04, LLM08).

**Mechanism:** Rejects public ticket ingestion with HTTP 403 and checks source provenance tags during document writes.

**Does not cover:** Write-time checks do not filter read-time vector search or enforce index segmentation (`segment_internal=false`). In Task 10 retests, restricted internal chunks returned in 3 of 3 local searches and 3 of 3 peer searches (LLM08 failed). The FAQ-suggestion path also bypassed write blocks into retrieval (LLM04 failed), and republishing untrusted text launders provenance.

**Residual:** LLM04 and LLM08 remain fully open at the retrieval boundary: any user can retrieve internal pricing memos (including the $321-per-seat floor), and poisoned FAQ entries remain retrievable across sessions.

## Resource caps

**Class:** Unbounded token and compute consumption (LLM10).

**Mechanism:** Enforces numeric limits on session tokens, request rates, tool iterations, and output length.

**Does not cover:** Volume caps do not inspect payload content or stop data leakage within a single allowed request. Task 10 metrics reported `avg_tokens_per_request` as null, leaving thresholds uncalibrated against real traffic and dependent on a synthetic 1,500-tokens-per-call assumption.

**Residual:** Uncalibrated consumption risk remains open at the resource boundary: repeated calls below the ceiling generate unmeasured provider spend, while legitimate complex sessions risk premature cutoff.

## Input guardrail and output filtering

**Class:** Direct adversarial phrasing (LLM01) and pattern-matched secret leakage (LLM02).

**Mechanism:** Blocks literal or encoded injection strings in chat messages and redacts regex-matched secrets or invalid schemas in replies.

**Does not cover:** In Task 10 retesting, 47 of 60 mutated prompts (78.3%) bypassed the input filter, including all semantic, indirect, multilingual, fake-delimiter, and benign-lookalike variants. Input scanning ignores retrieved text and tickets, while output filtering runs after retrieval and tool execution.

**Residual:** LLM01 remains open at the filter boundary with a 78.3% bypass rate, and sensitive leaks that do not match static secret regexes pass unredacted.

## Removal order under a two-control reduction

**First removed: Input guardrail.** It showed the lowest measured coverage (bypassed by 47 of 60 mutated variants, or 78.3%) and ignores retrieval and ticket channels. Removing it raises the LLM01 bypass residual at the input-filter boundary from 78.3% to 100%, allowing literal zero-effort injection strings to reach the model while leaving the standalone residuals of all other layers unchanged.

**Second removed: Owned system prompt secrecy wording.** Textual secrecy rules are non-enforceable guidance with unmeasured resistance (`upstream_error_502` on LLM07). Removing them leaves the LLM07 prompt-disclosure residual completely open at the prompt boundary, an accepted standalone increase since no other control covers prompt confidentiality.

**Preserved longest:** Per-tool authorization (the sole boundary verifying server-side account ownership), human approval (the sole boundary pausing irreversible refunds and deletions), and parameterized tool output (the sole boundary binding SQL parameters as literal data, though over-broad template reads remain open).

**Weakest kept control:** Retrieval provenance and ingestion restriction. Task 10 retests proved `segment_internal=false` leaked internal pricing in 3 of 3 local and 3 of 3 peer searches (LLM08) and left FAQ poisoning open (LLM04), requiring retrieval segmentation and FAQ ingestion fixes before any retrieval change is approved.
