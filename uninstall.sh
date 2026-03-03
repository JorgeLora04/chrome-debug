#!/usr/bin/env bash
# chrome-debug uninstaller
set -euo pipefail

echo ""
echo "  chrome-debug uninstaller"
echo "  ────────────────────────"
echo ""

# Stop any running instances
if command -v chrome-debug &>/dev/null; then
    chrome-debug stop all 2>/dev/null || true
fi

# Remove binary
rm -f "$HOME/.local/bin/chrome-debug"
echo "  [ok] Removed chrome-debug from ~/.local/bin/"

# Remove Claude Code command
rm -f "$HOME/.claude/commands/multi-browser.md"
echo "  [ok] Removed /multi-browser Claude Code command"

# Remove data directory
if [[ -d "$HOME/.chrome-debug" ]]; then
    printf "  Delete all data (~/.chrome-debug including saved identity)? [y/N] "
    read -r confirm </dev/tty 2>/dev/null || confirm="n"
    if [[ "$confirm" =~ ^[Yy] ]]; then
        rm -rf "$HOME/.chrome-debug"
        echo "  [ok] Removed ~/.chrome-debug"
    else
        echo "  [--] Kept ~/.chrome-debug"
    fi
fi

# Note about manual cleanup
echo ""
echo "  Manual cleanup (optional):"
echo "    - Remove alias from ~/.zshrc or ~/.bashrc"
echo "    - Remove 'Bash(agent-browser' and 'Bash(chrome-debug' from ~/.claude/settings.json"
echo ""
echo "  Uninstall complete."
echo ""
