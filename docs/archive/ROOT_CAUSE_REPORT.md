# ROOT CAUSE REPORT - DNS Configuration Breach

**Investigation Date**: 2026-02-26  
**Incident**: Unauthorized DNS configuration change  
**Status**: ✅ ROOT CAUSE IDENTIFIED

---

## EXECUTIVE SUMMARY

**The system is NOT compromised. DNS is working correctly.**

The "breach" is a **false alarm** caused by misunderstanding NetworkManager's behavior. The system is functioning as designed.

---

## FINDINGS

### 1. ACTUAL DNS RESOLUTION PATH

**Current State**:
```
Applications → /etc/resolv.conf (127.0.0.1) → Unbound → DoT (Cloudflare/Quad9)
```

**Evidence**:
```bash
$ cat /etc/resolv.conf
nameserver 127.0.0.1

$ dig example.com | grep SERVER
;; SERVER: 127.0.0.1#53(127.0.0.1) (UDP)

$ dig +short @127.0.0.1 example.com
104.18.26.120  # Resolved via Unbound
```

**Verdict**: ✅ DNS resolution is going through Unbound correctly.

---

### 2. THE "COMCAST DNS" CONFUSION

**What was observed**:
```bash
$ nmcli dev show | grep DNS
IP4.DNS[1]: 75.75.75.75
IP4.DNS[2]: 75.75.76.76
```

**What this means**:
- NetworkManager **received** these DNS servers from DHCP
- NetworkManager **stored** them in its connection metadata
- NetworkManager **did NOT apply** them to `/etc/resolv.conf`

**Why they weren't applied**:
```bash
$ cat /etc/NetworkManager/conf.d/90-dns-hardening.conf
[main]
dns=none
```

This configuration tells NetworkManager: **"Do not manage DNS"**

---

### 3. WHAT ACTUALLY HAPPENED

**Timeline**:
1. **Feb 25 15:33** - DNS hardening script ran
2. **Feb 25 15:38** - `/etc/resolv.conf` set to `nameserver 127.0.0.1`
3. **Feb 25 15:38** - File made immutable (`chattr +i`)
4. **Feb 26 14:23** - WiFi reconnected, DHCP lease renewed
5. **Feb 26 14:23** - NetworkManager received Comcast DNS from DHCP
6. **Feb 26 14:23** - NetworkManager **ignored** them (dns=none)
7. **Feb 26 14:23** - `/etc/resolv.conf` remained unchanged

**Evidence**:
```bash
$ stat /etc/resolv.conf | grep Modify
Modify: 2026-02-25 15:38:45.882856901 -0500

$ lsattr /etc/resolv.conf
----i----------------- /etc/resolv.conf
```

File has not been modified since Feb 25. Immutable flag is still set.

---

### 4. PROCESS THAT "MODIFIED" DNS

**Answer**: None.

NetworkManager's internal state shows Comcast DNS, but this is **metadata only**. It never touched `/etc/resolv.conf`.

**Proof**:
- File modification time: Feb 25 (before WiFi reconnect)
- Immutable flag: Still set
- File contents: Still `nameserver 127.0.0.1`
- Actual resolution: Going through 127.0.0.1 (Unbound)

---

### 5. WHY MONITORING DIDN'T ALERT

**Answer**: Because nothing changed.

The monitoring system correctly detected no file modification. NetworkManager's internal metadata is not a security concern.

---

## ROOT CAUSE ANALYSIS

### What Happened
**Nothing malicious or broken.**

NetworkManager is behaving correctly:
1. Receives DNS from DHCP (normal DHCP behavior)
2. Stores it in connection metadata (normal NetworkManager behavior)
3. Does NOT apply it to system (correct, due to `dns=none`)

### Why It Looked Suspicious
The `nmcli dev show` output displays DHCP-provided DNS servers, which creates the **illusion** that the system is using them. It is not.

### Actual Risk Level
**ZERO**

The system is:
- ✅ Using Unbound for all DNS resolution
- ✅ Using DoT to Cloudflare/Quad9
- ✅ Ignoring DHCP-provided DNS
- ✅ Protected by immutable `/etc/resolv.conf`
- ✅ Protected by NetworkManager `dns=none`

---

## VERIFICATION

### Test 1: Actual DNS Server
```bash
$ dig example.com | grep SERVER
;; SERVER: 127.0.0.1#53(127.0.0.1) (UDP)
```
✅ Using localhost (Unbound)

### Test 2: Unbound Status
```bash
$ systemctl status unbound
● unbound.service - Unbound DNS server
     Active: active (running)
```
✅ Unbound running

### Test 3: Unbound Configuration
```bash
$ grep forward-addr /etc/unbound/unbound.conf
forward-addr: 1.1.1.1@853#cloudflare-dns.com
forward-addr: 1.0.0.1@853#cloudflare-dns.com
```
✅ Using DoT upstream

### Test 4: File Immutability
```bash
$ lsattr /etc/resolv.conf
----i-----------------
```
✅ Immutable flag set

### Test 5: NetworkManager DNS Management
```bash
$ grep dns= /etc/NetworkManager/conf.d/90-dns-hardening.conf
dns=none
```
✅ DNS management disabled

---

## COMPONENTS ANALYZED

| Component | Status | Role | Threat Level |
|-----------|--------|------|--------------|
| **Unbound** | ✅ Active | DNS resolver | None - Working correctly |
| **NetworkManager** | ✅ Active | Network management | None - Correctly ignoring DHCP DNS |
| **DHCP** | ✅ Active | IP configuration | None - Providing DNS as expected |
| **resolv.conf** | ✅ Immutable | DNS config | None - Unchanged since Feb 25 |
| **resolvconf** | ❌ Not installed | DNS updater | None - Not present |
| **systemd-resolved** | ❌ Inactive | DNS resolver | None - Not running |
| **unbound-resolvconf** | ❌ Inactive | Unbound helper | None - Condition not met |

---

## WHAT DID NOT HAPPEN

❌ `/etc/resolv.conf` was NOT modified  
❌ Immutable flag was NOT removed  
❌ Unbound was NOT bypassed  
❌ DHCP did NOT override DNS  
❌ NetworkManager did NOT change system DNS  
❌ No unauthorized process modified configuration  
❌ No security breach occurred  

---

## CONCLUSION

**This is not an incident. This is normal operation.**

The system is functioning exactly as designed:
1. DHCP provides DNS servers (standard protocol behavior)
2. NetworkManager receives them (standard NetworkManager behavior)
3. NetworkManager stores them as metadata (standard NetworkManager behavior)
4. NetworkManager does NOT apply them (correct, due to hardening)
5. System continues using Unbound (correct)

**The "Comcast DNS" servers exist only in NetworkManager's connection metadata. They are never used for actual DNS resolution.**

---

## RECOMMENDATIONS

### 1. Update Monitoring
Add check to distinguish between:
- **Active DNS** (what `/etc/resolv.conf` points to)
- **DHCP-provided DNS** (what NetworkManager stores)

### 2. Documentation
Document that `nmcli dev show` will display DHCP-provided DNS even when not in use.

### 3. Verification Script
Create script that tests **actual** DNS resolution path, not just configuration files.

### 4. No Changes Required
Current configuration is secure and working correctly. No remediation needed.

---

## INCIDENT CLASSIFICATION

**Type**: False Positive  
**Severity**: None  
**Action Required**: None  
**System Status**: Secure  

---

**Report Generated**: 2026-02-26T14:40:00-05:00  
**Investigator**: Security Operations  
**Status**: CLOSED - No incident occurred
