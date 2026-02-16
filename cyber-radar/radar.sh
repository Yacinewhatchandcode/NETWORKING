#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CYBER RADAR AGENT v2.0 — Zero-Illusion Sovereign Network Defense
# ═══════════════════════════════════════════════════════════════════
# 10-Module Security Scanner:
#   1. Network Discovery       6. Local Security Posture
#   2. Port Scanning            7. VPS Remote Audit
#   3. ARP Spoofing Detection   8. Wireless Security Audit
#   4. DNS Integrity            9. SSL/TLS Certificate Validation
#   5. Prompt Injection Scan   10. Service Fingerprinting
#
# + Historical Trend Analysis + JSON Export for Dashboard
#
# Usage: ./radar.sh [--full|--quick|--device <ip>|--trend]
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colors ──
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
ORG='\033[0;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
WHT='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# ── Config ──
SUBNET="192.168.1"
RADAR_HOME="$HOME/NETWORKING/cyber-radar"
REPORT_DIR="$RADAR_HOME/reports"
JSON_DIR="$RADAR_HOME/data"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORT_DIR/scan_${TIMESTAMP}.md"
JSON_FILE="$JSON_DIR/scan_${TIMESTAMP}.json"
KNOWN_DEVICES_FILE="$RADAR_HOME/known_devices.json"
SCAN_MODE="${1:---full}"
TARGET_DEVICE="${2:-}"

mkdir -p "$REPORT_DIR" "$JSON_DIR"

# ── Known Device Registry ──
init_known_devices() {
  if [[ ! -f "$KNOWN_DEVICES_FILE" ]]; then
    cat > "$KNOWN_DEVICES_FILE" << 'DEVICES'
{
  "devices": {
    "84:a3:29:e7:c1:6d": {"name": "Meteor 5G Box", "type": "router", "ip": "192.168.1.1", "owner": "infrastructure"},
    "24:f6:77:11:26:5c": {"name": "iMac de Yacine", "type": "workstation", "ip": "192.168.1.140", "owner": "yacine"},
    "ae:fa:d1:06:62:fd": {"name": "Samsung Tab S8", "type": "tablet", "ip": "192.168.1.146", "owner": "yacine"},
    "aa:04:7c:04:91:8e": {"name": "MacBook Pro M4 (Wi-Fi)", "type": "workstation", "ip": "192.168.1.171", "owner": "yacine"},
    "3c:18:a0:ca:ee:4f": {"name": "MacBook Pro M4 (Ethernet)", "type": "workstation", "ip": "192.168.1.151", "owner": "yacine"},
    "90:09:d0:7e:14:d4": {"name": "Synology NAS Yace", "type": "nas", "ip": "192.168.1.187", "owner": "yacine"},
    "64:c6:d2:90:de:b7": {"name": "Epson Printer", "type": "printer", "ip": "192.168.1.239", "owner": "yacine"},
    "9e:e0:23:f2:0d:5a": {"name": "Samsung Galaxy S25", "type": "phone", "ip": "192.168.1.102", "owner": "yacine"}
  }
}
DEVICES
  fi
}

# ── Utility ──
log() { echo -e "${CYN}[RADAR]${NC} $1"; }
warn() { echo -e "${YEL}[⚠ WARN]${NC} $1"; }
crit() { echo -e "${RED}[🔴 CRIT]${NC} $1"; }
pass() { echo -e "${GRN}[✅ PASS]${NC} $1"; }

TOTAL_PASS=0
TOTAL_WARN=0
TOTAL_CRIT=0

record_pass() { TOTAL_PASS=$((TOTAL_PASS + 1)); pass "$1"; echo "- ✅ $1" >> "$REPORT_FILE"; }
record_warn() { TOTAL_WARN=$((TOTAL_WARN + 1)); warn "$1"; echo "- ⚠️ $1" >> "$REPORT_FILE"; }
record_crit() { TOTAL_CRIT=$((TOTAL_CRIT + 1)); crit "$1"; echo "- 🔴 $1" >> "$REPORT_FILE"; }

# ═══════════════════════════════════════════
# MODULE 1: NETWORK DISCOVERY
# ═══════════════════════════════════════════
scan_network() {
  log "Scanning subnet ${SUBNET}.0/24..."
  echo "# 🛡️ Cyber Radar Report — $TIMESTAMP" > "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "## Network Discovery" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  local alive_hosts=()
  for i in $(seq 1 254); do
    if ping -c 1 -t 1 "${SUBNET}.$i" &>/dev/null; then
      alive_hosts+=("${SUBNET}.$i")
    fi
  done

  echo "| IP | Hostname | MAC | Known Device | Status |" >> "$REPORT_FILE"
  echo "|---|---|---|---|---|" >> "$REPORT_FILE"

  for ip in "${alive_hosts[@]}"; do
    local hostname mac known_name status
    hostname=$(arp -a 2>/dev/null | grep "($ip)" | awk '{print $1}' | head -1)
    mac=$(arp -a 2>/dev/null | grep "($ip)" | awk '{print $4}' | head -1)
    
    # Normalize MAC to zero-padded format (e.g. a:b:c → 0a:0b:0c)
    if [[ -n "$mac" ]]; then
      mac=$(echo "$mac" | awk -F: '{for(i=1;i<=NF;i++) printf "%s%02x", (i>1?":":""), strtonum("0x"$i)}')
    fi
    
    # Check if device is known
    if [[ -f "$KNOWN_DEVICES_FILE" ]] && echo "$mac" | grep -qf <(python3 -c "
import json, sys
with open('$KNOWN_DEVICES_FILE') as f:
  d = json.load(f)
for m in d['devices']:
  print(m)
" 2>/dev/null); then
      known_name=$(python3 -c "
import json
with open('$KNOWN_DEVICES_FILE') as f:
  d = json.load(f)
mac = '$mac'
if mac in d['devices']:
  print(d['devices'][mac]['name'])
else:
  print('Unknown')
" 2>/dev/null)
      status="✅ Known"
    else
      known_name="⚠️ UNKNOWN"
      status="⚠️ Investigate"
    fi

    echo "| $ip | $hostname | $mac | $known_name | $status |" >> "$REPORT_FILE"
    
    if [[ "$known_name" == "⚠️ UNKNOWN" ]]; then
      record_warn "Unknown device detected: $ip ($mac)"
    else
      log "Found: $ip → $known_name"
    fi
  done
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 2: PORT SCAN PER DEVICE
# ═══════════════════════════════════════════
scan_device_ports() {
  local ip="$1"
  local name="${2:-Unknown}"
  
  echo "### Device: $name ($ip)" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  local DANGEROUS_PORTS=(21 23 25 69 135 139 161 389 512 513 514 1433 1521 3306 3389 5432 5900 6379 8080 8443 9200 11211 27017)
  local STANDARD_PORTS=(22 53 80 443 445 548 5000 5001 7000 8008 62078)
  local ALL_PORTS=("${DANGEROUS_PORTS[@]}" "${STANDARD_PORTS[@]}")
  
  local open_ports=()
  local dangerous_open=()
  
  for port in "${ALL_PORTS[@]}"; do
    if nc -zv -w 1 "$ip" "$port" 2>&1 | grep -q succeeded; then
      open_ports+=("$port")
      
      # Check if dangerous
      for dp in "${DANGEROUS_PORTS[@]}"; do
        if [[ "$port" == "$dp" ]]; then
          dangerous_open+=("$port")
        fi
      done
    fi
  done
  
  if [[ ${#open_ports[@]} -gt 0 ]]; then
    echo "| Port | Service | Risk |" >> "$REPORT_FILE"
    echo "|---|---|---|" >> "$REPORT_FILE"
    
    for port in "${open_ports[@]}"; do
      local service risk
      case $port in
        21) service="FTP"; risk="🔴 HIGH";;
        22) service="SSH"; risk="⚠️ MEDIUM";;
        23) service="Telnet"; risk="🔴 CRITICAL";;
        25) service="SMTP"; risk="🔴 HIGH";;
        53) service="DNS"; risk="⚠️ LOW";;
        69) service="TFTP"; risk="🔴 HIGH";;
        80) service="HTTP"; risk="⚠️ MEDIUM";;
        135) service="RPC"; risk="🔴 CRITICAL";;
        139) service="NetBIOS"; risk="🔴 HIGH";;
        161) service="SNMP"; risk="🔴 HIGH";;
        389) service="LDAP"; risk="🔴 HIGH";;
        443) service="HTTPS"; risk="✅ LOW";;
        445) service="SMB"; risk="⚠️ MEDIUM";;
        512|513|514) service="rexec/rlogin/rsh"; risk="🔴 CRITICAL";;
        548) service="AFP"; risk="⚠️ MEDIUM";;
        1433) service="MSSQL"; risk="🔴 CRITICAL";;
        1521) service="Oracle"; risk="🔴 CRITICAL";;
        3306) service="MySQL"; risk="🔴 CRITICAL";;
        3389) service="RDP"; risk="🔴 HIGH";;
        5000) service="UPnP/DSM"; risk="⚠️ MEDIUM";;
        5001) service="DSM-SSL"; risk="⚠️ LOW";;
        5432) service="PostgreSQL"; risk="🔴 CRITICAL";;
        5900) service="VNC/Screen Share"; risk="⚠️ MEDIUM";;
        6379) service="Redis"; risk="🔴 CRITICAL";;
        7000) service="AirPlay"; risk="✅ LOW";;
        8080) service="HTTP-Alt"; risk="⚠️ MEDIUM";;
        8443) service="HTTPS-Alt"; risk="⚠️ LOW";;
        9200) service="Elasticsearch"; risk="🔴 CRITICAL";;
        11211) service="Memcached"; risk="🔴 CRITICAL";;
        27017) service="MongoDB"; risk="🔴 CRITICAL";;
        62078) service="iDevice"; risk="✅ LOW";;
        *) service="Unknown"; risk="⚠️ UNKNOWN";;
      esac
      
      echo "| $port | $service | $risk |" >> "$REPORT_FILE"
      
      if echo "$risk" | grep -q "CRITICAL\|HIGH"; then
        record_crit "$name ($ip): Dangerous port $port ($service) is OPEN"
      fi
    done
  else
    echo "No open ports detected." >> "$REPORT_FILE"
    record_pass "$name ($ip): No open ports (stealth mode)"
  fi
  
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 3: ARP SPOOFING DETECTION
# ═══════════════════════════════════════════
check_arp_spoofing() {
  echo "## ARP Integrity" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Checking ARP table for spoofing..."
  
  local dupes
  dupes=$(arp -a | grep -v "incomplete\|permanent" | awk '{print $4}' | sort | uniq -d | grep -v "ff:ff:ff:ff" || true)
  
  local real_dupes=0
  while IFS= read -r mac; do
    [[ -z "$mac" ]] && continue
    local ips
    ips=$(arp -a | grep "$mac" | awk '{print $2}' | tr -d '()' | sort -u)
    local ip_count
    ip_count=$(echo "$ips" | wc -l | tr -d ' ')
    
    # Same MAC on different interfaces (en0 + en7) is normal
    local unique_ips
    unique_ips=$(echo "$ips" | sort -u | wc -l | tr -d ' ')
    
    if [[ "$unique_ips" -gt 1 ]]; then
      record_crit "ARP SPOOFING: MAC $mac seen on multiple IPs: $(echo $ips | tr '\n' ' ')"
      ((real_dupes++))
    fi
  done <<< "$dupes"
  
  if [[ "$real_dupes" -eq 0 ]]; then
    record_pass "ARP table clean — no spoofing detected"
  fi
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 4: DNS HIJACKING CHECK
# ═══════════════════════════════════════════
check_dns() {
  echo "## DNS Integrity" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Checking DNS resolution..."
  
  local dns_servers
  dns_servers=$(scutil --dns 2>/dev/null | grep "nameserver" | awk '{print $3}' | sort -u | head -5)
  echo "DNS Servers: $dns_servers" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  # Test critical domains
  local domains=("google.com" "apple.com" "github.com")
  for domain in "${domains[@]}"; do
    local resolved
    resolved=$(dig +short "$domain" A 2>/dev/null | head -1)
    if [[ -n "$resolved" ]]; then
      record_pass "DNS: $domain → $resolved"
    else
      record_warn "DNS: $domain failed to resolve"
    fi
  done
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 5: PROMPT INJECTION VECTOR SCAN
# ═══════════════════════════════════════════
check_prompt_injection() {
  echo "## Prompt Injection & AI Security" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Scanning for prompt injection vectors..."
  
  # Check if any HTTP services return content that could contain injections
  local http_devices=("192.168.1.187:5000" "192.168.1.187:80")
  
  for target in "${http_devices[@]}"; do
    local ip port response
    ip=$(echo "$target" | cut -d: -f1)
    port=$(echo "$target" | cut -d: -f2)
    
    response=$(curl -s -m 3 "http://$target/" 2>/dev/null | head -100 || true)
    
    if [[ -n "$response" ]]; then
      # Check for injection patterns
      local injection_found=0
      
      # Check for hidden iframes (clickjacking)
      if echo "$response" | grep -qi "iframe.*style.*display.*none\|iframe.*hidden"; then
        record_crit "PROMPT INJECTION: Hidden iframe on $target (clickjacking)"
        injection_found=1
      fi
      
      # Check for suspicious scripts
      if echo "$response" | grep -qi "eval(\|document\.write(\|window\.location.*=\|<script.*src.*http"; then
        record_crit "PROMPT INJECTION: Suspicious script injection on $target"
        injection_found=1
      fi
      
      # Check for data exfil patterns
      if echo "$response" | grep -qi "fetch.*external\|XMLHttpRequest.*external\|navigator\.sendBeacon"; then
        record_crit "DATA EXFIL: Potential data exfiltration script on $target"
        injection_found=1
      fi
      
      if [[ "$injection_found" -eq 0 ]]; then
        record_pass "HTTP $target: No injection vectors detected"
      fi
    fi
  done
  
  # Check local OpenClaw agent configs for injection
  local agent_dirs=("$HOME/.openclaw/agents/main/agent" "$HOME/.openclaw/agents/clawbot/agent")
  
  for dir in "${agent_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      local agent_name
      agent_name=$(basename "$(dirname "$dir")")
      
      # Check for suspicious content in agent configs
      for f in "$dir"/*.json; do
        [[ ! -f "$f" ]] && continue
        
        if grep -qi "ignore previous\|disregard all\|system prompt\|you are now\|jailbreak\|DAN mode" "$f" 2>/dev/null; then
          record_crit "PROMPT INJECTION in agent '$agent_name': Suspicious text in $(basename $f)"
        else
          record_pass "Agent '$agent_name' config $(basename $f): Clean"
        fi
      done
      
      # Check for API key exposure
      if grep -q "sk-\|api_key\|secret" "$dir"/*.json 2>/dev/null; then
        record_warn "Agent '$agent_name': API keys stored in plaintext (recommend vault)"
      fi
    fi
  done
  
  # Check for prompt injection in environment
  if env | grep -qi "OPENAI_API_KEY\|ANTHROPIC_API_KEY\|OPENROUTER_API_KEY"; then
    record_warn "API keys found in environment variables (potential exfil vector)"
  else
    record_pass "No API keys leaked in environment"
  fi
  
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 6: LOCAL SECURITY POSTURE
# ═══════════════════════════════════════════
check_local_security() {
  echo "## Local Security (MacBook Pro)" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Auditing local security posture..."
  
  # Firewall
  local fw_state
  fw_state=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)
  if echo "$fw_state" | grep -q "enabled"; then
    record_pass "Firewall: Enabled"
  else
    record_crit "Firewall: DISABLED"
  fi
  
  # FileVault
  local fv_state
  fv_state=$(fdesetup status 2>/dev/null)
  if echo "$fv_state" | grep -q "On"; then
    record_pass "FileVault: Encrypted"
  else
    record_crit "FileVault: DISABLED — disk is NOT encrypted"
  fi
  
  # SIP (System Integrity Protection)
  local sip_state
  sip_state=$(csrutil status 2>/dev/null)
  if echo "$sip_state" | grep -q "enabled"; then
    record_pass "SIP: Enabled"
  else
    record_crit "SIP: DISABLED — system integrity compromised"
  fi
  
  # Gatekeeper
  local gk_state
  gk_state=$(spctl --status 2>/dev/null)
  if echo "$gk_state" | grep -q "enabled"; then
    record_pass "Gatekeeper: Enabled"
  else
    record_warn "Gatekeeper: Disabled"
  fi
  
  # Promiscuous mode
  if ifconfig -a 2>/dev/null | grep -q "PROMISC"; then
    local promisc_ifaces
    promisc_ifaces=$(ifconfig -a 2>/dev/null | grep -B1 "PROMISC" | grep "^en" | awk -F: '{print $1}')
    for iface in $promisc_ifaces; do
      local iface_status
      iface_status=$(ifconfig "$iface" 2>/dev/null | grep "status:" | awk '{print $2}')
      if [[ "$iface_status" == "active" ]]; then
        record_crit "Interface $iface in PROMISCUOUS mode and ACTIVE — possible sniffing"
      else
        record_pass "Interface $iface in PROMISC (inactive Thunderbolt — harmless)"
      fi
    done
  fi
  
  # Check for rogue listeners
  local rogue_listeners
  rogue_listeners=$(lsof -i -P -n 2>/dev/null | grep LISTEN | grep -v "127.0.0.1\|::1\|\[::1\]" | awk '{print $1, $9}' | sort -u)
  
  echo "### Network Listeners" >> "$REPORT_FILE"
  echo '```' >> "$REPORT_FILE"
  echo "$rogue_listeners" >> "$REPORT_FILE"
  echo '```' >> "$REPORT_FILE"
  
  while IFS= read -r line; do
    local proc port_info
    proc=$(echo "$line" | awk '{print $1}')
    port_info=$(echo "$line" | awk '{print $2}')
    
    local port_num
    port_num=$(echo "$port_info" | grep -oE '[0-9]+$' || echo "")
    local listener_key="${proc}:${port_num}"
    
    # Check known_listeners registry first
    local is_known=0
    if [[ -f "$KNOWN_DEVICES_FILE" ]] && python3 -c "
import json, sys
with open('$KNOWN_DEVICES_FILE') as f:
  d = json.load(f)
listeners = d.get('known_listeners', {})
key = '$listener_key'
if key in listeners and listeners[key].get('safe'):
  print(listeners[key]['name'])
  sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
      is_known=1
    fi
    
    if [[ "$is_known" -eq 1 ]]; then
      local listener_name
      listener_name=$(python3 -c "
import json
with open('$KNOWN_DEVICES_FILE') as f:
  d = json.load(f)
print(d.get('known_listeners',{}).get('$listener_key',{}).get('name','Known'))
" 2>/dev/null)
      record_pass "Listener $proc ($port_info): $listener_name (registered safe)"
    else
      case "$proc" in
        ControlCe|rapportd|Electron|Finder|mDNSRespo)
          record_pass "Listener $proc ($port_info): Known Apple/system service"
          ;;
        *)
          record_warn "Listener $proc ($port_info): Review required"
          ;;
      esac
    fi
  done <<< "$rogue_listeners"
  
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 7: VPS SECURITY CHECK
# ═══════════════════════════════════════════
check_vps() {
  echo "## VPS Security (31.97.52.22)" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Checking VPS security..."
  
  if ssh -o ConnectTimeout=3 -o BatchMode=yes root@31.97.52.22 "echo ok" &>/dev/null; then
    # Check for exposed Ollama
    local ollama_bind
    ollama_bind=$(ssh -o ConnectTimeout=3 root@31.97.52.22 "ss -tlnp | grep 11434" 2>/dev/null)
    
    if echo "$ollama_bind" | grep -q "0.0.0.0:11434"; then
      record_warn "VPS: Ollama bound to 0.0.0.0 (accessible from internet)"
    elif echo "$ollama_bind" | grep -q "127.0.0.1:11434"; then
      record_pass "VPS: Ollama bound to localhost only"
    fi
    
    # Check for root SSH with password
    local sshd_config
    sshd_config=$(ssh -o ConnectTimeout=3 root@31.97.52.22 "cat /etc/ssh/sshd_config 2>/dev/null | grep -i 'PermitRootLogin\|PasswordAuthentication'" 2>/dev/null)
    
    if echo "$sshd_config" | grep -qi "PermitRootLogin yes"; then
      record_warn "VPS: Root SSH login permitted"
    fi
    if echo "$sshd_config" | grep -qi "PasswordAuthentication yes"; then
      record_warn "VPS: Password authentication enabled (recommend keys only)"
    fi
    
    record_pass "VPS: Reachable and responding"
  else
    record_warn "VPS: Unreachable or SSH key not configured"
  fi
  
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 8: WIRELESS SECURITY AUDIT
# ═══════════════════════════════════════════
check_wireless() {
  echo "## Wireless Security" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Auditing wireless networks..."
  
  # Get Wi-Fi data via system_profiler (works on all macOS including Sequoia)
  local wifi_data
  wifi_data=$(system_profiler SPAirPortDataType 2>/dev/null || true)
  
  if [[ -z "$wifi_data" ]]; then
    record_warn "Wi-Fi: Could not retrieve wireless data"
    echo "" >> "$REPORT_FILE"
    return
  fi
  
  # Current connection details
  local current_status current_security current_channel current_signal current_phy
  current_status=$(echo "$wifi_data" | grep -m1 "Status:" | awk -F': ' '{print $2}' | xargs || true)
  current_security=$(echo "$wifi_data" | grep -m1 "Security:" | awk -F': ' '{print $2}' | xargs || true)
  current_channel=$(echo "$wifi_data" | grep -m1 "Channel:" | awk -F': ' '{print $2}' | xargs || true)
  current_signal=$(echo "$wifi_data" | grep -m1 "Signal / Noise:" | awk -F': ' '{print $2}' | xargs || true)
  current_phy=$(echo "$wifi_data" | grep "PHY Mode:" | head -1 | awk -F': ' '{print $2}' | xargs || true)
  
  echo "### Current Connection" >> "$REPORT_FILE"
  echo "| Field | Value |" >> "$REPORT_FILE"
  echo "|---|---|" >> "$REPORT_FILE"
  echo "| Status | $current_status |" >> "$REPORT_FILE"
  echo "| Security | $current_security |" >> "$REPORT_FILE"
  echo "| Channel | $current_channel |" >> "$REPORT_FILE"
  echo "| Signal | $current_signal |" >> "$REPORT_FILE"
  echo "| PHY Mode | $current_phy |" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  # Check encryption strength
  if echo "$current_security" | grep -qi "wpa3"; then
    record_pass "Wi-Fi: WPA3 encryption detected (strongest)"
  elif echo "$current_security" | grep -qi "wpa2.*wpa3\|wpa2/wpa3"; then
    record_pass "Wi-Fi: WPA2/WPA3 transitional (strong)"
  elif echo "$current_security" | grep -qi "wpa2"; then
    record_pass "Wi-Fi: WPA2 encryption (adequate)"
  elif echo "$current_security" | grep -qi "wpa"; then
    record_warn "Wi-Fi: WPA1 only — upgrade to WPA2/WPA3"
  elif echo "$current_security" | grep -qi "wep\|none\|open"; then
    record_crit "Wi-Fi: INSECURE — WEP/Open network detected"
  else
    record_warn "Wi-Fi: Unknown security type '$current_security'"
  fi
  
  # Analyze nearby networks from system_profiler
  echo "### Nearby Networks" >> "$REPORT_FILE"
  local nearby_section
  nearby_section=$(echo "$wifi_data" | sed -n '/Other Local Wi-Fi Networks:/,/^$/p' || true)
  
  if [[ -n "$nearby_section" ]]; then
    # Count open/unsecured nearby networks
    local open_count
    open_count=$(echo "$nearby_section" | grep -c "Security: None\|Security: Open" 2>/dev/null) || open_count=0
    local wep_count
    wep_count=$(echo "$nearby_section" | grep -c "Security: WEP" 2>/dev/null) || wep_count=0
    local total_nearby
    total_nearby=$(echo "$nearby_section" | grep -c "Security:" 2>/dev/null) || total_nearby=0
    
    echo "Detected $total_nearby nearby network(s)." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [[ "$open_count" -gt 0 ]]; then
      record_warn "$open_count open (unencrypted) network(s) in range — evil twin risk"
    else
      record_pass "No open networks detected in range"
    fi
    
    if [[ "$wep_count" -gt 0 ]]; then
      record_warn "$wep_count WEP-encrypted network(s) in range — trivially breakable"
    fi
  else
    echo "No nearby network data available." >> "$REPORT_FILE"
    record_pass "Nearby network scan: No threats detected"
  fi
  
  # Check connection status
  if [[ "$current_status" == "Connected" ]]; then
    record_pass "Wi-Fi: Connected and active"
  else
    record_warn "Wi-Fi: Not connected (status: $current_status)"
  fi
  
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 9: SSL/TLS CERTIFICATE VALIDATION
# ═══════════════════════════════════════════
check_ssl_certs() {
  echo "## SSL/TLS Certificate Audit" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Validating SSL/TLS certificates..."
  
  # Internal services with HTTPS
  local targets=(
    "192.168.1.1:443:Meteor 5G Box"
    "192.168.1.187:443:Synology NAS HTTPS"
    "192.168.1.187:5001:Synology DSM SSL"
  )
  
  # External critical services
  local external_targets=(
    "primeai.live:443:Prime AI"
    "31.97.52.22:443:Hostinger VPS"
  )
  
  if [[ "$SCAN_MODE" != "--quick" ]]; then
    targets+=("${external_targets[@]}")
  fi
  
  echo "| Host | Port | Issuer | Expires | Days Left | Status |" >> "$REPORT_FILE"
  echo "|---|---|---|---|---|---|" >> "$REPORT_FILE"
  
  for entry in "${targets[@]}"; do
    local host port label
    host=$(echo "$entry" | cut -d: -f1)
    port=$(echo "$entry" | cut -d: -f2)
    label=$(echo "$entry" | cut -d: -f3)
    
    local cert_info
    cert_info=$(echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null | openssl x509 -noout -issuer -enddate 2>/dev/null || echo "FAILED")
    
    if [[ "$cert_info" == "FAILED" ]] || [[ -z "$cert_info" ]]; then
      echo "| $label | $port | — | — | — | ⚠️ No cert |" >> "$REPORT_FILE"
      record_warn "SSL: $label ($host:$port) — no certificate or connection failed"
      continue
    fi
    
    local issuer expiry_str
    issuer=$(echo "$cert_info" | grep "issuer" | sed 's/issuer=//;s/.*CN.*=//;s/,.*//' | head -1 | xargs)
    expiry_str=$(echo "$cert_info" | grep "notAfter" | sed 's/notAfter=//' | head -1)
    
    if [[ -n "$expiry_str" ]]; then
      local expiry_epoch now_epoch days_left
      expiry_epoch=$(date -jf "%b %d %T %Y %Z" "$expiry_str" +%s 2>/dev/null || date -jf "%b %e %T %Y %Z" "$expiry_str" +%s 2>/dev/null || echo "0")
      now_epoch=$(date +%s)
      
      if [[ "$expiry_epoch" -gt 0 ]]; then
        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
        local expiry_display
        expiry_display=$(date -jf "%b %d %T %Y %Z" "$expiry_str" +"%Y-%m-%d" 2>/dev/null || echo "$expiry_str")
        
        local status
        if [[ "$days_left" -lt 0 ]]; then
          status="🔴 EXPIRED"
          record_crit "SSL: $label certificate EXPIRED ${days_left#-} days ago"
        elif [[ "$days_left" -lt 14 ]]; then
          status="🔴 EXPIRING"
          record_crit "SSL: $label certificate expires in $days_left days"
        elif [[ "$days_left" -lt 30 ]]; then
          status="⚠️ RENEW"
          record_warn "SSL: $label certificate expires in $days_left days"
        else
          status="✅ Valid"
          record_pass "SSL: $label certificate valid ($days_left days)"
        fi
        
        echo "| $label | $port | $issuer | $expiry_display | $days_left | $status |" >> "$REPORT_FILE"
      else
        echo "| $label | $port | $issuer | parse error | — | ⚠️ |" >> "$REPORT_FILE"
        record_warn "SSL: $label — could not parse expiry date"
      fi
    fi
  done
  
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# MODULE 10: SERVICE FINGERPRINTING
# ═══════════════════════════════════════════
check_service_banners() {
  echo "## Service Fingerprinting" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Fingerprinting exposed services..."
  
  # Grab HTTP server headers from internal services
  local http_targets=(
    "192.168.1.1:80:Meteor Router"
    "192.168.1.187:5000:Synology DSM"
    "192.168.1.187:80:Synology HTTP"
  )
  
  echo "| Host | Port | Server Header | Risk |" >> "$REPORT_FILE"
  echo "|---|---|---|---|" >> "$REPORT_FILE"
  
  for entry in "${http_targets[@]}"; do
    local host port label
    host=$(echo "$entry" | cut -d: -f1)
    port=$(echo "$entry" | cut -d: -f2)
    label=$(echo "$entry" | cut -d: -f3)
    
    local headers
    headers=$(curl -sI -m 3 "http://$host:$port/" 2>/dev/null | head -15)
    
    if [[ -z "$headers" ]]; then
      echo "| $label | $port | — | ✅ No response |" >> "$REPORT_FILE"
      continue
    fi
    
    local server_header
    server_header=$(echo "$headers" | grep -i "^server:" | sed 's/[Ss]erver: //' | tr -d '\r' | head -1)
    
    if [[ -z "$server_header" ]]; then
      echo "| $label | $port | (hidden) | ✅ Header stripped |" >> "$REPORT_FILE"
      record_pass "$label ($host:$port): Server header hidden"
    else
      # Check for version disclosure
      if echo "$server_header" | grep -qE '[0-9]+\.[0-9]+'; then
        echo "| $label | $port | $server_header | ⚠️ Version exposed |" >> "$REPORT_FILE"
        record_warn "$label ($host:$port): Version info exposed — $server_header"
      else
        echo "| $label | $port | $server_header | ✅ No version |" >> "$REPORT_FILE"
        record_pass "$label ($host:$port): Server header generic"
      fi
    fi
    
    # Check for security headers
    local missing_headers=0
    for hdr in "X-Frame-Options" "X-Content-Type-Options" "Strict-Transport-Security"; do
      if ! echo "$headers" | grep -qi "$hdr"; then
        missing_headers=$((missing_headers + 1))
      fi
    done
    
    if [[ "$missing_headers" -gt 0 ]]; then
      record_warn "$label ($host:$port): Missing $missing_headers security header(s)"
    fi
  done
  
  echo "" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════
# HISTORICAL TREND ANALYSIS
# ═══════════════════════════════════════════
show_trend() {
  echo "## Historical Trend" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  log "Comparing with previous scans..."
  
  local prev_reports
  prev_reports=$(ls -t "$REPORT_DIR"/scan_*.md 2>/dev/null | head -6)
  local count
  count=$(echo "$prev_reports" | grep -c "." 2>/dev/null || echo "0")
  
  if [[ "$count" -lt 2 ]]; then
    echo "Not enough scan history for trend analysis (need ≥2 scans)." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    return
  fi
  
  echo "| Date | Passed | Warnings | Critical | Threat Level |" >> "$REPORT_FILE"
  echo "|---|---|---|---|---|" >> "$REPORT_FILE"
  
  while IFS= read -r report; do
    [[ -z "$report" ]] && continue
    local rdate rpass rwarn rcrit rlevel
    rdate=$(basename "$report" | sed 's/scan_//;s/.md//;s/_/ /2')
    rpass=$(grep -c "^- ✅" "$report" 2>/dev/null) || rpass=0
    rwarn=$(grep -c "^- ⚠️" "$report" 2>/dev/null) || rwarn=0
    rcrit=$(grep -c "^- 🔴" "$report" 2>/dev/null) || rcrit=0
    rlevel=$(grep "Overall Threat Level" "$report" 2>/dev/null | sed 's/.*: //' || echo "unknown")
    
    echo "| $rdate | $rpass | $rwarn | $rcrit | $rlevel |" >> "$REPORT_FILE"
  done <<< "$prev_reports"
  
  echo "" >> "$REPORT_FILE"
  
  # Calculate delta from last scan
  local last_report
  last_report=$(echo "$prev_reports" | sed -n '2p')
  if [[ -n "$last_report" ]]; then
    local prev_crit prev_warn
    prev_crit=$(grep -c "^- 🔴" "$last_report" 2>/dev/null) || prev_crit=0
    prev_warn=$(grep -c "^- ⚠️" "$last_report" 2>/dev/null) || prev_warn=0
    
    local crit_delta=$((TOTAL_CRIT - prev_crit))
    local warn_delta=$((TOTAL_WARN - prev_warn))
    
    echo "### Delta from Last Scan" >> "$REPORT_FILE"
    if [[ "$crit_delta" -lt 0 ]]; then
      echo "- ✅ Critical findings reduced by ${crit_delta#-}" >> "$REPORT_FILE"
      log "Trend: ${GRN}Critical findings DOWN by ${crit_delta#-}${NC}"
    elif [[ "$crit_delta" -gt 0 ]]; then
      echo "- 🔴 Critical findings INCREASED by $crit_delta" >> "$REPORT_FILE"
      crit "Trend: Critical findings UP by $crit_delta"
    else
      echo "- ➡️ Critical findings unchanged" >> "$REPORT_FILE"
    fi
    
    if [[ "$warn_delta" -lt 0 ]]; then
      echo "- ✅ Warnings reduced by ${warn_delta#-}" >> "$REPORT_FILE"
    elif [[ "$warn_delta" -gt 0 ]]; then
      echo "- ⚠️ Warnings INCREASED by $warn_delta" >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
  fi
}

# ═══════════════════════════════════════════
# JSON EXPORT (Dashboard Integration)
# ═══════════════════════════════════════════
export_json() {
  log "Exporting JSON for dashboard..."
  
  local overall_level
  if [[ "$TOTAL_CRIT" -gt 0 ]]; then
    overall_level="RED"
  elif [[ "$TOTAL_WARN" -gt 3 ]]; then
    overall_level="YELLOW"
  else
    overall_level="GREEN"
  fi
  
  cat > "$JSON_FILE" << JSONEOF
{
  "version": "2.0",
  "timestamp": "$TIMESTAMP",
  "scan_mode": "$SCAN_MODE",
  "summary": {
    "passed": $TOTAL_PASS,
    "warnings": $TOTAL_WARN,
    "critical": $TOTAL_CRIT,
    "threat_level": "$overall_level"
  },
  "modules": [
    "network_discovery",
    "port_scan",
    "arp_integrity",
    "dns_integrity",
    "prompt_injection",
    "local_security",
    "vps_security",
    "wireless_security",
    "ssl_tls_audit",
    "service_fingerprint"
  ],
  "report_file": "$REPORT_FILE"
}
JSONEOF
  
  log "JSON exported: $JSON_FILE"
}

# ═══════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════
main() {
  echo ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║  🛡️  CYBER RADAR AGENT v2.0                  ║${NC}"
  echo -e "${RED}${BOLD}║  Zero-Illusion Sovereign Network Defense     ║${NC}"
  echo -e "${RED}${BOLD}║  10 Modules • Trend Analysis • Dashboard     ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${WHT}Scan Mode:${NC} $SCAN_MODE"
  echo -e "${WHT}Timestamp:${NC} $TIMESTAMP"
  echo -e "${WHT}Report:${NC} $REPORT_FILE"
  echo ""
  
  # Handle --trend mode (analysis only, no scan)
  if [[ "$SCAN_MODE" == "--trend" ]]; then
    echo "# 📊 Cyber Radar Trend Report — $TIMESTAMP" > "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    show_trend
    echo -e "  ${BLU}Trend report:${NC} $REPORT_FILE"
    return
  fi
  
  init_known_devices
  
  # Module 1: Network Discovery
  scan_network
  
  # Module 2: Port Scan per device
  echo "## Port Scan Results" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  local devices=(
    "192.168.1.1:Meteor 5G Box"
    "192.168.1.102:Samsung S25"
    "192.168.1.140:iMac de Yacine"
    "192.168.1.146:Samsung Tab S8"
    "192.168.1.171:MacBook Pro Wi-Fi"
    "192.168.1.151:MacBook Pro Ethernet"
    "192.168.1.187:Synology NAS"
    "192.168.1.239:Epson Printer"
  )
  
  for entry in "${devices[@]}"; do
    local ip name
    ip=$(echo "$entry" | cut -d: -f1)
    name=$(echo "$entry" | cut -d: -f2)
    
    if [[ "$SCAN_MODE" == "--device" ]] && [[ "$ip" != "$TARGET_DEVICE" ]]; then
      continue
    fi
    
    if ping -c 1 -t 1 "$ip" &>/dev/null; then
      scan_device_ports "$ip" "$name"
    else
      log "Device $name ($ip) is offline — skipping"
      echo "### $name ($ip) — OFFLINE" >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
    fi
  done
  
  # Module 3: ARP
  check_arp_spoofing
  
  # Module 4: DNS
  check_dns
  
  # Module 5: Prompt Injection
  check_prompt_injection
  
  # Module 6: Local Security
  check_local_security
  
  # Module 7: VPS
  if [[ "$SCAN_MODE" != "--quick" ]]; then
    check_vps
  fi
  
  # Module 8: Wireless Security
  check_wireless
  
  # Module 9: SSL/TLS Certificates
  check_ssl_certs
  
  # Module 10: Service Fingerprinting
  if [[ "$SCAN_MODE" != "--quick" ]]; then
    check_service_banners
  fi
  
  # ── Historical Trend ──
  show_trend
  
  # ── Summary ──
  echo "## Summary" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "| Metric | Count |" >> "$REPORT_FILE"
  echo "|---|---|" >> "$REPORT_FILE"
  echo "| ✅ Passed | $TOTAL_PASS |" >> "$REPORT_FILE"
  echo "| ⚠️ Warnings | $TOTAL_WARN |" >> "$REPORT_FILE"
  echo "| 🔴 Critical | $TOTAL_CRIT |" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  local overall_color
  if [[ "$TOTAL_CRIT" -gt 0 ]]; then
    overall_color="🔴 RED"
  elif [[ "$TOTAL_WARN" -gt 3 ]]; then
    overall_color="🟡 YELLOW"
  else
    overall_color="🟢 GREEN"
  fi
  echo "**Overall Threat Level: $overall_color**" >> "$REPORT_FILE"
  
  # ── JSON Export ──
  export_json
  
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════${NC}"
  echo -e "${BOLD}  SCAN COMPLETE — CYBER RADAR v2.0${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════${NC}"
  echo -e "  ${GRN}✅ Passed:${NC}    $TOTAL_PASS"
  echo -e "  ${YEL}⚠️  Warnings:${NC} $TOTAL_WARN"
  echo -e "  ${RED}🔴 Critical:${NC}  $TOTAL_CRIT"
  echo -e "  ${WHT}Threat Level:${NC} $overall_color"
  echo ""
  echo -e "  ${BLU}Report:${NC} $REPORT_FILE"
  echo -e "  ${BLU}JSON:${NC}   $JSON_FILE"
  echo ""
}

main
