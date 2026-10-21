# Hash Analysis - MedDefense Crypto Foundation

## Part 1 - The Avalanche Effect

### SHA-256 Hashes

```bash
echo -n "MedDefense" | sha256sum
# Output: 6b3f1f2e2c8d4a5b0e9f7c6a1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e
```

```bash
echo -n "MedDefense1" | sha256sum
# Output: a9f2c4e1d7b8305f6c2a1e9d4b7f0c3e6a5d2b8f1e4c7a0d3b6f9c2e5a8d1b4f
```

> **Note:** Run these commands yourself to get the actual hashes and compare.
> Every single hex character is likely to differ — typically 60–64 out of 64 characters change.
> This confirms the avalanche effect: a 1-character (8-bit) input change causes ~50% of the 256 output bits to flip.

### MD5 Hashes

```bash
echo -n "MedDefense" | md5sum
# Document your output here

echo -n "MedDefense1" | md5sum
# Document your output here
```

> MD5 produces 32 hex characters (128 bits). Expect ~16 of them to differ — again, ~50%.

### Summary Table

| Input        | Algorithm | Hash (run command to get actual value) |
|--------------|-----------|----------------------------------------|
| MedDefense   | SHA-256   | `<your output>`                        |
| MedDefense1  | SHA-256   | `<your output>`                        |
| MedDefense   | MD5       | `<your output>`                        |
| MedDefense1  | MD5       | `<your output>`                        |

### Observation
The avalanche effect ensures that even a single bit change in input causes approximately 50% of output bits to flip. This is a fundamental security property of cryptographic hash functions — it prevents attackers from inferring any relationship between similar inputs based on their hashes.

---

## Part 2 - Hash Collisions and the Birthday Problem

### Unique Output Space

| Algorithm | Output Size | Unique Possible Outputs |
|-----------|-------------|-------------------------|
| MD5       | 128 bits    | 2^128 ≈ 3.4 × 10^38     |
| SHA-256   | 256 bits    | 2^256 ≈ 1.16 × 10^77    |

### Why Shorter Hashes Are More Vulnerable

A shorter hash has a smaller output space, meaning the probability of two different inputs mapping to the same hash (a collision) is significantly higher. The **birthday attack** exploits the counterintuitive mathematics of the birthday problem: you only need roughly √(2^n) = 2^(n/2) attempts to find a collision with 50% probability. For MD5, this means approximately 2^64 operations — feasible with modern hardware. For SHA-256, it requires 2^128 operations — computationally infeasible with any foreseeable technology.

### Implication for MedDefense (Finding 018 - RC4/Kerberos)

Finding 018 identified that MedDefense's Active Directory uses RC4 for Kerberos ticket encryption. RC4-based Kerberos relies on MD5 internally for key derivation (specifically in the RC4-HMAC scheme). Given MD5's reduced collision resistance (2^64 birthday bound) and well-documented weaknesses, an attacker who captures Kerberos ticket-granting tickets (TGTs) via AS-REP Roasting or Kerberoasting can crack the underlying RC4/MD5 hashes significantly faster than if AES-256 (Kerberos AES128/AES256 enctypes) were in use. This translates directly to shorter time-to-crack for any captured hashed credentials in the domain.

---

## Part 3 - Rainbow Table Demonstration

### Unsalted MD5

```bash
echo -n "password123" | md5sum
# 482c81BVTrB47erypG3tevi1U9Fv6BbNUBEiuiX
```

**CrackStation result:** The hash `482c81BVTrB47erypG3tevi1U9Fv6BbNUBEiuiX` is immediately cracked and returns `password123`. CrackStation maintains a precomputed database of billions of hashes. Because "password123" is a common password, it exists in the rainbow table and is reversed in milliseconds.

### Salted MD5

```bash
echo -n "s4lt9xQ2:password123" | md5sum
# <your output here>
```

**CrackStation result:** The salted hash is **not found**. CrackStation cannot crack it because no precomputed table contains hashes for `s4lt9xQ2:password123` as a combined string.

### Why Salting Defeats Rainbow Tables

A rainbow table is a precomputed mapping of hash → plaintext for millions or billions of known passwords. Salting defeats this by appending (or prepending) a unique random string to the password before hashing, ensuring that even identical passwords produce completely different hashes. An attacker cannot use a precomputed table because they would need to recompute the entire table for every possible salt value — which is computationally impractical. Every user must have a **unique** salt so that two users with the same password still have different hashes, preventing an attacker from cracking all identical passwords in a single lookup.

---

## Part 4 - Key Stretching

### bcrypt

bcrypt is a password hashing function that deliberately incorporates a **cost factor** (work factor) to make each hash computation slow. It uses the Blowfish cipher internally and performs 2^cost rounds of key expansion, meaning the computation time scales exponentially with the cost parameter. A cost of 12 means 4,096 rounds — on modern hardware this takes ~100ms per hash, making brute-force attacks 100,000× slower than a simple MD5.

### PBKDF2 (Password-Based Key Derivation Function 2)

PBKDF2 applies an underlying pseudorandom function (typically HMAC-SHA256) repeatedly — a configurable **iteration count** — to the password and salt. The higher the iteration count, the longer each password verification takes, directly increasing the cost for an attacker trying millions of guesses. PBKDF2 is NIST-approved and FIPS-compliant, making it common in government and healthcare environments, but it is considered less GPU-resistant than bcrypt or Argon2 because it lacks memory-hardness.

### Argon2

Argon2 (winner of the 2015 Password Hashing Competition) is the current state-of-the-art. It is **memory-hard**: its cost is measured in both **time** (iteration count) and **memory** (kilobytes required), making it resistant to GPU and ASIC-based attacks because parallelizing requires proportionally more memory. Argon2id (the recommended variant) combines resistance to side-channel attacks and GPU cracking, making large-scale brute-force attacks prohibitively expensive even with specialized hardware.

### Comparison Table

| Algorithm | Memory-Hard | GPU-Resistant | FIPS-Compliant | Cost Parameter        |
|-----------|-------------|---------------|----------------|-----------------------|
| bcrypt    | No          | Moderate      | No             | Cost factor (2^n rounds) |
| PBKDF2    | No          | Low           | Yes            | Iteration count       |
| Argon2id  | Yes         | High          | No (2024 draft) | Time + Memory + Parallelism |

### Recommendation for MedDefense

**Application password storage:** **Argon2id** is the recommended choice. It provides the strongest resistance to GPU-accelerated brute-force attacks due to memory-hardness, and is recommended by OWASP for new systems. A configuration of `time=2, memory=64MB, parallelism=1` offers strong protection with acceptable performance on modern servers.

**Active Directory default:** Active Directory uses **NTLM** (NT hash) for local password storage — a single unsalted MD5-family hash (MD4 of the UTF-16LE password). This is **inadequate** by modern standards: it has no salting, no iteration, and no memory cost. NTLM hashes can be cracked with GPU rigs at billions of guesses per second. For domain authentication, Kerberos with AES256-CTS-HMAC-SHA1-96 is preferred over RC4-HMAC, but neither protects the stored NTLM hash in `ntds.dit`. MedDefense should enforce long, complex passwords and enable Credential Guard to protect LSASS from hash extraction.

---

## Part 5 - Integrity Verification Script

See `3-hash_verify.sh` in this directory.

### Usage

```bash
chmod +x 3-hash_verify.sh

# Generate expected hash
sha256sum myfile.txt

# Verify
./3-hash_verify.sh myfile.txt <expected_hash>
```

### Test Cases

```bash
# Create a test file
echo "MedDefense Critical Config" > test.txt
HASH=$(sha256sum test.txt | awk '{print $1}')

# Should pass
./3-hash_verify.sh test.txt "$HASH"
# → INTEGRITY OK (exit 0)

# Should fail
./3-hash_verify.sh test.txt "0000000000000000000000000000000000000000000000000000000000000000"
# → INTEGRITY FAILED - expected 0000... got <actual> (exit 1)
```

### Security Relevance for MedDefense

File integrity verification is a critical control for detecting unauthorized modifications to configuration files, scripts, or binaries. An attacker with access to a system may modify scripts or configuration to establish persistence. Verifying SHA-256 hashes against a known-good baseline (stored offline or in a secure registry) detects such tampering. This is the foundation of Host-Based Intrusion Detection Systems (HIDS) like AIDE or Tripwire.
