# LogiCorp Gateway — Black-Box Audit Report

**Auditor:** Ramazan  
**Date:** 2026-09-10  
**Target:** `ip-10-42-176-28.ec2.internal` (`10.42.176.28`)  
**Access:** SSH through the active Termius lab session as `student`

## Executive summary

The live host is an Ubuntu 22.04.5 gateway/container with a flat `10.42.0.0/16` network. It exposes SSH, FTP, a ttyd terminal, and an OpenVSCode server on all IPv4 interfaces. Root SSH login and password authentication are enabled. `vsftpd` is running, and a root cron entry calls an internal HTTP endpoint every minute. No host firewall or MAC-control status could be verified as the `student` user because `sudo` requires a password and the container lacks `systemd`.

## 1. System information

| Item | Observed value |
|---|---|
| OS | Ubuntu 22.04.5 LTS (Jammy) |
| Kernel | Linux `6.1.177`, x86_64 |
| Hostname | `ip-10-42-176-28.ec2.internal` |
| Uptime at audit | 24 minutes |
| Init | Not systemd; PID 1 is `/bin/sh` |

Command: `cat /etc/os-release; uname -a; hostname; uptime`

## 2. Network topology

| Interface | Address | State |
|---|---|---|
| `eth0@if5` | `169.254.172.2/22` | UP |
| `eth1` | `10.42.176.28/16` | UP |
| `lo` | `127.0.0.1/8`, `::1/128` | UNKNOWN |

Routing:

```text
default via 10.42.0.1 dev eth1
10.42.0.0/16 dev eth1 src 10.42.176.28
169.254.169.254 blackhole
169.254.170.2 via 169.254.172.1 dev eth0
```

ARP/neighbour discovery showed gateway `10.42.0.1`, MAC `16:ca:fb:da:4b:d3`, state `REACHABLE`. The topology is flat rather than segmented into documented trust zones.

## 3. Attack surface

Observed with `ss -tulpn`:

| Protocol | Bind | Process/evidence |
|---|---|---|
| TCP | `0.0.0.0:21` | `vsftpd` (PID 63) |
| TCP | `0.0.0.0:22`, `[::]:22` | OpenSSH `sshd` (PID 89) |
| TCP | `0.0.0.0:3000` | root-run OpenVSCode server/node |
| TCP | `0.0.0.0:3001` | root-run `ttyd` terminal |
| UDP | none observed | — |

Relevant process evidence:

```text
root 63  vsftpd /usr/sbin/vsftpd
root 91  ttyd   ttyd --cwd /root --writable ... -p 3001 /bin/bash
root 98  sh     /usr/bin/openvscode-server --host 0.0.0.0 ...
root 105 node   /usr/node /usr/out/server-main.js --host 0.0.0.0 ...
```

## 4. Security controls

- Firewall: **not verifiable** as `student`; `sudo -n nft list ruleset` required a password and unprivileged `nft` returned “Operation not permitted”.
- SELinux: `getenforce` is not installed.
- AppArmor: `aa-status` is not installed.
- SSH: `PermitRootLogin yes`, `PasswordAuthentication yes`, `PubkeyAuthentication yes`, `AllowUsers student`.
- Multiple services bind to all IPv4 interfaces.

## 5. User accounts and SSH keys

Local interactive accounts include `root` and `student`; service accounts include `ftp`, `sshd`, `www-data`, and standard system users. `/home/student/.ssh/authorized_keys` exists. Root’s SSH directory could not be inspected because `/root` is not readable by `student`. `sudo -l` was attempted but requires a password.

## 6. Running services

Active processes include `sshd`, `vsftpd`, `cron`, `ttyd`, OpenVSCode Server/node, and the `/etc/run.sh` launcher. `systemctl` is unavailable because the host is not booted with systemd.

## 7. Scheduled tasks

`/etc/cron.d/logicorp` contains:

```cron
* * * * * root /usr/bin/curl http://192.168.1.200/ping
# FLAG{CR0N_B4CKD00R}
```

Standard hourly/daily/weekly/monthly root jobs are also present. No personal crontab exists for `student`. No systemd timers could be listed because systemd is not PID 1.

## 8. Flag-discovery evidence

Commands used:

```bash
find / -type f -iname '*flag*' 2>/dev/null -print
find / -type f -iname '*flag*' -exec sh -c 'echo "=== $1"; cat "$1"' _ {} \; 2>/dev/null
```

The Level 2 indicator was confirmed with:

```bash
cat /etc/logicorp/telnet.flag
```

Output:

```text
# FLAG{UNN3C3SS4RY_S3RV1C3}
```

Additional direct evidence from `/etc/logicorp/`:

```bash
cat security.policy
# FLAG{R00T_L0G1N_D3T3CT3D}

cat network.conf
# FLAG{AUD1T_FL4T_N3TW0RK}

cat db.conf
# FLAG{Z3R0_TRU5T_Z0N3S}
```

These files confirm the flat network and root-login findings. `db.conf` also exposes an internal database endpoint (`192.168.1.50:3306`) and a zero-trust-zone finding.

## 9. Discrepancies from documentation

| Documented/expected | Live reality |
|---|---|
| Trust zones / segmented design | `NETWORK_MODE=FLAT`; one `10.42.0.0/16` segment |
| Minimal gateway exposure | FTP, SSH, ttyd, and OpenVSCode are listening |
| Hardened SSH | Root login and password authentication are enabled |
| Services verified by systemd | Container uses shell launcher; systemd is unavailable |
| Scheduled-task state unknown | Root cron callback exists every minute |

## 10. Findings and recommendations

1. Disable root SSH login and password authentication; use restricted key-based access.
2. Stop/remove FTP, ttyd, and OpenVSCode unless required; bind administration services to a management/VPN address.
3. Replace the flat network with explicit trust zones and restrictive ingress rules.
4. Investigate `/etc/cron.d/logicorp` and the `192.168.1.200` callback as unauthorized persistence or beaconing.
5. Run a privileged follow-up audit to capture nftables rules, root SSH keys, and complete service configuration.
