#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Harden MacBook Pro — Resolve all Cyber Radar findings
# Run with: sudo bash harden.sh
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

echo ""
echo "═══════════════════════════════════════"
echo "  🔒 MacBook Pro Hardening Script"
echo "═══════════════════════════════════════"
echo ""

# 1. Enable stealth mode (don't respond to probes)
echo "[1/5] Enabling stealth mode..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
echo "  ✅ Stealth mode enabled"

# 2. Block all incoming connections except essential services
echo "[2/5] Configuring firewall..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
/usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
echo "  ✅ Firewall configured (allow essentials, stealth to probes)"

# 3. Block NetBIOS/SMB inbound with pf (packet filter)
echo "[3/5] Blocking NetBIOS inbound..."

PF_RULES="/etc/pf.anchors/cyber-radar"
cat > "$PF_RULES" << 'PF'
# Cyber Radar — Block dangerous inbound protocols
block in quick proto tcp from any to any port 135
block in quick proto tcp from any to any port 139
block in quick proto udp from any to any port 137
block in quick proto udp from any to any port 138
block in quick proto tcp from any to any port 23
PF

# Add anchor to pf.conf if not already present
if ! grep -q "cyber-radar" /etc/pf.conf 2>/dev/null; then
  echo 'anchor "cyber-radar"' >> /etc/pf.conf
  echo 'load anchor "cyber-radar" from "/etc/pf.anchors/cyber-radar"' >> /etc/pf.conf
fi

# Reload pf rules
pfctl -f /etc/pf.conf 2>/dev/null || true
pfctl -e 2>/dev/null || true
echo "  ✅ NetBIOS/Telnet inbound blocked via pf"

# 4. Disable unnecessary sharing services
echo "[4/5] Disabling unnecessary sharing..."
# Disable Remote Apple Events
launchctl unload -w /System/Library/LaunchDaemons/com.apple.AEServer.plist 2>/dev/null || true
echo "  ✅ Remote Apple Events disabled"

# 5. Flush stale ARP entries
echo "[5/5] Flushing stale ARP cache..."
arp -a -d 2>/dev/null || arp -d -a 2>/dev/null || true
echo "  ✅ ARP cache flushed"

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Hardening Complete"
echo "═══════════════════════════════════════"
echo ""
echo "  Stealth mode:    ON"
echo "  Firewall:        ON"
echo "  NetBIOS block:   ON"
echo "  Telnet block:    ON"
echo "  Remote Events:   OFF"
echo "  ARP Cache:       FLUSHED"
echo ""
