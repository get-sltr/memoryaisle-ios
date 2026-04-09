# Light/Dark Mode + WidgetKit + Mira Recipe Enhancement

**Date:** 2026-04-08
**Status:** Approved

---

## 1. Light/Dark Mode QA

### Problem
`MemoryAisleApp.swift:59` forces `.preferredColorScheme(.dark)`. Theme.swift already has full light/dark support, but many views bypass it with hardcoded `.white.opacity()` colors.

### Fix
1. Remove `.preferredColorScheme(.dark)` from RootView - app follows system setting
2. Audit all views that use hardcoded `.white` or `.white.opacity()` for text and backgrounds
3. Replace with `Theme.Text.primary`, `Theme.Text.secondary(for: scheme)`, `Theme.Text.tertiary(for: scheme)`, `Theme.Surface.glass(for: scheme)`, etc.
4. Views to audit: MealsView, ScanView, ScanResultView, GroceryListView, MiraChatView, ProgressDashboardView, ProfileView, all Onboarding screens
5. Test both modes render correctly

### Pattern
Every hardcoded `.white` or `.white.opacity(N)` used for text should become:
- Opacity 1.0 -> `Theme.Text.primary`
- Opacity 0.5-0.7 -> `Theme.Text.secondary(for: scheme)`
- Opacity 0.2-0.4 -> `Theme.Text.tertiary(for: scheme)`

Every hardcoded `.white.opacity(0.03-0.12)` used for backgrounds should become:
- `Theme.Surface.glass(for: scheme)` or `Theme.Surface.strong(for: scheme)`

Every hardcoded `.white.opacity(0.06)` used for borders should become:
- `Theme.Border.glass(for: scheme)`

---

## 2. WidgetKit

### Architecture
- **App Group:** `group.com.sltrdigital.memoryaisle`
- **Shared data:** `AppGroupDataProvider` reads SwiftData from the shared container
- **Widget target:** `MemoryAisleWidgets` (WidgetBundle containing 3 widgets)
- **Refresh:** TimelineProvider with 15-minute intervals

### Widgets

**ProteinWidget**
- Families: `.accessoryCircular`, `.accessoryRectangular`, `.systemSmall`
- Displays: current protein / target (e.g., "85/140g")
- Visual: circular progress ring (violet) for accessory, progress bar for small
- Data: reads today's NutritionLog from shared SwiftData

**HydrationWidget**
- Families: `.accessoryCircular`, `.accessoryRectangular`, `.systemSmall`
- Displays: current water / target (e.g., "1.8/2.5L")
- Visual: circular progress ring (sky blue) for accessory, progress bar for small
- Data: reads today's NutritionLog from shared SwiftData

**TodaysMealWidget**
- Families: `.systemSmall`, `.systemMedium`
- Displays: next meal name, protein, calories, prep time
- Visual: meal name prominent, macros below, nausea-safe badge if applicable
- Data: reads active MealPlan from shared SwiftData

### Files
- `Widgets/MemoryAisleWidgets.swift` - WidgetBundle
- `Widgets/ProteinWidget.swift` - Protein progress widget
- `Widgets/HydrationWidget.swift` - Hydration progress widget
- `Widgets/TodaysMealWidget.swift` - Next meal widget
- `Widgets/AppGroupDataProvider.swift` - Shared SwiftData reader
- Main app `MemoryAisleApp.swift` - Update ModelContainer to use App Group shared URL

### App Group Setup
- Add `group.com.sltrdigital.memoryaisle` capability to main app target
- Add same capability to widget extension target
- Main app ModelContainer uses `modelConfiguration` with `groupContainerURL`
- Widget reads from same URL

---

## 3. Mira Recipe Enhancement

### Problem
When Mira generates meal plans or users ask for recipes, the response is 1-2 sentences. Users want full cookbook-style recipes with detailed steps.

### Fix
Update the MealGenerator prompt to request full recipes with:
- Complete ingredient list with exact measurements
- Step-by-step cooking instructions (numbered)
- Prep time and cook time separately
- Tips for GLP-1 users (e.g., "This is gentle on the stomach" or "High protein density makes this ideal for low-appetite days")

Update the Meal model's `cookingInstructions` field usage - it exists but is often empty. The MealGenerator prompt must explicitly request detailed instructions.

Update MealsView to show a expandable recipe detail when tapping a meal card, displaying the full ingredients list and cooking steps.

### MealGenerator Prompt Update
The meal request format changes to include a multi-line cooking instructions field. The response parser already handles the `|` delimited format with an instructions field at position 11.

The system prompt addition:
```
When generating meals, include complete cookbook-style recipes:
- List ALL ingredients with exact measurements (cups, oz, grams)
- Write step-by-step cooking instructions (numbered, 4-8 steps)
- Include prep time and cook time
- Note any GLP-1 specific tips (nausea-safe variations, protein boosters)
```
