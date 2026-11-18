# Design Defense

Controls sit at separate boundaries because the model is an unreliable decision maker. Each section states the vulnerability class, how the control changes its attack surface, what it does not cover, and the residual risk.

## Owned system prompt

**Class:** instruction-data confusion and prompt disclosure, where untrusted text is followed as instructions or directives are extracted.

**Mechanism:** Defines the support role, scopes tasks to the signed-in account, and marks retrieved text as reference, setting in-context precedence.

**Does not cover:** Raises attacker effort against naive overrides without eliminating instruction-data confusion because models cannot enforce hard boundaries between instructions and data. Persuasive framing still overrides it, and extraction resistance (LLM07) is unmeasured.

**Residual:** LLM01 and LLM07 remain open in context; directives and secrets in context can still be overridden or extracted (LLM07 unmeasured).

## Parameterized tool output

**Class:** executable-output injection, where model output is interpreted as query syntax.

**Mechanism:** Supplies typed values to registered statements instead of composing SQL, so bound parameters cannot alter query structure.

**Does not cover:** Eliminates SQL syntax injection on bound fields without restricting available statements, returned columns, or over-broad statement selection using valid values.

**Residual:** LLM05 is partially closed (LLM05 partial): syntax injection is eliminated on bound calls, while over-broad permitted reads remain open.

## Per-tool authorization

**Class:** broken object-level authorization and excessive agency, where a target is trusted without a server-side ownership check.

**Mechanism:** Checks session identity against the target owner before execution, enforcing authority from server state rather than model claims.

**Does not cover:** Eliminates cross-account access on covered tools without judging whether same-account actions were coerced via prompt injection. New tools must wire the check manually, and denial tests ran in plan mode rather than live execution (LLM06 partial).

**Residual:** Coerced actions on the signed-in user's records remain open and rely on human approval, while live enforcement is unverified (LLM06 partial).

## Human approval

**Class:** high-consequence action without an independent human decision on intent.

**Mechanism:** Queues refund and deletion calls until a reviewer approves them, adding a human gate before irreversible changes.

**Does not cover:** Raises attacker effort by requiring a plausible excuse without eliminating coerced actions. Unlisted tools bypass the queue, deceived reviewers approve harm, reviewer error rates are unmeasured, and live execution is unverified.

**Residual:** LLM06 and LLM09 remain partially open: unqueued tools run immediately, and approved false requests cause real refunds or data loss.

## Retrieval provenance and ingestion restriction

**Class:** untrusted retrieval and persistent poisoning, where untrusted text enters storage or becomes trusted context across sessions.

**Mechanism:** Rejects public ingestion and checks provenance at write time, blocking direct planting via public tickets.

**Does not cover:** Write-time checks raise effort against direct planting without eliminating retrieval exposure or indirect poisoning. Read-time segmentation is disabled, and republished text loses untrusted provenance. Restricted chunks were retrieved across two builds (LLM08 falls) and poisoned FAQ content reached retrieval (LLM04 falls).

**Residual:** Weakest control because both boundaries failed in retesting: LLM08 falls at the read boundary, exposing restricted internal pricing ($321-per-seat floor) to any user, and LLM04 falls at the pipeline boundary, letting poisoned FAQ entries persist across sessions.

## Resource caps

**Class:** unbounded consumption, where repeated or long generation exhausts budget or capacity.

**Mechanism:** Per-session limits on tokens, request rate, tool iterations, and output length bound single-session work.

**Does not cover:** Raises attacker effort by forcing session rotation without eliminating unbounded consumption across parallel or rotated sessions (LLM10 partial). Caps are content-blind, so short requests still leak data, and thresholds are uncalibrated.

**Residual:** LLM10 remains partially open (LLM10 partial): single-session loops are bounded, while multi-session spend and denial-of-wallet remain open.

## Input guardrail and output filtering

**Class:** adversarial-input evasion and sensitive-output leakage across message boundaries.

**Mechanism:** Regex filters block known injection strings in messages, and output redaction strips matched secret formats.

**Does not cover:** Raises attacker effort against literal strings without eliminating either class. Paraphrase, indirection, and other languages bypass the input filter, which ignores tickets and retrieved text. Output redaction runs post-execution, missing unformatted secrets like conversational price disclosures.

**Residual:** LLM01 and LLM02 remain open while only literal strings are harder: four in five mutated prompts bypassed the filter, and unformatted secrets pass unredacted.

## Removal order under a two-control reduction

**First removed: input guardrail and output filtering.** Adds latency, regex maintenance, and false-positive cost. Overlaps with downstream compensating controls—parameterized output, per-tool authorization, and human approval—bounding what a manipulated model executes. Removal drops literal-string screening, raising the LLM01 and LLM02 residual so unmutated attacks reach the model without raising effort.

**Second removed: owned system prompt.** Adds per-turn token overhead and maintenance cost. Overlaps with compensating controls—server-side per-tool authorization and parameterized output—enforcing data and action boundaries regardless of model compliance. Removal drops in-context precedence, increasing residual risk for instruction-data confusion (LLM01) and unmeasured prompt disclosure (LLM07).

**Preserved longest (load-bearing):** per-tool authorization, the sole control enforcing account ownership; human approval, the sole gate before irreversible refunds and deletions; and parameterized output, eliminating SQL syntax injection.

**Weakest control:** retrieval provenance and ingestion restriction, where LLM08 falls and LLM04 falls leave restricted and poisoned content exposed without compensating read-time controls.
