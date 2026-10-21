# CSR Workshop – MedDefense Patient Portal

## Part 1 – Key Generation Decision

I chose **RSA-2048** for the private key. It provides a strong and widely accepted level of security while maintaining excellent compatibility with older browsers and legacy medical devices that may still be in use. RSA-4096 offers higher security but adds unnecessary computational overhead for a portal handling around 800 daily connections. ECC P-256 is more efficient but may introduce compatibility issues in older environments. Therefore, RSA-2048 is the best balance of security, performance, and compatibility.

**Key Generation Command:**

```bash
openssl genrsa -out portal_key.pem 2048
```

---

## Part 2 – CSR Generation

### OpenSSL Configuration (`openssl.cnf`)

```ini
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = AZ
ST = Baku
L = Baku
O = MedDefense Health Systems
OU = Information Technology
CN = portal.meddefense.local

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = portal.meddefense.local
DNS.2 = www.portal.meddefense.local
```

### CSR Generation Command

```bash
openssl req -new -key portal_key.pem -out portal.csr -config openssl.cnf
```

---

## Part 3 – CSR Inspection

```bash
openssl req -text -noout -in portal.csr
```

### Key Output Verification (Summary)

* **Subject:** CN=portal.meddefense.local, O=MedDefense Health Systems
* **Organization Unit:** Information Technology
* **Location:** Baku, AZ
* **Public Key Algorithm:** RSA (2048 bits)
* **Signature Algorithm:** sha256WithRSAEncryption
* **Subject Alternative Names:**

  * DNS:portal.meddefense.local
  * DNS:www.portal.meddefense.local

✔ All required fields are correctly present
✔ SAN entries are included and valid

---

## Part 4 – Certificate Lifecycle

1. **CSR Generation**
   Private key and CSR are generated securely on the server.

2. **Submission to Certificate Authority (CA)**
   Submit CSR to a CA such as **Let’s Encrypt (via ACME)** or a commercial provider.

3. **Validation Process**
   The CA verifies domain ownership (e.g., DNS challenge or HTTP challenge).

4. **Certificate Issuance**
   The CA issues a signed certificate based on the CSR.

5. **Installation**
   Install the certificate and private key on the web server (e.g., Nginx/Apache).

6. **Verification**
   Confirm the certificate is active using a browser or `openssl s_client`.

7. **Decommission Old Certificate**
   Remove expired certificate and ensure it is no longer used.

8. **Monitoring & Renewal**
   Set up automated renewal (e.g., Certbot) and monitor expiration dates.

---

