# Design Defense

The controls sit at different points because the model is an unreliable decision maker. No single layer absorbs every failure, so each control is defended by the class it addresses and the residual it leaves.

## Owned system prompt

**Class:** instruction-data confusion and disclosure of privileged context.

**Mechanism:** The prompt limits the assistant to the signed-in customer's account and treats retrieved content as reference, not instructions.

**Does not cover:** The prompt is model-visible text and enforces nothing; authorization must come from the tools. A persuasive input can still induce paraphrase or disclosure of context the model already holds, including restricted chunks returned by search (LLM08 is falls). Prompt extraction (LLM07) was not measured successfully.

**Residual:** Instruction-following is probabilistic. The control raises the effort needed for disclosure but does not eliminate it.

## Parameterized tool output

**Class:** executable-output injection (LLM05).

**Mechanism:** The model supplies parameter values to a registered statement, not SQL text. A value containing quote marks or operators is bound as data.

**Does not cover:** It does not limit which statements exist, which columns they return, or which targets they accept. Model-directed exploitation was not measured successfully (LLM05 is partial).

**Residual:** Any data a registered statement exposes is reachable through a valid parameter. The control closes syntax injection, not over-retrieval.

## Per-tool authorization

**Class:** broken authorization and excessive agency (LLM06).

**Mechanism:** Each tool checks the session's identity against the requested target before executing. Authority comes from the server, not the model's explanation.

**Does not cover:** It decides whether a call may run, not what an allowed call returns. It depends on correct identity binding and on every future tool implementing the check. The denial tests ran in plan mode, so live mutation behavior is unverified (LLM06 is partial).

**Residual:** A permitted but harmful call is not screened by this control.

## Human approval

**Class:** high-consequence action taken without a decision about intent.

**Mechanism:** Refund and delete requests are held for a person and change no state until approved.

**Does not cover:** It applies only to the two listed tools. A reviewer can approve a harmful request if the screen omits context. One consequential request remains pending, so the decision path is not verified end to end.

**Residual:** Safety of refunds and deletions depends on reviewer judgment, which this control does not measure.

## Retrieval provenance and ingestion restriction

**Class:** untrusted retrieval and persistent poisoning (LLM04, LLM08).

**Mechanism:** Public user ingestion is disabled, and provenance is checked at write time. The planted ticket was quarantined.

**Does not cover:** This is the weakest control. The FAQ-suggestion path reached retrieval, so provenance did not stop poisoning there (LLM04 is falls). Segmentation is disabled (`segment_internal=false`), and restricted chunks were returned in 3 of 3 embedding searches on my build and a peer endpoint (LLM08 is falls). Provenance can be laundered when untrusted text is republished into a trusted-looking source. The victim response was inferred, not observed live.

**Residual:** A customer making semantically related support queries can reach internal pricing and escalation chunks, including the $321-per-seat floor. Poisoned FAQ content can enter retrieval. The control raises the effort for a crafted ticket but does not eliminate the class.

## Resource caps

**Class:** unbounded consumption (LLM10).

**Mechanism:** Session token, request-rate, tool-iteration, and output-token limits bound cost and loop length.

**Does not cover:** Caps limit consumption, not what a permitted request discloses, and can cut off a legitimate long request. Thresholds are uncalibrated because `avg_tokens_per_request` is null. The stop was shown only under a 1500-tokens-per-call assumption.

**Residual:** One session can spend up to 8000 tokens, and new sessions are possible within the rate limit. The dollar cost is unknown.

## Input guardrail and output filtering

**Class:** adversarial-input evasion (input side) and sensitive-output leakage (output side).

**Mechanism:** The input filter catches some literal or decodable injection phrases in user messages. Output redaction and schema validation reduce accidental exposure of secret-shaped strings.

**Does not cover:** The input filter bypassed 47 of 60 mutated variants (78.3%) and screens only the message channel. Output filtering runs after retrieval and tool calls, so it cannot stop data being fetched or an action executing. It must not be credited for retrieval or tool risk.

**Residual:** Injection through tickets and retrieved content is unscreened, and most mutated attempts in the test set reached the agent. LLM01 is falls.

## Removal order under a two-control reduction

**First to remove: the input guardrail.** Its measured coverage is lowest, and it screens only the message channel, not the ticket and retrieval channels where the largest residual lies. Its cost is real: obvious injection phrases reach the model. Measured LLM01 exposure barely changes, since 47 of 60 variants already bypass it, but the cheap signal and the block on obvious attempts are lost. Per-tool authorization and human approval bound what a manipulated request can do to the listed actions. New residual: more obvious injections reach the model unflagged. This is accepted, not eliminated.

**Second to remove: the prompt's secrecy wording.** It is guidance, not enforcement. The cost is weaker resistance to casual extraction, which cannot be quantified because LLM07 was not measured. Parameterized output and per-tool authorization remain, but neither addresses retrieval disclosure, so casual extraction of context becomes easier.

**Load-bearing, preserved longest:** per-tool authorization, the only control that decides whether a session may act on a target. Human approval, because refunds and deletions cannot be reversed by the model. Parameterized output, because it closes syntax injection at the database boundary.

**Weakest control:** retrieval provenance. It targets the class with measured failures on two paths, and no other layer covers retrieval disclosure. Fix it before any decision that touches ingestion or retrieval.
