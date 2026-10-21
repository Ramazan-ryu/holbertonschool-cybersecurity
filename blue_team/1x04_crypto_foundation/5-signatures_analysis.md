# Digital Signatures in Practice

## Part 1 — Sign and Verify

Create prescription.txt:


Patient: John Smith | MRN: MED-10042 | Rx: Metoprolol 50mg | Prescriber: Dr. Patel


Sign the file:

```bash
openssl dgst -sha256 -sign rsa_private.pem -out prescription.txt.sig prescription.txt

Verify the signature:

openssl dgst -sha256 -verify rsa_public.pem -signature prescription.txt.sig prescription.txt

Output:

Verified OK

Modify one character in prescription.txt, then verify:

Output:

Verification Failure

Explanation:
In a hospital, if verification fails, the pharmacist cannot trust the prescription. Admins must resolve it before dispensing medication, preventing potential patient harm.

Part 2 — Three Properties of Digital Signatures

Integrity:
The hash of the document is signed with the private key. Verification recomputes the hash and ensures it matches, so any modification is detected.

Authentication:
Only the holder of the private key could have created the signature. Verification with the public key confirms the signer’s identity.

Non-repudiation:
The signer cannot deny signing because the private key uniquely produces the valid signature. Forging it would require access to the private key.

Part 3 — MedDefense Application
Electronic Prescriptions:
Data signed: prescription text
Signed by: prescribing doctor
Verified by: pharmacist
Consequence: dispensing wrong meds if signature invalid
Clinical Trial Consent Forms:
Data signed: consent document
Signed by: patient
Verified by: clinical staff
Consequence: legal compliance violated if signature missing
Audit Logs:
Data signed: log entries
Signed by: system logging service
Verified by: compliance officer
Consequence: tampering undetected, regulatory breach
