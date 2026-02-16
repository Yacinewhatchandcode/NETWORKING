# Synology NAS "Yace" — Security Hardening Guide
## IP: 192.168.1.187 | DSM: http://192.168.1.187:5000

### ⚠️ Current Issues:
1. **NetBIOS (port 139)** — Legacy protocol, attack vector for SMB relay
2. **HTTP (port 80)** — Unencrypted DSM access
3. **SSH (port 22)** — Open to LAN (password auth)

---

### Step 1: Disable NetBIOS
1. Open DSM: `http://192.168.1.187:5000`
2. Go to **Control Panel** → **File Services** → **SMB**
3. Click **Advanced Settings**
4. **Uncheck** "Enable NetBIOS service"
5. Click **Apply**

### Step 2: Force HTTPS Only
1. Go to **Control Panel** → **Login Portal** → **DSM**
2. Check **"Automatically redirect HTTP connections to HTTPS for DSM desktop"**
3. Click **Apply**

### Step 3: Disable SSH (if not needed)
1. Go to **Control Panel** → **Terminal & SNMP**
2. **Uncheck** "Enable SSH service"
3. Click **Apply**
4. (If you need SSH, at least change the port from 22 to a non-standard port)

### Step 4: Enable Auto-Block
1. Go to **Control Panel** → **Security** → **Protection**
2. Enable **Auto Block**
3. Set: Block after **5** failed login attempts within **5** minutes
4. Click **Apply**

### Step 5: Enable 2FA
1. Go to **Control Panel** → **Security** → **Account**
2. Enable **2-Factor Authentication**
3. Follow the setup wizard

### Step 6: Firewall Rules
1. Go to **Control Panel** → **Security** → **Firewall**
2. Enable Firewall
3. Create rules to only allow your LAN subnet (192.168.1.0/24)
4. Deny all other traffic

---

### After Hardening — Expected Port Profile:
| Port | Service | Status |
|---|---|---|
| 80 | HTTP | ❌ Closed (redirected to HTTPS) |
| 139 | NetBIOS | ❌ Closed |
| 22 | SSH | ❌ Closed (or non-standard port) |
| 443 | HTTPS | ✅ Open |
| 445 | SMB | ✅ Open (LAN only) |
| 5001 | DSM-HTTPS | ✅ Open (LAN only) |
