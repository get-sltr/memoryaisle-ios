# Reflection Page — Design Spec

**Date:** 2026-04-13
**Author:** Kevin Minn (with Claude)
**Status:** Design approved, ready for implementation plan
**Branch:** `feature/flair-pass` (to be forked into `feature/reflection-v1` for implementation)

---

## 1. Purpose

Reflection is the emotional core of MemoryAisle. It is not a dashboard, check-in screen, or logging tool. It is a results-driven scrapbook that plays the user's journey back to them in a way that makes them feel happy, encouraged, motivated, and celebrated.

Competing apps have dashboards. Reflection is MemoryAisle's differentiator: a warm, user-driven record of who the user has been and what they have done. Every design decision in this spec is evaluated against whether it makes the user feel celebrated. If a choice could equally live inside FitBit or MyFitnessPal, it has been rethought.

This spec covers v1 of Reflection: the view itself, the source transformers that feed it, the data layer fixes required to populate those sources, and the onboarding changes that anchor Day 1.

---

## 2. Scope

### In scope (v1)

- New `Features/Reflection/` view with all 5 filter chips from the design system spec
- New `Services/Reflection/` service layer with derived moment aggregation
- Data layer fix: `PhotoCheckInView` persistence bug resolved so check-ins actually write `BodyComposition` records with weights and photos
- Onboarding change: new `StartingPhotoScreen` (optional) seeds the Day 1 record
- `ReflectionHeroInviteCard` for users with no Day 1 photo yet, with a gentle 30-day cooldown
- Menu integration: new Reflection row, Progress moved to position 2
- Unit test coverage for every service and every non-empty transformer

### Not in scope (v2+)

- **Mira-authored auto-moments** ("You made chicken 4 times this month") — needs pattern detection
- **Meal moments with cooked-meal photos** — needs `Meal.photoData` + `wasEaten` fields
- **Feeling moments from Mira chats** — needs Mira chat persistence
- **Saved recipes in Meals filter** — scheduled as a separate feature (task #11). When it ships, `MealMomentTransformer` will be wired to its source with zero view changes.
- **Grocery run moments** — needs "notable run" heuristics
- **Personal best card variant** — not enough orthogonal signals for v1
- **Editable Day 1 date** — v1 keeps it simple: Day 1 equals the earliest photo in the database
- **Photo comparison carousel** (arbitrary two-date compare) — v1 is Day 1 vs Today only
- **Reflection sharing or export**
- **Analytics on invite card accept or decline**
- **Haptic celebration on first-view of a new milestone**

---

## 3. Architecture

### Core principle: derived moments, not materialized

Reflection queries existing SwiftData models at render time and transforms them into moment cards through a service layer. There is **no new SwiftData model**. This choice has three consequences:

1. Moments cannot drift from their source data. Deleting a `BodyComposition` record automatically removes its moment card. No sync bugs possible.
2. Fixing `PhotoCheckInView` once lights up check-ins, photos, and milestones for free.
3. Filter chips that are "wired but empty" cost nothing to ship — the empty `MealMomentTransformer` and `FeelingMomentTransformer` become non-empty the day their sources exist, with no view changes required.

### The `ReflectionMoment` value type

Moments are value types (`struct`), not SwiftData models. They exist only in memory, computed per render.

```swift
struct ReflectionMoment: Identifiable, Hashable {
    let id: String                // stable prefixed ID: "checkin-<uuid>", "gym-<uuid>"
    let date: Date
    let type: MomentType          // .checkIn, .gym, .proteinStreak, .toughDay,
                                  // .milestone, .mealMoment, .feeling
    let category: MomentCategory  // .standard, .milestone, .toughDay, .personalBest
    let title: String
    let description: String?
    let quote: String?            // user's own words when available
    let photoData: Data?
    let metadataLabel: String?    // e.g. "45g protein", "30 min", "WEEK 3"
}

enum MomentType: String, Hashable {
    case checkIn, gym, proteinStreak, toughDay, milestone, mealMoment, feeling
}

enum MomentCategory: String, Hashable {
    case standard, milestone, toughDay, personalBest
}

enum ReflectionFilter: String, CaseIterable, Identifiable {
    case all = "All moments"
    case photos = "Photos"
    case meals = "Meals"
    case gym = "Gym"
    case feelings = "Feelings"

    var id: String { rawValue }

    func matches(_ moment: ReflectionMoment) -> Bool {
        switch self {
        case .all:      return true
        case .photos:   return moment.photoData != nil
        case .meals:    return moment.type == .mealMoment
        case .gym:      return moment.type == .gym
        case .feelings: return moment.type == .feeling
        }
    }
}
```

### Transformer protocol and source record bundle

Transformers take plain typed arrays (not a `ModelContext`). This is idiomatic SwiftUI + SwiftData: the view uses `@Query` to subscribe to live updates, then passes the arrays into the service, which routes them through each transformer. Testing becomes trivial — pass fixture arrays directly, no in-memory SwiftData stack required.

```swift
struct ReflectionSourceRecords {
    let bodyCompositions: [BodyComposition]
    let trainingSessions: [TrainingSession]
    let nutritionLogs: [NutritionLog]
    let symptomLogs: [SymptomLog]
    let userProfile: UserProfile?
}

protocol MomentTransformer {
    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment]
}
```

Every source type has its own transformer, one file per transformer. Transformers are pure functions over their inputs — no state, no side effects.

### Service: `ReflectionMomentService`

Single entry point:

```swift
@MainActor
final class ReflectionMomentService {
    private let transformers: [MomentTransformer]

    init(transformers: [MomentTransformer] = ReflectionMomentService.defaultTransformers()) {
        self.transformers = transformers
    }

    func moments(
        for filter: ReflectionFilter,
        from records: ReflectionSourceRecords
    ) -> [ReflectionMoment] {
        let all = transformers.flatMap { transformer -> [ReflectionMoment] in
            do {
                return try transformer.moments(from: records)
            } catch {
                Logger.reflection.error("Transformer failed: \(error)")
                return []
            }
        }
        let sorted = all.sorted { $0.date > $1.date }
        return sorted.filter { filter.matches($0) }
    }
}
```

**Error handling convention:** one broken transformer never blanks the whole timeline. Failures are logged; the remaining transformers continue.

### Filter predicates

Filter chips are predicates over the aggregated list, not per-filter database queries.

| Chip | Predicate |
|---|---|
| All moments | `{ _ in true }` |
| Photos | `$0.photoData != nil` |
| Meals | `$0.type == .mealMoment` |
| Gym | `$0.type == .gym` |
| Feelings | `$0.type == .feeling` |

Moments that do not match any non-`all` filter (protein streaks, tough days, milestones, check-ins without photos) appear only under "All moments." This is deliberate and matches the spec's taxonomy.

### Supporting services

- **`TransformationStatsService`** — computes `(lbsDelta, direction, leanDelta, days)` for the three-stat row
- **`HeroPhotosService`** — returns `(day1: Data?, today: Data?)` by selecting the earliest and latest `BodyComposition` records with `photoData != nil`

### Data flow per render

The view holds `@Query` properties for each source model. SwiftData automatically publishes changes to those arrays; SwiftUI recomputes the body. The service layer is called from the view body as a pure transformation.

```
ReflectionView (live-updating via @Query)
  ├─ @Query bodyCompositions: [BodyComposition]
  ├─ @Query trainingSessions: [TrainingSession]
  ├─ @Query nutritionLogs:    [NutritionLog]
  ├─ @Query symptomLogs:      [SymptomLog]
  ├─ @Query userProfiles:     [UserProfile]
  │
  └─ body computes:
      let records = ReflectionSourceRecords(...)
      ├─ momentService.moments(for: selectedFilter, from: records)
      │     ├─ CheckInMomentTransformer
      │     ├─ GymMomentTransformer
      │     ├─ ProteinStreakMomentTransformer
      │     ├─ ToughDayMomentTransformer
      │     ├─ MilestoneMomentTransformer
      │     ├─ MealMomentTransformer  (returns [] in v1)
      │     └─ FeelingMomentTransformer (returns [] in v1)
      │         → merged, sorted by date desc, filtered by chip
      │         → [ReflectionMoment]
      │
      ├─ statsService.stats(from: records)
      │     → reads UserProfile, earliest and latest BodyComposition
      │     → reads UserDefaults for journeyStartDate
      │     → returns TransformationStats
      │
      └─ heroService.photos(from: records)
            → returns (day1: Data?, today: Data?)
```

When any underlying SwiftData record changes, `@Query` publishes the new array, SwiftUI recomputes `body`, the services re-run, and the view updates. No explicit refresh calls required.

---

## 4. Source transformers

### `CheckInMomentTransformer`

**Reads from:** `BodyComposition` where `source == .manual`

**Produces:** one moment per record.

**ID format:** `"checkin-\(record.id)"`

**Type:** `.checkIn` (category: `.standard`)

**Title:** `"Week \(weekNumber) check-in"` where `weekNumber` is weeks since `journeyStartDate`

**Description logic:**

- If weight moved **toward goal** vs previous check-in:
  `"\(weight) lbs. That's \(delta) closer to your goal."`
- If weight is **equal** to previous check-in:
  `"You showed up. That's the hard part."`
- If weight moved **away from goal**:
  `"\(weight) lbs. The scale is just one signal. Look at you."`
- If this is the **first** check-in:
  `"Your very first check-in. This is where the story starts."`

**Photo:** `record.photoData` (nil is acceptable; renders without a photo)

**Rationale for skipping HealthKit-sourced records:** moments represent intentional user actions. A HealthKit pull is passive. HealthKit data still feeds `TransformationStatsService` and `HeroPhotosService` because it is useful for stats computation, but it does not produce timeline cards.

### `GymMomentTransformer`

**Reads from:** `TrainingSession`

**Produces:** one moment per session. A user who trains five times a week gets five celebrations that week, and that is the point.

**ID format:** `"gym-\(session.id)"`

**Type:** `.gym` (category: `.standard`)

**Title:** maps by `WorkoutType`:
`weights` → `"Weights day"`
`cardio` → `"Cardio session"`
`crossfit` → `"CrossFit"`
`bodyweight` → `"Bodyweight"`
`yoga` → `"Yoga"`
`walking` → `"Walk"`
`hiit` → `"HIIT"`
`sports` → `"Sports"`

**Description:** `"\(durationMinutes) min · \(intensity.rawValue)"` (e.g. `"45 min · Moderate"`)

**Metadata label:** for `.weights`, `.crossfit`, `.bodyweight` sessions with muscle groups, render the groups in all caps, joined by `" + "` (e.g. `"LEGS"`, `"CHEST + BACK"`). Skip for cardio.

**Photo:** none in v1.

### `ProteinStreakMomentTransformer`

**Reads from:** `NutritionLog` and `UserProfile`

**Streak definition:** consecutive days where `NutritionLog.proteinGrams >= userProfile.proteinTargetGrams`.

**Detection:** walk `NutritionLog` chronologically. A streak is a maximal run of consecutive days meeting the threshold. A user who hits 7 days, breaks, then hits 7 again produces two streaks (and two moments).

**Threshold moments** (emit one per streak that reaches or crosses the threshold on its final day):

| Days | Title | Description |
|---|---|---|
| 7 | `"7 days of protein"` | `"Your muscles are listening."` |
| 14 | `"Two weeks strong"` | `"You are making this part automatic."` |
| 30 | `"A whole month"` | `"30 days of fueling yourself right."` |
| 60 | `"60 days unshakeable"` | `"This is who you are now."` |
| 90 | `"90 days"` | `"The rhythm is real."` |
| 180 | `"Six months"` | `"Half a year of showing up for yourself."` |

**ID format:** `"proteinStreak-\(days)-\(endDateISO)"`

**Category:** `.milestone` (green-tinted card)

**Filter:** `All` only

### `ToughDayMomentTransformer`

**Reads from:** `SymptomLog` and `NutritionLog`

**Triggers** (any one fires for a given date):

- `SymptomLog.nauseaLevel >= 3` on that date
- `NutritionLog.caloriesConsumed < 1200` on that date
- Third consecutive day with `proteinGrams < proteinTarget * 0.7`

**Dedup:** at most one tough day moment per date. If multiple triggers hit on the same date, the softest trigger wins (nausea first, then low calories, then protein miss) so the copy matches the actual struggle.

**Copy by trigger:**

| Trigger | Title | Description |
|---|---|---|
| Nausea ≥ 3 | `"A tough day"` | `"You pushed through. That counts."` |
| Calories < 1200 | `"Low fuel day"` | `"Some days the body just will not eat. You are still here."` |
| 3-day protein miss | `"A quieter stretch"` | `"A few softer days. And you are still here."` |

**ID format:** `"toughDay-\(dateISO)"`

**Category:** `.toughDay` (amber-tinted card with "tough day" pill)

**Filter:** `All` only

### `MilestoneMomentTransformer`

**Reads from:** `UserProfile`, `BodyComposition`, and UserDefaults

Three sub-categories of milestones:

**Weight-toward-goal milestones** — every 5 lbs crossed in the goal direction.

- Works for both loss and gain goals
- Example (loss user, 200 → 175): moments at 195, 190, 185, 180, 175
- Example (gain user, 155 → 175): moments at 160, 165, 170, 175
- **ID:** `"milestoneWeight-\(lbsCrossed)"`
- **Title:** `"5 pounds \(direction)"` where direction is `"down"` for loss goals, `"up"` for gain goals
- **Description:** tiered by magnitude:
  - 5 lbs: `"First milestone on the way to \(goal) lbs."`
  - 10 lbs: `"Double digits. That is a real one."`
  - halfway: `"Halfway there."`
  - at goal: `"You hit your goal."`
- **Photo:** closest-by-date `BodyComposition` with `photoData`, if any
- **Category:** `.milestone`

**Anniversary milestones** — 30, 90, 180, 365 days since `journeyStartDate`.

- **ID:** `"milestoneAnniversary-\(days)"`
- **Title:** `"One month in"` / `"Three months in"` / `"Half a year"` / `"One year"`
- **Description:** `"You have been showing up for \(days) days."`
- **Category:** `.milestone`

**First-photo milestone** — earliest `BodyComposition` with `photoData`.

- **ID:** `"milestoneFirstPhoto"`
- **Title:** `"Day 1"`
- **Description:** `"Where the journey starts."`
- **Category:** `.milestone`

All milestone moments appear in `All`, and in `Photos` if they carry a photo.

### `MealMomentTransformer` (empty in v1)

**Reads from:** `Meal`

**Returns:** `[]` in v1. Code comment explains the empty state: the predicate will activate when `Meal` gains `photoData` and either a `wasEaten` flag or a "saved from recipe browser" link.

**When wired (v2):**
- Saved recipes (from task #11) and cooked meals with photos both produce moment cards
- **Category:** `.standard` (or `.personalBest` for "first cooked meal of a recipe" once we track that)
- **Filter:** `Meals`

### `FeelingMomentTransformer` (empty in v1)

**Reads from:** (future Mira message store, not yet built)

**Returns:** `[]` in v1. Structural placeholder.

**When wired (v2):**
- Queries persisted Mira messages flagged as emotionally significant (feeling shared, milestone acknowledged, hard day confessed)
- Quotes user's own words directly into the moment card's `quote` field
- **Filter:** `Feelings`

---

## 5. Transformation stats math

`TransformationStatsService` returns:

```swift
struct TransformationStats {
    let lbsDelta: Double?         // absolute value, always positive
    let direction: Direction      // .lost, .gained, .none
    let leanDelta: Double?        // positive for gains, negative for loss; nil if uncomputable
    let days: Int?                // nil only if no journeyStartDate anywhere

    enum Direction { case lost, gained, none }
}
```

### `lbsDelta` computation

```
starting = earliestBodyComposition?.weightLbs ?? userProfile.weightLbs ?? nil
current  = latestBodyComposition?.weightLbs   ?? starting

if goal < starting:
    lbsDelta  = max(0, starting - current)  // loss goal, clamp to 0 so gains show as "0 lost"
    direction = .lost
else if goal > starting:
    lbsDelta  = max(0, current - starting)  // gain goal
    direction = .gained
else:
    lbsDelta  = abs(current - starting)
    direction = .none
```

Display labels: `"LOST"`, `"GAINED"`, `"CHANGED"`.

### `leanDelta` computation

Requires both the earliest and latest `BodyComposition` records to have `leanMassLbs` set (or `bodyFatPercent` set so lean can be derived via `BodyComposition.computedLeanMass`).

```
leanDelta = latest.computedLeanMass - earliest.computedLeanMass
```

If uncomputable → `nil`. The stats row gracefully collapses from three stats to two, preserving the divider layout.

### `days` computation

Reads `journeyStartDate` from UserDefaults. If absent, falls back to `earliestBodyComposition?.date`. If still absent → `nil`.

```
days = Calendar.current.dateComponents([.day], from: journeyStartDate, to: .now).day
```

---

## 6. Data layer changes

### `PhotoCheckInView` fix

**Problem:** weight is captured in `@State private var weight = ""` (line 13) but never persisted. `saveCheckIn()` (lines 222–243) only writes the photo to `Documents/ProgressPhotos/` and never creates a `BodyComposition` record.

**Fix:**

1. Extract a new service at `Services/Progress/CheckInSaveService.swift`:
   ```swift
   @MainActor
   final class CheckInSaveService {
       func save(
           weight: Double,
           photoData: Data?,
           in context: ModelContext
       ) throws {
           let record = BodyComposition(
               date: .now,
               weightLbs: weight,
               source: .manual,
               photoData: photoData
           )
           context.insert(record)
           try context.save()
       }
   }
   ```

2. Inject `@Environment(\.modelContext)` into `PhotoCheckInView`.

3. Rewrite `saveCheckIn()` to delegate:
   ```swift
   private func saveCheckIn() {
       guard let weightLbs = Double(weight) else { return }
       do {
           try saveService.save(weight: weightLbs, photoData: photoData, in: context)
           HapticManager.success()
           withAnimation(.easeOut(duration: 0.3)) { saved = true }
       } catch {
           Logger.checkIn.error("Save failed: \(error)")
       }
   }
   ```

4. **Disable the save button when weight is empty.** Photo-only check-ins are not supported in v1.

5. **Delete the disk-write block entirely.** Photos live in `BodyComposition.photoData` going forward; single source of truth.

6. **Do not migrate existing orphaned photos in `Documents/ProgressPhotos/`.** They are left alone, will be reclaimed by the OS if the app is uninstalled.

### `journeyStartDate` in UserDefaults

Single key in UserDefaults: `"journeyStartDate"` (ISO8601 Date). Written once, at onboarding completion. Read by `TransformationStatsService` and `MilestoneMomentTransformer`.

For users who completed onboarding before this feature shipped (pre-existing test users), the key is absent. Fallback order:

1. UserDefaults `journeyStartDate`
2. Earliest `BodyComposition.date`
3. `nil` → days stat hides, anniversary milestones do not fire until the user completes a real check-in

### No SwiftData schema changes

The only new writes are:

- New `BodyComposition` records from `CheckInSaveService` and `StartingPhotoScreen` (using existing schema)
- UserDefaults key `"journeyStartDate"` (not a schema change)
- UserDefaults key `"reflectionHeroInviteDismissedUntil"` (not a schema change)

No new `@Model` types. No new fields on existing `@Model` types.

---

## 7. Onboarding changes

**Important context** — the multi-step onboarding sequence does NOT live in `OnboardingFlow.swift`. That file is a thin wrapper that displays `MiraOnboardingView` and handles the final `completeOnboarding()` callback. The actual sub-screens (BodyStats, Training, Worries, etc.) are composed inside `Features/Onboarding/MiraOnboardingView.swift`. The insertion point for the new starting photo step is there, not in `OnboardingFlow`.

### New file: `Features/Onboarding/StartingPhotoScreen.swift`

Inserted inside `MiraOnboardingView`'s sub-step sequence, after `BodyStatsScreen` (which captures weight) and before the next screen. Exact position to be confirmed by reading `MiraOnboardingView.swift` at implementation time — the general principle is: after weight is captured, before training is asked about.

### Screen composition

- `MiraWaveform(state: .idle, size: .hero)` at top
- Serif headline: **"Your first photo"**
- Body text: `"This is optional. You can add a photo now, later, or never. You can always change your mind. It is your journey."`
- Photo preview area (thumbnail or empty placeholder)
- Button that opens a `.confirmationDialog`: `"Take Photo"` / `"Choose from Library"` / `"Cancel"` — matches the existing `PhotoCheckInView` pattern so the two flows feel identical
- Primary button: `GlowButton("Continue")` — always enabled
- Secondary button: `"Skip for now"` in `Theme.Text.tertiary`, matching existing onboarding skip style

### `OnboardingProfile` field addition

One new optional field on `OnboardingProfile` (defined in `OnboardingFlow.swift` around line 87) to carry the captured photo through to completion:

```swift
var startingPhotoData: Data?
```

This is a transient in-memory field on the accumulator struct — it does NOT touch any `@Model` schema.

### `OnboardingFlow.completeOnboarding()` additions

Two lines added to `completeOnboarding()` (currently lines 27–50 of `OnboardingFlow.swift`):

```swift
// After UserProfile insert, before appState flag flip:
UserDefaults.standard.set(Date(), forKey: "journeyStartDate")

if let photoData = profile.startingPhotoData,
   let weightLbs = profile.weightLbs {
    let starting = BodyComposition(
        date: .now,
        weightLbs: weightLbs,
        source: .manual,
        photoData: photoData
    )
    modelContext.insert(starting)
}
```

### On continue with photo (in `StartingPhotoScreen`)

1. Write `capturedPhotoData` to `profile.startingPhotoData`
2. Advance to next onboarding screen

### On continue without photo (skipped)

1. Leave `profile.startingPhotoData` as `nil`
2. Advance to next onboarding screen

Note that the `BodyComposition` record is only written in `completeOnboarding()`, not in `StartingPhotoScreen`. This keeps the screen pure — it only updates the in-memory profile accumulator, matching the pattern of every other onboarding screen.

---

## 8. View structure

### New folder: `Features/Reflection/`

```
Features/Reflection/
├── ReflectionView.swift              ~180 lines — top-level container
├── ReflectionHeroCard.swift          ~100 lines — Day 1 vs Today comparison
├── ReflectionHeroInviteCard.swift    ~90 lines  — empty hero with Mira invite
├── TransformationStatsRow.swift      ~70 lines  — LBS | LEAN | DAYS row
├── ReflectionFilterChipRow.swift     ~90 lines  — horizontal chip row
├── MomentCard.swift                  ~200 lines — unified card, style dispatch via category
├── MomentBadge.swift                 ~50 lines  — reusable pill for milestone/tough day
└── ReflectionEmptyState.swift        ~100 lines — per-filter empty state
```

All files respect the CLAUDE.md 300-line limit and the one-type-per-file rule.

### `ReflectionView.swift` composition (top to bottom)

Inside a single `ScrollView { VStack(spacing: 20) }`:

1. **Header** — reuses existing Home wordmark + `JourneyAvatarButton`, zero duplication
2. **Section label** — `"REFLECTION"` in `Theme.violetGhost`, 11px, 1.5px tracking
3. **Headline** — `"Look how far you've come."` in `Theme.Text.primary`, 24px serif
4. **Hero slot** — branches on data:
   - If any `BodyComposition` with `photoData != nil` exists → `ReflectionHeroCard(day1:, today:)`
   - Else → `ReflectionHeroInviteCard()`
5. **Transformation stats row** — `TransformationStatsRow(stats:)` with auto-collapse for uncomputable leanDelta
6. **Filter chip row** — `ReflectionFilterChipRow(selected: $selectedFilter)`
7. **Section label** — `"YOUR MOMENTS"` in `Theme.Text.hint`, 10px, 1px tracking
8. **Timeline** — branches on results:
   - If `filteredMoments.isEmpty` → `ReflectionEmptyState(filter: selectedFilter)`
   - Else → `LazyVStack(spacing: 10) { ForEach(filteredMoments) { MomentCard(moment: $0) } }`

State:

```swift
@Query(sort: \BodyComposition.date) private var bodyCompositions: [BodyComposition]
@Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
@Query(sort: \NutritionLog.date) private var nutritionLogs: [NutritionLog]
@Query(sort: \SymptomLog.date) private var symptomLogs: [SymptomLog]
@Query private var userProfiles: [UserProfile]

@State private var selectedFilter: ReflectionFilter = .all

private let momentService = ReflectionMomentService()
private let statsService  = TransformationStatsService()
private let heroService   = HeroPhotosService()
```

In the view body, records are bundled once per render and passed to all three services:

```swift
let records = ReflectionSourceRecords(
    bodyCompositions: bodyCompositions,
    trainingSessions: trainingSessions,
    nutritionLogs: nutritionLogs,
    symptomLogs: symptomLogs,
    userProfile: userProfiles.first
)
let moments = momentService.moments(for: selectedFilter, from: records)
let stats = statsService.stats(from: records)
let heroPhotos = heroService.photos(from: records)
```

`@Query` publishes new arrays whenever any underlying SwiftData record changes. SwiftUI recomputes `body`, the services re-run, the view updates. No explicit refresh needed.

Note: `ReflectionView` itself is pure read. Any write path (the invite card's "Set Day 1 photo" flow) lives in the child view and carries its own `@Environment(\.modelContext)`.

---

## 9. UI components

### `ReflectionHeroCard`

- Two photos side by side in an `HStack(spacing: 8)`
- Each photo: `aspectRatio(3/4, contentMode: .fill)`, `cornerRadius(16)`
- Left (Day 1): `Theme.Surface.glass` background, `Theme.Border.subtle`, overlay label `"DAY 1"` + starting weight + date in `text.tertiary`
- Right (Today): `Theme.Surface.glassElevated`, `Theme.Border.medium`, overlay label `"TODAY"` in `violet.primary` + current weight + date
- Overlay bar: `Color.black.opacity(0.7)` rectangle at the bottom of each photo, 36pt tall
- No AI analysis text. Photos speak for themselves.

### `ReflectionHeroInviteCard`

- Single glass elevated card, same overall aspect ratio as the real hero
- `MiraWaveform(state: .idle, size: .small)` inline at top-left
- Headline: `"Day 1 hasn't started yet."` in 18pt serif
- Body: `"When you're ready, set your starting photo. It is how the story begins. You can always change it later."` in `Theme.Text.secondary`
- Primary: `GlowButton("Set Day 1 photo")` → opens camera/library `.confirmationDialog`
- Secondary: `"Not now"` text button in `Theme.Text.tertiary`
- On "Not now": writes `Date().addingTimeInterval(30 * 86400)` to UserDefaults key `"reflectionHeroInviteDismissedUntil"`
- Card hidden if `now < dismissedUntil`
- Card permanently gone once a `BodyComposition` with `photoData` exists (natural disappearance)

### `TransformationStatsRow`

- Three stats in a centered `HStack`
- Separators: 0.5px vertical dividers in `Theme.Border.subtle`
- Each stat: value in SF Mono 20pt/500, label below in 9pt/500 with 0.8px letter spacing, text.hint
- Value coloring: LBS in white, LEAN in `Theme.Semantic.onTrack` (green), DAYS in white
- Layout collapses gracefully when `leanDelta` is `nil`: two stats with one divider
- Labels: `"LBS LOST"` / `"LBS GAINED"` / `"LBS CHANGED"`, `"LEAN"`, `"DAYS"`

### `ReflectionFilterChipRow`

- Horizontal `ScrollView(.horizontal)` with 6pt spacing
- Each chip: `Text(filter.rawValue)` in 13pt, 10pt horizontal padding, 6pt vertical, `cornerRadius(20)`
- Active chip: `violet.primary` text, `Theme.Border.strong`, `Color.violet.opacity(0.08)` background
- Inactive chip: `Theme.Text.secondary` text, `Theme.Border.subtle`, `Theme.Surface.glass` background
- `HapticManager.selection()` on tap
- Animation: `.easeOut(duration: 0.18)` on selection change

### `MomentCard`

Unified component, style dispatch by `moment.category`. Roughly:

```swift
struct MomentCard: View {
    let moment: ReflectionMoment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topRow           // week/date label + optional badge
            photoIfPresent   // aspect 4/3 corner radius 12
            Text(moment.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
            if let description = moment.description {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Text.tertiary)
            }
            if let quote = moment.quote {
                quoteBlock(quote)
            }
            if let metadata = moment.metadataLabel {
                metadataFootnote(metadata)
            }
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardBorder)
        .cornerRadius(16)
    }

    private var cardBackground: Color {
        switch moment.category {
        case .standard: return Theme.Surface.glass
        case .milestone: return Theme.Semantic.onTrackBackground
        case .toughDay: return Theme.Semantic.warningBackground
        case .personalBest: return Theme.Surface.glass
        }
    }

    // ... similar dispatch for border and badge
}
```

### `MomentBadge`

Reusable pill component with variants for `.milestone`, `.toughDay`, `.personalBest`. 10pt text, 3pt/10pt padding, 12pt corner radius. Colors from `Theme.Semantic`.

### `ReflectionEmptyState`

Centered column with soft violet mark + headline + body, one per filter:

| Filter | Headline | Body |
|---|---|---|
| All moments | `"Your moments will live here."` | `"As you check in and show up for yourself, this space fills in on its own."` |
| Photos | `"Photo moments appear here."` | `"Every check-in photo becomes part of your story."` |
| Meals | `"Meal moments appear here."` | `"Recipes you save and meals you cook become part of your story."` |
| Gym | `"Gym moments appear here."` | `"Every session you log shows up here. From first squat to first mile."` |
| Feelings | `"Your own words live here."` | `"Words you share with Mira become part of your journey. Wins, hard days, real thoughts, all of it."` |

No CTAs. No tutorial popups. These are ambient messaging, not directives.

---

## 10. Mira voice compliance

All copy in this spec has been reviewed against `project_mira_voice.md`:

- **No banned vocabulary.** No "off-track," "behind," "missed," "failed," "fell short," "below target," "stalled," "plateau," "flat."
- **No em dashes.** Replaced with periods or rewritten per CLAUDE.md rule.
- **Pattern applied:** acknowledge what the user did, reframe as effort or progress, offer forward motion as a gift never a correction.
- **Tough days are validating, not clinical.** `"You pushed through. That counts."` not `"Your nausea levels exceeded threshold."`
- **User's own words sacred.** `quote` field on `ReflectionMoment` exists specifically so user-authored text can be rendered verbatim when it becomes available (v2).

Any new copy added during implementation MUST pass the same review.

---

## 11. Menu integration

**Modified file:** `App/MainTabView.swift`

### New menu order (inside `menuSheet` body)

```
1. My Journey        (unchanged)
2. Progress          (moved from position 7)
3. Recipes           (shifted from 2)
4. Scan              (shifted from 3)
5. Smart Calendar    (shifted from 4)
6. Pantry            (shifted from 5)
7. My Safe Space     (shifted from 6)
8. Reflection        (NEW)
9. Subscribe         (shifted from 8)
   ─── divider ───
   Settings          (unchanged)
```

### Enum case addition

```swift
enum MenuDestination: String, Identifiable, Hashable {
    case profile, progress, recipes, scan, calendar, pantry, safeSpace, reflection, subscribe, settings
    var id: String { rawValue }
}
```

### Destination view addition

```swift
case .reflection: ReflectionView()
```

**Icon:** `square.and.pencil` in `Color.violet`
**Row title:** `"Reflection"`

---

## 12. Testing strategy

Per CLAUDE.md: every service file has a corresponding test file. No view tests. Views stay thin; logic lives in services.

### Test files

```
Tests/Reflection/
├── ReflectionMomentServiceTests.swift
├── TransformationStatsServiceTests.swift
├── HeroPhotosServiceTests.swift
├── Helpers/
│   └── ReflectionTestFixtures.swift
└── Transformers/
    ├── CheckInMomentTransformerTests.swift
    ├── GymMomentTransformerTests.swift
    ├── ProteinStreakMomentTransformerTests.swift
    ├── ToughDayMomentTransformerTests.swift
    └── MilestoneMomentTransformerTests.swift

Tests/Progress/
└── CheckInSaveServiceTests.swift
```

No test files for `MealMomentTransformer` or `FeelingMomentTransformer` in v1 — both return `[]` and there is nothing meaningful to assert. Skeleton test files will be added when their sources land.

### Infrastructure

- `@MainActor` test classes where required (SwiftData models are main-bound)
- **No in-memory SwiftData stack required** — transformers take typed arrays, so fixtures are just `[BodyComposition]` literals built via the fixture helpers. For `CheckInSaveServiceTests` which exercises write paths, a `ModelConfiguration(isStoredInMemoryOnly: true)` stack is created per-test.
- `ReflectionTestFixtures.swift` provides builders for `BodyComposition`, `TrainingSession`, `NutritionLog`, `SymptomLog`, `UserProfile` with sensible defaults. Models are instantiated directly (not via a context) — SwiftData `@Model` types can be constructed without a stack for the purposes of array-based transformer tests.

### Key coverage per file

| File | Required test cases |
|---|---|
| `ReflectionMomentServiceTests` | all-filter returns merged set, each chip predicate works, empty `ReflectionSourceRecords` → empty result, one broken transformer does not blank the whole list, transformer errors are logged |
| `TransformationStatsServiceTests` | loss goal math, gain goal math, maintenance case, lean delta from leanMassLbs, lean delta from bodyFatPercent fallback, lean delta hidden when uncomputable, days from UserDefaults, days from earliest BodyComposition fallback, days nil when no anchor, negative delta clamps to 0 |
| `HeroPhotosServiceTests` | 0 records → (nil, nil), 1 record with photo → same, multiple records → earliest and latest by date, records without photoData ignored |
| `CheckInMomentTransformerTests` | only `.manual` source produces moments, HealthKit records skipped, toward-goal copy, flat-weight copy, away-from-goal copy, first check-in special copy, photoData carried through |
| `GymMomentTransformerTests` | title maps correctly per `WorkoutType`, duration + intensity formatting, muscle-group metadata only for strength sessions |
| `ProteinStreakMomentTransformerTests` | below-7-day streak produces no moment, exactly 7 days produces one moment, broken and restarted streak produces two moments, 7/14/30 all fire, mixed hit and miss days do not emit false streaks |
| `ToughDayMomentTransformerTests` | nausea ≥ 3 fires, calories < 1200 fires, 3-day protein miss fires but 2-day does not, multiple triggers on same day produce one moment (softest wins), day with no triggers produces no moment |
| `MilestoneMomentTransformerTests` | 5 lb increments fire toward loss goal, toward gain goal, anniversaries at 30/90/180/365, first-photo milestone, goal-reached milestone, no double-firing across repeated runs |
| `CheckInSaveServiceTests` | save creates BodyComposition with correct fields, photoData optional, save error propagated, `context.save()` actually called |

---

## 13. Open questions

The following items deserve a second look during implementation. None of them block the build; all have a clear default.

1. **Exact insertion point of `StartingPhotoScreen` in `OnboardingFlow.swift`.** Verified at implementation time by reading the file.

2. **HealthKit-sourced `BodyComposition` records** — confirmed decision: they feed `TransformationStatsService` and `HeroPhotosService` but do NOT produce check-in moments. The moment timeline is for intentional user actions.

3. **Pre-existing test users on real devices** have:
   - Orphaned photos in `Documents/ProgressPhotos/` (left alone)
   - No `BodyComposition` records (bug meant nothing was saved)
   - No `journeyStartDate` in UserDefaults

   Proposed behavior: on first Reflection open for these users, the invite card renders in the hero slot, transformation stats show `—`, days shows `—`, moment timeline is empty. The moment they do their first real check-in, everything lights up. `journeyStartDate` gets written the first time they open Reflection (best-effort approximation).

4. **`weightLbs` optional debate** — v1 requires weight. If users request photo-only check-ins, revisit making `BodyComposition.weightLbs` optional as a schema change.

5. **Progress dashboard coexistence** — `ProgressDashboardView.WeightTrendChart` currently reads HealthKit only. After `PhotoCheckInView` is fixed, verify the chart also reads from manual `BodyComposition` records so both flows feed the same graph. Small follow-up, not a blocker.

6. **Photo memory pressure** — a user with 100+ check-in photos loads all binary blobs in memory. `LazyVStack` view recycling should handle this for v1. If profiling at scale shows pressure, v2 generates thumbnails into a separate cache.

7. **Dynamic Type and accessibility** — all Reflection text flows through existing `Typography` styles (already Dynamic Type aware). All interactive elements need `accessibilityLabel`. Standard CLAUDE.md compliance, flagged here so it is not forgotten during implementation.

---

## 14. Implementation order (suggested)

1. **Data layer fix** — extract `CheckInSaveService`, wire `PhotoCheckInView` to persist `BodyComposition` records, delete the disk-write block. Ship and test.
2. **Onboarding change** — new `StartingPhotoScreen`, insert into `OnboardingFlow`, wire `journeyStartDate` write on completion.
3. **Service layer** — `ReflectionMoment` value type, `MomentTransformer` protocol, one transformer at a time with its test file (`CheckIn`, `Gym`, `ProteinStreak`, `ToughDay`, `Milestone`, then the empty-v1 stubs).
4. **Stats and hero services** — `TransformationStatsService`, `HeroPhotosService`, with tests.
5. **View components bottom-up** — `MomentBadge` → `MomentCard` → `ReflectionFilterChipRow` → `TransformationStatsRow` → `ReflectionEmptyState` → `ReflectionHeroCard` → `ReflectionHeroInviteCard`.
6. **Assembly** — `ReflectionView` composing all of the above.
7. **Menu integration** — reorder `MainTabView` menu, add the new destination case.
8. **End-to-end smoke test** — run in simulator, verify a fresh user sees the invite card, a user with one check-in sees a populated hero, and each filter chip produces sensible results.

---

## 15. Dependencies and blockers

- **Apple frameworks only** + `aws-amplify/amplify-swift` (already in project). No new Swift packages.
- No CDK infrastructure changes.
- No Cognito/auth changes.
- No schema migrations.

This work is fully self-contained within the iOS app.

---

*End of spec.*
