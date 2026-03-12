# V0 Design Patterns Library

When building any frontend UI, apply these professional-grade patterns extracted from 10 v0 projects. Layer multiple subtle effects for high-end results — never ship flat, unstyled, or "default Tailwind" looking interfaces.

---

## 1. ANIMATION TECHNIQUES

### Framer Motion Patterns

**Scroll-triggered reveal (most common pattern):**
```tsx
<motion.div
  initial={{ opacity: 0, y: 20, scale: 0.98 }}
  whileInView={{ opacity: 1, y: 0, scale: 1 }}
  viewport={{ once: true }}
  transition={{ duration: 0.8, ease: [0.33, 1, 0.68, 1], delay }}
/>
```
- Easing: `[0.33, 1, 0.68, 1]` (deceleration curve) or `[0.22, 1, 0.36, 1]`
- Stagger children with `staggerChildren: 0.1`, `delayChildren: 0.3`

**Tab/page transitions with AnimatePresence:**
```tsx
<AnimatePresence mode="wait">
  <motion.div
    key={activeTab}
    initial={{ opacity: 0, y: 10 }}
    animate={{ opacity: 1, y: 0 }}
    exit={{ opacity: 0, y: -10 }}
    transition={{ duration: 0.2 }}
  />
</AnimatePresence>
```

**Card hover interactions:**
```tsx
whileHover={{ scale: 1.02, y: -5 }}
whileTap={{ scale: 0.98 }}
```

**Morphing gradient backgrounds (30s infinite loop):**
```tsx
<motion.div
  className="absolute inset-0 -z-10 opacity-20"
  animate={{
    background: [
      "radial-gradient(circle at 50% 50%, rgba(120,41,190,0.5) ...)",
      "radial-gradient(circle at 30% 70%, rgba(233,30,99,0.5) ...)",
      "radial-gradient(circle at 70% 30%, rgba(76,175,80,0.5) ...)",
    ],
  }}
  transition={{ duration: 30, repeat: Infinity, ease: "linear" }}
/>
```

**InfiniteSlider (marquee) with hover-to-slow:**
Uses `framer-motion` `animate()` API + `react-use-measure` for continuous linear loop.

### CSS Keyframe Animations

**Character entrance with blur dissolve:**
```css
@keyframes char-in {
  0% { opacity: 0; filter: blur(40px); transform: translateY(100%); }
  100% { opacity: 1; filter: blur(0); transform: translateY(0); }
}
```
Apply per-character with staggered `animationDelay: i * 50ms`.

**Fade-in-up with blur:**
```css
@keyframes fade-in-up {
  0% { opacity: 0; transform: translateY(24px); filter: blur(8px); }
  100% { opacity: 1; transform: translateY(0); filter: blur(0px); }
}
```

**Shine sweep effect (on bento cards):**
```css
@keyframes shine {
  0% { transform: translateX(-100%) skewX(-12deg); }
  100% { transform: translateX(200%) skewX(-12deg); }
}
```
```tsx
<div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent
  transform -skew-x-12 -translate-x-full animate-[shine_4s_ease-in-out_infinite] w-[200%]" />
```

**Line reveal with clip-path:**
```css
@keyframes line-reveal {
  from { clip-path: inset(0 100% 0 0); }
  to { clip-path: inset(0 0 0 0); }
}
```

**Wandering gradient blobs (CSS custom property driven):**
```css
@keyframes background-gradient {
  0%, 100% { transform: translate(0, 0); }
  20% { transform: translate(calc(100% * var(--tx-1)), calc(100% * var(--ty-1))); }
  /* ... more stops with randomized --tx/--ty vars */
}
```

**Custom spin speeds:**
```css
animate-spin-slow: "spin-slow 3s linear infinite"
animate-spin-slower: "spin-slower 6s linear infinite" /* reverse direction */
```

**Marquee scrolling:**
```css
@keyframes marquee { 0% { transform: translateX(0); } 100% { transform: translateX(-50%); } }
@keyframes marquee-reverse { 0% { transform: translateX(-50%); } 100% { transform: translateX(0); } }
```

### CSS Transition Patterns

**Hover lift with overshoot:**
```css
transition: transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
&:hover { transform: translateY(-4px); }
```

**Price toggle blur-scale crossfade:**
```tsx
style={{
  opacity: isActive ? 1 : 0,
  transform: `scale(${isActive ? 1 : 0.8})`,
  filter: `blur(${isActive ? 0 : 4}px)`,
}}
className="transition-all duration-500"
```

**Accordion expand/collapse:**
```tsx
className={cn(
  "overflow-hidden transition-all duration-200",
  isExpanded ? "mt-3 max-h-40 opacity-100" : "max-h-0 opacity-0"
)}
```

### Canvas/JS Animations

**Particle system on canvas** (100 particles, requestAnimationFrame):
- Random sizes 1-3px, slow drift speeds
- Color range: `rgba(100-200, 150-250, 200-255, 0.2-0.7)` (blue-tinted)
- Canvas at `opacity-30` behind UI

**Canvas particle text effect:**
- Render text to offscreen canvas, read pixel data, spawn particles at opaque pixels
- Steering behavior (velocity/acceleration/max-force) to seek target positions
- Motion blur via semi-transparent overlay each frame
- Word cycling every ~4 seconds

**ASCII 3D objects on Canvas 2D:**
- Rotating sphere/tetrahedron using Unicode block chars (`░▒▓█▀▄▌▐│─`)
- Depth-sorted with alpha mapping

**Eased number counter:**
```tsx
const eased = 1 - Math.pow(1 - progress, 3); // cubic ease-out
setCount(Math.floor(eased * end));
```

### SVG Animations

**Animated stroke-dashoffset paths:**
- Procedurally generate Bezier curves with random dash/gap/duration/delay
- Dynamic `@keyframes travelPath-N` per path via styled-jsx

**SMIL `<animate>` on SVG elements:**
- Pulsing opacity/radius, expanding bars, animated dashoffsets
- `<animateMotion>` with `<mpath>` for objects traveling along paths

### DOM-Measured Sliding Indicators

**Tab indicator that follows hover/active state:**
```tsx
useEffect(() => {
  const el = tabRefs.current[hoveredIndex]
  setHoverStyle({ left: `${el.offsetLeft}px`, width: `${el.offsetWidth}px` })
}, [hoveredIndex])
```
Two layers: translucent rounded-rect hover follower + sharp 2px underline for active.

---

## 2. VISUAL EFFECTS

### Glassmorphism
```tsx
// Header
className="bg-background/80 backdrop-blur-xl border-border/40 sticky top-0 z-50"
// Cards
className="bg-white/80 backdrop-blur border-0 shadow-lg"  // light theme
className="bg-slate-900/50 border-slate-700/50 backdrop-blur-sm"  // dark/cyber theme
style={{ background: "rgba(231,236,235,0.08)", backdropFilter: "blur(4px)" }}  // SaaS dark
```

### Noise/Grain Overlays

**SVG feTurbulence filter:**
```tsx
<filter id="noise">
  <feTurbulence baseFrequency="0.4" numOctaves="2" type="fractalNoise" />
  <feColorMatrix type="saturate" values="0" />
  <feComponentTransfer><feFuncA type="discrete" tableValues="0.02 0.04 0.06" /></feComponentTransfer>
  <feComposite operator="over" in2="SourceGraphic" />
</filter>
```

**CSS pseudo-element noise:**
```css
.noise-overlay::after {
  background-image: url("data:image/svg+xml,...feTurbulence baseFrequency='0.9' numOctaves='4'...");
  opacity: 0.03;
  pointer-events: none;
}
```

### Ambient Glow Effects

**Blurred glow orbs:**
```tsx
<div className="absolute -bottom-6 -right-6 h-16 w-16 rounded-full
  bg-gradient-to-r from-cyan-500 to-blue-500 opacity-20 blur-xl" />
```

**Pulsing glow orbs (staggered):**
```tsx
<div className="absolute w-96 h-96 bg-blue-500/10 rounded-full blur-3xl animate-pulse" />
<div className="... bg-purple-500/10 ..." style={{ animationDelay: "1s" }} />
<div className="... bg-cyan-500/10 ..." style={{ animationDelay: "2s" }} />
```

**Large ambient blur:**
```tsx
<div className="bg-primary/10 blur-[130px] rotate-12" />  // behind bento/FAQ sections
```

### Progressive Blur
Layered `backdropFilter: blur()` with gradient masks creating smooth blur-to-clear edge transitions on marquee/slider edges.

### Text Effects

**Gradient text:**
```tsx
className="bg-gradient-to-r from-pink-500 via-purple-600 to-teal-500 bg-clip-text text-transparent"
```

**Text stroke (outlined):**
```css
-webkit-text-stroke: 1.5px currentColor;
-webkit-text-fill-color: transparent;
```

### Dot Pattern Overlays
```tsx
backgroundImage: `radial-gradient(circle at 25% 25%, rgba(255,255,255,0.05) 1px, transparent 1px),
                   radial-gradient(circle at 75% 75%, rgba(255,255,255,0.03) 1px, transparent 1px)`,
backgroundSize: "48px 48px, 64px 64px",
```

### Multi-Layer Box Shadows (Physical Depth)
```tsx
boxShadow: "0px 26px 7px rgba(0,0,0,0), 0px 17px 6px rgba(0,0,0,0.01),
  0px 9px 6px rgba(0,0,0,0.05), 0px 4px 4px rgba(0,0,0,0.09), 0px 1px 2px rgba(0,0,0,0.1)"
```

### Mouse-Following Spotlight
```tsx
style={{
  background: `radial-gradient(600px circle at ${mouseX}% ${mouseY}%, rgba(0,0,0,0.15), transparent 40%)`
}}
```

### Multi-Ring Loading Spinner
5 concentric rings at different `inset` levels, each showing one colored border side, spinning at different speeds/directions (using `animate-spin`, `animate-spin-slow`, `animate-spin-slower`).

### Sketch/Dashed Borders
```css
.border-sketch {
  background: linear-gradient(var(--background), var(--background)) padding-box,
    linear-gradient(135deg, var(--foreground) 25%, transparent 25%, transparent 50%,
    var(--foreground) 50%, var(--foreground) 75%, transparent 75%) border-box;
  background-size: 100% 100%, 8px 8px;
}
```

### SVG Hero Grid Backgrounds
Programmatic dashed grid (35x22 cells, `strokeDasharray="2 2"`) with layered gradient blobs using `fegaussianblur`, `feBlend`, and blend modes (`lighten`, `overlay`).

---

## 3. COLOR SCHEMES

### Monochrome Dark (SaaS/Developer)
- Background: `#000000` or `oklch(0.985 0.002 90)` (warm cream)
- Foreground: `#ffffff`
- Card: `#1a1a1a`
- Borders: `rgba(255,255,255,0.08)`
- Accent at very low opacity only (blue/purple/cyan at 2-10%)

### Dark + Mint/Teal Accent
- Background: `hsl(210 11% 7%)` -- near-black with green tint
- Primary: `hsl(165 96% 71%)` -- bright mint `#78fcd6`
- All hierarchy via foreground opacity variations

### Cyberpunk Dark (NEXUS OS)
- `from-black to-slate-900` background
- Cyan-400/500 primary accent
- Purple-500/pink-500 for memory
- Green-400/500 for security/positive
- Amber-500 for warnings

### Pink-Purple-Teal (Feminine/Community)
- Page: `bg-gradient-to-br from-pink-50 via-purple-50 to-teal-50`
- CTAs: `bg-gradient-to-r from-pink-500 to-purple-600`
- Brand text: `from-pink-500 via-purple-600 to-teal-500 bg-clip-text text-transparent`

### Multi-Gradient Creative (per-section identity)
- Home: `from-violet-600 via-indigo-600 to-blue-600`
- Apps: `from-pink-600 via-red-600 to-orange-600`
- Files: `from-teal-600 via-cyan-600 to-blue-600`
- Projects: `from-purple-600 via-violet-600 to-indigo-600`

### OKLCH-Based Design Tokens
```css
--primary: oklch(0.45 0.18 255);  /* deep blue */
--accent: oklch(0.62 0.19 145);   /* vivid green */
```

### Alpha Channel Hex Colors (Subtle Transparency)
`#0e0f1114` (8% black), `#ffffff1a` (10% white), `#0e0f1199` (60% black) -- more precise than Tailwind opacity utilities.

---

## 4. TYPOGRAPHY PATTERNS

### Font Stacks
- **Primary sans**: Geist Sans, Inter, or Instrument Sans
- **Monospace**: Geist Mono, JetBrains Mono
- **Display/Serif**: Playfair Display, Instrument Serif (for headlines only)

### Heading Scale
- Hero: `text-[clamp(3rem,12vw,10rem)]` or `text-5xl md:text-6xl font-bold`
- Section: `text-3xl md:text-4xl lg:text-6xl font-semibold`
- Card title: `text-lg font-semibold` or `text-base font-semibold`
- Body: `text-sm` (14px) as workhorse size
- Meta/labels: `text-xs text-muted-foreground`

### Eyebrow Label Pattern
```tsx
<span className="inline-flex items-center gap-3 text-sm font-mono text-muted-foreground mb-6">
  <span className="w-8 h-px bg-foreground/30" />
  Section Label
</span>
```

### Numeric Display
- `tabular-nums` for aligned numbers
- `font-mono` for stats, counts, system values

---

## 5. SPACING & LAYOUT

### Container Patterns
- `max-w-[1400px] mx-auto px-6 lg:px-12` (SaaS landing)
- `container mx-auto px-4` (app pages)
- `max-w-7xl mx-auto px-4 lg:px-6` (dashboards)

### Section Spacing
- Between sections: `py-20 px-4` or `py-24 lg:py-32`
- Within sections: `space-y-8` major, `space-y-4` minor
- Card grids: `gap-6` standard, `gap-8` for pricing

### Responsive Grids
- Cards: `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4`
- Bento: `grid-cols-1 md:grid-cols-3 gap-6` with `col-span-2`/`col-span-3`
- Dashboard: 12-column CSS grid with responsive `col-span-*`

### Container Queries (shadcn v4)
```tsx
<div className="@container/main">
  <div className="@xl/main:grid-cols-2 @5xl/main:grid-cols-4" />
</div>
```

### gap-px Border Grid Technique
```tsx
<div className="gap-px bg-foreground/10">
  <div className="bg-background p-6">Cell</div>
</div>
```
Creates 1px borders between grid cells without explicit borders.

---

## 6. COMPONENT COMPOSITION PATTERNS

### Slot-Based Data Attributes (shadcn v4)
```tsx
*:data-[slot=card]:bg-gradient-to-t
**:data-[slot=select-value]:block
```

### Compound Component Systems
```
FieldGroup > FieldSet > Field > [FieldLabel, FieldContent, FieldError]
ItemGroup > Item > [ItemMedia, ItemContent, ItemActions]
InputGroup > [InputGroupInput, InputGroupAddon]
Empty > EmptyHeader > [EmptyMedia, EmptyTitle] + EmptyContent
```

### Consistent Page Shell (App Pages)
```tsx
<div className="min-h-screen bg-gradient-to-br from-pink-50 via-purple-50 to-teal-50">
  <header className="bg-white/80 backdrop-blur border-b sticky top-0 z-50">
    <div className="container mx-auto px-4 py-4">{/* nav */}</div>
  </header>
  <main className="container mx-auto px-4 py-8">{/* content */}</main>
</div>
```

### Icon Badge Pattern
```tsx
<div className="w-12 h-12 bg-gradient-to-r from-X to-Y rounded-xl flex items-center justify-center">
  <Icon className="w-6 h-6 text-white" />
</div>
```

### Choice Card (Selected State)
```tsx
"has-data-[state=checked]:bg-primary/5 has-data-[state=checked]:border-primary"
```

### Transparent Inline-Editable Inputs
```tsx
className="hover:bg-input/30 focus-visible:bg-background h-8 border-transparent
  bg-transparent shadow-none focus-visible:border"
```

### Navigation Morph on Scroll
Nav bar shrinks height, gains backdrop-blur + border + shadow + rounded corners, insets from viewport edges.

### Inverted Section
```tsx
className="bg-foreground text-background" // dark section in light page
```

---

## 7. LIBRARIES TOOLKIT

### Animation
- `framer-motion` -- scroll reveals, page transitions, hover effects, infinite rotation, gradient morphing
- `tailwindcss-animate` or `tw-animate-css` -- Tailwind animation plugin
- `react-use-measure` -- DOM measurement for slider/marquee components

### Data/Tables
- `@tanstack/react-table` -- headless table with sorting, filtering, pagination
- `@dnd-kit/core` + `@dnd-kit/sortable` -- drag-and-drop row reordering
- `recharts` -- area/bar charts with SVG gradients

### UI Primitives
- `cmdk` -- command palette
- `vaul` -- drawer/bottom sheet
- `sonner` -- toast notifications
- `input-otp` -- OTP input
- `embla-carousel-react` -- carousel
- `react-resizable-panels` -- resizable panels

### Icons
- `lucide-react` -- primary icon set
- `@tabler/icons-react` -- alternative icon set

### Forms
- `react-hook-form` + `@hookform/resolvers` + `zod` -- form validation

### Backend
- `@supabase/ssr` + `@supabase/supabase-js` -- auth + database
- `ai` + `@ai-sdk/react` -- Vercel AI SDK for streaming chat

### Theming
- `next-themes` -- dark/light mode
- `geist` -- font package

---

## 8. KEY DESIGN PRINCIPLES

1. **Layer effects at low opacity** -- noise at 3%, glow orbs at 10-20%, particle canvas at 30%
2. **Combine multiple subtle effects** rather than one obvious one (noise + glassmorphism + glow + gradient)
3. **Use CSS transitions for micro-interactions**, Framer Motion for orchestrated reveals
4. **Monospace for system/meta text**, serif for display headlines, sans for everything else
5. **Rounded design language**: `rounded-2xl` cards, `rounded-xl` buttons, `rounded-full` avatars
6. **Gradient text for brand identity** via `bg-clip-text text-transparent`
7. **Semi-transparent white layers** (`bg-white/10` through `bg-white/50`) for depth on dark backgrounds
8. **Stagger all entrance animations** with 50-100ms delays per item
9. **Custom easing curves** -- never use default linear. Use `[0.33, 1, 0.68, 1]` for reveals, `cubic-bezier(0.34, 1.56, 0.64, 1)` for bouncy hover
10. **Container queries** for truly responsive components (not just viewport breakpoints)
