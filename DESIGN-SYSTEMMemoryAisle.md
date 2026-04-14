# MemoryAisle Design System

Hand this file to Claude Code. It contains every color, token, and rule needed to build `Theme.swift`, `GlassCard.swift`, and all design system components in SwiftUI.

---

## Color Palette

### Backgrounds

| Token | Value | Usage |
|-------|-------|-------|
| `background.primary` | `#0A0914` | App background, base canvas |
| `background.glass` | `rgba(167,139,250,0.04)` | Cards, tiles, containers |
| `background.glassElevated` | `rgba(167,139,250,0.07)` | Mira cards, active states, elevated panels |
| `background.tabBar` | `rgba(167,139,250,0.03)` | Tab bar surface |

### Borders

| Token | Value | Usage |
|-------|-------|-------|
| `border.subtle` | `rgba(167,139,250,0.08)` | Default card borders, dividers |
| `border.medium` | `rgba(167,139,250,0.14)` | Elevated card borders, Mira cards |
| `border.strong` | `rgba(167,139,250,0.25)` | Buttons, focus rings, interactive edges |
| `border.tabBar` | `rgba(167,139,250,0.06)` | Tab bar top edge |

All borders are 0.5px. No exceptions.

### Text

| Token | Value | Usage |
|-------|-------|-------|
| `text.primary` | `#FFFFFF` | Headlines, numbers, meal names |
| `text.secondary` | `rgba(255,255,255,0.5)` | Body text, Mira messages |
| `text.tertiary` | `rgba(255,255,255,0.25)` | Labels, section headers, meta |
| `text.hint` | `rgba(255,255,255,0.12)` | Disabled states, placeholders |

### Accent: Violet

| Token | Value | Usage |
|-------|-------|-------|
| `violet.primary` | `#A78BFA` | Mira identity, active tab icon, CTA fills, scan button stroke |
| `violet.muted` | `rgba(167,139,250,0.15)` | Scan button background, hover/pressed states, secondary actions |
| `violet.ghost` | `rgba(167,139,250,0.5)` | Wordmark "MEMORYAISLE", section labels |
| `violet.subtle` | `rgba(167,139,250,0.08)` | Chip backgrounds, inactive controls |

### Semantic: Success (Green)

| Token | Value | Usage |
|-------|-------|-------|
| `green.text` | `#34D399` | Positive deltas, "on track", "gentle" badge text |
| `green.bg` | `rgba(52,211,153,0.06)` | Badge/pill background |
| `green.border` | `rgba(52,211,153,0.12)` | Badge/pill border |
| `green.dot` | `rgba(107,143,113,0.5)` | Streak dots (active days) |

### Semantic: Warning (Amber)

| Token | Value | Usage |
|-------|-------|-------|
| `amber.text` | `#FBBF24` | Behind target, low protein alert text |
| `amber.bg` | `rgba(251,191,36,0.08)` | Warning badge/pill background |
| `amber.border` | `rgba(251,191,36,0.15)` | Warning badge/pill border |

### Semantic: Danger (Red)

| Token | Value | Usage |
|-------|-------|-------|
| `red.text` | `#F87171` | Missed goals, scan warnings text |
| `red.bg` | `rgba(248,113,113,0.08)` | Danger badge/pill background |
| `red.border` | `rgba(248,113,113,0.15)` | Danger badge/pill border |

---

## Mira Identity

Mira's visual mark is five vertical bars in an ascending/descending center pattern. This is locked and final.

### Specification

- 5 bars, each 3px wide, 1.5px corner radius
- Gap between bars: 2.5px
- Bar heights (bottom-aligned): 6px, 12px, 20px, 12px, 6px
- Color: `#A78BFA` (violet.primary) on dark backgrounds
- Container: circle, background `rgba(167,139,250,0.08)`, border `0.5px solid rgba(167,139,250,0.15)`
- Container sizes: 56px (large/onboarding), 32px (cards), 28px (inline/tab bar)

### Sizes

| Context | Container | Bar heights |
|---------|-----------|-------------|
| Onboarding intro | 80px circle | 8, 16, 24, 16, 8 |
| Home Mira card | 32px circle | 4, 8, 13, 8, 4 |
| Tab bar icon | no circle | 4, 8, 12, 8, 4 |
| Chat avatar | 32px circle | 4, 8, 13, 8, 4 |

### Rules

- No face. No orb. No glow. No animation on the bars at rest.
- Bars may animate (equalizer-style) only when Mira is actively speaking via voice.
- The four-point star appears alongside bars in the splash/loading screen only, not in the UI.

---

## Typography

| Style | Font | Size | Weight | Usage |
|-------|------|------|--------|-------|
| Headline | SF Pro Display | 28px | 500 (medium) | Main greeting, hero text |
| Title | SF Pro Display | 22px | 500 | Section headers when needed |
| Body | SF Pro Text | 15px | 400 (regular) | Mira messages, descriptions |
| Body bold | SF Pro Text | 15px | 500 | Inline emphasis within body |
| Caption | SF Pro Text | 13px | 400 | Meal meta, timestamps |
| Label | SF Pro Text | 11px | 500 | Section labels, pill text |
| Micro | SF Pro Text | 10px | 500 | PROTEIN, CALORIES, letter-spaced labels |
| Data | SF Mono | 22px | 500 | Numeric values (protein, calories, weight) |
| Data small | SF Mono | 15px | 500 | Secondary numbers |

Letter spacing on labels (micro/label): 0.8px to 1.5px.
Tabular figures always on for all numeric displays.

---

## Spacing and Radius

| Token | Value | Usage |
|-------|-------|-------|
| `radius.card` | 22px | Glass cards, Mira insight card |
| `radius.button` | 24px | Action buttons, pills, chips |
| `radius.avatar` | 50% | User avatar, Mira dot, streak dots |
| `radius.mealThumb` | 14px | Meal image/icon container |
| `padding.screen` | 28px | Left/right screen padding |
| `padding.card` | 20px | Internal card padding |
| `gap.cards` | 10px | Between sibling cards |
| `gap.sections` | 20px | Between major sections |
| `border.width` | 0.5px | All borders, everywhere |

---

## Components

### Glass Card (default)

```
background: rgba(167,139,250,0.04)
border: 0.5px solid rgba(167,139,250,0.08)
border-radius: 22px
padding: 20px
```

### Glass Card Elevated (Mira cards, active)

```
background: rgba(167,139,250,0.07)
border: 0.5px solid rgba(167,139,250,0.14)
border-radius: 22px
padding: 20px
```

### Action Button (primary/filled)

```
background: #A78BFA
border: none
border-radius: 24px
padding: 10px 18px
text: #0A0914 (or #FEFDFB depending on contrast)
font: 13px / 500
```

### Action Button (ghost)

```
background: rgba(167,139,250,0.04)
border: 0.5px solid rgba(167,139,250,0.08)
border-radius: 24px
padding: 10px 18px
text: rgba(255,255,255,0.5)
font: 13px / 400
```

### Pill Badge

```
background: rgba(52,211,153,0.06)  // or amber/red variant
border: 0.5px solid rgba(52,211,153,0.12)
border-radius: 20px
padding: 4px 10px
text: #34D399 at 11px
```

### Streak Dot

```
size: 8px circle
active: rgba(107,143,113,0.5)
inactive: rgba(139,115,85,0.12) or rgba(167,139,250,0.12)
```

### Scan Button (tab bar center)

```
size: 48px circle
background: rgba(167,139,250,0.15)
border: 0.5px solid rgba(167,139,250,0.3)
icon: barcode scanner, stroke #A78BFA, 1.5px
```

### Tab Bar

```
background: rgba(167,139,250,0.03)
border-top: 0.5px solid rgba(167,139,250,0.06)
padding: 10px horizontal, 28px bottom (safe area)
active icon/text: #A78BFA
inactive icon/text: rgba(255,255,255,0.25)
```

### Medication Cycle Bar

```
container: glass card style, padding 14px 20px
label: "MOUNJARO 5MG" in text.tertiary, micro style
value: "Day 3 of 7" in text.primary, 13px/500
progress: 7 segments, 16px wide, 3px tall, 2px radius
  filled: rgba(107,143,113,0.4)
  empty: rgba(167,139,250,0.08)
```

For non-GLP-1 users, this slot becomes a "Weekly Goal" card instead:
```
label: "WEEKLY GOAL" in text.tertiary
value: "Lose 0.5 lbs/week" in text.primary
status: "On track" in green.text + green dot
```

### Meal Card

```
container: glass card, padding 16px 20px
thumbnail: 44px square, 14px radius, background rgba(167,139,250,0.04)
title: text.primary, 14px/500
meta: text.tertiary, 12px/400
"gentle" badge: green pill (GLP-1 users only)
chevron: rgba(139,115,85,0.15) or rgba(167,139,250,0.15), 14px
```

### Body Composition Card

```
container: glass card
section label: "BODY COMPOSITION" in text.tertiary
stat value: text.primary, 15px/500 SF Mono
stat label: text.hint, 9px/500 letter-spaced
delta: green.text for positive, red.text for negative
mini sparkline: violet stroke 1.5px (weight), green stroke 1px (lean mass)
```

---

## Home Screen Layout (top to bottom)

1. **Header bar**: wordmark left ("MEMORYAISLE" in violet.ghost, 11px, 2px letter-spacing), avatar circle right
2. **Greeting block**: centered, time-of-day greeting in text.tertiary (14px), headline in text.primary (28px/500), accent word in violet.primary
3. **Streak**: centered row of 7 dots + label
4. **Mira insight card**: glass elevated, Mira avatar + name + message + action buttons
5. **Glance tiles**: 3-column row (protein, calories, weight) in glass cards
6. **Tonight's meal**: single meal card row
7. **Body composition**: glass card with lean mass + body fat + sparkline
8. **Medication cycle** (GLP-1) or **Weekly goal** (general): slim info bar
9. **Tab bar**: Home, Meals, Scan (center floating), Mira, Progress

---

## Adaptive Behavior

### GLP-1 User vs General User

| Element | GLP-1 | General |
|---------|-------|---------|
| Mira language | References cycle, stomach, side effects | References wins, streaks, goals |
| Meal badge | Shows "gentle" green pill | No badge |
| Action chips | "Sounds good" / "Show me options" / "I already ate" | "Sounds good" / "Swap it" / "I'm eating out" |
| Slot 8 | Medication cycle bar (drug, dose, day X of Y) | Weekly goal card (target, on-track status) |
| Body comp emphasis | Lean mass preservation (primary concern) | General fat loss progress |

### Time of Day

| Time | Greeting | Mira tone |
|------|----------|-----------|
| 5am to 12pm | "Good morning" | Forward-looking (today's plan) |
| 12pm to 5pm | "Good afternoon" | Mid-day check-in (how's it going) |
| 5pm to 10pm | "Good evening" | Closing the day (what's left) |
| 10pm to 5am | "Late night" | Gentle (rest, tomorrow's a new day) |

---

## Reflection Page

Reflection is the soul of MemoryAisle. It is NOT a dashboard, NOT a check-in screen, NOT a logging tool. It is a results-driven scrapbook that plays your journey back to you. Every moment is auto-collected from the rest of the app (Home, Meals, Scan, Mira). The user does not input anything on this page. They come here to see how far they've come.

Reflection is a separate full page, not a tab replacement. It lives in the nav bar as the 5th tab, replacing Progress. The tab label is "Reflect" with a pencil/journal icon.

### Page Structure (top to bottom)

#### 1. Header
- Wordmark "MEMORYAISLE" left, avatar right (same as Home)

#### 2. Section Label + Headline
- "REFLECTION" in `violet.ghost` (11px, 1.5px letter-spacing)
- "Look how far you've come." in `text.primary` (24px/500)

#### 3. Day 1 vs Today Photo Comparison (the hero)
- Two side-by-side photos in a flex row with 8px gap
- Each photo: `aspect-ratio: 3/4`, `border-radius: 16px`
- Left photo: user's first-ever photo, labeled "DAY 1" with starting weight and date
- Right photo: user's most recent photo, labeled "TODAY" in `violet.primary` with current weight and date
- Photo overlay at bottom: semi-transparent dark bar (`rgba(10,9,20,0.7)`) with label, weight, date
- Left card: `background.glass` + `border.subtle`
- Right card: `background.glassElevated` + `border.medium` (slightly more prominent)
- No AI analysis text. The photos speak for themselves.

#### 4. Transformation Stats
- Centered row below photos, 14px top margin
- Three stats separated by 0.5px vertical dividers (`rgba(167,139,250,0.08)`)
- Stat 1: total lbs lost (white, 20px/500), label "LBS" (9px, `text.hint`, 0.8px letter-spacing)
- Stat 2: lean mass gained (`green.text`, 20px/500), label "LEAN"
- Stat 3: total days (white, 20px/500), label "DAYS"

#### 5. Filter Chips
- Horizontal scrollable row: "All moments" (active), "Photos", "Meals", "Gym", "Feelings"
- Chip style: same as Home action chips
- Active chip: `violet.primary` text, `border.strong`, `rgba(167,139,250,0.08)` bg

#### 6. Moments Timeline
- Section label: "YOUR MOMENTS" in `text.hint` (10px, 1px letter-spacing)
- Scrollable list of moment cards, each 10px apart

### Moment Card Types

All moment cards share the same base structure:
```
border-radius: 16px
padding: 16px
margin-bottom: 10px
```

#### Standard Moment (protein streak, gym day, general)
```
background: rgba(167,139,250,0.04)
border: 0.5px solid rgba(167,139,250,0.08)
```
- Top row: week + date label in `violet.ghost` (10px), optional badge on right
- Title: `text.primary` (14px/500)
- Description: `text.tertiary` (12px/400, line-height 1.5)
- User's own words in quotes when available

#### Moment with Photo (meals, gym selfies, grocery runs)
- Same card as standard
- Photo placeholder: `aspect-ratio: 4/3`, `border-radius: 12px`, `background.glass` + `border.subtle`
- Photo sits above title, 10px margin-bottom
- Caption below: meal name or user's note
- Macro data as quiet footnote: 10px, `text.hint`

#### Milestone Moment (first 5 lbs, first 10 lbs, streaks)
```
background: rgba(52,211,153,0.03)
border: 0.5px solid rgba(52,211,153,0.08)
```
- Green-tinted card
- Badge: "milestone" pill in `green.text` on `green.bg` with `green.border`

#### Tough Day Moment (nausea, low calories, hard days)
```
background: rgba(251,191,36,0.03)
border: 0.5px solid rgba(251,191,36,0.08)
```
- Amber-tinted card
- Badge: "tough day" pill in `amber.text` on `amber.bg` with `amber.border`
- These exist because the hard moments are part of the journey too

#### Personal Best Moment
- Standard violet card
- Badge: "personal best" pill in `green.text` on `green.bg` with `green.border`

### Badge Pill Component
```
padding: 3px 10px
border-radius: 12px
font-size: 10px
```
Variants:
- milestone: `green.bg` / `green.border` / `green.text`
- tough day: `amber.bg` / `amber.border` / `amber.text`
- personal best: `green.bg` / `green.border` / `green.text`

### Data Source Rules

Reflection does NOT have any input forms, text fields, or add buttons. All moments are auto-generated from data already captured elsewhere in the app:

| Moment type | Source |
|-------------|--------|
| Protein streaks | Home daily tracking |
| Meal moments | Meals tab (user-saved meals with photos) |
| Gym days | User-logged activity (from Mira chat or Home) |
| Feelings | Mira conversations where user mentioned how they feel |
| Weigh-ins | Weekly weigh-in prompt (triggered from Home, stored here) |
| Milestones | Auto-calculated (every 5 lbs lost, streak records, etc.) |
| Tough days | Days where calories were very low, nausea reported, or protein missed |
| Photos | Any photo the user took anywhere in the app |
| Grocery runs | Scan history (first scan, notable scans) |

Mira can also auto-generate moment cards by recognizing patterns: "You made lemon herb chicken 4 times this month" or "This was your first gym session in 2 weeks."

### What Makes This Page Different From Every Competitor

1. The user does NOTHING here. It's all auto-generated. They just scroll and remember.
2. Good AND bad moments are shown. The tough days make the wins feel real.
3. The Day 1 vs Today photo comparison is always at the top. Every time they open Reflection, they see the transformation.
4. User's own words (from Mira conversations, meal notes, etc.) are quoted back to them in their moment cards.
5. No charts, no graphs, no rings, no dashboards. Just moments, photos, and feelings.

### Nav Bar Update

The 5th tab changes from "Progress" to "Reflect":
- Icon: pencil/journal (SF Symbol: `square.and.pencil` or similar)
- Label: "Reflect"
- Active color: `violet.primary` (#A78BFA)
- Inactive color: `rgba(255,255,255,0.22)`

---

## What This File Does NOT Cover

- Onboarding flow (separate spec)
- Mira chat interface (separate spec)
- Scan result screen (separate spec)
- Meals planner (separate spec)
- Light mode (not shipping in v1)
- Animation/motion spec (future)

This file covers the Home screen design system and the Reflection page. Build `Theme.swift` and components from this, then the Home screen view, then Reflection.
