# SaaS Architecture Patterns

Production-tested patterns for building multi-tenant SaaS applications with Next.js, Convex, TypeScript, and Tailwind CSS. Apply these when building any SaaS product.

---

## 1. MULTI-TENANCY

### Company-Scoped Data Isolation (CRITICAL)

**Every query and mutation MUST scope data by company.** This is the #1 rule.

```typescript
// ALWAYS: scope queries with company index
const contacts = await ctx.db
  .query("contacts")
  .withIndex("by_company", q => q.eq("companyId", companyId))
  .collect()

// NEVER: query without company filter
const contacts = await ctx.db.query("contacts").collect() // DANGEROUS
```

### Schema Pattern: Join Table for Multi-Company Users

```typescript
// Users can belong to multiple companies
companyUsers: defineTable({
  companyId: v.id("companies"),
  userId: v.id("users"),
  role: v.union(v.literal("admin"), v.literal("agent"), v.literal("viewer")),
  status: v.union(v.literal("invited"), v.literal("active"), v.literal("suspended")),
  seatType: v.optional(v.string()),
  moduleOverrides: v.optional(v.array(v.string())),
}).index("by_company_user", ["companyId", "userId"])
```

### Active Company Session Model

Store `activeCompanyId` on the user record. Backend resolves company from session automatically — no need to pass companyId on every API call.

```typescript
// Backend: single enforcement point
function requireCompanyContext(ctx, user, opts?) {
  // 1. Check company status (disabled/suspended/expired)
  // 2. Check user membership in company
  // 3. Owner bypass if allowOwnerFallback
  return { company, membership }
}
```

### Owner Bypass Pattern

A `globalRole: "owner"` allows cross-tenant access. `requireCompanyContext()` accepts `allowOwnerFallback` — when true, owners operate without company context (viewing all companies).

### Seat Limits Enforcement

Check at user creation AND role assignment time against `companyUsers` count. Never trust the frontend to enforce limits.

---

## 2. THREE-LAYER AUTHORIZATION

### Layer 1: RBAC (Role-Based)

```typescript
const PERMISSIONS = {
  admin: ["BATCH_CREATE", "CONTACT_DELETE", "ANALYTICS_VIEW", ...],
  agent: ["BATCH_VIEW", "CONTACT_VIEW", ...],
  viewer: ["BATCH_VIEW", "ANALYTICS_VIEW"],
}
const hasPermission = (role, permission) => PERMISSIONS[role]?.includes(permission)
```

### Layer 2: Module Access (Feature Flags per User)

Each user has a `modules` array. Sub-pattern: `_use` modules (e.g., `agents_use`) grant read-only access without full management rights. Check both exact module and `_use` variant as fallback.

### Layer 3: Company Module Toggles

The `companyModules` table enables/disables features per company. Even if a user has the module, the company must also have it enabled. Explicit overrides win over `defaultModules`.

### Backend Enforcement

```typescript
async function requireModuleAccess(ctx, moduleName) {
  const user = await getCurrentUser(ctx)          // 1. Authenticate
  assertUserHasModule(user, moduleName)            // 2. User has module?
  const company = await requireCompanyContext(ctx, user)  // 3. Company context
  await assertCompanyModuleEnabled(ctx, company, moduleName) // 4. Company allows it?
  return { user, company }
}
```

### Frontend Guard Pattern

```tsx
const { ready, allowed, fallbackRoute } = useModuleAccess('moduleName')
if (!ready) return <Loading />
if (!allowed) return <AccessRestricted />
return <Content />
```

---

## 3. CONVEX PATTERNS

### Strict Argument Validation

Convex rejects undeclared fields. Never spread raw objects into mutations.

```typescript
// BAD: spreading unfiltered objects
await ctx.runMutation(mutation, { ...rawObject })

// GOOD: explicit fields only
await ctx.runMutation(mutation, {
  field1: rawObject.field1,
  field2: rawObject.field2,
})
```

Let mutations own timestamps internally — never pass `createdAt`/`updatedAt` as arguments.

### Convex Runtime Is Not Node.js

Convex runs in V8 isolates. Node.js built-ins are unavailable:

| Node.js | Convex Equivalent |
|---------|-------------------|
| `crypto.createHmac()` | `crypto.subtle.importKey()` + `crypto.subtle.sign()` |
| `Buffer.from()` | `TextEncoder` / `Uint8Array` |
| `http.request()` | `fetch()` |

**Never** import Node.js built-ins in `convex/` files.

### Internal Functions for Scheduled Contexts

When called via `ctx.scheduler.runAfter()`, there's no auth context. Use `internalQuery`/`internalAction` — not public functions that require auth.

### External Service Sync Pattern

Mutations can't call actions directly. Schedule an immediate action:
```typescript
await ctx.scheduler.runAfter(0, internal.hubspot.syncContact, { contactId })
```

### FIFO Bounded Storage

```typescript
const MAX_HISTORY = 5
const existing = await ctx.db.query("history")
  .withIndex("by_target", q => q.eq("targetId", id).eq("field", field))
  .order("asc").collect()

if (existing.length > 0 && existing[existing.length - 1].content === newContent) return // dedup

if (existing.length >= MAX_HISTORY) {
  for (const entry of existing.slice(0, existing.length - MAX_HISTORY + 1)) {
    await ctx.db.delete(entry._id)
  }
}
await ctx.db.insert("history", { ...args, createdAt: Date.now() })
```

### Data Flow (No Redux Needed)

- `useQuery()` — real-time subscriptions (auto-updates UI)
- `useMutation()` — writes
- `useAction()` — external API calls
- React Context only for cross-cutting concerns (locale, notifications)
- `localStorage` for persistence (language preference)

---

## 4. NEXT.JS APP ROUTER PATTERNS

### Role-Based Landing Pages

Every role must have an explicit default route. Use exhaustive redirect map so TypeScript catches missing routes:

```typescript
const ROLE_LANDING: Record<Role, string> = {
  owner: "/owner/companies",
  admin: "/dashboard/batches",
  agent: "/dashboard/calls",
  viewer: "/dashboard/analytics",
}
```

### Module-Route Mapping (Single Source of Truth)

```typescript
const moduleRoutes: Record<string, string> = {
  batches: "/dashboard/batches",
  contacts: "/dashboard/contacts",
  analytics: "/dashboard/analytics",
  // ...
}
function getFirstAllowedRoute(user) { /* find first accessible */ }
function getModuleFromPath(path) { /* reverse lookup for guards */ }
```

### Modal to Page Migration

Modal-based CRUD doesn't scale for complex forms. Migrate to pages when forms grow beyond a dialog. Cards navigate via `router.push`, duplication via `?duplicate=<id>` query param.

---

## 5. PERFORMANCE OPTIMIZATION

### Component Extraction Rules

| Trigger | Action |
|---------|--------|
| 300+ lines | Consider extraction |
| 500+ lines | **Mandatory** extraction |
| 10+ useState | Split by feature domain |
| Tab interfaces | Extract every tab from day one |

### Extraction Props Pattern

```typescript
interface TabSectionProps {
  company: Company
  onMessage: (msg: { type: 'success' | 'error', text: string }) => void
}
```
Parent is orchestrator only. Each tab owns its queries, mutations, and state.

### Dynamic Imports for Heavy Libraries

```tsx
const Chart = dynamic(() => import('recharts'), { ssr: false })
// Reduces initial bundle by ~50KB
```

### Memoization Checklist

- `useCallback` for event handlers passed to children
- `useMemo` for filtering, aggregation, computed values
- `React.memo` on list item/card components

---

## 6. TYPESCRIPT PATTERNS

- Define types BEFORE implementing features (types-first approach)
- Create `*-types.ts` files per domain module
- **Never use `any`** — use `unknown` with type guards
- Use Convex's generated types for compile-time safety

---

## 7. I18N PATTERN (Simple Bilingual)

All translations in one file with identical key structures per locale:

```typescript
type Locale = "es" | "en"
const es = { dashboard: { title: "Panel", noAccess: (m: string) => `Sin acceso a ${m}` } }
const en = { dashboard: { title: "Dashboard", noAccess: (m: string) => `No access to ${m}` } }
```

Simpler than i18next for 2-3 languages. Type system ensures both objects have same shape.

---

## 8. COMPANY BRANDING

Apply per-tenant colors as CSS custom properties at runtime. Always check luminance contrast:

```typescript
const getLuminance = (hex: string) => {
  const c = hex.replace('#', '')
  const [r, g, b] = [0, 2, 4].map(i => parseInt(c.slice(i, i + 2), 16))
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255
}
const hasContrast = Math.abs(getLuminance(text) - getLuminance(bg)) > 0.3
```

**Never** share theme defaults between admin and tenant contexts. Every layout must set its own CSS vars on mount.

---

## 9. CUSTOM FIELDS (Extensible Data Model)

```typescript
customContactFields: v.array(v.object({
  key: v.string(),
  label: v.string(),
  type: v.union(v.literal("text"), v.literal("number"), v.literal("date"), v.literal("select")),
  options: v.optional(v.array(v.string())),
  group: v.optional(v.string()),
}))
// Contacts store values in: metadata: v.any()
```

Each company defines their own fields without schema changes.

---

## 10. UI/UX PATTERNS

### Browser Autocomplete Suppression (for secrets/tokens)
```tsx
<input autoComplete="new-password" data-1p-ignore="" data-lpignore="true" />
```

### Local vs Saved State in Config Forms
Pass both `localValue` and `savedValue`. Use `const effective = localValue ?? savedValue`. Gate downstream actions (checkout, export) on SAVED values, not local state.

### CRUD Completeness
Every entity needs Create, Read, Update, AND Delete. Missing Update forces destructive delete+recreate workflows.

---

## 11. UNIVERSAL "NEVER DO THIS" WARNINGS

1. **Never query without company filter** in multi-tenant apps
2. **Never use `any`** — use `unknown` with type guards
3. **Never spread unfiltered objects** into Convex mutations
4. **Never import Node.js built-ins** in `convex/` files
5. **Never assume all fields exist** during mid-call webhook handlers
6. **Never code against an API field** without testing in the provider's explorer first
7. **Never apply user-configured colors** without checking luminance contrast
8. **Never gate downstream actions** on unsaved form state
9. **Never share themes** between admin and tenant contexts
10. **Never let a component exceed 500 lines** without extracting
11. **Never assume a single field name** for third-party API responses
12. **Never hardcode prices** when a pricing config table exists
