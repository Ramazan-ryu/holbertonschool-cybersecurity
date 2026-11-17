# Design Defense

Controls sit at separate boundaries because the model is an unreliable decision maker. Each section states the vulnerability class, how the control changes its attack surface, what it does not cover, and the resulting residual risk.

## Owned system prompt

**Class:** instruction-data confusion and prompt disclosure, where untrusted text is followed as instructions or directives are extracted.

**Mechanism:** Defines the support role, scopes tasks to the signed-in account, and marks retrieved text as reference, giving an in-context precedence rule.

**Does not cover:** In-context rules raise attacker effort against naive overrides without eliminating instruction-data confusion because the model cannot enforce a hard boundary between instructions and data. Persuasive framing still overrides it, and extraction resistance (LLM07) is unmeasured.

**Residual:** LLM01 and LLM07 remain open in context; directives and secrets in context can be overridden or extracted (LLM07 unmeasured).

## Parameterized tool output

**Class:** executable-output injection, where model output is interpreted as query syntax.

**Mechanism:** The model supplies typed values to registered statements rather than composing SQL. Bound parameters cannot alter query structure.

**Does not cover:** Binding eliminates SQL syntax injection on bound fields, but does not restrict which statements exist, which columns they return, or whether the model chooses an over-broad statement with valid values.

**Residual:** LLM05 is partially closed (LLM05 partial): syntax injection is eliminated on bound calls, while over-broad permitted reads remain open.

## Per-tool authorization

**Class:** broken object-level authorization and excessive agency, where a target is trusted without a server-side ownership check.

**Mechanism:** The server checks session identity against the target owner before execution, enforcing authority from server state rather than model claims.

**Does not cover:** It eliminates cross-account access on covered tools, but cannot judge whether a same-account action was coerced by prompt injection. New tools must add the check manually, and denial tests ran in plan mode rather than live execution (LLM06 partial).

**Residual:** Coerced actions on the signed-in user's own records remain open and rely on human approval, while live enforcement is unverified (LLM06 partial).

## Human approval

**Class:** high-consequence action without an independent human decision on intent.

**Mechanism:** Refund and deletion calls wait in a queue until a reviewer approves them, adding a human gate before irreversible changes.

**Does not cover:** Approval raises attacker effort by requiring a plausible excuse, without eliminating coerced actions. Unlisted tools bypass the queue, a reviewer fooled by a false rationale approves the harm, reviewer error rates are unmeasured, and live execution is unverified.

**Residual:** LLM06 and LLM09 remain partially open: unqueued tools run immediately, and rubber-stamped false requests cause real refunds or data loss.

## Retrieval provenance and ingestion restriction

**Class:** untrusted retrieval and persistent poisoning, where untrusted text enters storage or becomes trusted context across sessions.

**Mechanism:** Public ingestion is rejected and provenance is checked at write time, blocking direct planting via public tickets.

**Does not cover:** Write-time checks raise effort against direct ticket planting without eliminating retrieval exposure or indirect poisoning. Read-time segmentation is disabled, and republished text loses its untrusted provenance. Restricted chunks were retrieved across two builds (LLM08 falls) and poisoned FAQ content reached retrieval (LLM04 falls).

**Residual:** This is the weakest control because both boundaries failed in retesting: LLM08 falls at the read boundary, exposing restricted internal pricing ($321-per-seat floor) to any signed-in user, and LLM04 falls at the pipeline boundary, letting poisoned FAQ entries persist across sessions.

## Resource caps

**Class:** unbounded consumption, where repeated or long generation exhausts budget or capacity.

**Mechanism:** Per-session limits on tokens, request rate, tool iterations, and output length bound single-session work.

**Does not cover:** Per-session caps raise attacker effort by forcing session rotation, without eliminating unbounded consumption across parallel or rotated sessions (LLM10 partial). Caps are content-blind, so short requests still leak data, and thresholds are uncalibrated.

**Residual:** LLM10 remains partially open (LLM10 partial): single-session loops are bounded, while multi-session spend and denial-of-wallet remain open.

## Input guardrail and output filtering

**Class:** adversarial-input evasion and sensitive-output leakage across message boundaries.

**Mechanism:** Regex filters block known injection strings in messages, and output redaction strips matched secret formats.

**Does not cover:** Pattern matching raises attacker effort against literal copy-paste strings without eliminating either class. Paraphrase, indirection, and other languages bypass the input filter, which ignores tickets and retrieved text. Output redaction runs after retrieval and tool calls, missing unformatted secrets like conversational price disclosures.

**Residual:** LLM01 and LLM02 remain open while only literal strings are harder: four in five mutated prompts bypassed the filter to reach the agent, and unformatted secrets pass unredacted.

## Removal order under a two-control reduction

**First removed: input guardrail and output filtering.** It adds operational cost in request latency, regex maintenance, and false positives. Its effect overlaps with stronger downstream boundaries: parameterized output, per-tool authorization, and human approval remain as compensating controls bounding what a manipulated model can execute. Removing it drops literal-string screening, raising the LLM01 and LLM02 residual so unmutated attacks reach the model without raising attacker effort.

**Second removed: owned system prompt.** It adds operational cost in per-turn token overhead and prompt maintenance. Its scoping overlaps with server-side per-tool authorization and parameterized output, which remain as compensating controls enforcing data and action boundaries regardless of model compliance. Removing it drops in-context precedence, creating higher residual risk for instruction-data confusion (LLM01) and unmeasured prompt disclosure (LLM07).

**Preserved longest (load-bearing):** per-tool authorization, the sole control enforcing account ownership; human approval, the sole gate before irreversible refunds and deletions; and parameterized output, which eliminates SQL syntax injection.

**Weakest control:** retrieval provenance and ingestion restriction, where LLM08 falls and LLM04 falls leave restricted and poisoned content exposed with no compensating read-time control.
