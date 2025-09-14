# DNSSEC Setup and Usage Guide

## 🔐 DNSSEC Enabled!

Your PowerDNS stack now has full DNSSEC support enabled:

- **PowerDNS Auth**: DNSSEC signing capabilities for your zones
- **PowerDNS Recursor**: DNSSEC validation for recursive queries
- **Easy Management**: Justfile commands for common operations

## 🚀 Quick Start

### 1. **Enable DNSSEC for a Zone**

```bash
# Enable DNSSEC for your zone
just dnssec-secure example.com

# This automatically:
# ✅ Generates cryptographic keys (KSK + ZSK) 
# ✅ Signs all DNS records
# ✅ Creates DNSSEC records (DNSKEY, RRSIG, NSEC)
# ✅ Shows DS record for parent zone submission
```

### 2. **Submit DS Record to Registrar**

```bash
# Get the DS record for your registrar
just dnssec-ds example.com

# Submit the DS record to your domain registrar
# This creates the chain of trust from the root
```

### 3. **Validate DNSSEC Works**

```bash
# Test DNSSEC signatures
just dnssec-validate example.com

# Test DNSSEC validation via recursor
just dnssec-test example.com
```

## 📋 Available Commands

### **DNSSEC Management**

| Command | Purpose | Example |
|---------|---------|---------|
| `just dnssec-secure ZONE` | Enable DNSSEC for a zone | `just dnssec-secure example.com` |
| `just dnssec-disable ZONE` | Disable DNSSEC for a zone | `just dnssec-disable example.com` |
| `just dnssec-status ZONE` | Show DNSSEC status | `just dnssec-status example.com` |
| `just dnssec-keys ZONE` | List DNSSEC keys | `just dnssec-keys example.com` |
| `just dnssec-ds ZONE` | Show DS record | `just dnssec-ds example.com` |
| `just dnssec-validate ZONE` | Validate signatures | `just dnssec-validate example.com` |
| `just dnssec-test ZONE` | Test via recursor | `just dnssec-test example.com` |
| `just dnssec-zones` | List all zones + status | `just dnssec-zones` |

### **DNS Testing**

| Command | Purpose | Example |
|---------|---------|---------|
| `just dig ZONE [TYPE]` | Query via Auth server | `just dig example.com A` |
| `just dig-rec ZONE [TYPE]` | Query via Recursor | `just dig-rec google.com A` |
| `just dig-dnssec ZONE` | Query with DNSSEC | `just dig-dnssec example.com` |

## 🔧 DNSSEC Configuration

### **PowerDNS Auth DNSSEC Settings**

```ini
# Enabled in config/pdns.conf
dnssec=yes                              # Enable DNSSEC signing
default-ksk-algorithm=ecdsa256           # Use ECDSA P-256 for KSK
default-zsk-algorithm=ecdsa256           # Use ECDSA P-256 for ZSK
auto-dnssec=on                          # Automatic key management
signature-validity-default=604800       # 7 days signature validity
```

### **PowerDNS Recursor DNSSEC Settings**

```ini
# Enabled in config/recursor.conf
dnssec=validate                         # Enable DNSSEC validation
dnssec-log-bogus=yes                    # Log invalid signatures
trust-anchors-file=trust-anchors.conf   # Root trust anchors
```

## 🎯 Common Workflows

### **Securing a New Zone**

1. **Create and secure the zone:**
   ```bash
   # First create your zone (via API or PowerDNS Admin)
   # Then enable DNSSEC
   just dnssec-secure example.com
   ```

2. **Submit DS record:**
   ```bash
   # Get DS record
   just dnssec-ds example.com
   
   # Copy the DS record and submit to your registrar
   # This usually takes 24-48 hours to propagate
   ```

3. **Verify DNSSEC is working:**
   ```bash
   # Test locally first
   just dnssec-validate example.com
   
   # Test via external validators
   dig +dnssec @8.8.8.8 example.com SOA
   dig +dnssec @1.1.1.1 example.com SOA
   ```

### **Monitoring DNSSEC Health**

```bash
# Check all zones DNSSEC status
just dnssec-zones

# Check specific zone details
just dnssec-status example.com
just dnssec-keys example.com

# Test validation via your recursor
just dnssec-test example.com
```

### **Key Management**

```bash
# View current keys
just dnssec-keys example.com

# Keys are automatically managed by PowerDNS:
# - ZSK rotation every 90 days (configurable)
# - KSK rotation every 1 year (configurable)
# - Automatic signing of all records
```

## 🛡️ DNSSEC Security Features

### **What's Protected**

✅ **DNS Response Authenticity** - Verify responses are from legitimate servers  
✅ **DNS Response Integrity** - Detect modified DNS responses  
✅ **Cache Poisoning Prevention** - Can't inject fake DNS records  
✅ **DNS Spoofing Prevention** - Can't impersonate your DNS server

### **Attack Prevention**

- **Man-in-the-middle attacks** - DNSSEC signatures detect modified responses
- **DNS cache poisoning** - Invalid signatures are rejected
- **Zone enumeration** - NSEC3 provides authenticated denial of existence
- **Response modification** - Any changes break cryptographic signatures

## 🔍 Testing and Validation

### **Internal Testing**

```bash
# Test via your PowerDNS Auth server
just dig-dnssec example.com SOA

# Test via your PowerDNS Recursor  
just dig-rec example.com SOA

# Test DNSSEC validation
just dnssec-test example.com
```

### **External Testing**

```bash
# Test via public DNS resolvers
dig +dnssec @8.8.8.8 example.com SOA      # Google DNS
dig +dnssec @1.1.1.1 example.com SOA      # Cloudflare DNS
dig +dnssec @9.9.9.9 example.com SOA      # Quad9 DNS

# Online DNSSEC validators
# - https://dnssec-analyzer.verisignlabs.com/
# - https://dnsviz.net/
# - https://www.whatsmydns.net/
```

## 📊 Monitoring and Maintenance

### **Regular Checks**

1. **Weekly**: Check DNSSEC status of critical zones
   ```bash
   just dnssec-zones
   ```

2. **Monthly**: Validate DNSSEC chains
   ```bash
   just dnssec-validate example.com
   ```

3. **Before key expiry**: Monitor key rotation
   ```bash
   just dnssec-keys example.com
   ```

### **Key Rotation**

PowerDNS handles key rotation automatically:
- **ZSK (Zone Signing Key)**: Rotates every 90 days
- **KSK (Key Signing Key)**: Rotates every 365 days
- **DS Record Updates**: You'll need to update DS records with registrar when KSK rotates

### **Troubleshooting**

```bash
# Check zone consistency
just exec powerdns-auth
pdnsutil check-zone example.com

# View DNSSEC logs
just logs-service powerdns-auth | grep -i dnssec
just logs-service powerdns-recursor | grep -i dnssec

# Rectify zone if needed
docker compose exec powerdns-auth pdnsutil rectify-zone example.com
```

## 🎓 Learning More

### **DNSSEC Resources**
- **What is DNSSEC**: See `what_is_dnssec.md` in this repo
- **DNSSEC Standards**: RFC 4033, 4034, 4035
- **PowerDNS DNSSEC Docs**: https://doc.powerdns.com/authoritative/dnssec/

### **Best Practices**
- **Use strong algorithms**: ECDSA P-256 (default in this setup)
- **Regular key rotation**: Automated by PowerDNS
- **Monitor expiration**: Set up alerts for key/signature expiry
- **Test regularly**: Validate DNSSEC chains monthly
- **Keep DS records updated**: When KSK rotates, update with registrar

## 🚨 Important Notes

### **Initial Setup**
- DNSSEC is now **enabled but not active** until you secure your first zone
- Use `just dnssec-secure ZONE` to enable DNSSEC for specific zones
- You **must submit DS records** to your registrar for full DNSSEC validation

### **Production Considerations**
- **Signature validation overhead**: ~5-10% CPU increase
- **Larger DNS responses**: +100-500 bytes per response
- **Key storage**: Keys are stored in LMDB and synced via LightningStream
- **Parent zone dependency**: DS records must be published by parent zone

### **Emergency Procedures**
If DNSSEC validation fails:
```bash
# Temporarily disable DNSSEC for a zone
just dnssec-disable example.com

# Re-enable after fixing issues
just dnssec-secure example.com
```

## 🎉 You're Ready!

Your PowerDNS stack now has enterprise-grade DNSSEC capabilities. Start by securing your first zone:

```bash
just dnssec-secure your-domain.com
```

For questions or issues, check the logs or consult the PowerDNS DNSSEC documentation.