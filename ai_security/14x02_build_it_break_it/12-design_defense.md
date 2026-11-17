# Design Defense

Controls sit at separate boundaries because the model is an unreliable decision maker. Each section names the vulnerability class, how the control changes that class's attack surface, what it does not cover, and the residual that remains.

## Owned system prompt

**Class:** instruction-data confusion, where untrusted text is followed as instructions, and prompt disclosure.

**Mechanism:** Sets the support role, scopes discussion to the signed-in account, and labels retrieved content as reference. This gives the model an explicit precedence rule between instructions and data.

**Does not cover:** Text inside the model's context cannot enforce authorization or secrecy. A persuasive input can still override it, and extraction resistance (LLM07) is unmeasured.

**Residual:** Prompt contents and any secret placed in context can be extracted, and overrides are not blocked.

## Parameterized tool output

**Class:** executable-output injection, where model-generated text is interpreted as query syntax.

**Mechanism:** The model supplies typed values to registered statements rather than composing SQL. The model can no longer alter query structure, because values are bound as data.

**Does not cover:** Binding does not limit which statements exist, which columns they return, or whether the model selects an over-broad statement with valid values. Those are authorization and data-minimization problems.

**Residual:** Over-broad permitted reads across registered statements remain possible (LLM05 partial).

## Per-tool authorization

**Class:** broken object-level authorization and excessive agency, where a requested target is trusted without a server-side check.

**Mechanism:** The server checks the session identity against the target owner before each tool executes. Authority moves from the model's stated justification to server state.

**Does not cover:** Ownership checks block cross-account access only. They do not judge whether an action on the user's own account is coerced or harmful. Each new tool must add the check itself, and denial tests ran in plan mode, so live enforcement is unverified (LLM06 partial).

**Residual:** Changes to the signed-in customer's own records pass this control and rely on the approval gate.

## Human approval

**Class:** high-consequence action without an independent decision about intent.

**Mechanism:** Refund and deletion requests wait in a queue until a reviewer approves them. A decision point now sits before irreversible state changes.

**Does not cover:** Only the two listed tools are queued. A reviewer who accepts a plausible but false justification approves the harm, and reviewer error rates are unmeasured. The approve-and-execute path is unverified end to end.

**Residual:** A false refund or deletion approved by a reviewer becomes a real transfer or permanent record loss.

## Retrieval provenance and ingestion restriction

**Class:** untrusted retrieval and persistent poisoning, where untrusted content becomes trusted context on later reads.

**Mechanism:** Public ingestion is rejected, and provenance is checked at write time. Direct planting through the public ticket channel is removed from the attack surface.

**Does not cover:** Write-time checks do not govern read-time retrieval. Segmentation is disabled, so internal content is not separated from support content at query time. Republished untrusted text loses its provenance. Restricted chunks were retrievable on two builds (LLM08 falls), and poisoned FAQ content reached retrieval (LLM04 falls).

**Residual:** Any support user can retrieve internal pricing, including the $321-per-seat floor, and poisoned FAQ entries persist across sessions. This is the weakest control.

## Resource caps

**Class:** unbounded consumption, where repeated or long generation exhausts budget or capacity.

**Mechanism:** Numeric limits on session tokens, request rate, tool iterations, and output length cap the cost of any single session.

**Does not cover:** The token cap is per session, so aggregate spend across sessions is unbounded. Caps do not inspect content, so a request within the cap can still disclose retrieved data. Thresholds are uncalibrated because average usage is not measured.

**Residual:** Provider cost grows with session count, and its size is unknown. Long legitimate sessions can be cut off.

## Input guardrail and output filtering

**Class:** adversarial-input evasion and sensitive-output leakage. Both are attacked by variation, so pattern matching raises effort without closing either class.

**Mechanism:** The input filter blocks known injection patterns in messages. Output redaction and schema checks remove matched secret formats and malformed replies.

**Does not cover:** Paraphrase, indirection, and other languages pass the filter. It ignores tickets and retrieved text. Output filtering runs after retrieval and tool calls, so it cannot stop data being fetched or actions executing. Secrets without a matched format pass unredacted.

**Residual:** LLM01 remains open at the filter boundary: about four in five mutated attempts in the measured set reached the agent.

## Removal order under a two-control reduction

**First removed: input guardrail.** Its class is adversarial-input evasion, and it addresses only known patterns. Removing it leaves known-pattern injection unscreened at the message boundary. The cost is that the model sees more hostile input, but per-tool authorization and human approval still bound what a manipulated request can execute. They do not stop manipulation, so LLM01 residual rises and is accepted, not offset.

**Second removed: owned system prompt.** Its class is instruction-data confusion, which it reduces through stated precedence but cannot enforce. Removing it increases the chance that quoted text is followed as instruction and that context is extracted. Authorization and parameterized output still limit actions regardless of model belief, but they do not prevent disclosure of text in context. The new residual is unmeasured LLM07 prompt disclosure.

**Preserved longest:** per-tool authorization, because it is the only control deciding whether a session may act on a target. Human approval is next, because it governs irreversible refunds and deletions. Parameterized output follows, because it removes executable injection at the database boundary.

**Weakest:** retrieval provenance and ingestion restriction. No remaining control stops untrusted content or restricted chunks from being retrieved and served, so it must be fixed before approval.
