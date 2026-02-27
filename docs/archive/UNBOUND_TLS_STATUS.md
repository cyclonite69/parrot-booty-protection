# 🔒 Unbound DNS over TLS: Signal Strength

Verify that your DNS signal is encrypted and your booty is secure.

## 🧭 What a Secure Signal Looks Like

### 1. Active TLS Connections (Port 853)
Check if the ship is talking to the secure ports:
```bash
sudo ss -tnp | grep :853
```
**Good:** You should see established connections to `1.1.1.1:853` or `9.9.9.9:853`.

### 2. The Authenticity Seal (DNSSEC)
Verify that the signal hasn't been tampered with by privateers:
```bash
dig @127.0.0.1 google.com +dnssec | grep flags
```
**Good:** Look for the `ad` flag (Authenticated Data). This means the rigging is secure.

### 3. Localhost Hook
Ensure all queries are being funneled through the local Unbound resolver:
```bash
nslookup google.com
```
**Good:** Should show `Server: 127.0.0.1`.

---

## ⚠️ The Ghost Signal (BAD - FALLBACK)

If you see these signs, your defenses have been breached:
*   **No Port 853 connections**: Your signal is unencrypted (Plain DNS).
*   **Bypassing Localhost**: `nslookup` shows a server other than `127.0.0.1`.
*   **Unbound service is dead**: The fortress has fallen.

---

## 📡 Automatic Signal Monitoring

The **Crow's Nest (Module 40)** in the dashboard (`hardenctl`) handles this for you. It runs the `dns_tls_monitor.sh` script to:
- Verify Unbound is active.
- Confirm TLS connections are established.
- Detect if the system is bypassing our secure resolver.

---

## 🏴‍☠️ Quick Inspection Commands

| Action | Command |
| :--- | :--- |
| **Inspect Rigging** | `sudo ss -tnp | grep :853` |
| **Test the Signal** | `dig @127.0.0.1 google.com +short` |
| **Verify the Seal** | `dig @127.0.0.1 google.com +dnssec | grep "flags.*ad"` |
| **Check the Fortress** | `systemctl status unbound` |
| **Read the Logs** | `sudo journalctl -u unbound -f` |

---

## 🛠️ Repairing the Signal

If the signal is weak or unencrypted:
1.  **Check Config**: `sudo unbound-checkconf`
2.  **Restart the Engines**: `sudo systemctl restart unbound`
3.  **Inspect the Ledger**: Use **Module 90 (Log Explorer)** in `hardenctl`.

*“May your signal be strong and your treasure stay hidden.”* 🦜🏴‍☠️
