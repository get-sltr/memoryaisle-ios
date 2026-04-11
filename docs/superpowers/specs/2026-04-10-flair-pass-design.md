# MemoryAisle Flair Pass — Design Spec

**Date:** 2026-04-10
**Branch target:** `feature/flair-pass` (branched from `dev`)
**Owner:** Kevin Minn
**Status:** Draft — awaiting review

## Problem

Every surface, border, card, and button in MemoryAisle is violet-on-violet. The `Theme.swift` file defines rich semantic colors (water, fiber, protein, onTrack, warning) but almost none of them reach the UI at the surface or section level — they're reserved for small indicator moments. The result is that every tab reads as the same lilac wash, with no visual hierarchy between passive cards, interactive cards, and hero elements. Users cannot tell pages apart at a glance, and the app feels flat, monotone, and undifferentiated.

The pain is sharpest on Scanner, Grocery List, Recipes, Smart Calendar, and Pantry — these are the pages the solo founder explicitly flagged as "plain" and needing "flair." Every other page also needs lift, but to a lesser degree.

## Goals

1. Kill the mono-violet wash by introducing a category color system — each major feature gets a signature hue that appears on its hero header, stat tiles, borders, and accent chips.
2. Keep violet as the brand anchor so the redesign reads as an enhancement, not a rebrand.
3. Modernize every button, close affordance, dismiss affordance, and frame so the app feels like one cohesive system rather than 15 screens glued together.
4. Add one "wow" moment per page via animated mesh gradients reserved for hero headers and Mira's chat surface, without draining battery.
5. Ship without breaking any existing view — the migration is backward-compatible and phased.

## Non-Goals

- Typography scale changes (keep `Typography.swift` as-is).
- SwiftData model/schema changes.
- MiraEngine prompt or Bedrock integration changes.
- Service math (ProteinCalculator, GIToleranceEngine, etc.).
- CDK / Lambda / Cognito / Info.plist / entitlements.
- Onboarding flow logic — only its visual skin.
- New Swift package dependencies.

## Design Direction

**Hybrid: Spectrum + Aurora.** Each major section gets a signature hue (Spectrum); hero headers and Mira's chat surface additionally get an animated mesh gradient (Aurora). Everything else stays calm pastel glass for content readability.

**Saturation rule:** Bold saturation for hero headers and stat tiles (entry moments); pastel glass for list rows, inline cards, and secondary surfaces (content).

## Section Color System

| Section | Base hue | Hex | Use |
|---|---|---|---|
| Home / Today | Violet (existing) | `#A78BFA` | brand anchor |
| Pantry | Emerald | `#10B981` | fresh food, inventory |
| Recipes | Amber | `#F59E0B` | warmth, cooking |
| Scanner | Cyan | `#06B6D4` | tech, verdicts, scan light |
| Grocery | Sky | `#0EA5E9` | lists, checkouts |
| Calendar | Rose | `#F472B6` | time, social, events |
| Progress | Lime | `#84CC16` | growth, body comp |
| Mira | Aurora (violet+cyan+rose mesh) | — | animated |

Each section exposes four tones, all adaptive to color scheme:

- `hero(for:)` — bold mesh gradient for hero headers
- `tile(for:)` — bold radial glow for stat tiles
- `glass(for:)` — pastel tinted glass for list rows
- `border(for:)` — pastel tinted border at 0.22 opacity for content, 0.35 for tiles
- `text(for:)` — readable label color on dark and light backgrounds

## Architecture

### New file: `DesignSystem/SectionPalette.swift`

Defines:

```swift
enum SectionID: String, CaseIterable, Sendable {
    case home, pantry, recipes, scanner, grocery, calendar, progress, mira
}

struct SectionStyle: Sendable {
    let id: SectionID
    let hero: (ColorScheme) -> LinearGradient
    let tile: (ColorScheme) -> RadialGradient
    let glass: (ColorScheme) -> Color
    let border: (ColorScheme) -> Color
    let text: (ColorScheme) -> Color
}

extension EnvironmentValues {
    var sectionID: SectionID { get set }  // default: .home
}
```

Views set `.environment(\.sectionID, .pantry)` once on their root, and all nested `StatTile`, `SectionCard`, `HeroHeader`, button components inherit without prop drilling.

### New file: `DesignSystem/MeshGradient.swift`

`MeshGradientView` renders three overlapping radial gradients (primary hue + two accent tones) with a subtle noise overlay. Driven by `TimelineView(.animation)` with an 8-second cycle that interpolates between three anchor positions for each radial gradient center. Cheap on battery — no continuous redraw, just a `.timeInterval` schedule on SwiftUI's animation timeline.

Used only in: `HeroHeader`, `MiraChatView`. Never on list rows or scrollable content.

### New file: `DesignSystem/HeroHeader.swift`

Top-of-page header component, ~220pt tall. Renders a `MeshGradientView` in the section hue as background, places title + subtitle + optional trailing icon button on top. Reads `@Environment(\.sectionID)` to pick its colors.

### New file: `DesignSystem/StatTile.swift`

Bold stat card: number + label + optional sub. Background uses `Theme.Section.tile(for:)` (bold radial glow in section hue), border uses `Theme.Border.glow(section:, scheme:)`. Inherits section from environment or takes an explicit override. Used for the stat row on every dashboard.

### New file: `DesignSystem/SectionCard.swift`

Pastel list-row container. Background uses `Theme.Section.glass(for:)`, 0.5pt border in `Theme.Border.glass(section:, scheme:)`. Replaces ad-hoc rounded rectangles across feature views. The new default for any list row or inline card.

### New file: `DesignSystem/CloseButton.swift`

Universal X. 44×44 tap target, 22×22 visual. Glass circle background with pastel border, SF Symbol `xmark` inside. Haptic light on tap. Accessibility label: "Close". Replaces every ad-hoc `Image(systemName: "xmark")` inside a `Button` across the codebase.

### New file: `DesignSystem/DismissButton.swift`

Back/exit affordance. Chevron-left on a glass pill, same sizing rules as `CloseButton`. Accessibility label: "Back". Replaces ad-hoc dismiss buttons.

### New file: `DesignSystem/IconButton.swift`

Generic circular icon button (search, filter, more, settings). Section-aware. 44×44 tap target, glass background, optional glow border.

### New file: `DesignSystem/SegmentedPill.swift`

Animated segmented control. Matched-geometry effect slides the selection indicator between options. Section-hued fill. Replaces ad-hoc `Picker(.segmented)` usage and custom toggle rows.

### New file: `DesignSystem/ShimmerModifier.swift`

`.shimmer()` view modifier for loading states. Animates a linear gradient highlight across a section-hued base. Replaces plain `ProgressView` for content placeholders (not spinners).

### Modified: `DesignSystem/Theme.swift`

Add `Theme.Section` namespace that wraps `SectionStyle` lookups. Extend `Theme.Surface` and `Theme.Border` with optional `section:` parameter; default of `.home` preserves current violet behavior. Keep all existing APIs working unchanged — migration is opt-in, page by page.

### Modified: `DesignSystem/VioletButton.swift`

Accept optional `section:` parameter. Gradient uses the section's deep + mid tones. Press state gets a brief glow pulse (0.2s ease-out) layered on top of the existing scale + brightness. Public `VioletButton(...)` signature preserved via default argument so no existing call sites break.

### Modified: `DesignSystem/GhostButton.swift`

Picks up section border color. Adds subtle inner shadow on press for physicality.

### Modified: `DesignSystem/GlowButton.swift`

Becomes the "hero CTA" — outer halo glow in section hue, one-shot pulse on appearance. Used sparingly: onboarding finish, scan success, recipe save.

### Modified: `DesignSystem/GlassCard.swift`, `GlassCardStrong.swift`

Section-aware. Pastel tinted glass and border instead of pure violet when a section is provided.

## Per-Page Flair Application

Each page follows the same recipe: `HeroHeader` at top, `StatTile` row beneath, `SectionCard` list content below. Feature-specific flair layered on top.

### Priority 1 — pages the founder flagged

**Scanner** (`ScanView.swift`, `ScanResultView.swift`) — cyan
- Hero: cyan+violet mesh with subtle scan-line sweep animation (top→bottom, 3s cycle)
- Viewfinder: corner brackets animate in on appear (0.3s stagger), cyan glow on detection
- ScanResult: full-bleed verdict banner (green/amber/rose) + bold StatTiles for calories/protein/fiber
- Success: cyan ripple from center + haptic success

**Grocery** (`GroceryListView.swift`) — sky blue
- Hero: sky+violet mesh. "18 items · $64 estimated" in giant type
- Rows: pastel sky `SectionCard`. Checked items cross-fade to 0.4 opacity with sky strikethrough (0.3s)
- Category headers: 2pt sky accent bar on the left, full row height
- FAB: sky `GlowButton` with halo pulse on appearance

**Recipes** (`RecipesView.swift`, `RecipeDetailView.swift`) — amber
- Hero: amber+rose mesh
- Cards: full-bleed 16:9 image, pastel amber body. Protein=violet pill, calories=amber pill
- RecipeDetail: full-screen hero image with amber gradient fade; title overlays the fade; ingredients in pastel amber `SectionCard`s with check-off interactions
- Macros: colored rings (protein=violet, carbs=sky, fat=amber, fiber=lime) replace flat bars

**Smart Calendar** (`CalendarView.swift`, `HolidayCalendar.swift`) — rose
- Hero: rose+violet mesh
- Cells: current day gets rose glow ring + mesh background (only animated cell). Meal-logged = violet dot, symptoms = amber dot, dose = rose dot
- Selected day drawer: slides up from bottom, pastel rose `SectionCard` with day's meals, doses, symptoms
- Holiday rows: subtle rose gradient background

**Pantry** (`PantryView.swift`) — emerald
- Hero: emerald+cyan mesh. "24 items · 3 expiring soon," where the "3 expiring" number is amber (semantic urgency override)
- Rows: pastel emerald `SectionCard`s. Expiration chips: green → amber → rose gradient by days remaining. Staples get a star
- Shelf sections: "Fridge," "Freezer," "Dry goods" as sticky headers with emerald accent bars
- Empty state: emerald `GlowButton` "Scan your pantry" with halo pulse

### Priority 2 — universal treatment

- **Home** — violet mesh hero with user name + next meal; StatTiles for today's protein, water, next dose
- **Meals** — violet mesh hero; meal cards in pastel violet with protein ring
- **Progress** — lime+violet mesh; weight chart gets lime gradient fill under the line
- **Mira Chat** — the only page with the full Aurora mesh (violet+cyan+rose, animated); avatar bars pick up mesh tone as she speaks
- **Profile / Journey** — violet+rose mesh hero; body comp stats as tiles
- **Onboarding** — each step gets a different section hue so progression *feels* like progress. Body stats = violet, dose timing = rose, goals = lime
- **Auth / Legal** — violet mesh hero with logo; pastel cards below

### Repo-wide sweep

- Every `Image(systemName: "xmark")` inside a `Button` → `CloseButton`
- Every `Button { dismiss() } label: { Image(systemName: "chevron.left" or "chevron.backward") }` → `DismissButton`
- Every ad-hoc `RoundedRectangle(...).fill(Color.violet.opacity(0.04))` → `.glassCard()` modifier

## Data Flow

No new data flow. This is a pure visual refactor. Views still drive from the same view models, services, and SwiftData models they do today. The only new piece is a `SectionID` environment value that cascades section context down the view tree.

## Error Handling

Not applicable — no new runtime logic, no network calls, no new failure modes.

## Testing Strategy

- **Previews:** Every new DS component gets a `#Preview` covering dark mode, light mode, and (where section-aware) each `SectionID`.
- **Unit tests:** None required — no new calculation, state machine, or data transformation logic.
- **Manual device testing:** Each priority page verified in dark + light mode at Dynamic Type XXL before merging `feature/flair-pass` → `dev` → `main`. Specifically check: no cropped hero headers, no unreadable text on mesh gradients, battery impact of `MeshGradientView` over a 30-minute session.
- **Build gate:** Zero warnings on build. No `@available` or `#if` suppressions.

## Hard Constraints Checklist

Compliance against `CLAUDE.md`:

- [x] Apple frameworks only (no new Swift packages)
- [x] Dark + light mode adaptive (every new color threads `scheme:`)
- [x] Max 300 lines per file, max 50 lines per function, one type per file
- [x] No hardcoded colors in views — all via `Theme.Section` / `Theme.Surface`
- [x] No force unwraps, async/await only, Swift 6 strict concurrency
- [x] Accessibility labels on every new button
- [x] Dynamic Type on all text
- [x] No SwiftData model changes
- [x] No Cognito / CDK / Lambda changes
- [x] No Info.plist / entitlements changes
- [x] No scheme / build settings changes
- [x] Backward compatible — existing views keep working without modification until migrated
- [x] No em dashes in generated UI copy

## Rollout Plan

**Phase 1 — Design system foundation.** Ship the 10 new DS component files and the `Theme.swift` extension. No feature views touched. Build stays green; zero visual change. Single commit on `feature/flair-pass`.

**Phase 2 — Priority pages.** Migrate the 5 founder-flagged pages: Scanner, Grocery, Recipes, Calendar, Pantry. This is the first visible "wow." One commit per page so individual pages can be reverted cleanly if one direction feels wrong.

**Phase 3 — Universal treatment.** Remaining ~15 pages + the repo-wide close/dismiss sweep. One commit per logical page group.

**Merge order:** `feature/flair-pass` → `dev` (after build passes with zero warnings) → `main` (after manual device testing per `CLAUDE.md` branch rules).

## Risks

1. **MeshGradientView battery.** A `TimelineView`-driven mesh gradient on every hero header could drain battery if naively implemented. Mitigation: 8-second cycle, only 3 anchor positions, `.timeInterval` schedule (not `.periodic`), pause on `scenePhase == .inactive`. Budget: <1% CPU when idle on-screen.
2. **Mesh gradient legibility.** Bold gradients under white title text can cause contrast failures. Mitigation: every hero header applies a fixed 0 → 55% black overlay from the bottom, and all titles use `Typography.titleLarge` (already tested for contrast). Manual XXL Dynamic Type check on every priority page.
3. **Phase 1 drift.** Phase 1 ships new components that no view uses yet. Risk that they sit unused if Phase 2 is delayed. Mitigation: Phase 1 and Phase 2 ship within the same branch; Phase 1 is a preparatory commit, not a merge.
4. **Section hue clash with semantic colors.** Pantry is emerald; `Theme.Semantic.onTrack` is also green. Mitigation: pantry uses `#10B981`, `onTrack` uses `#34D399` — distinct enough in context (tiles vs inline indicators), and they never share a surface.
5. **Migration scope creep.** The repo-wide close/dismiss sweep touches many files. Mitigation: sweep is its own commit at the end of Phase 3, reviewed as a single diff.

## Out of Scope (Explicit)

- SwiftData schema or migrations
- MiraEngine / Bedrock prompt engineering
- ProteinCalculator, GIToleranceEngine, or any service math
- CDK, Lambda, Cognito, Aurora configuration
- New haptic patterns (reuse existing `HapticManager`)
- Typography scale changes (reuse `Typography.swift`)
- Onboarding wizard flow/state logic — only its visual skin
- New Swift packages, CocoaPods, Carthage deps
- Widget extension redesign (`Widgets/`) — separate future pass
