# 14x02 Build It Break It

Deliverables in this directory are based on the lab evidence supplied in this session. RESULT lines are copied from proof output; replay outcomes and live outcomes are distinguished. No dynamic reference flag or peer finding has been invented.

Included: `0-prompt.md`, `1-test.txt`–`6-guardrail.txt`, `SBOM.md`, `model_provenance.txt`, `8-self_attack.txt`, `9-flag.txt`, `10-peer_exchange.md`, `11-residual_risk.md`, and `12-design_defense.md`.

Evidence updates: Task 6 was rerun under `p2_hardened_reference` and measured 13/60 blocked, 47/60 bypassed, and 0/30 benign false positives. Task 8 includes the later live `llm05` upstream error as inconclusive. The shipped lock SHA-256 is `1a2fd284091270f3b8c4274263a574d4e00451ef915390986a6407f554c4e830`. The pin file SHA-256 is `6753c0a1b60028ac44d0c4246f0d025e04c825262ecda0462b0ee196df0cb25d`.

Evidence limits: prompt extraction did not return a successful model response; `/config` reports `resolved_version` equal to the configured model name, but the captured live request failed before reaching Google, so no provider-reported `modelVersion` is established. No model weights or provider-signed model digest were supplied. No reference residual flag was earned. Two replay-only runs against the same external endpoint reproduced the findings, but its owner/build revision and the reverse peer test are still missing. Tester intranet ID `11349` has now been added; the permitted peer ID and both build revisions remain outstanding. The SBOM lists locked runtime package artifact hashes and classifies build tooling separately.
