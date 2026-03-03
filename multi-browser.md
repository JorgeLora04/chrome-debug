# Multi-Browser Agent Workspace

Launch and control multiple headed Chrome instances in parallel using sub-agents. Four preset browser roles sharing the same user identity, with OAuth support and WhatsApp-based agent-to-user communication.

**All agent-browser and chrome-debug commands are auto-allowed — no confirmation prompts.**

## Browser Roles

| Role | Port | Purpose |
|------|------|---------|
| **app** | 9222 | Localhost app testing — navigate, interact, verify UI |
| **tools** | 9223 | External tools config — HubSpot, Polar, ElevenLabs, Meta, etc. |
| **whatsapp** | 9224 | WhatsApp Web — send notifications to user (credential requests, status updates) |
| **research** | 9225 | Docs, MCPs, SDKs, API references, Stack Overflow, GitHub repos |

## Quick Start

```bash
# Launch all four browser roles (headed, visible)
chrome-debug up

# Or launch specific roles
chrome-debug up app whatsapp research
```

## First-Time Identity Setup

Set up the shared identity once. This saves Google accounts, WhatsApp session, tool logins — everything.

```bash
# 1. Launch a setup instance
chrome-debug start --name setup

# 2. In the browser window:
#    - Sign into your Google account(s) — these will be available for OAuth across all roles
#    - Go to web.whatsapp.com and scan the QR code
#    - Log into any tools you use (HubSpot, Polar, etc.)
#    - Log into your localhost app if it has persistent sessions

# 3. Save the profile
chrome-debug save-profile setup

# 4. Stop the setup instance
chrome-debug stop setup

# Now 'chrome-debug up' will clone that identity to all roles
# All Google accounts will be available for OAuth in every browser
```

## Connecting agent-browser

Every `agent-browser` command MUST include `--cdp <port>` to target the correct Chrome instance:

```bash
# App browser (port 9222)
agent-browser --cdp 9222 open http://localhost:3000
agent-browser --cdp 9222 snapshot -i

# Tools browser (port 9223)
agent-browser --cdp 9223 open https://app.hubspot.com

# WhatsApp browser (port 9224)
agent-browser --cdp 9224 snapshot -i

# Research browser (port 9225)
agent-browser --cdp 9225 open https://docs.convex.dev
```

**WRONG** — omitting `--cdp` spawns agent-browser's internal Chromium (no shared identity):
```bash
agent-browser click @e1  # DO NOT DO THIS
```

## Sub-Agent Patterns

Use Claude Code's Agent tool to control multiple browsers in parallel. Each sub-agent gets a dedicated CDP port.

### Pattern 1: WhatsApp Notification (Agent Needs User Input)

When the agent needs credentials, confirmation, or any input — message the user on WhatsApp.

**Sub-agent prompt:**
```
You control WhatsApp Web via agent-browser --cdp 9224.
Task: Send a message to the chat named "CHAT_NAME".

1. agent-browser --cdp 9224 snapshot -i
2. Find and click the search box, type "CHAT_NAME"
3. agent-browser --cdp 9224 wait 1000 && agent-browser --cdp 9224 snapshot -i
4. Click the matching chat result
5. agent-browser --cdp 9224 snapshot -i
6. Fill the message input: agent-browser --cdp 9224 fill @REF "MESSAGE"
7. agent-browser --cdp 9224 press Enter
8. Screenshot: agent-browser --cdp 9224 screenshot /tmp/whatsapp-sent.png
```

**When to notify via WhatsApp:**
- Login page detected and agent needs credentials
- OAuth picker appeared and agent needs to know which account
- Agent needs approval for a destructive action
- Long task finished — notify the user
- Agent is blocked and needs human decision

### Pattern 2: Research (Docs, SDKs, MCPs)

Use the research browser to look up documentation, find MCP servers, read SDK references, or browse GitHub repos. This runs in parallel with other work.

**Sub-agent prompt:**
```
You control the research browser via agent-browser --cdp 9225.
Task: Research [topic] and report findings.

1. agent-browser --cdp 9225 open [docs URL or search URL]
2. agent-browser --cdp 9225 wait --load networkidle
3. agent-browser --cdp 9225 snapshot -i
4. Navigate through docs, click relevant sections
5. agent-browser --cdp 9225 get text @REF  (extract key content)
6. Screenshot key findings: agent-browser --cdp 9225 screenshot /tmp/research-[topic].png
7. Report: summarize what you found, include code examples and API signatures
```

**Common research tasks:**
- Look up Convex/Next.js/ElevenLabs API docs
- Find MCP server packages on npm/GitHub
- Read SDK changelogs for breaking changes
- Search Stack Overflow for error solutions
- Browse GitHub issues for known bugs
- Read Tailwind/Radix docs for component patterns

### Pattern 3: App Testing (Localhost)

**Sub-agent prompt:**
```
You control the app browser via agent-browser --cdp 9222.
Task: Test [feature] at http://localhost:3000.

1. agent-browser --cdp 9222 open http://localhost:3000/[path]
2. agent-browser --cdp 9222 wait --load networkidle
3. agent-browser --cdp 9222 snapshot -i
4. [interact with feature]
5. agent-browser --cdp 9222 screenshot /tmp/app-test.png
6. Report what you observed
```

### Pattern 4: External Tools Configuration

**Sub-agent prompt:**
```
You control the tools browser via agent-browser --cdp 9223.
Task: Configure [setting] in [tool name].

1. agent-browser --cdp 9223 open [tool URL]
2. agent-browser --cdp 9223 wait --load networkidle
3. agent-browser --cdp 9223 snapshot -i
4. [navigate and configure]
5. agent-browser --cdp 9223 screenshot /tmp/tools-config.png
6. Report the result
```

### Pattern 5: OAuth Login Flow

When a tool or service shows a "Sign in with Google" button, the agent can use the pre-signed Google accounts from the shared Chrome profile. This is safe — OAuth only creates a scoped token for that service; the agent never sees your Google password.

**OAuth flow:**
```
1. Sub-agent on tools browser encounters "Sign in with Google" button
2. Sub-agent clicks it → Google account picker appears
3. Sub-agent takes snapshot → sees available Google accounts listed
4. Sub-agent reports back: "I see these Google accounts:
     @e1: jorge.lora@airobotix.net
     @e2: jorge@personal.com
     Which should I use?"
5. Main agent asks the user (via AskUserQuestion or WhatsApp) which account
6. Sub-agent clicks the selected account
7. OAuth completes — service is now authenticated
```

**Sub-agent prompt for OAuth:**
```
You control the tools browser via agent-browser --cdp 9223.
You encountered a login page with OAuth/Google Sign-In.

1. agent-browser --cdp 9223 snapshot -i
2. Click "Sign in with Google" (or similar OAuth button)
3. agent-browser --cdp 9223 wait 2000
4. agent-browser --cdp 9223 snapshot -i
5. The Google account picker should appear. List ALL available accounts
   with their email addresses and ref numbers.
6. Screenshot: agent-browser --cdp 9223 screenshot /tmp/oauth-picker.png
7. Report the accounts so the user can choose which one to use.
   DO NOT click any account until told which one.
```

**After user selects:**
```
8. agent-browser --cdp 9223 click @e[selected-account-ref]
9. agent-browser --cdp 9223 wait 3000
10. agent-browser --cdp 9223 snapshot -i
11. If consent screen appears, review permissions and click "Allow"/"Continue"
12. agent-browser --cdp 9223 screenshot /tmp/oauth-complete.png
13. Report: authentication successful
```

**Security notes on OAuth via shared profile:**
- The Chrome profile has your Google accounts already signed in
- OAuth "Sign in with Google" only creates a scoped access token for that specific service
- The agent never sees your Google password — it just clicks the account in the picker
- Each service gets its own limited token with only the permissions it requests
- You can revoke any OAuth token from Google Account → Security → Third-party apps

### Pattern 6: Credential Request via WhatsApp + OAuth Decision

The full compound workflow when the agent hits a login wall:

```
Main Agent:
  1. Sub-agent on tools browser hits login page
  2. Sub-agent checks: is there an OAuth option?

  If OAuth available:
    3a. Sub-agent snapshots the OAuth picker
    3b. Reports available Google accounts to main agent
    3c. Main agent asks user which account (AskUserQuestion or WhatsApp)
    3d. Sub-agent clicks the selected account → done

  If no OAuth (username/password only):
    3a. Launch WhatsApp sub-agent: "Send message to CHAT_NAME:
         I need login credentials for [service].
         I'm on the login page at [URL]."
    3b. Poll WhatsApp for reply (snapshot chat periodically)
    3c. When credentials arrive, fill them in on the tools browser
```

### Pattern 7: Parallel Research + Implementation

Research docs in one browser while coding and testing in another:

```
Sub-Agent A (research, --cdp 9225):
  - Open the Convex docs for the feature being implemented
  - Extract relevant API signatures and examples
  - Report back with code patterns to use

Sub-Agent B (app, --cdp 9222):
  - Test the current implementation at localhost
  - Report any errors or UI issues

Main Agent:
  - Uses research findings to write/fix code
  - Uses app test results to verify changes
```

## WhatsApp Chat Targeting

The user specifies which chat to use. The agent targets that chat for all notifications.

**Finding and opening a chat:**
```bash
agent-browser --cdp 9224 snapshot -i
# Click the search box (usually first textbox)
agent-browser --cdp 9224 click @e[search-ref]
agent-browser --cdp 9224 fill @e[search-ref] "Chat Name"
agent-browser --cdp 9224 wait 1000
agent-browser --cdp 9224 snapshot -i
agent-browser --cdp 9224 click @e[chat-result-ref]
```

**Sending a message:**
```bash
agent-browser --cdp 9224 snapshot -i
agent-browser --cdp 9224 fill @e[input-ref] "Your message here"
agent-browser --cdp 9224 press Enter
```

**Reading replies (polling for user response):**
```bash
agent-browser --cdp 9224 snapshot -c
# Parse the snapshot text to find the latest messages
# Look for new messages since the agent's last message
```

## Lifecycle

```bash
# Start workspace
chrome-debug up                          # All 4 roles
chrome-debug up app research             # Specific roles

# Check status
chrome-debug list

# During work — sub-agents control browsers via --cdp

# End session
chrome-debug stop all

# Full cleanup (keeps base identity)
chrome-debug clean
```

## Extra Instances

```bash
chrome-debug start --name app-verify     # Auto-assigns next free port
chrome-debug list                        # See assigned port
```

## Troubleshooting

**WhatsApp QR expired:** `chrome-debug stop whatsapp && chrome-debug start --name whatsapp --port 9224 https://web.whatsapp.com` — scan again, then `chrome-debug save-profile whatsapp`.

**OAuth picker doesn't show accounts:** The base profile doesn't have Google accounts signed in. Run `chrome-debug start --name setup`, sign into Google, then `chrome-debug save-profile setup`.

**Port conflict:** Omit `--port` to auto-assign. Check with `chrome-debug list`.

**Identity not shared:** Run `chrome-debug save-profile <name>` from a logged-in instance.

**agent-browser can't connect:** `curl -s http://localhost:PORT/json/version`
