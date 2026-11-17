# Design Defense

The controls sit at different points because the model is an unreliable decision maker. No single layer can absorb every failure, so each control is defended below by the vulnerability class it addresses and by what it does not cover.

## Owned system prompt

**Class:** instruction-data confusion and disclosure of privileged context.

**Mechanism:** The prompt sets the support role, limits discussion to the signed-in customer's account, and treats retrieved content as reference, not instructions.

**Does not cover:** The prompt is model-visible text and cannot enforce authorization. A persuasive input can still induce paraphrase or disclosure. Prompt extraction (LLM07) was not measured successfully, so its effect here is unverified. A model update can change how the instructions are followed.

**Effect on surface:** It reduces scope drift in ordinary use. It does not change what the tools can reach.

## Parameterized tool output

**Class:** executable-output injection (LLM05).

**Mechanism:** Model output supplies parameter values to a registered statement, not SQL text. A value containing quote marks or operators is bound as data and cannot alter query structure.

**Does not cover:** It does not limit which statements exist or which columns they return. A valid parameterized request can still retrieve more rows than it should, and an unauthorized but well-formed request is the job of the authorization layer. LLM05 is rated partial because model-directed exploitation was not measured successfully.

## Per-tool authorization

**Class:** broken authorization and excessive agency (LLM06).

**Mechanism:** Each tool checks the session's identity against the requested target before executing. Authority comes from the server, not from the model's explanation.

**Does not cover:** It depends on correct identity binding and on every future tool implementing the same check. One missing check reopens the class for that tool. The denial tests ran in plan mode, so live mutation behavior is unverified. It does not judge whether an allowed action is prudent. LLM06 is rated partial.

## Human approval

**Class:** high-consequence action taken without a decision about intent.

**Mechanism:** Refund and delete actions are held for a person. A queued request changes no state until a reviewer approves it.

**Does not cover:** It applies only to the listed tools, so side effects from other tools fall outside it. A reviewer can approve a harmful request if the review screen omits context. One consequential request remains pending, so the decision path has not been verified end to end. Approval slows harm; it does not prove a decision is correct.

## Retrieval provenance and ingestion restriction

**Class:** untrusted retrieval and persistent poisoning (LLM04, LLM08).

**Mechanism:** Public user ingestion is disabled, and provenance is checked when content is written.

**Does not cover:** This is the weakest control. The FAQ-suggestion path reached retrieval, so provenance checks did not stop poisoning on that path (LLM04 is falls). Segmentation is disabled (`segment_internal=false`), and restricted chunks were returned in 3 of 3 embedding searches on my build and on a peer endpoint (LLM08 is falls). Provenance can be laundered when untrusted text is republished into a source that looks trusted. The victim response was inferred from retrieval, not observed live.

## Resource caps

**Class:** unbounded consumption (LLM10).

**Mechanism:** Session token, request-rate, tool-iteration, and output limits bound cost and loop length.

**Does not cover:** Caps limit impact, not intent, and can cut off a legitimate long request. Thresholds are uncalibrated because `avg_tokens_per_request` is null. A cap does not limit what a single permitted request discloses. LLM10 is stopped only under the harness's 1500-tokens-per-call assumption.

## Input guardrail and output filtering

**Class:** adversarial-input evasion (input side) and sensitive-output leakage (output side).

**Mechanism:** The input filter catches some literal or decodable injection phrases in user messages. Output redaction and schema validation reduce accidental exposure of secret-shaped strings and malformed results.

**Does not cover:** The input filter bypassed 47 of 60 mutated variants (78.3%) and screens only the message channel, not tickets or retrieved text. Output filtering runs after retrieval and tool calls, so it cannot prevent data from being fetched or an action from executing. This control raises attacker effort; it does not remove the class (LLM01 is falls). Output handling must not be credited for fetch or tool risk, which other controls own.

## Removal order under a two-control reduction

**First to remove: the input guardrail.** It has the lowest measured coverage and screens the message channel, not the ticket or retrieval channels where the highest residual sits. Its cost is real: obvious injection attempts reach the model. LLM01 stays falls with no screening, but per-tool authorization and human approval bound what a manipulated request can do. Those controls do not stop the manipulation itself, so this increase is accepted, not eliminated.

**Second to remove: the prompt's secrecy wording.** It is guidance rather than enforcement, and the real boundaries are authorization and parameterization. The cost is weaker resistance to casual extraction. Because LLM07 was not measured, this loss cannot be quantified. Parameterized output and per-tool authorization remain as compensating controls.

**Preserved longest (load-bearing):** per-tool authorization, the only control that decides whether a session may act on a target. Human approval, because it governs refunds and deletions the model cannot reverse. Parameterized output, because it closes executable injection at the database boundary.

**Weakest control:** retrieval provenance. The FAQ path reached retrieval and restricted chunks were reachable in every tested embedding search. This gap must be fixed before any decision that touches ingestion or retrieval.
