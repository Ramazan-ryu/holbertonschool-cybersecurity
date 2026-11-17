# Design Defense

The controls sit at different points because the model is an unreliable decision maker. Each section names the class, the mechanism, and what that control alone leaves open, tied to the residual in the Task 10 report. No control is claimed as complete protection, and no section relies on another control to cover its own gap.

## Owned system prompt

**Class:** instruction-data confusion and disclosure of privileged context.

**Mechanism:** Sets the support role, limits discussion to the signed-in customer's account, and treats retrieved content as reference.

**Does not cover:** The prompt is model-visible text and cannot enforce authorization. A persuasive input can still override it. Prompt extraction (LLM07) was not measured: attempts returned upstream_error_502, so resistance is unknown.

**Residual:** A successful override or extraction exposes the prompt and any secret placed in context. No bound was measured. A model update can change compliance.

## Parameterized tool output

**Class:** executable-output injection (LLM05).

**Mechanism:** The model supplies parameter values to registered statements, not SQL text. Values are bound as data.

**Does not cover:** It does not limit which statements exist or which columns they return. A well-formed call to a registered statement passes this control, so over-broad reads through permitted statements remain open. It also does not decide whether a permitted request is appropriate. LLM05 is partial: no model-directed exploitation was measured successfully.

**Residual:** Over-broad reads through permitted statements. The injection class is reduced at the database boundary, not eliminated.

## Per-tool authorization

**Class:** broken authorization and excessive agency (LLM06).

**Mechanism:** Each tool checks the session's identity against the requested target before executing. Authority comes from the server, not the model's explanation.

**Does not cover:** It depends on correct identity binding and on every future tool implementing the same check. The denial tests ran in plan mode, so live mutation behavior is unverified. It does not judge whether an allowed action is prudent.

**Residual:** LLM06 is partial. A correctly bound session can still act within its own account, and one missing check reopens the class for any new tool.

## Human approval

**Class:** high-consequence action taken without a decision about intent.

**Mechanism:** Refund and delete requests are queued until a reviewer approves them. The queued test request changed no state.

**Does not cover:** It applies only to the two listed tools. A reviewer can approve a harmful request if the review screen omits context. One own-order deletion remains pending, so the approve-and-execute path has not been verified end to end.

**Residual:** A reviewer error turns a queued refund into a real transfer. No reviewer error rate was measured.

## Retrieval provenance and ingestion restriction

**Class:** untrusted retrieval and persistent poisoning (LLM04, LLM08).

**Mechanism:** Public user ingestion is disabled, and provenance is checked at write time. The planted ticket was quarantined.

**Does not cover:** It does not stop retrieval of restricted content. Segmentation is off (`segment_internal=false`), and restricted chunks were returned in 3 of 3 internal searches on my build and 3 of 3 on a peer endpoint (LLM08 falls). The FAQ-suggestion path reached retrieval, so provenance checks did not stop poisoning there (LLM04 falls). Provenance can be laundered when untrusted text is republished into a trusted-looking source. The victim response was inferred from retrieval, not observed live.

**Residual:** Any support user can retrieve internal pricing, including the $321-per-seat floor, and poisoned FAQ content can be served. This is a bounded exposure, not a blocked class. It is the weakest control.

## Resource caps

**Class:** unbounded consumption (LLM10).

**Mechanism:** Session token, request-rate, tool-iteration, and output limits.

**Does not cover:** Caps bound volume, not content. A single request within the token cap can still disclose whatever retrieval supplies. Thresholds are uncalibrated because `avg_tokens_per_request` is null, and the LLM10 result holds only under the 1500-tokens-per-call assumption.

**Residual:** Sustained provider cost within the cap, with no dollar figure. A legitimate long request can be cut off.

## Input guardrail and output filtering

**Class:** adversarial-input evasion (input side) and sensitive-output leakage (output side).

**Mechanism:** The input filter catches some literal or decodable injection phrases in the message. Output redaction and schema validation catch secret-shaped strings and malformed results.

**Does not cover:** 47 of 60 mutated variants (78.3%) bypassed the input filter, including every semantic, indirect, multilingual, fake-delimiter, and benign-lookalike sample. It screens only the message channel, not tickets or retrieved text. Output filtering runs after retrieval and tool calls, so it cannot stop data being fetched or an action executing.

**Residual:** LLM01 is falls; about four in five mutated attempts reached the agent. This control raises attacker effort and removes no class.

## Removal order under a two-control reduction

**First: the input guardrail.** It has the lowest measured coverage and does not screen the channels where the residual sits. Removing it adds no residual to any other control, since it never covered retrieval or tool calls. The cost is that obvious injection attempts reach the model. The LLM01 residual stays falls, and this loss is accepted, not offset: per-tool authorization and human approval still limit what a manipulated request can do, but they do not reduce the manipulation itself.

**Second: the prompt's secrecy wording.** It is guidance, not enforcement, and covers no tool. Its removal raises exposure to extraction and override, which the system-prompt section already states without a measured bound. Its loss does not change the residuals of parameterized output or per-tool authorization, and those controls do not cover prompt-level exposure. Accepting this loss means accepting the LLM07 residual as unmeasured.

**Preserved longest:** per-tool authorization, the only control that decides whether a session may act on a target; human approval, for refunds and deletions the model cannot reverse; and parameterized output, which removes executable SQL injection at the database boundary.

**Weakest:** retrieval provenance. No remaining control stops restricted chunks or poisoned FAQ content from reaching the model. This must be fixed before any change to ingestion or retrieval is approved.
