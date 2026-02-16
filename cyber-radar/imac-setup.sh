#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# iMac OpenClaw + Local GPU Setup Script
# Run this ON the iMac via Screen Sharing / Terminal
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

echo ""
echo "═══════════════════════════════════════"
echo "  🖥️  iMac OpenClaw Engine Setup"
echo "═══════════════════════════════════════"
echo ""

# 1. Install Homebrew if missing
echo "[1/7] Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/usr/local/bin/brew shellenv)"
fi
echo "  ✅ Homebrew ready"

# 2. Install Node.js 22+
echo "[2/7] Checking Node.js..."
if ! command -v node &>/dev/null || [[ $(node -v | cut -d. -f1 | tr -d 'v') -lt 22 ]]; then
  brew install node@22
  echo 'export PATH="/usr/local/opt/node@22/bin:$PATH"' >> ~/.zprofile
  export PATH="/usr/local/opt/node@22/bin:$PATH"
fi
echo "  ✅ Node $(node -v)"

# 3. Install Ollama for local GPU inference
echo "[3/7] Installing Ollama..."
if ! command -v ollama &>/dev/null; then
  brew install ollama
fi
echo "  ✅ Ollama installed"

# 4. Start Ollama and pull models optimized for GPU
echo "[4/7] Starting Ollama & pulling models..."
brew services start ollama 2>/dev/null || ollama serve &>/dev/null &
sleep 3

# Pull models optimized for the available GPU
echo "  Pulling deepseek-r1:7b..."
ollama pull deepseek-r1:7b
echo "  Pulling qwen2.5-coder:7b..."
ollama pull qwen2.5-coder:7b
echo "  Pulling llama3.2:3b..."
ollama pull llama3.2:3b
echo "  ✅ Models pulled"

# 5. Install OpenClaw
echo "[5/7] Installing OpenClaw..."
npm install -g openclaw 2>/dev/null || npm install -g openclaw
echo "  ✅ OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'check PATH')"

# 6. Configure OpenClaw with local Ollama
echo "[6/7] Configuring OpenClaw..."
openclaw init 2>/dev/null || true

# Set up local Ollama as primary provider
mkdir -p ~/.openclaw/agents/main/agent

cat > ~/.openclaw/agents/main/agent/models.json << 'MODELS'
{
    "ollama/deepseek-r1:7b": {
        "providerId": "ollama",
        "name": "DeepSeek R1 7B (Local GPU)",
        "contextWindow": 32768,
        "maxOutput": 8192
    },
    "ollama/qwen2.5-coder:7b": {
        "providerId": "ollama",
        "name": "Qwen 2.5 Coder 7B (Local GPU)",
        "contextWindow": 32768,
        "maxOutput": 8192
    },
    "ollama/llama3.2:3b": {
        "providerId": "ollama",
        "name": "Llama 3.2 3B (Local GPU)",
        "contextWindow": 131072,
        "maxOutput": 8192
    },
    "openrouter/deepseek/deepseek-chat": {
        "providerId": "openrouter",
        "name": "DeepSeek Chat (Cloud Fallback)",
        "contextWindow": 65536,
        "maxOutput": 8192
    }
}
MODELS

cat > ~/.openclaw/agents/main/agent/auth-profiles.json << 'AUTH'
{
    "ollama:manual": {
        "providerId": "ollama",
        "token": "ollama",
        "baseUrl": "http://127.0.0.1:11434",
        "source": "manual",
        "addedAt": "2026-02-12T22:00:00.000Z"
    }
}
AUTH

echo "  ✅ OpenClaw configured with local Ollama"

# 7. Enable SSH for remote management from MacBook
echo "[7/7] Enabling SSH..."
sudo systemsetup -setremotelogin on 2>/dev/null || echo "  ⚠️  Enable SSH manually: System Settings > General > Sharing > Remote Login"
echo "  ✅ SSH enabled"

# 8. Mount Google Drive (if not already)
echo ""
echo "[BONUS] Google Drive..."
if [ -d "$HOME/Library/CloudStorage/GoogleDrive-"* ] 2>/dev/null; then
  echo "  ✅ Google Drive already mounted"
  ls ~/Library/CloudStorage/GoogleDrive-*/ 2>/dev/null | head -5
elif command -v "Google Drive" &>/dev/null; then
  echo "  ✅ Google Drive app found"
else
  echo "  ⚠️  Install Google Drive desktop app from https://www.google.com/drive/download/"
  echo "     After install, models can be stored at ~/Library/CloudStorage/GoogleDrive-*/models/"
fi

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ iMac Setup Complete"
echo "═══════════════════════════════════════"
echo ""
echo "  Ollama:     http://127.0.0.1:11434"
echo "  Models:     deepseek-r1:7b, qwen2.5-coder:7b, llama3.2:3b"
echo "  OpenClaw:   $(which openclaw 2>/dev/null || echo 'check PATH')"
echo ""
echo "  From MacBook, run:"
echo "    ssh yacinebenhamou@192.168.1.140"
echo "    openclaw agent -m 'Hello from iMac'"
echo ""
