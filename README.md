# vamoaeto

AI project creation toolkit for Claude Code. Manages multi-browser workspaces, learns your project's patterns, syncs knowledge across your team, and generates professional-grade UI with live design previews.

Built on top of [chrome-debug](#chrome-debug) for browser management and [agent-browser](https://github.com/nichochar/agent-browser) for browser automation.

## Install

```bash
# One-liner (clones repo automatically for team sync)
curl -fsSL https://raw.githubusercontent.com/JorgeLora04/chrome-debug/main/install.sh | bash

# Or clone manually
git clone https://github.com/JorgeLora04/chrome-debug.git
cd chrome-debug
bash install.sh
```

The installer:
- Clones the repo to `~/.vamoaeto/repo/` (enables team knowledge sync)
- Installs `chrome-debug` to `~/.local/bin/`
- Installs `/vamoaeto` command + knowledge base to Claude Code
- Adds auto-allow permissions for browser commands
- Optionally sets a shell alias

### Prerequisites

- **Google Chrome** (macOS, Linux, Windows via Git Bash)
- **agent-browser**: `npm install -g @anthropic-ai/agent-browser && agent-browser install`
- **git** (required for team knowledge sync)
- **jq** (optional, for settings merge): `brew install jq`

## What It Does

### 1. Interactive Setup Wizard

```
/vamoaeto
```

Launches an interactive wizard to configure your browser workspace:
- **App Browser** (port 9222) — test your app (localhost or production)
- **Tools Browser** (port 9223) — configure HubSpot, ElevenLabs, Polar, Meta
- **WhatsApp** (port 9224) — agent-to-user notifications when it needs input
- **Research Browser** (port 9225) — docs, SDKs, API references

All browsers share the same Chrome identity (Google accounts, cookies, sessions).

### 2. Project Knowledge Scanner

```
/vamoaeto update
```

Scans your current project and learns its patterns, architecture, and hard-won knowledge. Synced with your team via git.

**How it works:**
1. `git pull` — fetches teammates' knowledge updates
2. Scans project files: CLAUDE.md, schema files, docs/solutions/, configs, Claude memories
3. Compares against checkpoint — only re-analyzes changed files
4. Extracts patterns using parallel agents
5. Writes knowledge to `.vamoaeto/knowledge/` in the repo
6. `git commit + push` — shares updates with the team

**What it learns from:**
- `CLAUDE.md` and `.claude/` config
- `docs/solutions/**/*.md` (compound engineering learnings)
- `docs/plans/**/*.md` (implementation plans)
- Schema files (Convex, Prisma, GraphQL)
- Auth patterns, middleware, configs
- `package.json` / `Cargo.toml` / `Gemfile` (tech stack)

**Team sync:** Every member who runs `vamoaeto update` pulls the latest knowledge and pushes their own discoveries. No manual coordination needed — the installer clones the repo automatically so curl-installed users get sync too.

### 3. Auto-Applied Knowledge

After setup, vamoaeto automatically applies learned patterns when building features:

- **UI**: Framer Motion animations, glassmorphism, noise overlays, gradient text, staggered reveals, responsive design
- **SaaS**: Multi-tenant data isolation, three-layer auth (RBAC + modules + company toggles), Convex patterns
- **APIs**: Webhook HMAC validation, idempotent processing, three-layer status tracking, API proxy architecture
- **Voice AI**: 5-category guardrails, prompt structure templates, call state machines

### 4. UI Design Previews

When any task involves UI changes, vamoaeto asks: **"Want to preview 4 design alternatives?"**

- **Yes** — Generates 4 distinct UI variants as standalone HTML, opens them in a preview browser (port 9226) with separate tabs:
  1. Clean & minimal
  2. Bold & expressive
  3. Editorial & refined
  4. Dark & premium
- User picks one (or mixes: "combine 1 and 3"), preview browser closes, real component is built
- **No** — Picks the best design automatically, builds it with zero friction

## chrome-debug

The underlying browser management tool.

### Quick Start

```bash
chrome-debug up                    # Launch all 4 browser roles
chrome-debug up app research       # Launch specific roles
chrome-debug list                  # List running instances
chrome-debug stop all              # Stop everything
chrome-debug clean                 # Full cleanup (keeps identity)
```

### Roles

| Role | Port | Purpose |
|------|------|---------|
| `app` | 9222 | Localhost app testing |
| `tools` | 9223 | External tools (HubSpot, Polar, ElevenLabs, Meta) |
| `whatsapp` | 9224 | WhatsApp Web for agent notifications |
| `research` | 9225 | Docs, SDKs, API references |
| `preview` | 9226 | UI design previews (auto-managed) |

### Identity Sharing

All browser instances share login sessions, cookies, and Google accounts:

```bash
# One-time setup
chrome-debug start --name setup     # Launch a setup instance
# Sign into Google, WhatsApp, tools in the browser window
chrome-debug save-profile setup     # Save as shared identity
chrome-debug stop setup

# All future instances are already logged in
chrome-debug up
```

### Connecting with agent-browser

Every command must include `--cdp <port>`:

```bash
agent-browser --cdp 9222 open http://localhost:3000
agent-browser --cdp 9222 snapshot -i
agent-browser --cdp 9225 open https://docs.convex.dev
```

### Commands

```
chrome-debug [start] [options] [URL]    Launch a new instance
chrome-debug up [roles...]              Launch preset roles
chrome-debug roles                      Show available roles
chrome-debug list                       List running instances
chrome-debug stop <name|all>            Stop instance(s)
chrome-debug save-profile [name]        Save profile as shared identity
chrome-debug port-of <role>             Get CDP port for a role
chrome-debug ports                      List CDP ports
chrome-debug config set KEY VALUE       Save session config
chrome-debug config show                Show saved config
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

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHROME_DEBUG_HOME` | `~/.chrome-debug` | Data directory |
| `CHROME_DEBUG_BIN` | Auto-detected | Chrome binary path |

Linux users should set `CHROME_DEBUG_BIN`:
```bash
export CHROME_DEBUG_BIN=$(which google-chrome || which chromium)
```

## Knowledge Base

The installer includes these knowledge files (also available as `/slash-commands` in Claude Code):

| File | Contents |
|------|----------|
| `design-patterns.md` | Framer Motion, CSS animations, visual effects, color palettes, typography |
| `saas-patterns.md` | Multi-tenancy, auth, Convex, Next.js, TypeScript, performance |
| `integration-patterns.md` | Webhooks, ElevenLabs, Vercel AI SDK, billing, voice AI prompts |
| `multi-browser.md` | Sub-agent patterns, login detection, OAuth, WhatsApp notifications |

## Uninstall

```bash
bash uninstall.sh
```

## License

MIT
