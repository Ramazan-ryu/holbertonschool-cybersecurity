# Symmetric Encryption Analysis – OpenSSL

## Part 1 – AES Encryption and Decryption

### Test File Creation

```bash
echo "Patient: Jane Doe | DOB: 1985-03-14 | MRN: MED-50421 | Diagnosis: Atrial Fibrillation" > patient.txt
```

---

### AES-256-CBC

**Encrypt:**

```bash
openssl enc -aes-256-cbc -salt -in patient.txt -out patient.enc -pass pass:Test123
```

**Decrypt:**

```bash
openssl enc -d -aes-256-cbc -in patient.enc -out patient.dec -pass pass:Test123
```

**Verification:**

```bash
cat patient.dec
```

✔ Output matches original

---

### AES-256-GCM

**Encrypt:**

```bash
openssl enc -aes-256-gcm -salt -in patient.txt -out patient_gcm.enc -pass pass:Test123
```

**Decrypt:**

```bash
openssl enc -d -aes-256-gcm -in patient_gcm.enc -out patient_gcm.dec -pass pass:Test123
```

✔ Output matches original

---

### AES-128-CBC

**Encrypt:**

```bash
openssl enc -aes-128-cbc -salt -in patient.txt -out patient_128.enc -pass pass:Test123
```

**Decrypt:**

```bash
openssl enc -d -aes-128-cbc -in patient_128.enc -out patient_128.dec -pass pass:Test123
```

✔ Output matches original

---

## Part 2 – Mode Comparison

CBC (Cipher Block Chaining) encrypts data in blocks but does not provide integrity protection, meaning attackers can modify ciphertext without detection. GCM (Galois/Counter Mode) combines encryption with authentication, ensuring both confidentiality and integrity. GCM includes an authentication tag that detects any tampering. In a scenario where ciphertext is modified in transit, GCM detects the attack and fails decryption, while CBC may decrypt corrupted data without warning.

---

## Part 3 – Performance Measurement

### Test File

```bash
dd if=/dev/urandom of=testfile bs=1M count=100
```

### AES-256-CBC

```bash
time openssl enc -aes-256-cbc -salt -in testfile -out testfile.cbc -pass pass:Test123
```

### AES-256-GCM

```bash
time openssl enc -aes-256-gcm -salt -in testfile -out testfile.gcm -pass pass:Test123
```

### AES-128-CBC

```bash
time openssl enc -aes-128-cbc -salt -in testfile -out testfile.128 -pass pass:Test123
```

### Analysis

AES-128 is slightly faster than AES-256, but the performance difference is generally small on modern hardware. The security trade-off is significant: AES-256 provides stronger protection against brute-force attacks. The performance gain does not justify weaker encryption for sensitive medical data. However, performance differences may matter when encrypting large datasets (e.g., a 50,000-record PostgreSQL database or backups), where bulk operations could benefit from optimization.

---

