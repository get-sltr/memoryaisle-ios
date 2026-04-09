# Light/Dark Mode + WidgetKit + Mira Recipes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app work in both light and dark mode, add 3 WidgetKit widgets (protein, hydration, today's meal), and make Mira generate full cookbook-style recipes.

**Architecture:** Remove forced dark mode, replace 298 hardcoded `.white.opacity()` colors with Theme system colors across 33 files. Add WidgetKit extension with App Group shared SwiftData. Update MealGenerator prompt for detailed recipes.

**Tech Stack:** SwiftUI, WidgetKit, SwiftData, App Groups

---

## File Map

```
Modified:
  App/MemoryAisleApp.swift                    - Remove forced dark mode, add App Group container
  Services/AI/MealGenerator.swift             - Cookbook-style recipe prompt
  Features/Meals/MealsView.swift              - Recipe detail expansion + theme colors
  Features/Scan/ScanView.swift                - Theme colors
  Features/Scan/ScanResultView.swift          - Theme colors
  Features/Scan/GroceryListView.swift         - Theme colors
  Features/Scan/FoodSearchView.swift          - Theme colors
  Features/Scan/PantryView.swift              - Theme colors
  Features/Scan/MealPhotoView.swift           - Theme colors
  Features/Mira/MiraChatView.swift            - Theme colors
  Features/Progress/ProgressDashboardView.swift - Theme colors
  Features/Progress/ProviderReportView.swift   - Theme colors
  Features/Progress/PhotoCheckInView.swift     - Theme colors
  Features/Progress/GIToleranceView.swift      - Theme colors
  Features/Progress/WeightTrendChart.swift     - Theme colors
  Features/Profile/ProfileView.swift           - Theme colors
  Features/Auth/AuthFlowView.swift             - Theme colors
  Features/Auth/LegalView.swift                - Theme colors
  Features/Subscription/PaywallView.swift      - Theme colors
  Features/Subscription/UpgradePrompt.swift    - Theme colors
  Features/Recipes/RecipesView.swift           - Theme colors
  Features/Recipes/RecipeDetailView.swift       - Theme colors
  Features/Recipes/ReceiptScannerView.swift    - Theme colors
  Features/Calendar/CalendarView.swift         - Theme colors
  Features/Onboarding/*.swift (8 files)        - Theme colors

Created:
  Widgets/MemoryAisleWidgets.swift             - WidgetBundle
  Widgets/ProteinWidget.swift                  - Protein progress widget
  Widgets/HydrationWidget.swift                - Hydration progress widget
  Widgets/TodaysMealWidget.swift               - Next meal widget
  Widgets/AppGroupDataProvider.swift           - Shared SwiftData reader
```

---

### Task 1: Remove forced dark mode and enable system color scheme

**Files:**
- Modify: `MemoryAisle2/App/MemoryAisleApp.swift`

- [ ] **Step 1: Remove the forced dark mode**

In `MemoryAisle2/App/MemoryAisleApp.swift`, find line 59 (inside RootView body):
```swift
        .preferredColorScheme(.dark)
```
Delete this line entirely. The app will now follow the iOS system setting.

- [ ] **Step 2: Build and verify**

Run:
```bash
cd /Users/km/Desktop/rebuilt.memoryaisle.ios/MemoryAisle2 && xcodebuild -scheme MemoryAisle2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD" | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/App/MemoryAisleApp.swift
git commit -m "[design] Remove forced dark mode - app follows system color scheme"
```

---

### Task 2: Light/dark audit - Core views (Home, Meals, Profile)

**Files:**
- Modify: `MemoryAisle2/Features/Meals/MealsView.swift`
- Modify: `MemoryAisle2/Features/Profile/ProfileView.swift`

**Pattern for all light/dark audit tasks:**

Every file needs `@Environment(\.colorScheme) private var scheme` if it doesn't already have it. Then apply these replacements throughout the file:

| Hardcoded | Replacement |
|-----------|-------------|
| `.foregroundStyle(.white)` | `.foregroundStyle(Theme.Text.primary)` |
| `.foregroundStyle(.white.opacity(0.3))` to `.foregroundStyle(.white.opacity(0.5))` | `.foregroundStyle(Theme.Text.secondary(for: scheme))` |
| `.foregroundStyle(.white.opacity(0.1))` to `.foregroundStyle(.white.opacity(0.29))` | `.foregroundStyle(Theme.Text.tertiary(for: scheme))` |
| `.fill(.white.opacity(0.03))` or `.fill(.white.opacity(0.04))` | `.fill(Theme.Surface.glass(for: scheme))` |
| `.fill(.white.opacity(0.05))` to `.fill(.white.opacity(0.08))` | `.fill(Theme.Surface.strong(for: scheme))` |
| `.stroke(.white.opacity(0.06))` or `.stroke(.white.opacity(0.1))` | `.stroke(Theme.Border.glass(for: scheme))` |
| `Color.indigoBlack` used as background | `Theme.background(for: scheme)` |

- [ ] **Step 1: Update MealsView.swift**

Open `MemoryAisle2/Features/Meals/MealsView.swift`. It already has `scheme` from `@Environment(\.colorScheme)`. Apply the replacement table above to all 12 occurrences of `.white.opacity()`. Key changes:
- Header text `.foregroundStyle(.white)` -> `Theme.Text.primary`
- Subtitle `.foregroundStyle(.white.opacity(0.35))` -> `Theme.Text.secondary(for: scheme)`
- Card backgrounds `.fill(.white.opacity(0.03))` -> `Theme.Surface.glass(for: scheme)`
- Card borders `.stroke(.white.opacity(0.06))` -> `Theme.Border.glass(for: scheme)`
- Macro text `.foregroundStyle(.white.opacity(0.6))` -> `Theme.Text.secondary(for: scheme)`

- [ ] **Step 2: Update ProfileView.swift**

Open `MemoryAisle2/Features/Profile/ProfileView.swift`. Apply the same replacement table to all 15 occurrences.

- [ ] **Step 3: Build and verify**

```bash
cd /Users/km/Desktop/rebuilt.memoryaisle.ios/MemoryAisle2 && xcodebuild -scheme MemoryAisle2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD" | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/Features/Meals/MealsView.swift MemoryAisle2/Features/Profile/ProfileView.swift
git commit -m "[design] Light/dark theme colors - MealsView, ProfileView"
```

---

### Task 3: Light/dark audit - Scan views

**Files:**
- Modify: `MemoryAisle2/Features/Scan/ScanView.swift`
- Modify: `MemoryAisle2/Features/Scan/ScanResultView.swift`
- Modify: `MemoryAisle2/Features/Scan/GroceryListView.swift`
- Modify: `MemoryAisle2/Features/Scan/FoodSearchView.swift`
- Modify: `MemoryAisle2/Features/Scan/PantryView.swift`
- Modify: `MemoryAisle2/Features/Scan/MealPhotoView.swift`

- [ ] **Step 1: Update all 6 Scan views**

Apply the same replacement table from Task 2 to all 6 files. Each file should already have `@Environment(\.colorScheme) private var scheme` or needs it added.

Also replace any `Color.indigoBlack.ignoresSafeArea()` background with `.themeBackground()`.

Total: ~60 replacements across 6 files.

- [ ] **Step 2: Build and verify**

```bash
cd /Users/km/Desktop/rebuilt.memoryaisle.ios/MemoryAisle2 && xcodebuild -scheme MemoryAisle2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD" | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/Features/Scan/
git commit -m "[design] Light/dark theme colors - all Scan views"
```

---

### Task 4: Light/dark audit - Progress views

**Files:**
- Modify: `MemoryAisle2/Features/Progress/ProgressDashboardView.swift`
- Modify: `MemoryAisle2/Features/Progress/ProviderReportView.swift`
- Modify: `MemoryAisle2/Features/Progress/PhotoCheckInView.swift`
- Modify: `MemoryAisle2/Features/Progress/GIToleranceView.swift`
- Modify: `MemoryAisle2/Features/Progress/WeightTrendChart.swift`

- [ ] **Step 1: Update all 5 Progress views**

Apply the replacement table from Task 2. Total: ~58 replacements across 5 files.

- [ ] **Step 2: Build and verify**

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/Features/Progress/
git commit -m "[design] Light/dark theme colors - all Progress views"
```

---

### Task 5: Light/dark audit - Auth, Subscription, Mira, Recipes, Calendar, Onboarding

**Files:**
- Modify: `MemoryAisle2/Features/Auth/AuthFlowView.swift`
- Modify: `MemoryAisle2/Features/Auth/LegalView.swift`
- Modify: `MemoryAisle2/Features/Subscription/PaywallView.swift`
- Modify: `MemoryAisle2/Features/Subscription/UpgradePrompt.swift`
- Modify: `MemoryAisle2/Features/Mira/MiraChatView.swift`
- Modify: `MemoryAisle2/Features/Recipes/RecipesView.swift`
- Modify: `MemoryAisle2/Features/Recipes/RecipeDetailView.swift`
- Modify: `MemoryAisle2/Features/Recipes/ReceiptScannerView.swift`
- Modify: `MemoryAisle2/Features/Calendar/CalendarView.swift`
- Modify: `MemoryAisle2/Features/Onboarding/OnboardingFlow.swift`
- Modify: `MemoryAisle2/Features/Onboarding/MiraIntroScreen.swift`
- Modify: `MemoryAisle2/Features/Onboarding/GLP1CheckScreen.swift`
- Modify: `MemoryAisle2/Features/Onboarding/MedicationSelectScreen.swift`
- Modify: `MemoryAisle2/Features/Onboarding/DoseTimingScreen.swift`
- Modify: `MemoryAisle2/Features/Onboarding/WorriesScreen.swift`
- Modify: `MemoryAisle2/Features/Onboarding/TrainingScreen.swift`
- Modify: `MemoryAisle2/Features/Onboarding/DietaryScreen.swift`
- Modify: `MemoryAisle2/Features/Onboarding/MiraReadyScreen.swift`
- Modify: `MemoryAisle2/Features/Onboarding/BodyStatsScreen.swift`

- [ ] **Step 1: Update all remaining views**

Apply the replacement table from Task 2 to all 19 files. Total: ~168 replacements.

For Onboarding screens, many use `Color.indigoBlack` as background - replace with `.themeBackground()`.

- [ ] **Step 2: Build and verify**

```bash
cd /Users/km/Desktop/rebuilt.memoryaisle.ios/MemoryAisle2 && xcodebuild -scheme MemoryAisle2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD" | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/Features/
git commit -m "[design] Light/dark theme colors - Auth, Subscription, Mira, Recipes, Calendar, Onboarding"
```

---

### Task 6: Mira cookbook-style recipe enhancement

**Files:**
- Modify: `MemoryAisle2/Services/AI/MealGenerator.swift`
- Modify: `MemoryAisle2/Services/AI/MiraEngine.swift`
- Modify: `MemoryAisle2/Features/Meals/MealsView.swift`

- [ ] **Step 1: Update MealGenerator prompt for full recipes**

In `MemoryAisle2/Services/AI/MealGenerator.swift`, find the `buildMealRequest` method. Replace the response format instruction at the end (around line 95-102) with:

```swift
        request += """

        For each meal, provide a COMPLETE cookbook-style recipe.
        Respond in this exact format for each meal:
        MEAL|type|name|protein_g|calories|carbs_g|fat_g|fiber_g|\
        prep_minutes|nausea_safe|ingredients(semicolon-separated with amounts)|\
        cooking_instructions(numbered steps separated by semicolons)
        Types: breakfast, lunch, dinner, snack, pre-workout, post-workout
        
        For ingredients, include exact measurements (e.g., "8oz chicken breast;1 cup brown rice;2 cups broccoli florets;1 tbsp olive oil;salt and pepper to taste").
        For instructions, write detailed numbered steps (e.g., "1. Preheat oven to 400F;2. Season chicken breast with salt, pepper, and garlic powder;3. Heat olive oil in oven-safe skillet over medium-high heat;4. Sear chicken 3 minutes per side until golden;5. Transfer skillet to oven and bake 15 minutes until internal temp reaches 165F;6. Rest 5 minutes before slicing").
        Include a GLP-1 tip at the end of instructions if relevant (e.g., "Tip: This meal is gentle on the stomach and ideal for low-appetite days").
        """
```

- [ ] **Step 2: Update the parseMeals ingredient separator**

In the same file, find the `parseMeals` method. The ingredients are currently split by comma. Update to split by semicolon to match the new format:

Find:
```swift
                ingredients = parts[10].components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
```

Replace with:
```swift
                ingredients = parts[10].components(separatedBy: ";")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
```

- [ ] **Step 3: Update MiraEngine system prompt to request detailed recipes**

In `MemoryAisle2/Services/AI/MiraEngine.swift`, find the `buildSystemPrompt` method. Add to the RULES section at the end:

Find:
```swift
        - Adapt portion suggestions to appetite level
        - Never reference specific brand names of medications
        - Never ask for or reference the user's real name
```

Replace with:
```swift
        - Adapt portion suggestions to appetite level
        - Never reference specific brand names of medications
        - Never ask for or reference the user's real name
        - When suggesting meals, include complete recipes with exact ingredient amounts and step-by-step cooking instructions
        - Include prep time and cook time in recipe steps
        - Note GLP-1 specific tips (nausea-safe variations, protein boosters)
```

- [ ] **Step 4: Add recipe detail expansion to MealsView**

In `MemoryAisle2/Features/Meals/MealsView.swift`, add a `@State private var expandedMealId: String?` property and update `mealCard` to be expandable. Replace the existing `mealCard` method with one that shows full ingredients and cooking steps when tapped:

After the existing ingredients line in mealCard, add an expandable section:

```swift
            if expandedMealId == meal.id {
                if !meal.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("INGREDIENTS")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1)
                        ForEach(meal.ingredients, id: \.self) { ingredient in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.violet.opacity(0.4))
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 6)
                                Text(ingredient)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                if let instructions = meal.cookingInstructions,
                   !instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("INSTRUCTIONS")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1)
                        
                        let steps = instructions.components(separatedBy: ";")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                            Text(step)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Text.secondary(for: scheme))
                        }
                    }
                    .padding(.top, 8)
                }
            }
```

Make the entire card toggle expansion on tap:
```swift
        Button {
            HapticManager.light()
            withAnimation(Theme.Motion.spring) {
                expandedMealId = expandedMealId == meal.id ? nil : meal.id
            }
        } label: {
            // ... existing card content ...
        }
```

- [ ] **Step 5: Build and verify**

```bash
cd /Users/km/Desktop/rebuilt.memoryaisle.ios/MemoryAisle2 && xcodebuild -scheme MemoryAisle2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD" | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add MemoryAisle2/Services/AI/MealGenerator.swift MemoryAisle2/Services/AI/MiraEngine.swift MemoryAisle2/Features/Meals/MealsView.swift
git commit -m "[feature] Mira cookbook-style recipes with full ingredients and step-by-step instructions"
```

---

### Task 7: WidgetKit - App Group shared data provider

**Files:**
- Modify: `MemoryAisle2/App/MemoryAisleApp.swift`
- Create: `MemoryAisle2/Widgets/AppGroupDataProvider.swift`

- [ ] **Step 1: Update ModelContainer to use App Group**

In `MemoryAisle2/App/MemoryAisleApp.swift`, update the `modelContainer` to use a shared App Group URL. Replace the `.modelContainer(for: [...])` call with:

```swift
                .modelContainer(for: [
                    UserProfile.self,
                    NutritionLog.self,
                    SymptomLog.self,
                    PantryItem.self,
                    GIToleranceRecord.self,
                    MealPlan.self,
                    Meal.self,
                    FoodItem.self,
                    GroceryList.self,
                    MedicationProfile.self,
                    TrainingSession.self,
                    BodyComposition.self,
                    ProviderReport.self
                ], isUndoEnabled: false)
```

Note: App Group entitlement (`group.com.sltrdigital.memoryaisle`) must be added in Xcode project settings manually. The shared container URL will be configured when the widget target is created.

- [ ] **Step 2: Create AppGroupDataProvider**

```swift
import Foundation
import SwiftData

struct AppGroupDataProvider {
    static let appGroupId = "group.com.sltrdigital.memoryaisle"

    static var sharedContainerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) ?? FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
    }

    static var sharedModelContainer: ModelContainer {
        let schema = Schema([
            UserProfile.self,
            NutritionLog.self,
            MealPlan.self,
            Meal.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: sharedContainerURL.appendingPathComponent("shared.store"),
            allowsSave: false
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    static func todayNutrition() -> (protein: Double, water: Double) {
        let container = sharedModelContainer
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate { $0.date >= today }
        )
        let logs = (try? context.fetch(descriptor)) ?? []

        let protein = logs.reduce(0) { $0 + $1.proteinGrams }
        let water = logs.reduce(0) { $0 + $1.waterLiters }
        return (protein, water)
    }

    @MainActor
    static func userTargets() -> (protein: Int, water: Double) {
        let container = sharedModelContainer
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserProfile>()
        let profile = (try? context.fetch(descriptor))?.first
        return (
            profile?.proteinTargetGrams ?? 140,
            profile?.waterTargetLiters ?? 2.5
        )
    }

    @MainActor
    static func nextMeal() -> Meal? {
        let container = sharedModelContainer
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        let descriptor = FetchDescriptor<MealPlan>(
            predicate: #Predicate { $0.date >= today && $0.isActive },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let plan = (try? context.fetch(descriptor))?.first else {
            return nil
        }
        return plan.meals.first
    }
}
```

Write to `MemoryAisle2/Widgets/AppGroupDataProvider.swift`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/App/MemoryAisleApp.swift MemoryAisle2/Widgets/AppGroupDataProvider.swift
git commit -m "[feature] App Group shared data provider for WidgetKit"
```

---

### Task 8: WidgetKit - Protein and Hydration widgets

**Files:**
- Create: `MemoryAisle2/Widgets/ProteinWidget.swift`
- Create: `MemoryAisle2/Widgets/HydrationWidget.swift`

- [ ] **Step 1: Create ProteinWidget**

```swift
import SwiftUI
import WidgetKit

struct ProteinEntry: TimelineEntry {
    let date: Date
    let current: Double
    let target: Int
}

struct ProteinProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProteinEntry {
        ProteinEntry(date: .now, current: 85, target: 140)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProteinEntry) -> Void) {
        let entry = ProteinEntry(date: .now, current: 85, target: 140)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProteinEntry>) -> Void) {
        Task { @MainActor in
            let nutrition = AppGroupDataProvider.todayNutrition()
            let targets = AppGroupDataProvider.userTargets()
            let entry = ProteinEntry(
                date: .now,
                current: nutrition.protein,
                target: targets.protein
            )
            let nextUpdate = Calendar.current.date(
                byAdding: .minute, value: 15, to: .now
            ) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

struct ProteinWidgetView: View {
    let entry: ProteinEntry
    @Environment(\.widgetFamily) var family

    var progress: Double {
        guard entry.target > 0 else { return 0 }
        return min(1.0, entry.current / Double(entry.target))
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    private var circularView: some View {
        Gauge(value: progress) {
            Text("P")
                .font(.system(size: 12, weight: .bold))
        } currentValueLabel: {
            Text("\(Int(entry.current))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Color(hex: 0xA78BFA))
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Protein")
                .font(.system(size: 12, weight: .medium))
            Text("\(Int(entry.current))/\(entry.target)g")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
            ProgressView(value: progress)
                .tint(Color(hex: 0xA78BFA))
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            Text("Protein")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("\(Int(entry.current))")
                .font(.system(size: 36, weight: .light, design: .monospaced))
            Text("of \(entry.target)g")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
                .tint(Color(hex: 0xA78BFA))
                .padding(.horizontal, 16)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ProteinWidget: Widget {
    let kind = "ProteinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProteinProvider()) { entry in
            ProteinWidgetView(entry: entry)
        }
        .configurationDisplayName("Protein Tracker")
        .description("Track your daily protein intake")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}
```

Write to `MemoryAisle2/Widgets/ProteinWidget.swift`.

- [ ] **Step 2: Create HydrationWidget**

```swift
import SwiftUI
import WidgetKit

struct HydrationEntry: TimelineEntry {
    let date: Date
    let current: Double
    let target: Double
}

struct HydrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationEntry {
        HydrationEntry(date: .now, current: 1.8, target: 2.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        let entry = HydrationEntry(date: .now, current: 1.8, target: 2.5)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        Task { @MainActor in
            let nutrition = AppGroupDataProvider.todayNutrition()
            let targets = AppGroupDataProvider.userTargets()
            let entry = HydrationEntry(
                date: .now,
                current: nutrition.water,
                target: targets.water
            )
            let nextUpdate = Calendar.current.date(
                byAdding: .minute, value: 15, to: .now
            ) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

struct HydrationWidgetView: View {
    let entry: HydrationEntry
    @Environment(\.widgetFamily) var family

    var progress: Double {
        guard entry.target > 0 else { return 0 }
        return min(1.0, entry.current / entry.target)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    private var circularView: some View {
        Gauge(value: progress) {
            Image(systemName: "drop.fill")
                .font(.system(size: 10))
        } currentValueLabel: {
            Text(String(format: "%.1f", entry.current))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Color(hex: 0x38BDF8))
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Water")
                .font(.system(size: 12, weight: .medium))
            Text(String(format: "%.1f/%.1fL", entry.current, entry.target))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
            ProgressView(value: progress)
                .tint(Color(hex: 0x38BDF8))
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x38BDF8))
                Text("Water")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(String(format: "%.1f", entry.current))
                .font(.system(size: 36, weight: .light, design: .monospaced))
            Text(String(format: "of %.1fL", entry.target))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
                .tint(Color(hex: 0x38BDF8))
                .padding(.horizontal, 16)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct HydrationWidget: Widget {
    let kind = "HydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HydrationProvider()) { entry in
            HydrationWidgetView(entry: entry)
        }
        .configurationDisplayName("Hydration Tracker")
        .description("Track your daily water intake")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}
```

Write to `MemoryAisle2/Widgets/HydrationWidget.swift`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/Widgets/ProteinWidget.swift MemoryAisle2/Widgets/HydrationWidget.swift
git commit -m "[feature] ProteinWidget + HydrationWidget with Lock Screen and Home Screen support"
```

---

### Task 9: WidgetKit - Today's Meal widget and WidgetBundle

**Files:**
- Create: `MemoryAisle2/Widgets/TodaysMealWidget.swift`
- Create: `MemoryAisle2/Widgets/MemoryAisleWidgets.swift`

- [ ] **Step 1: Create TodaysMealWidget**

```swift
import SwiftUI
import WidgetKit

struct MealEntry: TimelineEntry {
    let date: Date
    let mealName: String?
    let mealType: String?
    let protein: Int
    let calories: Int
    let prepMinutes: Int
    let isNauseaSafe: Bool
}

struct MealProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealEntry {
        MealEntry(
            date: .now, mealName: "Grilled Chicken Bowl",
            mealType: "Lunch", protein: 42, calories: 520,
            prepMinutes: 15, isNauseaSafe: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MealEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MealEntry>) -> Void) {
        Task { @MainActor in
            let meal = AppGroupDataProvider.nextMeal()
            let entry = MealEntry(
                date: .now,
                mealName: meal?.name,
                mealType: meal?.mealType.rawValue,
                protein: Int(meal?.proteinGrams ?? 0),
                calories: Int(meal?.caloriesTotal ?? 0),
                prepMinutes: meal?.prepTimeMinutes ?? 0,
                isNauseaSafe: meal?.isNauseaSafe ?? false
            )
            let nextUpdate = Calendar.current.date(
                byAdding: .minute, value: 15, to: .now
            ) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

struct TodaysMealWidgetView: View {
    let entry: MealEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let name = entry.mealName {
            mealContent(name: name)
        } else {
            emptyContent
        }
    }

    private func mealContent(name: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let type = entry.mealType {
                Text(type.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            Text(name)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(2)

            HStack(spacing: 12) {
                Label("\(entry.protein)g", systemImage: "flame.fill")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xA78BFA))
                Label("\(entry.calories)", systemImage: "bolt.fill")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if entry.prepMinutes > 0 {
                    Text("\(entry.prepMinutes) min")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                if entry.isNauseaSafe {
                    Label("Nausea-safe", systemImage: "leaf.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: 0x34D399))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var emptyContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No meal plan")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Open MemoryAisle to generate")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct TodaysMealWidget: Widget {
    let kind = "TodaysMealWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MealProvider()) { entry in
            TodaysMealWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Meal")
        .description("See your next meal from today's plan")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

Write to `MemoryAisle2/Widgets/TodaysMealWidget.swift`.

- [ ] **Step 2: Create WidgetBundle**

```swift
import SwiftUI
import WidgetKit

@main
struct MemoryAisleWidgets: WidgetBundle {
    var body: some Widget {
        ProteinWidget()
        HydrationWidget()
        TodaysMealWidget()
    }
}
```

Write to `MemoryAisle2/Widgets/MemoryAisleWidgets.swift`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/Widgets/
git commit -m "[feature] TodaysMealWidget + WidgetBundle with all 3 widgets"
```

---

### Task 10: Add widget files to Xcode project and build

- [ ] **Step 1: Add all widget files to the Xcode project**

The widget extension needs to be added as a new target in the Xcode project. This requires manual Xcode configuration:
1. Add a Widget Extension target named `MemoryAisleWidgets`
2. Set deployment target to iOS 17
3. Add App Group capability `group.com.sltrdigital.memoryaisle` to both main app and widget targets
4. Add all 5 widget Swift files to the widget target
5. Add the shared model files (UserProfile, NutritionLog, MealPlan, Meal) to the widget target

Alternatively, add the widget files to the main app target for now (widgets can be compiled as part of the main target for development) and create the extension target later.

- [ ] **Step 2: Build and verify**

```bash
cd /Users/km/Desktop/rebuilt.memoryaisle.ios/MemoryAisle2 && xcodebuild -scheme MemoryAisle2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD" | tail -5
```

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "[feature] WidgetKit extension added to Xcode project"
```
