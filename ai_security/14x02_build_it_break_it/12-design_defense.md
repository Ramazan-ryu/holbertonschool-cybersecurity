# Design Defense

The controls sit at different points because the model is an unreliable decision maker. No single layer absorbs every failure, so each control is defended by the vulnerability class it addresses and by the residual it leaves.

## Owned system prompt

**Class:** instruction-data confusion and disclosure of privileged context.

**Mechanism:** The prompt limits the assistant to the signed-in customer's account and support topics, and treats retrieved content as reference, not instructions.

**Does not cover:** The prompt is model-visible text and enforces nothing; authorization must come from the tools. A persuasive input can still induce paraphrase or disclosure of context the model already holds, including restricted chunks returned by search (LLM08 is falls). Prompt extraction (LLM07) was not measured successfully, so its residual is unknown. A model update can change instruction-following.

**Residual:** Instruction-following is probabilistic. This control raises the effort needed for disclosure but does not eliminate it.

## Parameterized tool output

**Class:** executable-output injection (LLM05).

**Mechanism:** The model supplies parameter values to a registered statement, not SQL text. A value containing quote marks or operators is bound as data and cannot change query structure.

**Does not cover:** It does not limit which statements exist, which columns they return, or which targets they accept. A well-formed call with a valid value can return more rows than the customer should see. Model-directed exploitation was not measured successfully (LLM05 is partial), and disclosure through overbroad statements was not tested.

**Residual:** Any data a registered statement exposes is reachable through a valid parameter. This control closes syntax injection, not over-retrieval.

## Per-tool authorization

**Class:** broken authorization and excessive agency (LLM06).

**Mechanism:** Each tool checks the session's identity against the requested target before executing. Authority comes from the server, not from the model's explanation.

**Does not cover:** It decides whether a call may run. It does not control what an allowed call returns or whether the model shows that to the customer. It depends on correct identity binding and on every future tool implementing the same check. The denial tests ran in plan mode, so live mutation behavior is unverified (LLM06 is partial).

**Residual:** A permitted call that is harmful is not screened by this control.

## Human approval

**Class:** high-consequence action taken without a decision about intent.

**Mechanism:** Refund and delete requests are held for a person. A queued request changes no state until a reviewer approves it.

**Does not cover:** It applies only to the two listed tools, so side effects from other tools are outside it. A reviewer can approve a harmful request if the screen omits context. One consequential request remains pending, so the decision path has not been verified end to end.

**Residual:** Safety of refunds and deletions depends on reviewer judgment, which this control does not measure.

## Retrieval provenance and ingestion restriction

**Class:** untrusted retrieval and persistent poisoning (LLM04, LLM08).

**Mechanism:** Public user ingestion is disabled, and provenance is checked at write time. The planted ticket was quarantined.

**Does not cover:** This is the weakest control. The FAQ-suggestion path reached retrieval, so provenance did not stop poisoning there (LLM04 is falls). Segmentation is disabled (`segment_internal=false`), and restricted internal chunks were returned in 3 of 3 embedding searches on my build and on a peer endpoint (LLM08 is falls). Provenance can be laundered when untrusted text is republished into a trusted-looking source. The victim response was inferred from retrieval, not observed live.

**Residual:** A customer who makes semantically related support queries can reach internal pricing and escalation chunks, including the $321-per-seat floor. Poisoned FAQ content can enter retrieval. This control raises the effort for a crafted ticket but does not eliminate the class.

## Resource caps

**Class:** unbounded consumption (LLM10).

**Mechanism:** Session token, request-rate, tool-iteration, and output-token limits bound cost and loop length.

**Does not cover:** Caps limit consumption, not what a permitted request discloses. They can cut off a legitimate long request. Thresholds are uncalibrated because `avg_tokens_per_request` is null. The stop was shown only under the harness's assumption of 1500 tokens per call.

**Residual:** One session can spend up to 8000 tokens, and a user can open new sessions within the rate limit. The dollar cost is unknown.

## Input guardrail and output filtering

**Class:** adversarial-input evasion (input side) and sensitive-output leakage (output side).

**Mechanism:** The input filter catches some literal or decodable injection phrases in user messages. Output redaction and schema validation reduce accidental exposure of secret-shaped strings and malformed results.

**Does not cover:** The input filter bypassed 47 of 60 mutated variants (78.3%) and screens only the message channel, not tickets or retrieved text. Output filtering runs after retrieval and tool calls, so it cannot stop data being fetched or an action executing. It must not be credited for retrieval or tool risk, which other controls own.

**Residual:** Injection through tickets and retrieved content is unscreened, and most mutated attempts in the test set reached the agent. LLM01 is falls.

## Removal order under a two-control reduction

**First to remove: the input guardrail.** Its measured coverage is lowest, and it screens only the message channel, not the ticket and retrieval channels where the largest residual lies. Its cost is real: obvious injection phrases reach the model. Measured LLM01 exposure barely changes, since 47 of 60 variants already bypass it, but removal drops a cheap signal and the block on obvious attempts. Compensating controls are per-tool authorization and human approval, which bound what a manipulated request can do to the listed actions. New residual: more obvious injections reach the model, and no monitoring signal fires on them. This is accepted, not eliminated.

**Second to remove: the prompt's secrecy wording.** It is guidance, not enforcement. Its cost is weaker resistance to casual extraction, which cannot be quantified because LLM07 was not measured. Compensating controls are parameterized output and per-tool authorization. Neither addresses retrieval disclosure, so the new residual is that casual extraction of context becomes easier.

**Load-bearing, preserved longest:** per-tool authorization, the only control that decides whether a session may act on a target. Human approval, because refunds and deletions cannot be reversed by the model. Parameterized output, because it closes syntax injection at the database boundary.

**Weakest control:** retrieval provenance. It is the control aimed at the class with measured failures on two paths, and no other layer covers retrieval disclosure. Fix it before any decision that touches ingestion or retrieval.
