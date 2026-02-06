# Unbound DNS over TLS Status Check

## What Proper Operation Looks Like

### 1. Active TLS Connections (Port 853)
```bash
$ sudo ss -tnp | grep :853
ESTAB 0  0  10.0.0.73:35022  149.112.112.112:853  users:(("unbound",pid=1184,fd=18))
ESTAB 0  0  10.0.0.73:42156  1.1.1.1:853          users:(("unbound",pid=1184,fd=19))
```
**Good:** Multiple connections to port 853 (DNS over TLS)
- 1.1.1.1:853 (Cloudflare)
- 1.0.0.1:853 (Cloudflare)
- 9.9.9.9:853 (Quad9)
- 149.112.112.112:853 (Quad9)

### 2. DNS Resolution Through Unbound
```bash
$ dig @127.0.0.1 google.com +short
142.250.189.110
```
**Good:** Fast response from localhost (Unbound)

### 3. DNSSEC Validation Active
```bash
$ dig @127.0.0.1 google.com +dnssec | grep flags
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
```
**Good:** The `ad` flag means "authenticated data" (DNSSEC working)

### 4. System Using Localhost Resolver
```bash
$ nslookup google.com
Server:    127.0.0.1
Address:   127.0.0.1#53
```
**Good:** All queries go through Unbound first

---

## What Fallback Looks Like (BAD)

### 1. No TLS Connections
```bash
$ sudo ss -tnp | grep :853
(no output)
```
**Bad:** No port 853 connections = No DNS over TLS

### 2. Direct Queries to Fallback
```bash
$ nslookup google.com
Server:    1.1.1.1
Address:   1.1.1.1#53
```
**Bad:** Bypassing Unbound, using fallback directly (unencrypted)

### 3. Unbound Not Running
```bash
$ systemctl status unbound
● unbound.service - Unbound DNS server
   Active: inactive (dead)
```
**Bad:** Unbound stopped, system using fallback nameservers

---

## TLS Monitoring Script

### Install TLS Monitor
```bash
# Copy to system
sudo cp scripts/dns_tls_monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dns_tls_monitor.sh

# Add to cron (check every 30 minutes)
(sudo crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/dns_tls_monitor.sh") | sudo crontab -
```

### What It Monitors
- ✅ Unbound service status
- ✅ Active TLS connections on port 853
- ✅ Detects if system bypasses Unbound
- ✅ Alerts to `/var/log/dns_hardening_alerts.log`

### Manual Check
```bash
sudo ./scripts/dns_tls_monitor.sh && echo "TLS Active" || echo "TLS Problem"
```

---

## Quick Status Commands

```bash
# Check TLS connections
sudo ss -tnp | grep :853

# Check Unbound is running
systemctl status unbound

# Test DNS resolution
dig @127.0.0.1 google.com +short

# Check DNSSEC
dig @127.0.0.1 google.com +dnssec | grep "flags.*ad"

# View Unbound logs
sudo journalctl -u unbound -f
```

---

## Expected Behavior

**Normal Operation:**
- 1-4 active connections to port 853
- All DNS queries go through 127.0.0.1
- DNSSEC validation active (ad flag)
- No alerts in log

**Fallback Mode (Alert):**
- No port 853 connections
- Queries bypass Unbound
- Using plain DNS (port 53)
- Alerts logged

---

## Troubleshooting

### If TLS connections are missing:
```bash
# Check Unbound config
sudo unbound-checkconf

# Restart Unbound
sudo systemctl restart unbound

# Check logs
sudo journalctl -u unbound -n 50
```

### If using fallback:
```bash
# Check resolv.conf
cat /etc/resolv.conf

# Should show:
# nameserver 127.0.0.1
# nameserver 1.1.1.1  (fallback only)
```
