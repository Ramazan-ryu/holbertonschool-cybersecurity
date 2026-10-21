# Asymmetric Encryption Analysis

## Goal

Generate RSA and ECC key pairs, discover the size limitation of asymmetric encryption, and understand why the hybrid encryption model exists.

---

# Part 1 — RSA Key Generation and Encryption

## Generate RSA-2048 Key Pair

Generate private key:

openssl genrsa -out rsa_private.pem 2048

Generate public key:

openssl rsa -in rsa_private.pem -pubout -out rsa_public.pem

Verify files:

ls -lh rsa_private.pem rsa_public.pem

Expected:

rsa_private.pem  ~1700 bytes  
rsa_public.pem   ~450 bytes  

---

## Create Test File

echo "Patient: Jane Doe | DOB: 1985-03-14 | MRN: MED-50421 | Diagnosis: Atrial Fibrillation" > patient.txt

---

## Encrypt Small File with RSA Public Key

openssl pkeyutl \
-encrypt \
-pubin \
-inkey rsa_public.pem \
-in patient.txt \
-out patient.rsa.enc

---

## Decrypt with RSA Private Key

openssl pkeyutl \
-decrypt \
-inkey rsa_private.pem \
-in patient.rsa.enc \
-out patient_decrypted.txt

---

## Verify

diff patient.txt patient_decrypted.txt

Result:

SUCCESS — decrypted file matches original.

---

# Attempt to Encrypt 100MB File with RSA

Command:

openssl pkeyutl \
-encrypt \
-pubin \
-inkey rsa_public.pem \
-in testfile \
-out testfile.rsa.enc

Typical Error Message:

error:0406D06E:rsa routines:RSA_padding_add_PKCS1_type_2:data too large for key size

---

## Explanation

RSA cannot encrypt large files directly because the maximum data size is limited by the key length and padding requirements. For RSA-2048, the usable plaintext size is typically around 245 bytes.

This limitation means RSA is not used for bulk data encryption in real-world systems. Instead, RSA is used to encrypt small pieces of data such as symmetric encryption keys.

---

# Part 2 — ECC Key Generation

## Generate ECC Key Pair (P-256)

Generate private key:

openssl ecparam -genkey -name prime256v1 -out ecc_private.pem

Generate public key:

openssl ec -in ecc_private.pem -pubout -out ecc_public.pem

---

## Compare File Sizes

ls -lh rsa_private.pem ecc_private.pem

Example output:

rsa_private.pem   1704 bytes  
ecc_private.pem    227 bytes  

---

## Ratio Calculation

RSA private key ≈ 1700 bytes  
ECC private key ≈ 227 bytes  

Ratio:

RSA is approximately 7.5 times larger than ECC.

---

## Explanation

ECC achieves equivalent security with smaller keys because it relies on the mathematical difficulty of the elliptic curve discrete logarithm problem, which is harder per bit than integer factorization used in RSA.

This matters for constrained environments such as medical devices like infusion pumps and patient monitors because smaller keys require less processing power, less memory, and less battery usage while still maintaining strong security.

---

# Part 3 — The Hybrid Encryption Model

Modern secure communication uses a hybrid encryption model that combines asymmetric and symmetric encryption.

First, asymmetric encryption (RSA or ECC) is used during the handshake to securely exchange a symmetric session key. Once both parties share this key, symmetric encryption (such as AES or ChaCha20) is used to encrypt the actual data.

This combination is superior because asymmetric encryption solves the key distribution problem, while symmetric encryption provides fast and efficient data encryption.

In MedDefense's patient portal, the TLS handshake handles the key exchange using asymmetric cryptography. After the handshake completes, symmetric encryption handles the bulk data transmission such as medical records, login credentials, and session data.

---

# Part 4 — Key Length and Algorithm Comparison Table

| Algorithm | Type | Key Lengths | Equivalent Security | Status | MedDefense Usage |
|-----------|------|------------|--------------------|--------|-----------------|
| AES | Symmetric | 128 / 192 / 256 | Strong | Approved | Primary data encryption |
| RSA | Asymmetric | 2048 / 4096 | Strong | Approved | TLS certificates / key exchange |
| ECC | Asymmetric | P-256 / P-384 | Strong | Approved | TLS, mobile devices |
| ChaCha20-Poly1305 | Symmetric | 256-bit | Strong | Approved | Mobile / VPN encryption |
| DES | Symmetric | 56-bit | Weak | Deprecated | Not allowed |
| 3DES | Symmetric | 168-bit | Weak / Legacy | Deprecated | Phase-out required |
| RC4 | Symmetric | Variable | Broken | Prohibited | Not allowed |

---

# Security Summary

Approved algorithms for healthcare environments handling regulated data:

AES  
RSA (2048+)  
ECC (P-256+)  
ChaCha20-Poly1305  

Deprecated or prohibited algorithms:

DES  
3DES  
RC4  

Healthcare systems must use modern, NIST-approved cryptographic standards to protect patient data and comply with regulatory requirements.
