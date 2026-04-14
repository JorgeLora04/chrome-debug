#!/usr/bin/env bash
# chrome-debug installer
# Usage: curl -fsSL https://raw.githubusercontent.com/JorgeLora04/chrome-debug/main/install.sh | bash
#
# Options (via environment variables):
#   ALIAS_NAME=vamoaeto  ./install.sh    # Set a custom shell alias
#   SKIP_ALIAS=1         ./install.sh    # Don't add any alias
#   SKIP_CLAUDE=1        ./install.sh    # Don't install Claude Code command or permissions

set -euo pipefail

# ─── OS Detection ─────────────────────────────────────────────────────────────
case "$(uname -s)" in
    Darwin)                OS_TYPE="macos";;
    MINGW*|MSYS*|CYGWIN*) OS_TYPE="windows";;
    *)                     OS_TYPE="linux";;
esac

REPO_GIT_URL="${CHROME_DEBUG_GIT_URL:-https://github.com/JorgeLora04/chrome-debug.git}"
REPO_URL="${CHROME_DEBUG_REPO_URL:-https://raw.githubusercontent.com/JorgeLora04/chrome-debug/main}"
VAMOAETO_DIR="$HOME/.vamoaeto"
LOCAL_REPO="$VAMOAETO_DIR/repo"
BIN_DIR="$HOME/.local/bin"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
ALIAS_NAME="${ALIAS_NAME:-}"
SKIP_ALIAS="${SKIP_ALIAS:-0}"
SKIP_CLAUDE="${SKIP_CLAUDE:-0}"

echo ""
echo "  chrome-debug installer"
echo "  ──────────────────────"
echo "  Platform: $OS_TYPE"
echo ""

# ─── 1. Clone or update the repo ─────────────────────────────────────────────
mkdir -p "$VAMOAETO_DIR"

if [[ -d "$LOCAL_REPO/.git" ]]; then
    # Repo already cloned — pull latest
    echo "  [..] Updating existing repo..."
    git -C "$LOCAL_REPO" pull --rebase origin main 2>/dev/null || true
    echo "  [ok] Updated repo at $LOCAL_REPO"
else
    # Fresh clone
    echo "  [..] Cloning vamoaeto repo..."
    if command -v git &>/dev/null; then
        git clone "$REPO_GIT_URL" "$LOCAL_REPO" 2>/dev/null
        echo "  [ok] Cloned repo to $LOCAL_REPO"
    else
        echo "  [!!] git not found — installing without repo sync (vamoaeto update won't work)"
        echo "       Install git and re-run the installer to enable sync."
    fi
fi

# ─── 2. Install the script ───────────────────────────────────────────────────
mkdir -p "$BIN_DIR"

if [[ -f "chrome-debug" ]]; then
    # Running from a cloned repo directly
    cp chrome-debug "$BIN_DIR/chrome-debug"
elif [[ -f "$LOCAL_REPO/chrome-debug" ]]; then
    # Install from the local clone
    cp "$LOCAL_REPO/chrome-debug" "$BIN_DIR/chrome-debug"
else
    # Fallback: curl download
    curl -fsSL "$REPO_URL/chrome-debug" -o "$BIN_DIR/chrome-debug"
fi

chmod +x "$BIN_DIR/chrome-debug"
echo "  [ok] Installed chrome-debug to $BIN_DIR/chrome-debug"

# ─── 2b. Install vamoaeto-sync (silent background knowledge sync) ────────────
if [[ -f "vamoaeto-sync" ]]; then
    cp vamoaeto-sync "$BIN_DIR/vamoaeto-sync"
elif [[ -f "$LOCAL_REPO/vamoaeto-sync" ]]; then
    cp "$LOCAL_REPO/vamoaeto-sync" "$BIN_DIR/vamoaeto-sync"
else
    curl -fsSL "$REPO_URL/vamoaeto-sync" -o "$BIN_DIR/vamoaeto-sync" 2>/dev/null || true
fi
if [[ -f "$BIN_DIR/vamoaeto-sync" ]]; then
    chmod +x "$BIN_DIR/vamoaeto-sync"
    echo "  [ok] Installed vamoaeto-sync to $BIN_DIR/vamoaeto-sync"
fi

# ─── 2. Ensure ~/.local/bin is in PATH ────────────────────────────────────────
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_RC="$HOME/.bash_profile"
fi

# On Windows Git Bash, create .bashrc if no shell RC exists
if [[ -z "$SHELL_RC" && "$OS_TYPE" == "windows" ]]; then
    SHELL_RC="$HOME/.bashrc"
    touch "$SHELL_RC"
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
        ALIAS_LINE="alias $ALIAS_NAME='chrome-debug up'"
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

    # Install main command: /vamoaeto (unified toolkit)
    # Priority: current dir (dev) > local repo clone > curl download
    install_file() {
        local filename="$1"
        local dest="$2"
        if [[ -f "$filename" ]]; then
            cp "$filename" "$dest"
        elif [[ -f "$LOCAL_REPO/$filename" ]]; then
            cp "$LOCAL_REPO/$filename" "$dest"
        else
            curl -fsSL "$REPO_URL/$filename" -o "$dest"
        fi
    }

    install_file "vamoaeto.md" "$CLAUDE_COMMANDS_DIR/vamoaeto.md"
    echo "  [ok] Installed /vamoaeto command (AI project toolkit)"

    # Install knowledge base references (loadable via /command for deep-dives)
    for kb_file in multi-browser.md design-patterns.md saas-patterns.md integration-patterns.md; do
        install_file "$kb_file" "$CLAUDE_COMMANDS_DIR/$kb_file"
    done
    echo "  [ok] Installed knowledge base (multi-browser, design-patterns, saas-patterns, integration-patterns)"

    # Install any project-specific knowledge from the repo's .vamoaeto/knowledge/
    if [[ -d "$LOCAL_REPO/.vamoaeto/knowledge" ]]; then
        for kf in "$LOCAL_REPO/.vamoaeto/knowledge/"*.md; do
            [[ -f "$kf" ]] && cp "$kf" "$CLAUDE_COMMANDS_DIR/$(basename "$kf")"
        done
        echo "  [ok] Installed shared project knowledge from repo"
    fi

    # ─── 5. Add auto-allow permissions to Claude Code settings ────────────────
    PERMISSIONS_TO_ADD=(
        'Bash(agent-browser'
        'Bash(chrome-debug'
        'Bash(export PATH="$HOME/.local/bin:$PATH" && agent-browser'
        'Bash(export PATH="$HOME/.local/bin:$PATH" && chrome-debug'
        'Bash(curl -s http://localhost'
    )

    # On macOS, also add the Library/pnpm path variant
    if [[ "$OS_TYPE" == "macos" ]]; then
        PERMISSIONS_TO_ADD+=(
            'Bash(export PATH="$HOME/.local/bin:$HOME/Library/pnpm:$PATH" && agent-browser'
            'Bash(export PATH="$HOME/.local/bin:$HOME/Library/pnpm:$PATH" && chrome-debug'
        )
    fi

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

    # ─── 5b. Register SessionStart hook for silent knowledge auto-sync ───────
    # Every time you start a Claude Code session, vamoaeto-sync silently runs
    # `git pull` on the chrome-debug repo and refreshes ~/.claude/commands/.
    # No manual pull needed — like a plugin auto-update.
    if command -v jq &>/dev/null; then
        if ! jq -e '.hooks.SessionStart[]?.hooks[]? | select(.command | test("vamoaeto-sync"))' "$CLAUDE_SETTINGS" &>/dev/null; then
            tmp=$(mktemp)
            jq '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{matcher: "*", hooks: [{type: "command", command: "$HOME/.local/bin/vamoaeto-sync", timeout: 5000}]}])' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
            echo "  [ok] Registered SessionStart hook — knowledge auto-syncs each Claude session"
        else
            echo "  [ok] SessionStart hook already registered"
        fi
    else
        echo "  [!!] jq not found — add this hook manually to $CLAUDE_SETTINGS:"
        echo '        "hooks": { "SessionStart": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/vamoaeto-sync", "timeout": 5000 }] }] }'
    fi
fi

# ─── 6. Check prerequisites ──────────────────────────────────────────────────
echo ""

# Check Chrome (platform-specific)
CHROME_FOUND=false
case "$OS_TYPE" in
    macos)
        CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        if [[ -x "$CHROME_BIN" ]]; then
            CHROME_FOUND=true
        fi
        ;;
    windows)
        for candidate in \
            "/c/Program Files/Google/Chrome/Application/chrome.exe" \
            "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"; do
            if [[ -f "$candidate" ]]; then
                CHROME_FOUND=true
                break
            fi
        done
        # Also check via LOCALAPPDATA
        if [[ "$CHROME_FOUND" == "false" && -n "${LOCALAPPDATA:-}" ]]; then
            local_chrome="$(cygpath "$LOCALAPPDATA" 2>/dev/null)/Google/Chrome/Application/chrome.exe"
            if [[ -f "$local_chrome" ]]; then
                CHROME_FOUND=true
            fi
        fi
        ;;
    *)
        for bin in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$bin" &>/dev/null; then
                CHROME_FOUND=true
                break
            fi
        done
        ;;
esac

if $CHROME_FOUND; then
    echo "  [ok] Chrome found"
else
    echo "  [!!] Chrome not found. Install Google Chrome or set CHROME_DEBUG_BIN"
fi

# Check agent-browser
if command -v agent-browser &>/dev/null; then
    echo "  [ok] agent-browser found ($(agent-browser --version 2>/dev/null || echo 'unknown version'))"
else
    echo "  [!!] agent-browser not installed. Run: npm install -g @anthropic-ai/agent-browser && agent-browser install"
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
echo "  In Claude Code:"
echo "    /vamoaeto                        # Interactive setup wizard"
echo "    /vamoaeto update                 # Scan project & sync knowledge with team"
echo ""
if [[ -d "$LOCAL_REPO/.git" ]]; then
    echo "  Repo synced to: $LOCAL_REPO"
    echo "  Team knowledge syncs automatically via 'vamoaeto update'"
    echo ""
fi
if [[ -n "$SHELL_RC" ]]; then
    echo "  Reload your shell:  source $SHELL_RC"
    echo ""
fi
