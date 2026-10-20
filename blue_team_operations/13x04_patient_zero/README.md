# 13x04 — Corvan Industrial Patient Zero

## Status

Completed from the provided Corvan Patient Zero evidence path. The findings distinguish the document-container hash from the extracted payload hash and require payload, infrastructure, and time linkage before attributing entry.

## Required deliverables

- `4-flag.txt` — relay address, sending account, and accurate authentication posture.
- `5-flag.txt` — patient-zero and benign-forwarded message IDs, authentication results, and what each result proves and does not establish.
- `6-flag.txt` — attachment SHA-256 and C2 address linked to their downstream source projects.
- `7-flag.txt` — patient-zero Message-ID with payload, infrastructure, and delivery-time linkage.
- `8-flag.txt` — decoy Message-ID, why it is reportable, and which causal linkage it fails.
- `2-tracekey.txt` — assembled downstream indicators used to search the mailbox.
- `9-bypass.txt` — how the authenticated message passed configured controls; do not claim DMARC is absent.
- `10-report.md` — client-facing, evidence-bounded conclusion.
- `11-hardening.md` — recommendations that address the demonstrated control gap.

Quizzes `0-smtp_quiz`, `1-auth_quiz`, `3-headers_quiz`, and `12-review_quiz` are completed through the LMS, not stored here.

## Evidence method

Work from the provided disposable analyst workstation and its read-only mailbox. Enumerate candidates, inspect headers and `Authentication-Results`, verify SPF/DKIM/DMARC using the lab tools, and analyze attachments only statically or with the offline `detonate` tool. Defang links and resolve only against lab stand-ins. Keep the evidence in the lab; record message IDs rather than reproducing message content.

Patient-zero attribution requires all three independent linkages:

1. Payload hash continuity to the downstream victim/source project.
2. C2 infrastructure continuity to the downstream source project.
3. Delivery before the first downstream attacker activity.

Authentication is not a safety verdict: a pass establishes the relevant domain authorization/alignment result, not that the sender account or content is trustworthy. A fail alone is not proof of maliciousness. Corvan's SPF, DKIM, and DMARC records exist, and its gateway adds `Authentication-Results`.
