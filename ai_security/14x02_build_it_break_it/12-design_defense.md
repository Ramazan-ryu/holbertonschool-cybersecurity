# Design Defense

Security controls sit at separate architectural boundaries because the language model is an unreliable decision maker. Each section below identifies the targeted vulnerability class, the exact technical mechanism at that boundary, what that specific control does not cover on its own, and the resulting standalone residual risk tied to the Task 10 self-attack and peer-exchange retests. No control provides a complete block or borrows coverage from another layer.

## Owned system prompt

**Class:** Instruction-data confusion and system prompt disclosure (LLM01, LLM07).

**Mechanism:** Defines the assistant support role, instructs the model to restrict discussion to the signed-in customer account, and labels retrieved chunks as untrusted reference text.

**Does not cover:** This layer consists solely of model-visible text inside the context window and cannot enforce identity, tool boundaries, or secret confidentiality. It does not prevent adversarial instructions from overriding persona rules or extracting context tokens. In Task 10 retesting, prompt extraction (LLM07) returned `upstream_error_502`, leaving actual extraction resistance unmeasured.

**Residual:** LLM07 remains open and unquantified at this boundary: any successful prompt override or extraction directly exposes the system instructions and any sensitive strings present in the prompt context, and model updates can alter instruction compliance without warning.

## Parameterized tool output

**Class:** Executable-output injection at the database query interface (LLM05).

**Mechanism:** Restricts `db_query` so the model supplies typed parameter values to pre-registered SQL statement templates rather than raw SQL syntax, binding model output strictly as literal data.

**Does not cover:** This control only prevents syntax manipulation inside a query; it does not restrict which pre-registered statements exist, which tables or columns those statements return, or whether the model selects an inappropriate statement with valid parameter types. In Task 10 retesting, LLM05 remained partial because no live model-directed exploitation completed, leaving permitted query breadth untested end to end.

**Residual:** LLM05 remains partially open at the database boundary: an attacker who influences parameter selection can still execute over-broad data reads across any rows and columns exposed by the registered statement templates.

## Per-tool authorization

**Class:** Broken object-level authorization and excessive agency (LLM06).

**Mechanism:** Validates the authenticated session identity on the server against the target account or record owner before allowing a tool call to execute.

**Does not cover:** This boundary checks only cross-account ownership; it does not evaluate whether an authorized user's action on their own account is harmful, coerced, or excessive in volume. Furthermore, it does not automatically wrap newly registered tools, and Task 10 denial retests executed only in plan mode rather than live state mutation.

**Residual:** LLM06 remains partial at this layer: any action targeting the signed-in victim's own orders or records passes ownership verification completely, and live mutation enforcement remains unverified outside plan mode.

## Human approval

**Class:** Unverified execution of high-consequence state changes (LLM06).

**Mechanism:** Intercepts `issue_refund` and `delete_record` calls and holds them in a pending queue until a human operator explicitly approves execution.

**Does not cover:** This gate covers only those two specific tools and leaves all read tools and unguarded endpoints untouched. It also does not guarantee that reviewers have sufficient context to spot social engineering. In Task 10 self-attack and peer retesting, queued requests did not mutate state, but one own-order deletion remained pending in the queue, leaving the final approve-and-execute code path unverified end to end.

**Residual:** High-consequence mutation risk remains open to human reviewer error (with an unmeasured operator approval failure rate) and an unverified post-approval execution path.

## Retrieval provenance and ingestion restriction

**Class:** Untrusted data ingestion and cross-boundary retrieval disclosure (LLM04, LLM08).

**Mechanism:** Blocks public user ticket ingestion with HTTP 403 and checks source provenance tags during document write operations.

**Does not cover:** Write-time checks do not filter read-time vector retrieval or enforce index segmentation (`segment_internal=false`). In Task 10 retesting, restricted internal chunks were returned in 3 of 3 self-attack searches and 3 of 3 peer-endpoint searches (LLM08 failed). Additionally, the FAQ-suggestion ingestion path bypassed write blocks and reached retrieval (LLM04 failed), and untrusted text republished into an approved source launders provenance.

**Residual:** Both LLM04 and LLM08 remain fully open at the retrieval boundary: any user query can retrieve internal pricing memos (including the $321-per-seat floor), and poisoned FAQ entries remain retrievable across customer sessions.

## Resource caps

**Class:** Unbounded token and compute consumption (LLM10).

**Mechanism:** Enforces numeric ceilings on per-session tokens, request rates, tool-call iterations, and output length.

**Does not cover:** Volume thresholds do not inspect payload semantics or prevent data leakage within a single permitted call. Moreover, Task 10 metrics showed `avg_tokens_per_request` as null, meaning caps are uncalibrated against production traffic and LLM10 pass results hold only under a synthetic 1,500-tokens-per-call assumption.

**Residual:** Uncalibrated resource exhaustion remains open: attackers can sustain repeated provider spend right below the threshold with unmeasured dollar cost, while legitimate multi-turn support sessions face premature truncation.

## Input guardrail and output filtering

**Class:** Direct adversarial phrasing (input side, LLM01) and pattern-matched secret leakage (output side, LLM02).

**Mechanism:** Scans incoming chat messages for literal or base64-encoded injection strings and redacts regex-matched secret patterns or invalid schemas from final replies.

**Does not cover:** In Task 10 retesting, 47 of 60 mutated adversarial prompts (78.3%) bypassed the input filter, including 100% of semantic, indirect, multilingual, fake-delimiter, and benign-lookalike variants. The input scanner also ignores retrieval and ticket channels completely, while output redaction runs only after tools and retrieval have already executed.

**Residual:** LLM01 remains open at this boundary with a 78.3% measured bypass rate, and semantic disclosures that do not match static secret regexes pass through output filtering unredacted.

## Removal order under a two-control reduction

**First removed: Input guardrail.** It has the worst measured effectiveness (failing on 47 of 60 mutated prompts, or 78.3%) and inspects only the direct chat channel. Removing it increases the LLM01 residual on this boundary from a 78.3% bypass rate to 100%, allowing literal zero-effort injection phrases to reach the model directly without changing the separate residual risks of any other layer.

**Second removed: Owned system prompt secrecy wording.** Textual secrecy instructions provide no enforceable boundary and had zero verified resistance during Task 10 retesting (`upstream_error_502`). Removing this wording leaves the LLM07 prompt-disclosure residual completely open to trivial asks, an accepted loss on the prompt layer alone because no other control covers prompt confidentiality.

**Preserved longest:** Per-tool authorization (the sole boundary enforcing server-side account ownership on tool targets), human approval (the sole boundary pausing irreversible refund and deletion mutations), and parameterized tool output (the sole boundary preventing raw SQL syntax injection in `db_query`, even though over-broad template reads remain open).

**Weakest kept control:** Retrieval provenance and ingestion restriction. Task 10 evidence proved that `segment_internal=false` allowed 3 of 3 internal leaks on both local and peer endpoints (LLM08) and left the FAQ poisoning path open (LLM04), making retrieval segmentation and FAQ ingestion fixes mandatory before any retrieval changes are approved.
