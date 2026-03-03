# chrome-debug

Manage multiple Chrome debug instances for [agent-browser](https://github.com/nichochar/agent-browser). Launch headed or headless browsers with shared identity, preset roles, and CDP connectivity — built for AI coding agents that need to control multiple browsers in parallel.

## Features

- **Preset roles**: `app`, `tools`, `whatsapp`, `research` — each on a fixed CDP port
- **Shared identity**: all instances clone a base Chrome profile (cookies, sessions, OAuth)
- **Headed by default**: see what the agent is doing in real browser windows
- **Claude Code integration**: `/multi-browser` command with sub-agent patterns, OAuth flows, WhatsApp notifications
- **Auto-allow permissions**: no confirmation prompts for browser commands

## Install

```bash
# Clone and install
git clone https://github.com/JorgeLora04/chrome-debug.git
cd chrome-debug
bash install.sh

# Or one-liner (update URL with your repo)
curl -fsSL https://raw.githubusercontent.com/JorgeLora04/chrome-debug/main/install.sh | bash
```

The installer:
- Copies `chrome-debug` to `~/.local/bin/`
- Adds `~/.local/bin` to your PATH if needed
- Optionally sets a shell alias (e.g., `vamoaeto`)
- Installs the `/multi-browser` Claude Code command
- Adds auto-allow permissions to `~/.claude/settings.json`

### Prerequisites

- **Google Chrome** (macOS, Linux)
- **agent-browser**: `npm install -g agent-browser && agent-browser install`
- **jq** (optional, for settings merge): `brew install jq`

## Quick Start

```bash
# Launch all 4 browser roles
chrome-debug up

# Launch specific roles
chrome-debug up app research

# List running instances
chrome-debug list

# Stop everything
chrome-debug stop all
```

## Roles

| Role | Port | Purpose |
|------|------|---------|
| `app` | 9222 | Localhost app testing |
| `tools` | 9223 | External tools config (HubSpot, Polar, ElevenLabs, etc.) |
| `whatsapp` | 9224 | WhatsApp Web for agent-to-user notifications |
| `research` | 9225 | Docs, MCPs, SDKs, API references |

```bash
chrome-debug roles    # Show all roles with ports and descriptions
```

## Identity Sharing

All browser instances share the same login sessions, cookies, and Google accounts.

```bash
# 1. Launch a setup instance
chrome-debug start --name setup

# 2. In the browser window:
#    - Sign into your Google account(s)
#    - Go to web.whatsapp.com and scan the QR code
#    - Log into any tools you use

# 3. Save the profile as the shared base
chrome-debug save-profile setup

# 4. Stop the setup instance
chrome-debug stop setup

# All future instances will clone that identity
chrome-debug up    # Everything is already logged in
```

## Connecting with agent-browser

Every command must include `--cdp <port>`:

```bash
agent-browser --cdp 9222 open http://localhost:3000
agent-browser --cdp 9222 snapshot -i
agent-browser --cdp 9222 click @e1

agent-browser --cdp 9225 open https://docs.convex.dev
agent-browser --cdp 9225 snapshot -i
```

## OAuth Support

Since the Chrome profile has Google accounts pre-signed-in, OAuth "Sign in with Google" flows work out of the box. The agent:

1. Clicks the OAuth button
2. Sees the Google account picker with your accounts
3. Asks you which account to use
4. Clicks it — OAuth completes

This is safe. OAuth only creates a scoped token for that specific service. The agent never sees your Google password.

## Claude Code Integration

The installer adds a `/multi-browser` command to Claude Code with:

- Sub-agent prompt templates for each role
- WhatsApp notification patterns (agent messages you when it needs credentials or decisions)
- OAuth flow handling
- Parallel research + implementation patterns
- Action + verification workflows

All `agent-browser` and `chrome-debug` commands are auto-allowed — no confirmation prompts.

## Commands

```
chrome-debug [start] [options] [URL]    Launch a new instance
chrome-debug up [roles...]              Launch preset roles
chrome-debug roles                      Show available roles
chrome-debug list                       List running instances
chrome-debug stop <name|all>            Stop instance(s)
chrome-debug save-profile [name]        Save profile as shared identity
chrome-debug port-of <role>             Get CDP port for a role
chrome-debug ports                      List CDP ports of running instances
chrome-debug clean                      Remove all instance data
chrome-debug help                       Show help
```

### Start Options

```
--name, -n NAME       Instance name (default: browser-N)
--port, -p PORT       CDP port (default: auto from 9222)
--headless, -H        Run headless (default: headed)
--size, -s WxH        Window size (default: 1280,900)
--position X,Y        Window position on screen
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHROME_DEBUG_HOME` | `~/.chrome-debug` | Data directory |
| `CHROME_DEBUG_BIN` | `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` | Chrome binary path |

Linux users should set `CHROME_DEBUG_BIN`:

```bash
export CHROME_DEBUG_BIN=$(which google-chrome || which chromium)
```

## Uninstall

```bash
bash uninstall.sh
```

## License

MIT
