# DNS Hardening for Parrot OS

Enterprise-grade DNS security with protection against Portmaster/NetworkManager modifications.

## 🔒 Security Features
- DNS over TLS (DoT) encryption
- DNSSEC validation
- Query minimization for privacy
- **Immutable resolv.conf protection**
- **NetworkManager DNS override disabled**
- Emergency restoration capability
- **Top 1-2% global security posture**

## 🚀 Quick Start
```bash
# 1. Install Unbound
sudo apt update && sudo apt install -y unbound unbound-anchor

# 2. Harden DNS configuration (protects against Portmaster/NetworkManager)
sudo ./scripts/dns_harden.sh

# 3. Apply hardened Unbound configuration
sudo cp configs/unbound.conf /etc/unbound/
sudo systemctl restart unbound
```

## 📁 Repository Structure
```
├── README.md                        # Complete implementation guide
├── DNS_Hardening_Complete_Guide.md  # Detailed security analysis
├── scripts/
│   ├── dns_harden.sh               # Hardens resolv.conf (immutable flag)
│   └── dns_restore.sh              # Emergency DNS restoration
├── configs/
│   └── unbound.conf                # Hardened Unbound configuration
└── LICENSE
```

## 🛡️ Protection Against
- Portmaster DNS modifications
- NetworkManager dynamic DNS changes
- DNS Poisoning/Spoofing
- Man-in-the-Middle attacks
- DNS Hijacking
- DNS Rebinding attacks
- ISP surveillance

## 🆘 Emergency Recovery
If DNS breaks completely:
```bash
sudo ./scripts/dns_restore.sh
```

## 🔧 Unharden Temporarily
```bash
sudo chattr -i /etc/resolv.conf  # Remove immutable flag
# Make changes
sudo ./scripts/dns_harden.sh     # Re-apply hardening
```

## ⚡ Verification
```bash
# Check immutable flag is set
lsattr /etc/resolv.conf

# Test DNS over TLS is working
sudo ss -tupn | grep 853

# Test DNSSEC validation
dig @127.0.0.1 +dnssec google.com
```

## 📖 Full Documentation
See [README.md](README.md) for complete implementation guide with all configurations, troubleshooting, and security analysis.

---
**Tested on Parrot OS | Portmaster-Resistant | Emergency Recovery Included**
