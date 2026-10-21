# MedDefense Data Protection Map

## Data Protection Matrix

"""

| Data Category                                  | At Rest                                                                                                        | In Transit                                                                                                 | In Use                                                                                           |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **Patient medical records (EHR - PostgreSQL)** | Protection: None<br>Evidence: 1x02 finding – database not encrypted<br>Status: Absent                          | Protection: TLS 1.0<br>Evidence: 1x02 finding – legacy protocol on portal<br>Status: Weak                  | Protection: None<br>Evidence: 1x00 observation – no memory protection controls<br>Status: Absent |
| **Financial/Billing data (MySQL)**             | Protection: AES-128 (disk-level)<br>Evidence: Audit notes – partial disk encryption<br>Status: Weak            | Protection: TLS 1.1<br>Evidence: 1x02 finding – outdated TLS version<br>Status: Weak                       | Protection: None<br>Evidence: 1x00 observation<br>Status: Absent                                 |
| **Medical images (DICOM - PACS)**              | Protection: None<br>Evidence: 1x02 finding – unencrypted PACS storage<br>Status: Absent                        | Protection: None (cleartext DICOM)<br>Evidence: 1x02 finding – cleartext transmission<br>Status: Absent    | Protection: None<br>Evidence: 1x00 observation<br>Status: Absent                                 |
| **Credentials (AD, application passwords)**    | Protection: NTLM hashes<br>Evidence: Audit notes – legacy authentication<br>Status: Weak                       | Protection: Kerberos / LDAP (no signing)<br>Evidence: 1x02 finding – unsigned LDAP traffic<br>Status: Weak | Protection: None<br>Evidence: 1x00 observation<br>Status: Absent                                 |
| **Backup data (NAS-01)**                       | Protection: None<br>Evidence: 1x02 finding – unencrypted backups<br>Status: Absent                             | Protection: SMB (no encryption)<br>Evidence: Audit notes<br>Status: Absent                                 | Protection: None<br>Evidence: 1x00 observation<br>Status: Absent                                 |
| **Email (O365)**                               | Protection: AES-256 (Microsoft-managed)<br>Evidence: Audit notes – O365 default encryption<br>Status: Adequate | Protection: TLS 1.2<br>Evidence: Audit notes<br>Status: Adequate                                           | Protection: None<br>Evidence: 1x00 observation<br>Status: Absent                                 |
| **VPN traffic (site-to-site)**                 | Protection: AES-256 (IPsec tunnels)<br>Evidence: Audit notes<br>Status: Adequate                               | Protection: IPsec (AES-256/SHA-2)<br>Evidence: Audit notes<br>Status: Adequate                             | Protection: None<br>Evidence: 1x00 observation<br>Status: Absent                                 |

---

## Gap Summary

* **Total cells:** 21
* **Adequate:** 4
* **Weak:** 5
* **Absent:** 12

**Overall Crypto Coverage:**
Adequate protection exists in **~19%** of cases (4 out of 21).

**Conclusion:**
MedDefense has significant cryptographic gaps. Over half of all data flows lack any protection, and several critical systems rely on outdated or weak protocols. Immediate remediation is required, particularly for medical data, backups, and internal communications, where protection is either weak or completely absent.


"""
