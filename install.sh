#!/usr/bin/env bash
# chrome-debug installer
# Usage: curl -fsSL https://raw.githubusercontent.com/USER/chrome-debug/main/install.sh | bash
#
# Options (via environment variables):
#   ALIAS_NAME=vamoaeto  ./install.sh    # Set a custom shell alias
#   SKIP_ALIAS=1         ./install.sh    # Don't add any alias
#   SKIP_CLAUDE=1        ./install.sh    # Don't install Claude Code command or permissions

set -euo pipefail

REPO_URL="${CHROME_DEBUG_REPO_URL:-https://raw.githubusercontent.com/JorgeLora04/chrome-debug/main}"
BIN_DIR="$HOME/.local/bin"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
ALIAS_NAME="${ALIAS_NAME:-}"
SKIP_ALIAS="${SKIP_ALIAS:-0}"
SKIP_CLAUDE="${SKIP_CLAUDE:-0}"

echo ""
echo "  chrome-debug installer"
echo "  ──────────────────────"
echo ""

# ─── 1. Install the script ───────────────────────────────────────────────────
mkdir -p "$BIN_DIR"

if [[ -f "chrome-debug" ]]; then
    # Local install (cloned repo)
    cp chrome-debug "$BIN_DIR/chrome-debug"
else
    # Remote install (curl pipe)
    curl -fsSL "$REPO_URL/chrome-debug" -o "$BIN_DIR/chrome-debug"
fi

chmod +x "$BIN_DIR/chrome-debug"
echo "  [ok] Installed chrome-debug to $BIN_DIR/chrome-debug"

# ─── 2. Ensure ~/.local/bin is in PATH ────────────────────────────────────────
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_RC="$HOME/.bash_profile"
fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
        echo '' >> "$SHELL_RC"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
        echo "  [ok] Added ~/.local/bin to PATH in $SHELL_RC"
    fi
fi

# ─── 3. Add alias (optional) ─────────────────────────────────────────────────
if [[ "$SKIP_ALIAS" != "1" && -n "$SHELL_RC" ]]; then
    if [[ -z "$ALIAS_NAME" ]]; then
        echo ""
        echo "  Want a short alias? (leave blank to skip)"
        printf "  Alias name: "
        read -r ALIAS_NAME </dev/tty 2>/dev/null || ALIAS_NAME=""
    fi

    if [[ -n "$ALIAS_NAME" ]]; then
        ALIAS_LINE="alias $ALIAS_NAME='chrome-debug'"
        if ! grep -qF "$ALIAS_LINE" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# chrome-debug alias" >> "$SHELL_RC"
            echo "$ALIAS_LINE" >> "$SHELL_RC"
            echo "  [ok] Added alias '$ALIAS_NAME' to $SHELL_RC"
        else
            echo "  [ok] Alias '$ALIAS_NAME' already exists"
        fi
    fi
fi

# ─── 4. Install Claude Code command ──────────────────────────────────────────
if [[ "$SKIP_CLAUDE" != "1" ]]; then
    mkdir -p "$CLAUDE_COMMANDS_DIR"

    if [[ -f "multi-browser.md" ]]; then
        cp multi-browser.md "$CLAUDE_COMMANDS_DIR/multi-browser.md"
    else
        curl -fsSL "$REPO_URL/multi-browser.md" -o "$CLAUDE_COMMANDS_DIR/multi-browser.md"
    fi
    echo "  [ok] Installed /multi-browser command to $CLAUDE_COMMANDS_DIR/"

    # ─── 5. Add auto-allow permissions to Claude Code settings ────────────────
    PERMISSIONS_TO_ADD=(
        'Bash(agent-browser'
        'Bash(chrome-debug'
        'Bash(export PATH="$HOME/.local/bin:$HOME/Library/pnpm:$PATH" && agent-browser'
        'Bash(export PATH="$HOME/.local/bin:$HOME/Library/pnpm:$PATH" && chrome-debug'
        'Bash(curl -s http://localhost'
    )

    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        # Check if jq is available
        if command -v jq &>/dev/null; then
            for perm in "${PERMISSIONS_TO_ADD[@]}"; do
                # Check if permission already exists
                if ! jq -e --arg p "$perm" '.permissions.allow | index($p)' "$CLAUDE_SETTINGS" &>/dev/null; then
                    # Add the permission
                    tmp=$(mktemp)
                    jq --arg p "$perm" '.permissions.allow += [$p]' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
                fi
            done
            echo "  [ok] Added auto-allow permissions to $CLAUDE_SETTINGS"
        else
            echo "  [!!] jq not found — add these permissions manually to $CLAUDE_SETTINGS:"
            echo '        "Bash(agent-browser"'
            echo '        "Bash(chrome-debug"'
        fi
    else
        # Create settings from scratch
        mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
        cat > "$CLAUDE_SETTINGS" <<'SETTINGS'
{
  "permissions": {
    "allow": [
      "Bash(agent-browser",
      "Bash(chrome-debug",
      "Bash(curl -s http://localhost"
    ]
  }
}
SETTINGS
        echo "  [ok] Created $CLAUDE_SETTINGS with auto-allow permissions"
    fi
fi

# ─── 6. Check prerequisites ──────────────────────────────────────────────────
echo ""

# Check Chrome
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [[ ! -x "$CHROME_BIN" ]]; then
    # Try Linux paths
    for bin in google-chrome google-chrome-stable chromium chromium-browser; do
        if command -v "$bin" &>/dev/null; then
            CHROME_BIN="$bin"
            break
        fi
    done
fi

if [[ -x "$CHROME_BIN" ]] || command -v "$CHROME_BIN" &>/dev/null 2>&1; then
    echo "  [ok] Chrome found"
else
    echo "  [!!] Chrome not found. Install Google Chrome or set CHROME_DEBUG_BIN"
fi

# Check agent-browser
if command -v agent-browser &>/dev/null; then
    echo "  [ok] agent-browser found ($(agent-browser --version 2>/dev/null || echo 'unknown version'))"
else
    echo "  [!!] agent-browser not installed. Run: npm install -g agent-browser && agent-browser install"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "  Installation complete!"
echo ""
echo "  Quick start:"
echo "    chrome-debug up                  # Launch all browser roles"
echo "    chrome-debug roles               # See available roles"
echo "    chrome-debug help                # Full usage"
echo ""
if [[ -n "$SHELL_RC" ]]; then
    echo "  Reload your shell:  source $SHELL_RC"
    echo ""
fi
