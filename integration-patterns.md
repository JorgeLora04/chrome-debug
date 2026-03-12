# Integration & API Patterns

Production-tested patterns for integrating external services: ElevenLabs, webhooks, HubSpot, WhatsApp, Polar billing, Vercel AI SDK, and Meta Graph API.

---

## 1. WEBHOOK PATTERNS

### End-to-End Flow
```
External Service -> POST /api/webhooks/service -> Validate signature -> Forward to backend -> Update DB
```
Frontend auto-updates via Convex real-time subscriptions (no polling needed).

### HMAC-SHA256 Signature Validation
```typescript
function validateSignature(payload: string, signature: string, secret: string): boolean {
  const hmac = crypto.createHmac('sha256', secret)
  hmac.update(payload)
  return signature === hmac.digest('hex')
}
```

### Idempotent Processing (CRITICAL)
Always deduplicate by event ID before processing:
```typescript
const existing = await db.query("events")
  .withIndex("by_externalId", q => q.eq("externalId", eventId))
  .first()
if (existing) return // Already processed
```

### Three-Layer Status Tracking
1. **Webhook** (real-time) — immediate status from provider
2. **Polling** (fallback) — catch missed webhooks
3. **Cron** (stuck detection) — mark stuck records after timeout (e.g., "connecting" > 5 minutes)

### Security Checklist
- Always validate webhook signatures
- Use HTTPS endpoints only
- Rotate secrets periodically
- Rate-limit the webhook endpoint
- Log suspicious requests

---

## 2. ELEVENLABS PATTERNS

### API Proxy Architecture
All outbound requests proxied through backend (Convex actions or Next.js API routes). API keys NEVER touch the browser.

### Regional Endpoints
```
US: https://api.us.elevenlabs.io
EU: https://api.eu.residency.elevenlabs.io
IN: https://api.in.residency.elevenlabs.io
```
Configure per-tenant when latency or compliance requires it.

### Batch Calling Lifecycle
`draft -> running -> completed`

- Phone numbers MUST be E.164 format (`+1234567890`)
- `externalId` must be set on call records at creation time (or webhook matching fails silently)
- Use `conversation_config_override` for per-call prompt customization

### Tool Configuration Gotchas
- Properties must be **arrays**, not objects in tool JSON schema
- Dynamic variables use `{{variable}}` syntax
- System variables: `system__conversation_id` (note double underscore)
- Always include `X-Webhook-Secret` in request headers
- Test with a single call before batch operations

### Widget Conversation Sync
Three-layer sync: webhook (primary) + auto-sync on page load (fallback) + manual refresh button. Track sync state per session to avoid duplicate processing.

### Call State Machine
| Event | Status |
|-------|--------|
| `conversation.started` | `in_progress` |
| `conversation.completed` | `completed` (+ duration, audio, transcript) |
| `call.failed` | `failed` (+ error) |
| `call.no_answer` | `no_answer` |
| `call.voicemail` | `voicemail` |

### Centralize All Defaults
Keep languages, models, regions, starter prompts, and greetings in a single config file. Avoids scattering magic strings across the codebase.

---

## 3. VOICE AGENT PROMPT ENGINEERING

### Prompt Structure Template
```
[Identity & Role]
[Objective & Goals]
[Context & Knowledge]
[Conversation Flow / Steps]
[Guardrails (5 categories)]
[Tool Usage Instructions]
[Closing Rules]
[Language & Tone Guidelines]
[Contact Information - Dynamic]
```

### Five Universal Guardrail Categories

**1. Background Noise Handling:**
- Focus exclusively on primary speaker
- Ignore all background audio (TV, traffic, typing, side conversations)
- Never close a call due to background noise alone
- If someone briefly interrupts user, wait 2-3 seconds, then: "Shall we continue?"

**2. Conversation Momentum (Anti-Silence Protocol):**
- Max acceptable pause after valid answer: 1-2 seconds
- If more than 2 seconds pass, the agent is failing
- After valid answer: acknowledge briefly ("Perfect"), then immediately next question
- "If the user needs to say hello to re-engage you, you have failed"

**3. Unclear/Repeated Responses (Escalating Clarification):**
1. First attempt: "Sorry, I didn't hear you well. Could you repeat?"
2. Second attempt: Be type-specific (boolean: "yes or no?", rating: "what number 1-10?", choice: list ALL options)
3. Third attempt: Accept closest valid answer and proceed

**4. Decision Tree for Ambiguous Input:**
- "Si, si, si" alone → "Is that a yes?"
- "Dale, dale" or fillers → Repeat the question
- "Mmm... I don't know" → "Would you prefer to skip to the next question?"
- "Eight... no, seven" → Take the LAST number (7)
- Mixed languages "Si... yes... okay" → Accept as affirmative

**5. Pacing & Noise Handling:**
- 2-3 second max wait for distractions
- Post-answer audio is NOT "user still talking" unless clearly directed at agent

### Platform-Agent Handoff
Platform sends the first message automatically. Agent prompt must NOT repeat introduction. Begin with time-based greeting after user responds.

### Time-Based Greetings
```
5:00 AM - 11:59 AM  → "Good morning"
12:00 PM - 6:59 PM  → "Good afternoon"
7:00 PM - 4:59 AM   → "Good evening"
```
Use the TARGET timezone, not server timezone.

### Call Closing Rules (Whitelist)
Only close for:
1. Task completed successfully
2. User explicitly declines
3. User inactivity: 3 minutes silence + 60-second follow-up
- Exception: If user requests time, wait up to 5 minutes

### Survey-Specific Optimizations
- For consecutive rating questions, only mention the scale on the first
- For CHOICE questions, always read ALL options
- Explicitly state "Those were all the questions" before closing
- Never ask "anything else?" — this is a survey, not customer service

### Dynamic Contact Info
Inject contact data at the end of the prompt. Instruct agent to never ask for information it already has.

### Apply Guardrails Globally
When updating guardrails, apply to ALL active prompts simultaneously. Never update one without the others.

---

## 4. VERCEL AI SDK V6 (BREAKING CHANGES)

### Chat Hook Migration (v5 → v6)
```tsx
// v6: useChat requires transport object
import { useChat } from '@ai-sdk/react'
import { DefaultChatTransport } from 'ai'

const transport = useMemo(() => new DefaultChatTransport({
  api: '/api/ai/prompt-generator',
  body: { context },
}), [context])

const { messages, sendMessage, status, error } = useChat({ transport })
```

### Key API Changes
| v5 | v6 |
|----|-----|
| `handleSubmit()` | `sendMessage({ text })` |
| `isLoading` boolean | `status === 'submitted' \|\| status === 'streaming'` |
| `message.content` | `message.parts?.filter(p => p.type === 'text').map(p => p.text)` |
| `convertToModelMessages()` sync | `await convertToModelMessages()` (Promise!) |

### Vercel AI Gateway
Eliminates provider management. Swap models with a string:
```typescript
const result = streamText({
  model: 'anthropic/claude-sonnet-4-5',  // Just a string!
  system: systemPrompt,
  messages: await convertToModelMessages(messages),
})
```
No separate API keys, unified billing, built-in rate limiting.

### Structured AI Output → Form Fields
Use custom code fences (` ```prompt `, ` ```first-message `) that the UI detects and renders inline "Apply" buttons. Clean pattern for mapping AI output to specific form fields.

---

## 5. API INTEGRATION BEST PRACTICES

### Race Condition: Mid-Call vs Post-Call Data
When integrations fire mid-call (via custom tools), never assume all fields exist. Design cascading fallback lookups:
1. Primary: lookup by `conversationId`
2. Fallback: lookup by `externalId`
3. Fallback: widget session lookup
4. Fallback: call external API to resolve missing data

### Timestamp Normalization at Boundaries
```typescript
let normalized = payload.startTime
if (/^\d+$/.test(normalized)) {
  normalized = new Date(Number(normalized)).toISOString()
}
```
Different systems use different formats. Always detect and convert at system boundaries.

### Response Parsing Resilience
Never assume a single field name:
```typescript
const id = response.engagementId || response.id || response.calendarEventId || response.meetingId
```

### API Integration Checklist
Before deploying any integration:
- [ ] Verify URL path structure (params in path vs body vs query)
- [ ] Test in API sandbox before production
- [ ] Map all possible response shapes and field names
- [ ] Handle rate limits (429) with retryable flag
- [ ] Add idempotency fields to prevent duplicate processing
- [ ] Store error details on records for debugging

### Meta Graph API Rule
Never code against a Graph API field without testing in the Graph API Explorer first. Document verified fields in comments. Relationships can be one-directional with no reverse edge.

### Dual-Layer Validation
When your AI platform lacks a feature (conditionals, branching):
1. Embed logic in the prompt (instructions to skip/branch)
2. Enforce server-side as safety net (filter invalid responses post-call)

---

## 6. BILLING INTEGRATION (Polar)

### Metered vs Fixed Billing
- `pricingConfigs` per company define rates by service type
- `billingCycles` track usage metrics with cost breakdown
- `modulePricing` allows per-module fixed fees
- `billingMode`: `automatic | manual | disabled`

### Price Changes for Existing Subscribers
- Fixed-price subscribers are grandfathered
- Metered subscribers get new rate at next invoice
- If not: create new product + `subscriptions.update()` with proration

### Scheduled Sync Pattern
Mutations can't call actions. Use `ctx.scheduler.runAfter(0, ...)` for immediate external service sync after state changes.

---

## 7. CONVEX MCP SERVER

Expose your backend as an MCP server for AI coding assistants:
```json
{
  "type": "stdio",
  "command": "pnpm",
  "args": ["mcp:convex"],
  "env": {
    "CONVEX_DEPLOYMENT": "https://your-deployment.convex.cloud",
    "CONVEX_ADMIN_KEY": "your-admin-key"
  }
}
```
Gives Claude/Codex full access to schema, functions, and data for development.
