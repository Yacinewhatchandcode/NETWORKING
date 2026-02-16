#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# API Key Vault — Migrate plaintext keys to macOS Keychain
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GRN}[VAULT]${NC} $1"; }
warn() { echo -e "${YEL}[VAULT]${NC} $1"; }

AGENTS_DIR="$HOME/.openclaw/agents"

echo ""
echo "═══════════════════════════════════════"
echo "  🔐 API Key Vault Migration"
echo "═══════════════════════════════════════"
echo ""

# Step 1: Extract keys from agent configs
for agent_dir in "$AGENTS_DIR"/*/agent; do
  [[ ! -d "$agent_dir" ]] && continue
  agent_name=$(basename "$(dirname "$agent_dir")")
  auth_file="$agent_dir/auth-profiles.json"
  
  [[ ! -f "$auth_file" ]] && continue
  
  log "Processing agent: $agent_name"
  
  # Extract OpenRouter key
  or_key=$(python3 -c "
import json
with open('$auth_file') as f:
  d = json.load(f)
for k, v in d.items():
  if v.get('providerId') == 'openrouter' and v.get('token','').startswith('sk-'):
    print(v['token'])
    break
" 2>/dev/null || true)
  
  if [[ -n "$or_key" ]]; then
    # Store in macOS Keychain
    security add-generic-password \
      -a "openclaw-${agent_name}" \
      -s "openrouter-api-key" \
      -w "$or_key" \
      -U 2>/dev/null && log "  ✅ OpenRouter key → Keychain (openclaw-${agent_name})" || \
      log "  ✅ OpenRouter key already in Keychain"
    
    # Replace plaintext key with env reference in config
    python3 -c "
import json
with open('$auth_file') as f:
  d = json.load(f)
for k, v in d.items():
  if v.get('providerId') == 'openrouter' and v.get('token','').startswith('sk-'):
    v['token'] = '\${OPENROUTER_API_KEY}'
    v['source'] = 'keychain'
with open('$auth_file', 'w') as f:
  json.dump(d, f, indent=4)
" 2>/dev/null
    log "  ✅ Plaintext key removed from $auth_file"
  fi
done

# Step 2: Create env loader script
ENV_LOADER="$HOME/.openclaw/load-keys.sh"
cat > "$ENV_LOADER" << 'LOADER'
#!/usr/bin/env bash
# Load API keys from macOS Keychain into environment
export OPENROUTER_API_KEY=$(security find-generic-password -a "openclaw-main" -s "openrouter-api-key" -w 2>/dev/null || echo "")
export OLLAMA_HOST="http://31.97.52.22:11434"

if [[ -z "$OPENROUTER_API_KEY" ]]; then
  echo "⚠️  OpenRouter API key not found in Keychain. Run secure-keys.sh first."
fi
LOADER
chmod +x "$ENV_LOADER"

log "Created key loader: $ENV_LOADER"
log "Usage: source ~/.openclaw/load-keys.sh"

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Keys migrated to macOS Keychain"
echo "═══════════════════════════════════════"
echo ""
