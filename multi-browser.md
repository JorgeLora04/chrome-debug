# Multi-Browser Agent Workspace

Launch and control multiple headed Chrome instances in parallel using sub-agents. Four preset browser roles sharing the same user identity, with OAuth support and WhatsApp-based agent-to-user communication.

**All agent-browser and chrome-debug commands are auto-allowed — no confirmation prompts.**

> **CRITICAL RULE — Automatic Login Detection:**
> When ANY browser sub-agent detects a login/auth page after a page load, the main agent MUST immediately launch a WhatsApp notification sub-agent to alert the user — do NOT just report it in conversation text. The user may not be watching the terminal. Every sub-agent prompt includes a mandatory LOGIN CHECK step after each `snapshot -i`. See Pattern 6 for the full automatic flow.

> **Command prefix rule:** NEVER prefix `agent-browser` or `chrome-debug` with `sleep &&` or other shell commands. Always call them as standalone commands so auto-allow rules match the `Bash(agent-browser` prefix correctly.

## Interactive Setup Wizard ("vamoaeto")

When the user says **"vamoaeto"**, run this interactive setup before launching browsers. Use `AskUserQuestion` for each step.

### Step 1: Select Browsers

Ask the user (multiSelect): **"Which browsers do you want to open?"**
- App Browser — test your app (dev or production)
- Tools Browser — configure external tools
- WhatsApp Notifications — agent-to-user messaging
- Research Browser — docs, SDKs, MCPs

### Step 2: Per-Browser Config (only for selected browsers)

**App Browser** — Ask: "App environment?"
- Development (http://localhost:3000) *(Recommended)*
- Production (ask user for URL in follow-up)
- Skip (open empty)

**Tools Browser** — Ask: "Which tool to open?"
- HubSpot
- ElevenLabs
- Polar
- Meta / Facebook Developers
- Other (user provides URL)
- Skip (open empty)

**WhatsApp** — Ask: "Which WhatsApp chat should I use for notifications?"
- This is a free-text answer — the user provides a chat name
- IMPORTANT: Store this as WHATSAPP_CHAT for the entire session

**Research Browser** — Ask: "What docs to open first?"
- Convex Docs (https://docs.convex.dev)
- Next.js Docs (https://nextjs.org/docs)
- ElevenLabs API (https://elevenlabs.io/docs)
- Other (user provides URL)
- Skip (open empty)

### Step 3: Launch

For each selected browser:
1. `chrome-debug start --name <role> --port <port>`
2. `agent-browser --cdp <port> open <url>` (if a URL was chosen)
3. `agent-browser --cdp <port> wait --load networkidle`

**WhatsApp special case:** After opening `web.whatsapp.com`, always snapshot and check the state:
- If chat list is visible → WhatsApp is linked, proceed
- If QR code or "Link a device" screen → tell the user to scan the QR code in the WhatsApp browser window and wait for confirmation before proceeding
- Do NOT assume WhatsApp is ready — always verify

### Step 4: Save Session Config

Write all preferences to the config file so they persist:
```bash
chrome-debug config set WHATSAPP_CHAT "Chat Name"
chrome-debug config set APP_MODE dev
chrome-debug config set APP_URL http://localhost:3000
chrome-debug config set TOOLS_URL https://app.hubspot.com
chrome-debug config set RESEARCH_URL https://docs.convex.dev
chrome-debug config set ENABLED_ROLES app,tools,whatsapp,research
```

### Step 5: Offer Extras

Ask: "Want to open any additional browser instances?" (yes/no)
If yes, ask for a name and URL, then: `chrome-debug start --name <name>`

### Reading Saved Config

On subsequent "vamoaeto" triggers in the same session, check for existing config:
```bash
chrome-debug config show
```
If config exists, ask: "Use previous setup?" — if yes, skip the wizard and launch with saved preferences.

### Tool URL Presets

| Tool | URL |
|------|-----|
| HubSpot | https://app.hubspot.com |
| ElevenLabs | https://elevenlabs.io/app |
| Polar | https://polar.sh/dashboard |
| Meta | https://developers.facebook.com |

## Browser Roles

| Role | Port | Purpose |
|------|------|---------|
| **app** | 9222 | App testing (dev or production) |
| **tools** | 9223 | External tools config |
| **whatsapp** | 9224 | WhatsApp Web for agent notifications |
| **research** | 9225 | Docs, MCPs, SDKs, API references |

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

   *** LOGIN CHECK: If a login/sign-in page appears, report LOGIN_DETECTED
   immediately — do not try to bypass it. ***

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

   *** LOGIN CHECK: If you see a login/sign-in page, STOP and immediately
   report LOGIN_DETECTED to the main agent so it can notify the user via WhatsApp.
   Do NOT proceed past a login wall without the user's action. ***

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

   *** LOGIN CHECK: If you see a login/sign-in/OAuth page, STOP and immediately
   report LOGIN_DETECTED to the main agent. Check if OAuth is available first —
   if yes, snapshot the picker and list accounts. If no, notify user via WhatsApp. ***

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

### Pattern 6: Automatic Login Detection → WhatsApp Alert (MANDATORY)

**This pattern is MANDATORY — not optional.** When any browser sub-agent detects a login page, the main agent must immediately launch a WhatsApp notification sub-agent. Do NOT just report it in conversation text — the user is likely not watching the terminal.

**Full automatic flow:**

```
Sub-Agent (any browser) detects login page:
  → Immediately reports: "LOGIN_DETECTED at [URL]. OAuth available: yes/no."

Main Agent receives LOGIN_DETECTED:
  1. Immediately launch WhatsApp sub-agent in parallel

  If OAuth available:
    → WhatsApp message: "I hit a login page at [URL]. I see these Google accounts:
       - jorge.lora@airobotix.net
       - jorge@personal.com
       Which should I use?"
    → Wait for reply (poll WhatsApp every ~10s)
    → Sub-agent clicks selected account → OAuth completes

  If no OAuth (username/password only):
    → WhatsApp message: "I need login credentials for [service name].
       I'm blocked at: [URL]
       Please send username and password."
    → Poll WhatsApp for reply
    → When credentials arrive, fill them in the blocked browser

  If login page on app browser (localhost):
    → WhatsApp message: "The app at [URL] is showing a login page.
       Are you logged in? Do you want me to log in as a test user?"
    → Wait for instructions before proceeding
```

**WhatsApp sub-agent prompt for login alert:**
```
You control WhatsApp Web via agent-browser --cdp 9224.
Task: Send an urgent login-blocked notification to "CHAT_NAME".

1. agent-browser --cdp 9224 snapshot -i
2. Find the search box and type "CHAT_NAME"
3. agent-browser --cdp 9224 wait 1000
4. agent-browser --cdp 9224 snapshot -i
5. Click the matching chat
6. agent-browser --cdp 9224 snapshot -i
7. Fill the message input with: "🔐 LOGIN REQUIRED\n[SERVICE] is asking me to log in.\nURL: [URL]\n[OAUTH/CREDENTIALS instructions]\nPlease respond here."
8. agent-browser --cdp 9224 press Enter
9. Report: message sent successfully
```

**Polling for user reply:**
```bash
# Every ~10 seconds while waiting for credentials:
agent-browser --cdp 9224 snapshot -c
# Look for new messages (after the agent's last message timestamp)
# Parse incoming message text for credentials or account selection
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
  - *** LOGIN CHECK after every snapshot — alert main agent immediately if login page ***

Main Agent:
  - Uses research findings to write/fix code
  - Uses app test results to verify changes
```

### Pattern 8: WhatsApp Reply Polling (Waiting for User Input)

When the agent sends a WhatsApp message and needs the user's response (credentials, decision, confirmation):

```bash
# Send the message first (see Pattern 1)
# Then poll every 10 seconds:

agent-browser --cdp 9224 snapshot -c
# Look for messages AFTER the timestamp of your last sent message
# New incoming text = user's reply

# If no reply yet, wait and retry:
agent-browser --cdp 9224 wait 10000
agent-browser --cdp 9224 snapshot -c
```

**Parsing the reply:**
- Use `snapshot -c` (compact mode) to get text-only output — easier to parse than `-i` interactive mode
- Look for the most recent message bubble that isn't from "You" (the agent)
- The reply text is the user's response

**After getting the reply:**
- Credentials → fill them in the blocked browser immediately
- OAuth account selection → click the selected account in the picker
- Approval/denial → proceed or abort the action accordingly
- If unclear → send a follow-up WhatsApp message asking for clarification

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

## Lessons from Real Sessions

Hard-won learnings from actual use — things that weren't obvious until they happened.

### Command Prefixing Breaks Auto-Allow

Auto-allow rules match on the exact start of the bash command string. If you write:

```bash
sleep 2 && agent-browser --cdp 9224 snapshot -i  # BREAKS auto-allow
```

The rule matches `Bash(agent-browser` but the actual command starts with `sleep`. Always split into separate calls:

```bash
agent-browser --cdp 9224 wait 2000   # built-in wait, no prefix needed
agent-browser --cdp 9224 snapshot -i
```

### WhatsApp Must Be Verified, Not Assumed

After opening `web.whatsapp.com`, always snapshot before doing anything. WhatsApp Web may show:
- **Chat list** → linked and ready ✓
- **QR code / "Link a device"** → not linked, user must scan
- **"Phone not connected"** → phone is offline, user must check it
- **Loading spinner** → wait a few more seconds then re-snapshot

Never skip the verification step — a failed WhatsApp notification is worse than no notification.

### `snapshot -i` vs `snapshot -c`

- `-i` (interactive): Returns ref numbers (`@e1`, `@e2`) for clicking — use for interaction
- `-c` (compact): Returns text-only content — use for reading/parsing (replies, page text extraction)

When polling WhatsApp for a reply, use `-c` — easier to parse new message text without noise.

### WhatsApp Search Box Behavior

The search box in WhatsApp Web can be finicky. If typing doesn't filter results:
1. Click the search icon first (not the input directly)
2. Wait 500ms after clicking before filling
3. After filling, wait 1000ms before reading results — the filter is async

### Sub-Agent Snapshot After Navigation

Always wait for `networkidle` after `open` before taking a snapshot:

```bash
agent-browser --cdp 9222 open http://localhost:3000/dashboard
agent-browser --cdp 9222 wait --load networkidle
agent-browser --cdp 9222 snapshot -i
# Now safe to read the page state
```

Skipping the wait often produces a snapshot of the loading state, not the final page.

### Parallel Sub-Agents — Port Isolation Is Critical

Each sub-agent MUST use only its assigned `--cdp <port>`. If two sub-agents share the same port, their commands will interfere with each other's browser state. One agent's `open` will change the page the other agent is trying to interact with.

Rule: one port per concurrent sub-agent, always.

## Troubleshooting

**WhatsApp QR expired:** `chrome-debug stop whatsapp && chrome-debug start --name whatsapp --port 9224 https://web.whatsapp.com` — scan again, then `chrome-debug save-profile whatsapp`.

**OAuth picker doesn't show accounts:** The base profile doesn't have Google accounts signed in. Run `chrome-debug start --name setup`, sign into Google, then `chrome-debug save-profile setup`.

**Port conflict:** Omit `--port` to auto-assign. Check with `chrome-debug list`.

**Identity not shared:** Run `chrome-debug save-profile <name>` from a logged-in instance.

**agent-browser can't connect:** `curl -s http://localhost:PORT/json/version`
