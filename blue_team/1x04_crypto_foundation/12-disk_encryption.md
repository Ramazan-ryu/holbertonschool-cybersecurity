# LUKS Disk Encryption – MedDefense

## Part 1 – LUKS Setup

### Create Virtual Disk

```bash
dd if=/dev/zero of=encrypted_volume.img bs=1M count=500
```

### Format with LUKS

```bash
sudo cryptsetup luksFormat encrypted_volume.img
```

### Open Encrypted Volume

```bash
sudo cryptsetup luksOpen encrypted_volume.img secure_vol
```

### Create Filesystem

```bash
sudo mkfs.ext4 /dev/mapper/secure_vol
```

### Mount and Write Data

```bash
sudo mount /dev/mapper/secure_vol /mnt
echo "Sensitive backup data" | sudo tee /mnt/test.txt
```

### Unmount and Close

```bash
sudo umount /mnt
sudo cryptsetup luksClose secure_vol
```

---

## Part 2 – Verification

### Attempt to Read Raw File

```bash
strings encrypted_volume.img | head -50
```

**Result:** No readable sensitive data is visible. Only random-looking output appears.

**Conclusion:** This proves that encryption at rest protects data from being read directly from storage without the key.

---

### Reopen and Verify Data

```bash
sudo cryptsetup luksOpen encrypted_volume.img secure_vol
sudo mount /dev/mapper/secure_vol /mnt
cat /mnt/test.txt
```

✔ Output: "Sensitive backup data"

```bash
sudo umount /mnt
sudo cryptsetup luksClose secure_vol
```

✔ Data integrity confirmed after decryption cycle.

---

## Part 3 – MedDefense Backup Encryption Design

### Encryption Level

Full-disk encryption using LUKS is the most appropriate solution for NAS-01. It ensures that all backup data is protected transparently without requiring changes to backup applications.

### Performance Impact

Encryption introduces approximately 5–15% overhead based on typical AES performance. For MedDefense, this is acceptable given the high sensitivity of patient data and the importance of confidentiality.

### Key Storage

Encryption keys must be stored securely outside the NAS, such as in a centralized key management system or offline secure vault. Storing the key on the NAS would defeat the purpose, as an attacker gaining access would obtain both data and key.

### Key Loss Implications

If the encryption key is lost, all backup data becomes permanently inaccessible. Therefore, secure key backup procedures must be implemented (e.g., escrow copies in a secure location).

### Offsite Backup Integration

Offsite backups must also be encrypted. Ideally, encryption should occur before data leaves NAS-01, ensuring the cloud provider never sees plaintext data. MedDefense should retain control of the encryption keys, not the cloud provider.

---

