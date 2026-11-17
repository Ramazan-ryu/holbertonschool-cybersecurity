# Design Defense

Controls sit at separate boundaries because the model is an unreliable decision maker. Each section names the vulnerability class, how the control changes its attack surface, what the control does not cover, and the resulting residual risk.

## Owned system prompt

**Class:** instruction-data confusion and prompt disclosure, where untrusted text is followed as instructions or directives are extracted.

**Mechanism:** Sets the support role, scopes discussion to the signed-in account, and labels retrieved content as reference, giving the model an in-context precedence rule.

**Does not cover:** In-context text raises attacker effort against naive overrides without eliminating instruction-data confusion because the model cannot enforce a hard boundary between instructions and data. Persuasive framing still overrides it, and extraction resistance (LLM07) is unmeasured.

**Residual:** LLM01 and LLM07 remain open in context; prompt directives and any secret placed in context can still be overridden or extracted (LLM07 unmeasured).

## Parameterized tool output

**Class:** executable-output injection, where model-generated text is interpreted as query syntax by a downstream interpreter.

**Mechanism:** The model supplies typed argument values to registered statements rather than composing SQL. Values are bound as data parameters, eliminating query-structure tampering on bound fields.

**Does not cover:** Parameter binding eliminates SQL syntax injection on bound fields, but does not govern which statements exist, which columns they return, or whether the model selects an over-broad statement using valid arguments.

**Residual:** LLM05 is only partially closed (LLM05 partial): syntax tampering is eliminated on bound calls, while over-broad permitted reads and unparameterized paths remain open.

## Per-tool authorization

**Class:** broken object-level authorization and excessive agency, where a model-selected target is trusted without a server-side ownership check.

**Mechanism:** The server verifies the authenticated session identity against the target record owner before execution, enforcing authority from server state rather than model reasoning.

**Does not cover:** It eliminates cross-account target switching on covered tools, but does not evaluate whether an action on the signed-in user's own account was coerced by prompt injection. Each new tool must wire the check manually, and denial tests ran in plan mode rather than live execution (LLM06 partial).

**Residual:** Same-account coerced actions remain open and fall onto the approval gate, while live enforcement across all tool paths remains unverified (LLM06 partial).

## Human approval

**Class:** high-consequence action execution without an independent human decision on intent.

**Mechanism:** Refund and deletion calls enter a pending queue until a reviewer approves them, placing an external decision boundary before irreversible changes.

**Does not cover:** Approval raises attacker effort by requiring a plausible justification, without eliminating coerced actions. Unlisted tools bypass the queue, a reviewer who accepts a fabricated rationale approves the harm, reviewer error rates are unmeasured, and the live approve-and-execute path is unverified end to end.

**Residual:** LLM06 and LLM09 remain partially open: unqueued tools execute immediately, and social-engineered or rubber-stamped approvals still cause real refunds or permanent data loss.

## Retrieval provenance and ingestion restriction

**Class:** untrusted retrieval and persistent knowledge-base poisoning, where untrusted content enters storage or is served as trusted context across sessions.

**Mechanism:** Public ticket ingestion is rejected and provenance metadata is checked at write time, closing direct unauthenticated planting through the ticket channel.

**Does not cover:** Write-time checks raise effort against direct ticket planting without eliminating retrieval exposure or indirect poisoning. Read-time audience segmentation is disabled, so provenance labels are never enforced during vector search, and republished untrusted text loses its untrusted provenance tag. In verification, restricted internal chunks were retrieved across two builds (LLM08 falls) and poisoned FAQ content reached retrieval (LLM04 falls).

**Residual:** This is the weakest control because both boundaries failed in retesting: LLM08 falls at the read boundary, letting any signed-in user retrieve restricted internal pricing including the $321-per-seat floor, and LLM04 falls at the pipeline boundary, letting poisoned FAQ entries persist and reach every session.

## Resource caps

**Class:** unbounded consumption, where repeated, recursive, or high-volume requests exhaust compute budget or service capacity.

**Mechanism:** Numeric limits on per-session tokens, request rate, tool iterations, and output length bound the work a single session can trigger.

**Does not cover:** Per-session caps raise attacker effort by forcing session rotation, without eliminating unbounded consumption across concurrent or automated sessions (LLM10 partial). Caps are content-blind, so single requests within the limit still exfiltrate sensitive data, and thresholds are uncalibrated against production cost.

**Residual:** LLM10 remains partially open (LLM10 partial): single-session loops are bounded, while aggregate multi-session spend and denial-of-wallet exposure remain open.

## Input guardrail and output filtering

**Class:** adversarial-input evasion and sensitive-output leakage across message boundaries.

**Mechanism:** Pre-inference regex rules block known injection strings in user messages, and post-inference pattern redaction strips matched secret formats.

**Does not cover:** Pattern matching raises attacker effort against literal copy-paste strings without eliminating either class. Paraphrasing, encoding, indirection, and other languages bypass the input filter, which also ignores tickets and retrieved chunks. Output redaction runs after retrieval and tool execution, so it cannot stop unauthorized actions or redact unformatted secrets like conversational price disclosures.

**Residual:** LLM01 and LLM02 remain open while only literal strings are harder: four in five mutated prompts in the measured set bypassed the input filter to reach the agent, and unformatted secrets pass output redaction intact.

## Removal order under a two-control reduction

**First removed: input guardrail and output filtering.** It carries operational cost in per-request latency, rule maintenance, and false-positive friction. Its effect overlaps with stronger downstream boundaries: parameterized tool output, per-tool authorization, and human approval remain as compensating controls that bound what a manipulated model can execute. Removing it drops literal-string screening, raising the LLM01 and LLM02 residual so unmutated attack strings reach the model without raising attacker effort.

**Second removed: owned system prompt.** It carries operational cost in token overhead on every turn and maintenance across model updates. Its role-scoping intent overlaps with server-side per-tool authorization and parameterized output, which remain as compensating controls enforcing data and action boundaries regardless of model compliance. Removing it eliminates the in-context precedence rule, creating a higher residual risk of instruction-data confusion (LLM01) and unmeasured prompt disclosure (LLM07).

**Preserved longest (load-bearing):** per-tool authorization, the sole control enforcing account ownership; human approval, the sole gate before irreversible refunds and deletions; and parameterized tool output, which eliminates SQL syntax injection.

**Weakest control:** retrieval provenance and ingestion restriction, where LLM08 falls and LLM04 falls leave restricted and poisoned data exposed with no compensating read-time control.
