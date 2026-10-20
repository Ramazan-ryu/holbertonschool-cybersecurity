# Corvan Industrial: Patient Zero Investigation

## Executive conclusion

The UMBRA-7 campaign entered Corvan through message `PZ-0001`, delivered at `2026-09-18T07:14:00+00:00` from a compromised account at legitimate supplier Harrowfield Metalworks. The message carried a malicious macro-enabled document and linked to known campaign infrastructure. It passed SPF, DKIM, and DMARC because it genuinely originated from Harrowfield's authorised infrastructure and bore a valid signature for that domain. Corvan's email authentication controls operated correctly; they cannot determine whether a currently authorised supplier account has been compromised or whether an authorised message is malicious.

## Scope and method

The abuse mailbox was treated as evidence rather than as a collection of independent alerts. Mail headers and Corvan gateway authentication results were assessed to separate visible identity from sending infrastructure. Attachments were analyzed with static tooling and the lab's offline detonation fixture. Links were resolved only to the lab stand-in. Candidate messages were measured against indicators collected in the preceding engagements: the 13x01 and 13x02 dropper hash `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2`, campaign C2 `198.51.100.47`, and the first known downstream activity at `2026-09-18T07:55:00+00:00`.

This approach matters because the mailbox contains ordinary business mail, commodity phishing, an unrelated targeted phish, and a benign forwarded message whose authentication fails. Neither a frightening lure nor a failed authentication line establishes causation. Attribution of the entry point therefore requires three separate tests: payload continuity, infrastructure continuity, and delivery before observed downstream activity.

## Patient zero and causal proof

`PZ-0001` is the patient-zero message. Its payload linkage is direct. The email carried `Order_Confirmation_Revised_PO-48490.docm`, a macro-enabled document. Static examination identified an `AutoOpen` execution path, obfuscated base64 and hex content, and behaviour consistent with decoding an embedded payload. The decoded payload has SHA-256 `d13e0265140f33bc79de76e6c31708138443510e9d44184f5acd44ea7a88c6b2`. That is the hash previously recorded for the 13x01 payload and the 13x02 dropper. The message's attachment container has a different SHA-256, `86dce67a9c0c0000e9c3e7bdad4e6d4ee803fccce90b2fe1017080c98ab8584d`; that distinction prevents confusing the delivery document with the payload it carries.

Infrastructure linkage is also direct. The message body contains a link whose true destination resolves to `198.51.100.47`, the C2 address already characterised across engagements 13x00 through 13x02. The offline behavioural report for the document independently states that its decoded payload would beacon to the same address. The email link and attachment therefore converge on prior campaign infrastructure through two routes.

The timing test is satisfied. `PZ-0001` was delivered at `2026-09-18T07:14:00+00:00`; the earliest known downstream activity in 13x01 occurred at `2026-09-18T07:55:00+00:00`. Delivery predates activity by 41 minutes. The temporal sequence is compatible with the attachment or link initiating the later endpoint actions. Combined with the payload and infrastructure matches, it establishes causation rather than resemblance.

## True origin and authentication

The trusted appearance of `PZ-0001` was not a display-name spoof. Header evidence identifies `203.0.113.243`, an authorised relay for `harrowfield-metalworks.example`, and account `dana.berglund@harrowfield-metalworks.example`. This is a compromised supplier account using its normal sender domain, mail relay, and signing capability.

Authentication results confirm that origin. SPF passes for `harrowfield-metalworks.example` because its SPF record authorises `203.0.113.243`. DKIM passes with signing domain `harrowfield-metalworks.example` and selector `mail1`; the signed header set includes From, To, Subject, Date, and Message-ID. DMARC passes because both SPF and DKIM align with the visible From domain. These results prove domain authorisation and valid signature verification. They do not prove that the supplier account was controlled by its legitimate user, that the content was safe, or that the supplier intended the message.

Corvan was not missing authentication controls. Its published SPF record is `v=spf1 include:_spf.relaymesh-mail.example -all`; its DMARC policy is `p=reject` at 100 percent, and Corvan publishes DKIM. Its gateway applies inbound authentication and records results in the messages. Reporting this incident as missing DMARC or an authentication failure would be factually incorrect.

## Weaponised content

The attachment is a malicious macro-borne dropper. Its `AutoOpen` macro path and encoded embedded content explain how it could decode and launch the tracked payload after a recipient opened the document. The local offline detonation report classifies the document as malicious and identifies the same C2 address. The linked destination at `198.51.100.47` presents a document portal in the lab stand-in and represents a second delivery or collection route associated with the campaign. The evidence supports treating both attachment and link as malicious campaign content; it does not require executing either one.

## How the message passed controls

The message passed because authentication controls correctly evaluated an authorised, signed message from a real supplier domain. SPF, DKIM, and DMARC are authentication controls. They evaluate whether an entity may send for a domain and whether appropriately signed message parts verify; they do not evaluate account compromise, relationship context, intent, attachment behaviour, or link safety. A compromised trusted supplier is therefore outside the protection envelope of configuration changes to those mechanisms alone.

## Other relevant mailbox findings

`AUTHFAIL-0001` is benign and should be closed. Its visible From domain is `northgate-freight.example`. A mailing-list forwarder, `listrelay-partners.example`, appended a footer after the original message was signed. DKIM consequently fails on the body hash. SPF passes only for the forwarding list domain and does not align with the visible From domain; DMARC fails. This proves modification by a relay and an absence of aligned authentication, not maliciousness or an illegitimate original sender.

`DECOY-0001` is a real phishing incident that merits separate reporting. It impersonates a Corvan accounts function using recently registered lookalike domain `corvan-globalsupply.example`, uses an urgency lure, and carries malicious ISO `Voicemail_00_47.iso` with SHA-256 `f26546d1cca7ee88ddda176abd9d8a1bcb649b96256ddfe55348a3c97063939c`. Its delivery chain uses a shortcut-launched executable rather than the macro-borne tracked payload. Its infrastructure is `203.0.113.249` in AS64516, whereas the UMBRA-7 infrastructure is `198.51.100.47` in AS64512. It arrived before the patient-zero date, so timing cannot exclude it; payload and infrastructure do. It must remain an unrelated phishing finding rather than being attributed to this campaign.

## Conclusion

The evidence supports one entry point: `PZ-0001`, sent from compromised Harrowfield Metalworks account `dana.berglund` through its authorised relay. The payload hash, C2 linkage, and delivery time each independently connect it to the downstream intrusion. Corvan's authentication controls were present and worked as designed. Future protection must add controls that assess trusted-supplier account abuse, attachment and link risk, and anomalous supplier behaviour.
