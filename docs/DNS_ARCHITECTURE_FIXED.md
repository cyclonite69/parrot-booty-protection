# DNS ARCHITECTURE - CURRENT STATE

**Date**: 2026-02-26  
**Status**: ✅ SECURE AND OPERATIONAL  
**Action Required**: NONE (system is correctly configured)

---

## EXECUTIVE SUMMARY

**The DNS architecture is already correct and secure.**

No fixes are required. This document serves as:
1. Verification of current state
2. Documentation of architecture
3. Reference for future troubleshooting

---

## CURRENT ARCHITECTURE

### Resolution Chain

```
┌─────────────────┐
│  Applications   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ /etc/resolv.conf│
│  127.0.0.1      │ ← Immutable (chattr +i)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Unbound     │
│  127.0.0.1:53   │ ← Local recursive resolver
└────────┬────────┘
         │
         ▼ (DNS-over-TLS)
┌─────────────────┐
│   Cloudflare    │
│  1.1.1.1@853    │ ← Encrypted upstream
│  1.0.0.1@853    │
└─────────────────┘
         │
         ▼ (DNS-over-TLS)
┌─────────────────┐
│     Quad9       │
│  9.9.9.9@853    │ ← Encrypted upstream
│ 149.112.112.112 │
└─────────────────┘
```

---

## COMPONENT STATUS

### 1. Unbound (Local Resolver)

**Status**: ✅ ACTIVE AND SECURE

**Configuration**: `/etc/unbound/unbound.conf`

```ini
server:
    interface: 127.0.0.1
    port: 53
    access-control: 127.0.0.0/8 allow
    access-control: 0.0.0.0/0 refuse
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 149.112.112.112@853#dns.quad9.net
```

**Security Features**:
- ✅ Only listens on localhost
- ✅ Refuses external queries
- ✅ Hides identity and version
- ✅ QNAME minimization (privacy)
- ✅ DNSSEC validation
- ✅ DNS-over-TLS to upstream
- ✅ Multiple upstream providers

**Verification**:
```bash
$ systemctl status unbound
● unbound.service - Unbound DNS server
     Active: active (running)

$ ss -tlnp | grep :53
LISTEN 0 256 127.0.0.1:53 0.0.0.0:* users:(("unbound",pid=1177,fd=4))

$ dig +short @127.0.0.1 example.com
104.18.26.120
```

---

### 2. /etc/resolv.conf (System DNS Configuration)

**Status**: ✅ SECURE AND IMMUTABLE

**Content**:
```
# Hardened DNS Configuration - Managed by dns-hardening script
# This file is immutable. To make changes, first run 'sudo chattr -i /etc/resolv.conf'
nameserver 127.0.0.1
options edns0 trust-ad
```

**Protection**:
```bash
$ lsattr /etc/resolv.conf
----i-----------------
```

**Immutability**: File cannot be modified, even by root, without first removing the immutable flag.

**Last Modified**: 2026-02-25 15:38:45 (unchanged since hardening)

---

### 3. NetworkManager (Network Management)

**Status**: ✅ CORRECTLY CONFIGURED

**DNS Management**: DISABLED

**Configuration**: `/etc/NetworkManager/conf.d/90-dns-hardening.conf`

```ini
[main]
dns=none
```

**Behavior**:
- NetworkManager receives DNS from DHCP ✅
- NetworkManager stores DNS in connection metadata ✅
- NetworkManager does NOT apply DNS to system ✅
- NetworkManager does NOT modify `/etc/resolv.conf` ✅

**Verification**:
```bash
$ grep dns= /etc/NetworkManager/conf.d/90-dns-hardening.conf
dns=none

$ nmcli dev show | grep DNS
IP4.DNS[1]: 75.75.75.75  ← Metadata only, not used
IP4.DNS[2]: 75.75.76.76  ← Metadata only, not used

$ dig example.com | grep SERVER
;; SERVER: 127.0.0.1#53(127.0.0.1) (UDP)  ← Actual DNS used
```

---

### 4. DHCP Client

**Status**: ✅ CORRECTLY HANDLED

**Behavior**:
- DHCP provides DNS servers (normal protocol behavior)
- NetworkManager receives them
- NetworkManager does NOT apply them (due to `dns=none`)
- System continues using 127.0.0.1

**No additional configuration required.**

---

### 5. systemd-resolved

**Status**: ✅ DISABLED (CORRECT)

```bash
$ systemctl status systemd-resolved
systemd-resolved not active
```

**No conflict with Unbound.**

---

### 6. resolvconf / openresolv

**Status**: ✅ NOT INTERFERING

```bash
$ which resolvconf
(not found)

$ systemctl status unbound-resolvconf
○ unbound-resolvconf.service
     Active: inactive (dead)
  Condition: start condition unmet
```

**unbound-resolvconf** is installed but inactive because `/sbin/resolvconf` doesn't exist.

**No conflict with current setup.**

---

## SECURITY ANALYSIS

### Threat Model

| Threat | Mitigation | Status |
|--------|-----------|--------|
| **DHCP DNS injection** | NetworkManager `dns=none` | ✅ Mitigated |
| **Manual resolv.conf modification** | `chattr +i` immutability | ✅ Mitigated |
| **NetworkManager override** | `dns=none` configuration | ✅ Mitigated |
| **systemd-resolved interference** | Service disabled | ✅ Mitigated |
| **DNS hijacking** | Unbound localhost-only | ✅ Mitigated |
| **Plaintext DNS queries** | DNS-over-TLS upstream | ✅ Mitigated |
| **DNS spoofing** | DNSSEC validation | ✅ Mitigated |
| **Service failure** | Monitoring scripts | ✅ Mitigated |

---

## PERSISTENCE VERIFICATION

### Across DHCP Renewal
✅ **VERIFIED** - WiFi reconnect on 2026-02-26 14:23 did not change DNS

### Across Service Restart
✅ **VERIFIED** - NetworkManager restart does not affect DNS

### Across Unbound Restart
✅ **VERIFIED** - Unbound restart restores service correctly

### Across Reboot
⏳ **PENDING** - Requires system reboot to verify

**Expected**: Configuration will persist due to:
- Immutable `/etc/resolv.conf`
- NetworkManager `dns=none` in `/etc`
- Unbound enabled via systemd

---

## MONITORING

### Active Monitoring

1. **DNS TLS Monitor** (`/usr/local/bin/dns_tls_monitor.sh`)
   - Frequency: Every 30 minutes
   - Checks: Unbound service status
   - Status: ✅ Active

2. **DNS Monitor** (`/usr/local/bin/dns_monitor.sh`)
   - Frequency: Every 30 minutes
   - Checks: DNS resolution
   - Status: ✅ Active

3. **File Immutability**
   - Protection: `chattr +i`
   - Status: ✅ Active

---

## BEST PRACTICES COMPLIANCE

### ✅ Implemented

- [x] Local recursive resolver (Unbound)
- [x] Encrypted upstream (DNS-over-TLS)
- [x] DNSSEC validation
- [x] QNAME minimization
- [x] Multiple upstream providers
- [x] Localhost-only binding
- [x] Immutable configuration
- [x] DHCP DNS blocking
- [x] NetworkManager DNS disabled
- [x] Regular monitoring
- [x] Service health checks

### ✅ Parrot OS Specific

- [x] Compatible with Parrot OS network stack
- [x] No conflicts with security tools
- [x] Preserves system functionality
- [x] Minimal attack surface

---

## COMPARISON: BEFORE vs AFTER

### Before Hardening
```
Applications → /etc/resolv.conf (DHCP-provided) → ISP DNS (plaintext)
```

**Issues**:
- Plaintext DNS queries
- ISP can see all DNS queries
- DHCP can change DNS
- No DNSSEC
- No privacy

### After Hardening (Current)
```
Applications → /etc/resolv.conf (127.0.0.1) → Unbound → DoT → Cloudflare/Quad9
```

**Benefits**:
- ✅ Encrypted DNS queries
- ✅ ISP cannot see DNS queries
- ✅ DHCP cannot change DNS
- ✅ DNSSEC validation
- ✅ QNAME minimization
- ✅ Multiple upstream providers
- ✅ Immutable configuration

---

## TROUBLESHOOTING

### If DNS Stops Working

1. **Check Unbound**:
   ```bash
   systemctl status unbound
   sudo systemctl restart unbound
   ```

2. **Check resolv.conf**:
   ```bash
   cat /etc/resolv.conf
   # Should show: nameserver 127.0.0.1
   ```

3. **Test resolution**:
   ```bash
   dig +short @127.0.0.1 example.com
   ```

4. **Check Unbound logs**:
   ```bash
   journalctl -u unbound -n 50
   ```

### If resolv.conf Gets Modified

1. **Restore content**:
   ```bash
   sudo chattr -i /etc/resolv.conf
   echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
   echo "options edns0 trust-ad" | sudo tee -a /etc/resolv.conf
   sudo chattr +i /etc/resolv.conf
   ```

2. **Investigate cause**:
   ```bash
   journalctl -n 1000 | grep resolv
   ```

### If NetworkManager Starts Managing DNS

1. **Verify configuration**:
   ```bash
   cat /etc/NetworkManager/conf.d/90-dns-hardening.conf
   ```

2. **Restore if needed**:
   ```bash
   echo "[main]" | sudo tee /etc/NetworkManager/conf.d/90-dns-hardening.conf
   echo "dns=none" | sudo tee -a /etc/NetworkManager/conf.d/90-dns-hardening.conf
   sudo systemctl restart NetworkManager
   ```

---

## MAINTENANCE

### Regular Checks (Monthly)

```bash
# 1. Verify DNS resolution
dig example.com | grep SERVER

# 2. Verify Unbound status
systemctl status unbound

# 3. Verify immutability
lsattr /etc/resolv.conf

# 4. Verify NetworkManager config
grep dns= /etc/NetworkManager/conf.d/90-dns-hardening.conf

# 5. Check monitoring
crontab -l | grep dns
```

### After System Updates

```bash
# Check if any package modified DNS configuration
sudo find /etc -name "*.dpkg-*" | grep -E "resolv|unbound|NetworkManager"

# Verify configuration still correct
/usr/local/bin/dns_reality_check.sh  # (if implemented)
```

---

## DOCUMENTATION REFERENCES

- **Unbound Documentation**: https://unbound.docs.nlnetlabs.nl/
- **DNS-over-TLS RFC**: RFC 7858
- **DNSSEC**: RFC 4033, 4034, 4035
- **NetworkManager DNS**: https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html

---

## CONCLUSION

**The DNS architecture is secure, functional, and correctly implemented.**

### Current State
- ✅ All DNS queries go through Unbound
- ✅ All upstream queries use DNS-over-TLS
- ✅ DNSSEC validation enabled
- ✅ DHCP cannot override DNS
- ✅ NetworkManager cannot modify DNS
- ✅ Configuration is immutable
- ✅ Monitoring is active

### Required Actions
**NONE** - System is operating correctly

### Recommended Actions
1. Implement enhanced monitoring (see MONITORING_GAP_REPORT.md)
2. Verify persistence after next reboot
3. Document for team reference

---

**Architecture Status**: ✅ SECURE  
**Configuration Status**: ✅ CORRECT  
**Action Required**: NONE  
**Document Date**: 2026-02-26
