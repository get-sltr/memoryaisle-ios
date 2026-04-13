# Reflection Page v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Reflection v1 — a derived-moment scrapbook reached from the menu, wired to real data sources, with zero placecards. Along the way, fix the `PhotoCheckInView` persistence bug and add an optional starting photo step to onboarding.

**Architecture:** No new SwiftData models. A service layer (`ReflectionMomentService` + source transformers + stats/hero helpers) computes moments as pure value types from existing `BodyComposition`, `TrainingSession`, `NutritionLog`, `SymptomLog`, and `UserProfile` records. The view uses `@Query` for live updates and passes typed arrays into the services. Filter chips are predicates over the aggregated moment list. `MealMomentTransformer` and `FeelingMomentTransformer` are structurally complete but return `[]` in v1 — they wire up automatically when their sources land in a future feature.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest. Apple frameworks only. Scheme: `MemoryAisle2`. Test target: `MemoryAisle2Tests`.

**Spec reference:** `docs/superpowers/specs/2026-04-13-reflection-page-design.md`

---

## Important notes before you start

1. **Do not touch `Features/Onboarding/BodyStatsScreen.swift`.** It is dead code from an earlier design and is not imported anywhere. The real onboarding is a state machine inside `Features/Onboarding/MiraOnboardingView.swift`.

2. **Scheme is `MemoryAisle2`** (not `MemoryAisle` as shown in CLAUDE.md — CLAUDE.md is slightly outdated here).

3. **Build command** (run after any Swift change before committing):
   ```bash
   xcodebuild -scheme MemoryAisle2 \
     -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
     build 2>&1 | tail -30
   ```
   Expected output: `** BUILD SUCCEEDED **`. Treat any warning as an error per CLAUDE.md.

4. **Test command** (run to execute tests for a specific class):
   ```bash
   xcodebuild -scheme MemoryAisle2 \
     -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
     -only-testing:MemoryAisle2Tests/<TestClassName> \
     test 2>&1 | tail -30
   ```
   Expected output: `Test Suite '<TestClassName>' passed`.

5. **Commit format (per CLAUDE.md):** `[area] short description`. Examples: `[reflection] add ReflectionMoment value type`, `[fix] PhotoCheckInView persists BodyComposition`.

6. **All new files** go under `MemoryAisle2/MemoryAisle2/` (source) or `MemoryAisle2/MemoryAisle2Tests/` (tests). Paths in this plan are written as relative to the repo root.

---

## File structure overview

### New source files

```
MemoryAisle2/MemoryAisle2/Services/Reflection/
├── ReflectionMoment.swift                    (value type + enums + filter)
├── ReflectionSourceRecords.swift             (record bundle struct)
├── MomentTransformer.swift                   (protocol)
├── ReflectionMomentService.swift             (orchestrator)
├── TransformationStatsService.swift
├── HeroPhotosService.swift
└── Transformers/
    ├── CheckInMomentTransformer.swift
    ├── GymMomentTransformer.swift
    ├── ProteinStreakMomentTransformer.swift
    ├── ToughDayMomentTransformer.swift
    ├── MilestoneMomentTransformer.swift
    ├── MealMomentTransformer.swift
    └── FeelingMomentTransformer.swift

MemoryAisle2/MemoryAisle2/Services/Progress/
└── CheckInSaveService.swift                  (extracted from PhotoCheckInView)

MemoryAisle2/MemoryAisle2/Features/Reflection/
├── ReflectionView.swift
├── ReflectionHeroCard.swift
├── ReflectionHeroInviteCard.swift
├── TransformationStatsRow.swift
├── ReflectionFilterChipRow.swift
├── MomentCard.swift
├── MomentBadge.swift
└── ReflectionEmptyState.swift
```

### New test files

```
MemoryAisle2/MemoryAisle2Tests/Reflection/
├── ReflectionTestFixtures.swift              (builders)
├── ReflectionMomentServiceTests.swift
├── TransformationStatsServiceTests.swift
├── HeroPhotosServiceTests.swift
└── Transformers/
    ├── CheckInMomentTransformerTests.swift
    ├── GymMomentTransformerTests.swift
    ├── ProteinStreakMomentTransformerTests.swift
    ├── ToughDayMomentTransformerTests.swift
    └── MilestoneMomentTransformerTests.swift

MemoryAisle2/MemoryAisle2Tests/Progress/
└── CheckInSaveServiceTests.swift
```

### Modified files

```
MemoryAisle2/MemoryAisle2/Features/Progress/PhotoCheckInView.swift
MemoryAisle2/MemoryAisle2/Features/Onboarding/MiraOnboardingView.swift
MemoryAisle2/MemoryAisle2/Features/Onboarding/OnboardingFlow.swift
MemoryAisle2/MemoryAisle2/App/MainTabView.swift
```

---

## Task 1: Extract `CheckInSaveService` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Progress/CheckInSaveService.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Progress/CheckInSaveServiceTests.swift`

- [ ] **Step 1: Write the failing test file**

Create `MemoryAisle2/MemoryAisle2Tests/Progress/CheckInSaveServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import MemoryAisle2

@MainActor
final class CheckInSaveServiceTests: XCTestCase {

    private var context: ModelContext!
    private var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema([BodyComposition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    func test_save_createsBodyCompositionRecord() throws {
        let service = CheckInSaveService()
        try service.save(weight: 165.5, photoData: nil, in: context)

        let descriptor = FetchDescriptor<BodyComposition>()
        let records = try context.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].weightLbs, 165.5)
        XCTAssertEqual(records[0].source, .manual)
        XCTAssertNil(records[0].photoData)
    }

    func test_save_persistsPhotoData() throws {
        let service = CheckInSaveService()
        let sampleJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0])

        try service.save(weight: 160.0, photoData: sampleJPEG, in: context)

        let descriptor = FetchDescriptor<BodyComposition>()
        let records = try context.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].photoData, sampleJPEG)
    }

    func test_save_usesManualSource() throws {
        let service = CheckInSaveService()
        try service.save(weight: 170.0, photoData: nil, in: context)

        let descriptor = FetchDescriptor<BodyComposition>()
        let records = try context.fetch(descriptor)

        XCTAssertEqual(records[0].source, .manual)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/CheckInSaveServiceTests \
  test 2>&1 | tail -30
```

Expected: build failure — `CheckInSaveService` does not exist yet.

- [ ] **Step 3: Create `CheckInSaveService.swift`**

Create `MemoryAisle2/MemoryAisle2/Services/Progress/CheckInSaveService.swift`:

```swift
import Foundation
import SwiftData

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

- [ ] **Step 4: Run the test and verify it passes**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/CheckInSaveServiceTests \
  test 2>&1 | tail -30
```

Expected: `Test Suite 'CheckInSaveServiceTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Progress/CheckInSaveService.swift \
        MemoryAisle2/MemoryAisle2Tests/Progress/CheckInSaveServiceTests.swift
git commit -m "[fix] Extract CheckInSaveService for testable check-in persistence

Pure service over ModelContext that creates BodyComposition records
with weight, photoData, and .manual source. Unit tests cover
weight persistence, photo persistence, and source setting.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Wire `PhotoCheckInView` to use `CheckInSaveService`

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/Features/Progress/PhotoCheckInView.swift`

- [ ] **Step 1: Read the current file**

```bash
wc -l MemoryAisle2/MemoryAisle2/Features/Progress/PhotoCheckInView.swift
```

Confirm line count is ~244. Open the file and locate:
- Line 13: `@State private var weight = ""`
- Line 174: `GlowButton("Save check-in")`
- Lines 222–243: `saveCheckIn()` function

- [ ] **Step 2: Add environment and service references**

At the top of `PhotoCheckInView`, after the existing `@State` properties (around line 14), insert:

```swift
@Environment(\.modelContext) private var modelContext
private let saveService = CheckInSaveService()
```

- [ ] **Step 3: Rewrite `saveCheckIn()`**

Replace the entire function body (lines 222–243 in the original file) with:

```swift
private func saveCheckIn() {
    guard let weightLbs = Double(weight) else { return }
    do {
        try saveService.save(
            weight: weightLbs,
            photoData: photoData,
            in: modelContext
        )
        HapticManager.success()
        withAnimation(.easeOut(duration: 0.3)) {
            saved = true
        }
    } catch {
        // Save failure is non-fatal — the view simply does not advance
        // to the saved state. Logger added in a later task would go here.
    }
}
```

- [ ] **Step 4: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`. No warnings about unused variables or missing members.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Progress/PhotoCheckInView.swift
git commit -m "[fix] PhotoCheckInView persists BodyComposition via CheckInSaveService

Weight input was captured but never saved. Photos were written to
Documents/ProgressPhotos/ with no database link. Both bugs are
resolved: saveCheckIn() now calls CheckInSaveService which inserts
a BodyComposition record carrying both weight and photoData into the
SwiftData store. Disk-write path removed in the next commit.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Remove the orphaned disk-write path and disable the save button when weight is empty

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/Features/Progress/PhotoCheckInView.swift`

- [ ] **Step 1: Disable the save button when weight is empty**

Locate the `GlowButton("Save check-in")` block (around line 174). Replace it with:

```swift
let weightValue = Double(weight)
GlowButton("Save check-in") {
    saveCheckIn()
}
.padding(.horizontal, 32)
.disabled(weightValue == nil)
.opacity(weightValue == nil ? 0.5 : 1.0)
```

- [ ] **Step 2: Remove the disk-write block from `saveCheckIn`**

The old `saveCheckIn()` contained ~20 lines of disk-write code (`FileManager`, `Documents/ProgressPhotos/`, `photoData.write(to:)`). That code was already removed in Task 2 when the function body was replaced. Confirm the new `saveCheckIn()` (Task 2 Step 3) has no `FileManager` or `Documents` references.

Run:
```bash
grep -n "Documents\|FileManager\|ProgressPhotos" \
  MemoryAisle2/MemoryAisle2/Features/Progress/PhotoCheckInView.swift
```

Expected: no matches.

- [ ] **Step 3: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual smoke test**

Open the app in the simulator. Navigate to Journey → Weekly check-in. Verify:
1. The "Save check-in" button is visibly disabled (50% opacity) until you type a weight
2. Typing a valid weight enables the button
3. Tapping "Save check-in" completes without error and shows the "Check-in saved" confirmation

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Progress/PhotoCheckInView.swift
git commit -m "[fix] PhotoCheckInView requires weight, drops disk-write

Save button now disabled when weight field is empty. Photo-only
check-ins are not supported in v1. Orphaned photos in
Documents/ProgressPhotos/ on existing devices are left alone; no
migration required. BodyComposition.photoData is now the single
source of truth for check-in photos.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Add `startingPhotoData` field to `OnboardingProfile`

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Add the field to the struct**

Locate `struct OnboardingProfile` (around line 87 in `OnboardingFlow.swift`). Add one line after `goalWeightLbs`:

```swift
struct OnboardingProfile {
    var isOnGLP1 = true
    var medication: Medication?
    var modality: MedicationModality?
    var doseAmount: String?
    var injectionDay: Int?
    var injectionsPerWeek: Int?
    var pillTime: Date?
    var pillTimesPerDay: Int?
    var age: Int?
    var sex: BiologicalSex?
    var ethnicity: Ethnicity?
    var weightLbs: Double?
    var heightInches: Int?
    var goalWeightLbs: Double?
    var startingPhotoData: Data?   // NEW — transient, carries photo to completeOnboarding
    var worries: [Worry] = []
    var trainingLevel: TrainingLevel = .none
    var dietaryRestrictions: [DietaryRestriction] = []
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`. The field is optional so no existing callers break.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Onboarding/OnboardingFlow.swift
git commit -m "[onboarding] Add startingPhotoData to OnboardingProfile

Transient optional Data field for carrying a user-chosen starting
photo from the new onboarding photo step through to
completeOnboarding(), where it becomes a BodyComposition record.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Extend `MiraOnboardingView` with a `.startingPhoto` step

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/Features/Onboarding/MiraOnboardingView.swift`

This task adds a new case to `MiraQuestion`, inserts the UI into `choicesForCurrentStep`, and wires up the photo capture state. Keep the change additive; do not reorder existing cases except to bump their `Int` values.

- [ ] **Step 1: Update the `MiraQuestion` enum**

Locate lines 269–280 and replace with:

```swift
enum MiraQuestion: Int, CaseIterable {
    case intro = 0
    case goals = 1        // What matters to you? (worries)
    case training = 2     // Do you exercise?
    case dietary = 3      // Restrictions?
    case age = 4          // How old?
    case sex = 5          // Biological sex
    case heightWeight = 6 // Weight + goal
    case startingPhoto = 7 // Optional starting photo (NEW)
    case medication = 8   // On any appetite medication?
    case whichMed = 9     // Which one?
    case ready = 10       // Personalized summary
}
```

- [ ] **Step 2: Add `PhotosUI` import**

At the top of the file, change:

```swift
import SwiftUI
```

to:

```swift
import PhotosUI
import SwiftUI
```

- [ ] **Step 3: Add photo state variables**

Inside the `MiraOnboardingView` struct, after the existing `@State private var voice = VoiceManager()` line, add:

```swift
@State private var startingPhotoItem: PhotosPickerItem?
@State private var startingCameraData: Data?
@State private var showStartingSourceChoice = false
@State private var showStartingCamera = false
@State private var showStartingLibrary = false
```

- [ ] **Step 4: Add the `.startingPhoto` branch to `choicesForCurrentStep`**

Locate the `switch step` inside `choicesForCurrentStep` (around line 52). Add a new case between `.heightWeight` and `.medication`:

```swift
case .startingPhoto:
    VStack(spacing: 12) {
        // Photo preview or placeholder
        Group {
            if let data = profile.startingPhotoData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.violet.opacity(0.4))
                    Text("Add a photo")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
                .frame(width: 140, height: 180)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.Surface.glass(for: scheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                )
            }
        }
        .onTapGesture {
            HapticManager.light()
            showStartingSourceChoice = true
        }
        .accessibilityLabel(profile.startingPhotoData == nil
            ? "Add starting photo"
            : "Change starting photo")
        .confirmationDialog(
            "Starting photo",
            isPresented: $showStartingSourceChoice,
            titleVisibility: .visible
        ) {
            Button("Take Photo") { showStartingCamera = true }
            Button("Choose from Library") { showStartingLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showStartingCamera) {
            CameraPicker(imageData: $startingCameraData)
                .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showStartingLibrary,
            selection: $startingPhotoItem,
            matching: .images
        )
        .onChange(of: startingPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task { @MainActor in
                profile.startingPhotoData = try? await newValue.loadTransferable(type: Data.self)
            }
        }
        .onChange(of: startingCameraData) { _, newValue in
            guard let newValue else { return }
            profile.startingPhotoData = newValue
            startingCameraData = nil
        }

        choiceButton("Continue") { advanceTo(.medication) }
        choiceButton("Skip for now") {
            profile.startingPhotoData = nil
            advanceTo(.medication)
        }
    }
```

- [ ] **Step 5: Add the Mira question text for the new step**

Locate the `advanceTo(_:)` function (around line 235). Find the `switch next` inside it. Between the `.heightWeight` and `.medication` cases, add:

```swift
case .startingPhoto: "Want to set a starting photo? It is optional, and you can always change your mind later."
```

- [ ] **Step 6: Update the `.heightWeight` advance target**

The `.heightWeight` case's "Next" button currently calls `advanceTo(.medication)`. Change it to `advanceTo(.startingPhoto)`:

```swift
case .heightWeight:
    VStack(spacing: 12) {
        HStack(spacing: 10) {
            numberField("Weight (lbs)", value: Binding(
                get: { profile.weightLbs.map { "\(Int($0))" } ?? "" },
                set: { profile.weightLbs = Double($0) }
            ))
            numberField("Goal (lbs)", value: Binding(
                get: { profile.goalWeightLbs.map { "\(Int($0))" } ?? "" },
                set: { profile.goalWeightLbs = Double($0) }
            ))
        }
        choiceButton("Next") { advanceTo(.startingPhoto) }  // CHANGED
    }
```

- [ ] **Step 7: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Onboarding/MiraOnboardingView.swift
git commit -m "[onboarding] Add optional starting photo step to Mira flow

New .startingPhoto case in MiraQuestion sits between .heightWeight
and .medication. Photo picker uses same PhotosUI + CameraPicker
pattern as PhotoCheckInView. Skip is a first-class option with no
guilt-trip copy. Selected photo is stored on profile.startingPhotoData
for completion handler to persist as BodyComposition.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Update `OnboardingFlow.completeOnboarding()` to write journey anchor and starting record

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Update `completeOnboarding()`**

Locate `completeOnboarding()` (lines 27–50). Replace the entire function body with:

```swift
private func completeOnboarding() {
    let user = UserProfile(
        medication: profile.medication,
        medicationModality: profile.modality,
        productMode: deriveMode(),
        proteinTargetGrams: deriveProteinTarget()
    )
    user.hasCompletedOnboarding = true
    user.worries = profile.worries
    user.trainingLevel = profile.trainingLevel
    user.dietaryRestrictions = profile.dietaryRestrictions
    user.doseAmount = profile.doseAmount
    user.injectionDay = profile.injectionDay
    user.pillTime = profile.pillTime
    user.age = profile.age
    user.sex = profile.sex
    user.ethnicity = profile.ethnicity
    user.weightLbs = profile.weightLbs
    user.heightInches = profile.heightInches
    user.goalWeightLbs = profile.goalWeightLbs

    modelContext.insert(user)

    // Record the journey start date so Reflection can compute "days since"
    // and anchor anniversary milestones.
    UserDefaults.standard.set(Date(), forKey: "journeyStartDate")

    // If the user provided a starting photo, create a Day 1 BodyComposition
    // record. This anchors Reflection's hero comparison and produces the
    // first-photo milestone moment.
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

    appState.hasCompletedOnboarding = true
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Onboarding/OnboardingFlow.swift
git commit -m "[onboarding] Write journeyStartDate and starting BodyComposition

completeOnboarding() now writes the journey anchor to UserDefaults
and, if a starting photo was provided, creates the Day 1
BodyComposition record. Both writes happen in the OnboardingFlow
wrapper because it owns modelContext, keeping MiraOnboardingView
a pure state-machine view.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Create Reflection value types and transformer protocol

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/ReflectionMoment.swift`
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/ReflectionSourceRecords.swift`
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/MomentTransformer.swift`

- [ ] **Step 1: Create `ReflectionMoment.swift`**

```swift
import Foundation

struct ReflectionMoment: Identifiable, Hashable {
    let id: String
    let date: Date
    let type: MomentType
    let category: MomentCategory
    let title: String
    let description: String?
    let quote: String?
    let photoData: Data?
    let metadataLabel: String?

    init(
        id: String,
        date: Date,
        type: MomentType,
        category: MomentCategory = .standard,
        title: String,
        description: String? = nil,
        quote: String? = nil,
        photoData: Data? = nil,
        metadataLabel: String? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.category = category
        self.title = title
        self.description = description
        self.quote = quote
        self.photoData = photoData
        self.metadataLabel = metadataLabel
    }
}

enum MomentType: String, Hashable, CaseIterable {
    case checkIn
    case gym
    case proteinStreak
    case toughDay
    case milestone
    case mealMoment
    case feeling
}

enum MomentCategory: String, Hashable, CaseIterable {
    case standard
    case milestone
    case toughDay
    case personalBest
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

- [ ] **Step 2: Create `ReflectionSourceRecords.swift`**

```swift
import Foundation

struct ReflectionSourceRecords {
    let bodyCompositions: [BodyComposition]
    let trainingSessions: [TrainingSession]
    let nutritionLogs: [NutritionLog]
    let symptomLogs: [SymptomLog]
    let userProfile: UserProfile?

    init(
        bodyCompositions: [BodyComposition] = [],
        trainingSessions: [TrainingSession] = [],
        nutritionLogs: [NutritionLog] = [],
        symptomLogs: [SymptomLog] = [],
        userProfile: UserProfile? = nil
    ) {
        self.bodyCompositions = bodyCompositions
        self.trainingSessions = trainingSessions
        self.nutritionLogs = nutritionLogs
        self.symptomLogs = symptomLogs
        self.userProfile = userProfile
    }
}
```

- [ ] **Step 3: Create `MomentTransformer.swift`**

```swift
import Foundation

protocol MomentTransformer {
    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment]
}
```

- [ ] **Step 4: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/ReflectionMoment.swift \
        MemoryAisle2/MemoryAisle2/Services/Reflection/ReflectionSourceRecords.swift \
        MemoryAisle2/MemoryAisle2/Services/Reflection/MomentTransformer.swift
git commit -m "[reflection] Add value types and transformer protocol

ReflectionMoment is a pure struct (not @Model) since moments are
derived per render. MomentType enumerates source categories,
MomentCategory enumerates card styling variants, and
ReflectionFilter has a matches() predicate for filter chips.
ReflectionSourceRecords bundles typed arrays to pass into the
service layer. MomentTransformer is the protocol every source
transformer implements.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Create `ReflectionTestFixtures` helper

**Files:**
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/ReflectionTestFixtures.swift`

Test fixtures come first so every following transformer-test task can reuse them.

- [ ] **Step 1: Create the fixtures file**

```swift
import Foundation
@testable import MemoryAisle2

enum ReflectionTestFixtures {

    static func bodyComp(
        daysAgo: Int = 0,
        weightLbs: Double = 180,
        leanMass: Double? = nil,
        bodyFat: Double? = nil,
        photo: Data? = nil,
        source: BodyCompSource = .manual
    ) -> BodyComposition {
        BodyComposition(
            date: Calendar.current.date(
                byAdding: .day,
                value: -daysAgo,
                to: .now
            ) ?? .now,
            weightLbs: weightLbs,
            bodyFatPercent: bodyFat,
            leanMassLbs: leanMass,
            source: source,
            photoData: photo
        )
    }

    static func session(
        daysAgo: Int = 0,
        type: WorkoutType = .weights,
        duration: Int = 45,
        intensity: WorkoutIntensity = .moderate,
        muscles: [MuscleGroup] = [.legs]
    ) -> TrainingSession {
        TrainingSession(
            date: Calendar.current.date(
                byAdding: .day,
                value: -daysAgo,
                to: .now
            ) ?? .now,
            type: type,
            durationMinutes: duration,
            intensity: intensity,
            muscleGroups: muscles
        )
    }

    static func nutrition(
        daysAgo: Int = 0,
        protein: Double = 120,
        calories: Double = 1800,
        water: Double = 2.0,
        fiber: Double = 25
    ) -> NutritionLog {
        NutritionLog(
            date: Calendar.current.date(
                byAdding: .day,
                value: -daysAgo,
                to: .now
            ) ?? .now,
            proteinGrams: protein,
            caloriesConsumed: calories,
            waterLiters: water,
            fiberGrams: fiber
        )
    }

    static func symptom(
        daysAgo: Int = 0,
        nausea: Int = 0,
        appetite: Int = 3,
        energy: Int = 3
    ) -> SymptomLog {
        SymptomLog(
            date: Calendar.current.date(
                byAdding: .day,
                value: -daysAgo,
                to: .now
            ) ?? .now,
            nauseaLevel: nausea,
            appetiteLevel: appetite,
            energyLevel: energy
        )
    }

    static func profile(
        weightLbs: Double = 180,
        goalWeightLbs: Double = 165,
        proteinTarget: Int = 140
    ) -> UserProfile {
        let u = UserProfile(
            medication: nil,
            medicationModality: nil,
            productMode: .everyday,
            proteinTargetGrams: proteinTarget
        )
        u.weightLbs = weightLbs
        u.goalWeightLbs = goalWeightLbs
        return u
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`. (The test target builds as part of the main scheme build.)

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2Tests/Reflection/ReflectionTestFixtures.swift
git commit -m "[reflection] Add ReflectionTestFixtures helper

Builders for BodyComposition, TrainingSession, NutritionLog,
SymptomLog, UserProfile with sensible defaults and a daysAgo
parameter so tests can construct chronological scenarios without
repeating date math.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: `CheckInMomentTransformer` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/CheckInMomentTransformer.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/CheckInMomentTransformerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MemoryAisle2

final class CheckInMomentTransformerTests: XCTestCase {

    private let sut = CheckInMomentTransformer()

    func test_noRecords_returnsEmpty() throws {
        let records = ReflectionSourceRecords()
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_oneManualRecord_producesOneMoment() throws {
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 180)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = try sut.moments(from: records)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .checkIn)
        XCTAssertEqual(result[0].category, .standard)
    }

    func test_healthKitRecord_isSkipped() throws {
        let bc = ReflectionTestFixtures.bodyComp(source: .healthKit)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_firstCheckIn_hasSpecialCopy() throws {
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 180)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 180)
        )
        let moment = try sut.moments(from: records).first
        XCTAssertEqual(moment?.description, "Your very first check-in. This is where the story starts.")
    }

    func test_towardGoalCheckIn_hasProgressCopy() throws {
        // Loss goal: profile start 180, goal 165, previous check-in 180, current 178
        let older = ReflectionTestFixtures.bodyComp(daysAgo: 7, weightLbs: 180)
        let newer = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 178)
        let records = ReflectionSourceRecords(
            bodyCompositions: [older, newer],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 180, goalWeightLbs: 165)
        )
        let moments = try sut.moments(from: records)
        let latest = moments.first { $0.id == "checkin-\(newer.id)" }
        XCTAssertNotNil(latest)
        XCTAssertTrue(latest?.description?.contains("closer to your goal") ?? false)
    }

    func test_flatWeightCheckIn_hasShowUpCopy() throws {
        let older = ReflectionTestFixtures.bodyComp(daysAgo: 7, weightLbs: 180)
        let newer = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 180)
        let records = ReflectionSourceRecords(
            bodyCompositions: [older, newer],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moment = try sut.moments(from: records)
            .first { $0.id == "checkin-\(newer.id)" }
        XCTAssertEqual(moment?.description, "You showed up. That's the hard part.")
    }

    func test_photoDataCarriedThrough() throws {
        let data = Data([0xFF, 0xD8])
        let bc = ReflectionTestFixtures.bodyComp(photo: data)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records).first?.photoData, data)
    }
}
```

- [ ] **Step 2: Run test, verify compile failure**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -30
```

Expected: build fails with `CheckInMomentTransformer` undefined.

- [ ] **Step 3: Implement `CheckInMomentTransformer`**

```swift
import Foundation

struct CheckInMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        let manualRecords = records.bodyCompositions
            .filter { $0.source == .manual }
            .sorted { $0.date < $1.date }  // chronological for week numbering

        guard !manualRecords.isEmpty else { return [] }

        let journeyStart = manualRecords.first?.date ?? .now
        let goal = records.userProfile?.goalWeightLbs
        let starting = records.userProfile?.weightLbs
            ?? manualRecords.first?.weightLbs

        var result: [ReflectionMoment] = []

        for (index, record) in manualRecords.enumerated() {
            let previous = index > 0 ? manualRecords[index - 1] : nil
            let isFirst = index == 0
            let weekNumber = weekNumber(from: journeyStart, to: record.date)
            let title = isFirst ? "First check-in" : "Week \(weekNumber) check-in"

            let description = buildDescription(
                current: record,
                previous: previous,
                startingWeight: starting,
                goalWeight: goal,
                isFirst: isFirst
            )

            result.append(
                ReflectionMoment(
                    id: "checkin-\(record.id)",
                    date: record.date,
                    type: .checkIn,
                    category: .standard,
                    title: title,
                    description: description,
                    photoData: record.photoData
                )
            )
        }
        return result
    }

    private func weekNumber(from start: Date, to date: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: start, to: date)
        let days = components.day ?? 0
        return (days / 7) + 1
    }

    private func buildDescription(
        current: BodyComposition,
        previous: BodyComposition?,
        startingWeight: Double?,
        goalWeight: Double?,
        isFirst: Bool
    ) -> String {
        if isFirst {
            return "Your very first check-in. This is where the story starts."
        }
        guard let previous else {
            return "\(formatWeight(current.weightLbs)) lbs."
        }

        let currentW = current.weightLbs
        let previousW = previous.weightLbs
        let delta = currentW - previousW

        if abs(delta) < 0.1 {
            return "You showed up. That's the hard part."
        }

        guard let goal = goalWeight, let start = startingWeight else {
            return "\(formatWeight(currentW)) lbs."
        }

        let towardGoal: Bool
        if goal < start {
            towardGoal = delta < 0  // losing is toward goal
        } else if goal > start {
            towardGoal = delta > 0  // gaining is toward goal
        } else {
            towardGoal = abs(delta) < abs(previousW - start)
        }

        if towardGoal {
            let absDelta = abs(delta)
            return "\(formatWeight(currentW)) lbs. That's \(formatWeight(absDelta)) closer to your goal."
        } else {
            return "\(formatWeight(currentW)) lbs. The scale is just one signal. Look at you."
        }
    }

    private func formatWeight(_ lbs: Double) -> String {
        String(format: "%.1f", lbs)
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/CheckInMomentTransformerTests \
  test 2>&1 | tail -20
```

Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/CheckInMomentTransformer.swift \
        MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/CheckInMomentTransformerTests.swift
git commit -m "[reflection] Add CheckInMomentTransformer

Transforms manual BodyComposition records into check-in moments
with week numbering and context-aware descriptions. Skips
HealthKit-sourced records (those are for stats only, not moments).
Handles first check-in, toward-goal progress, flat weight, and
away-from-goal cases with Mira-voice copy.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: `GymMomentTransformer` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/GymMomentTransformer.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/GymMomentTransformerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MemoryAisle2

final class GymMomentTransformerTests: XCTestCase {

    private let sut = GymMomentTransformer()

    func test_noSessions_returnsEmpty() throws {
        let records = ReflectionSourceRecords()
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_oneSession_producesOneMoment() throws {
        let session = ReflectionTestFixtures.session(type: .weights)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        let result = try sut.moments(from: records)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .gym)
    }

    func test_weightsTitle() throws {
        let session = ReflectionTestFixtures.session(type: .weights)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.title, "Weights day")
    }

    func test_cardioTitle() throws {
        let session = ReflectionTestFixtures.session(type: .cardio)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.title, "Cardio session")
    }

    func test_yogaTitle() throws {
        let session = ReflectionTestFixtures.session(type: .yoga)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.title, "Yoga")
    }

    func test_descriptionFormatsDurationAndIntensity() throws {
        let session = ReflectionTestFixtures.session(
            duration: 45,
            intensity: .high
        )
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.description, "45 min · High")
    }

    func test_strengthSessionHasMuscleMetadata() throws {
        let session = ReflectionTestFixtures.session(
            type: .weights,
            muscles: [.legs]
        )
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.metadataLabel, "LEGS")
    }

    func test_strengthMultipleMusclesJoined() throws {
        let session = ReflectionTestFixtures.session(
            type: .weights,
            muscles: [.chest, .back]
        )
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.metadataLabel, "CHEST + BACK")
    }

    func test_cardioHasNoMuscleMetadata() throws {
        let session = ReflectionTestFixtures.session(
            type: .cardio,
            muscles: []
        )
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertNil(try sut.moments(from: records).first?.metadataLabel)
    }
}
```

- [ ] **Step 2: Run test, verify compile failure**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```

Expected: build fails — `GymMomentTransformer` undefined.

- [ ] **Step 3: Implement `GymMomentTransformer`**

```swift
import Foundation

struct GymMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        records.trainingSessions.map { session in
            ReflectionMoment(
                id: "gym-\(session.id)",
                date: session.date,
                type: .gym,
                category: .standard,
                title: title(for: session.type),
                description: "\(session.durationMinutes) min · \(session.intensity.rawValue)",
                metadataLabel: metadataLabel(for: session)
            )
        }
    }

    private func title(for type: WorkoutType) -> String {
        switch type {
        case .weights:    return "Weights day"
        case .cardio:     return "Cardio session"
        case .crossfit:   return "CrossFit"
        case .bodyweight: return "Bodyweight"
        case .yoga:       return "Yoga"
        case .walking:    return "Walk"
        case .hiit:       return "HIIT"
        case .sports:     return "Sports"
        }
    }

    private func metadataLabel(for session: TrainingSession) -> String? {
        guard session.isStrengthTraining, !session.muscleGroups.isEmpty else {
            return nil
        }
        return session.muscleGroups
            .map { $0.rawValue.uppercased() }
            .joined(separator: " + ")
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/GymMomentTransformerTests \
  test 2>&1 | tail -20
```

Expected: all 9 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/GymMomentTransformer.swift \
        MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/GymMomentTransformerTests.swift
git commit -m "[reflection] Add GymMomentTransformer

One moment per TrainingSession, title dispatched by WorkoutType,
description combines duration and intensity, muscle-group metadata
renders in all-caps joined by plus-space for strength sessions
only. Five gym sessions a week equals five celebrations.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: `ProteinStreakMomentTransformer` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/ProteinStreakMomentTransformer.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/ProteinStreakMomentTransformerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MemoryAisle2

final class ProteinStreakMomentTransformerTests: XCTestCase {

    private let sut = ProteinStreakMomentTransformer()

    func test_noLogs_returnsEmpty() throws {
        let records = ReflectionSourceRecords(
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_belowSevenDays_producesNoMoment() throws {
        let logs = (0..<6).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 150)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_exactlySevenDays_producesSevenDayMoment() throws {
        let logs = (0..<7).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 150)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        let moments = try sut.moments(from: records)
        XCTAssertEqual(moments.count, 1)
        XCTAssertEqual(moments[0].title, "7 days of protein")
        XCTAssertEqual(moments[0].category, .milestone)
    }

    func test_fourteenDays_producesBothSevenAndFourteen() throws {
        let logs = (0..<14).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 150)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        let moments = try sut.moments(from: records)
        XCTAssertEqual(moments.count, 2)
        XCTAssertTrue(moments.contains { $0.title == "7 days of protein" })
        XCTAssertTrue(moments.contains { $0.title == "Two weeks strong" })
    }

    func test_brokenStreakThenRestart_producesTwoSevenDayMoments() throws {
        var logs: [NutritionLog] = []
        // First streak: days 20-14 (7 days, hit target)
        for day in 14...20 {
            logs.append(ReflectionTestFixtures.nutrition(daysAgo: day, protein: 150))
        }
        // Gap: day 13 missed
        logs.append(ReflectionTestFixtures.nutrition(daysAgo: 13, protein: 80))
        // Second streak: days 12-6 (7 days, hit target)
        for day in 6...12 {
            logs.append(ReflectionTestFixtures.nutrition(daysAgo: day, protein: 150))
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        let sevenDayMoments = try sut.moments(from: records)
            .filter { $0.title == "7 days of protein" }
        XCTAssertEqual(sevenDayMoments.count, 2)
    }

    func test_missedDayInMiddle_doesNotFire() throws {
        var logs = (0..<7).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 150)
        }
        logs[3] = ReflectionTestFixtures.nutrition(daysAgo: 3, protein: 80)
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }
}
```

- [ ] **Step 2: Run test, verify compile failure**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```

Expected: build fails.

- [ ] **Step 3: Implement `ProteinStreakMomentTransformer`**

```swift
import Foundation

struct ProteinStreakMomentTransformer: MomentTransformer {

    private struct Threshold {
        let days: Int
        let title: String
        let description: String
    }

    private let thresholds: [Threshold] = [
        Threshold(days: 7, title: "7 days of protein", description: "Your muscles are listening."),
        Threshold(days: 14, title: "Two weeks strong", description: "You are making this part automatic."),
        Threshold(days: 30, title: "A whole month", description: "30 days of fueling yourself right."),
        Threshold(days: 60, title: "60 days unshakeable", description: "This is who you are now."),
        Threshold(days: 90, title: "90 days", description: "The rhythm is real."),
        Threshold(days: 180, title: "Six months", description: "Half a year of showing up for yourself.")
    ]

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        guard let target = records.userProfile?.proteinTargetGrams, target > 0 else {
            return []
        }

        let sortedLogs = records.nutritionLogs.sorted { $0.date < $1.date }
        let streaks = computeStreaks(logs: sortedLogs, target: Double(target))

        var result: [ReflectionMoment] = []
        for streak in streaks {
            for threshold in thresholds where streak.length >= threshold.days {
                result.append(
                    ReflectionMoment(
                        id: "proteinStreak-\(threshold.days)-\(streak.endDateISO)",
                        date: streak.endDate,
                        type: .proteinStreak,
                        category: .milestone,
                        title: threshold.title,
                        description: threshold.description
                    )
                )
            }
        }
        return result
    }

    private struct Streak {
        let length: Int
        let endDate: Date
        var endDateISO: String {
            let df = ISO8601DateFormatter()
            df.formatOptions = [.withInternetDateTime]
            return df.string(from: endDate)
        }
    }

    private func computeStreaks(logs: [NutritionLog], target: Double) -> [Streak] {
        guard !logs.isEmpty else { return [] }

        var streaks: [Streak] = []
        var currentLength = 0
        var currentEnd: Date?
        var previousDate: Date?

        for log in logs {
            let hit = log.proteinGrams >= target
            let consecutive = previousDate.map {
                Calendar.current.dateComponents([.day], from: $0, to: log.date).day == 1
            } ?? true

            if hit && consecutive {
                currentLength += 1
                currentEnd = log.date
            } else if hit {
                if let end = currentEnd, currentLength >= 7 {
                    streaks.append(Streak(length: currentLength, endDate: end))
                }
                currentLength = 1
                currentEnd = log.date
            } else {
                if let end = currentEnd, currentLength >= 7 {
                    streaks.append(Streak(length: currentLength, endDate: end))
                }
                currentLength = 0
                currentEnd = nil
            }
            previousDate = log.date
        }

        if let end = currentEnd, currentLength >= 7 {
            streaks.append(Streak(length: currentLength, endDate: end))
        }

        return streaks
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/ProteinStreakMomentTransformerTests \
  test 2>&1 | tail -20
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/ProteinStreakMomentTransformer.swift \
        MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/ProteinStreakMomentTransformerTests.swift
git commit -m "[reflection] Add ProteinStreakMomentTransformer

Computes consecutive-day streaks of meeting proteinTargetGrams,
then emits a milestone moment at each threshold (7, 14, 30, 60,
90, 180). Broken-and-restarted streaks each produce their own
moment. Missed days inside a would-be streak correctly do not fire.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: `ToughDayMomentTransformer` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/ToughDayMomentTransformer.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/ToughDayMomentTransformerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MemoryAisle2

final class ToughDayMomentTransformerTests: XCTestCase {

    private let sut = ToughDayMomentTransformer()

    func test_nauseaThreeFires() throws {
        let symptom = ReflectionTestFixtures.symptom(daysAgo: 1, nausea: 3)
        let records = ReflectionSourceRecords(
            symptomLogs: [symptom],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moment = try sut.moments(from: records).first
        XCTAssertNotNil(moment)
        XCTAssertEqual(moment?.title, "A tough day")
        XCTAssertEqual(moment?.category, .toughDay)
    }

    func test_nauseaBelowThreeDoesNotFire() throws {
        let symptom = ReflectionTestFixtures.symptom(daysAgo: 1, nausea: 2)
        let records = ReflectionSourceRecords(
            symptomLogs: [symptom],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_lowCaloriesFires() throws {
        let log = ReflectionTestFixtures.nutrition(daysAgo: 2, calories: 900)
        let records = ReflectionSourceRecords(
            nutritionLogs: [log],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moment = try sut.moments(from: records).first
        XCTAssertEqual(moment?.title, "Low fuel day")
    }

    func test_caloriesAtThresholdDoesNotFire() throws {
        let log = ReflectionTestFixtures.nutrition(daysAgo: 2, calories: 1200)
        let records = ReflectionSourceRecords(
            nutritionLogs: [log],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_threeDayProteinMissFires() throws {
        // proteinTarget 140, so 0.7x = 98. Three days below 98 in a row.
        let logs = (0..<3).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 80)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        let moment = try sut.moments(from: records).first
        XCTAssertEqual(moment?.title, "A quieter stretch")
    }

    func test_twoDayProteinMissDoesNotFire() throws {
        let logs = (0..<2).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 80)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_multipleTriggersSameDayProducesOne() throws {
        let nausea = ReflectionTestFixtures.symptom(daysAgo: 1, nausea: 4)
        let lowCal = ReflectionTestFixtures.nutrition(daysAgo: 1, calories: 800)
        let records = ReflectionSourceRecords(
            nutritionLogs: [lowCal],
            symptomLogs: [nausea],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moments = try sut.moments(from: records)
        XCTAssertEqual(moments.count, 1)
        // Nausea is softest-first, so title should be the nausea variant
        XCTAssertEqual(moments[0].title, "A tough day")
    }
}
```

- [ ] **Step 2: Run test, verify compile failure**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```

Expected: build fails.

- [ ] **Step 3: Implement `ToughDayMomentTransformer`**

```swift
import Foundation

struct ToughDayMomentTransformer: MomentTransformer {

    private enum Trigger: Int {
        case nausea = 0
        case lowCalories = 1
        case proteinMiss = 2

        var title: String {
            switch self {
            case .nausea: return "A tough day"
            case .lowCalories: return "Low fuel day"
            case .proteinMiss: return "A quieter stretch"
            }
        }

        var description: String {
            switch self {
            case .nausea: return "You pushed through. That counts."
            case .lowCalories: return "Some days the body just will not eat. You are still here."
            case .proteinMiss: return "A few softer days. And you are still here."
            }
        }
    }

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        let target = records.userProfile?.proteinTargetGrams ?? 0
        let proteinThreshold = Double(target) * 0.7

        var triggersByDay: [Date: Trigger] = [:]

        // Nausea
        for log in records.symptomLogs where log.nauseaLevel >= 3 {
            let day = Calendar.current.startOfDay(for: log.date)
            triggersByDay[day] = min(triggersByDay[day] ?? .proteinMiss, .nausea)
        }

        // Low calories
        for log in records.nutritionLogs where log.caloriesConsumed < 1200 {
            let day = Calendar.current.startOfDay(for: log.date)
            let existing = triggersByDay[day]
            if existing == nil || existing! == .proteinMiss {
                triggersByDay[day] = .lowCalories
            }
        }

        // Three-day protein miss — emit on the third day
        let sortedLogs = records.nutritionLogs.sorted { $0.date < $1.date }
        var missStreak = 0
        var missStreakStart: Date?
        for log in sortedLogs {
            if log.proteinGrams < proteinThreshold {
                if missStreak == 0 { missStreakStart = log.date }
                missStreak += 1
                if missStreak >= 3 {
                    let day = Calendar.current.startOfDay(for: log.date)
                    if triggersByDay[day] == nil {
                        triggersByDay[day] = .proteinMiss
                    }
                }
            } else {
                missStreak = 0
                missStreakStart = nil
            }
        }
        _ = missStreakStart  // silence unused-var warning

        // Build moments
        return triggersByDay.map { (day, trigger) in
            let df = ISO8601DateFormatter()
            df.formatOptions = [.withInternetDateTime]
            return ReflectionMoment(
                id: "toughDay-\(df.string(from: day))",
                date: day,
                type: .toughDay,
                category: .toughDay,
                title: trigger.title,
                description: trigger.description
            )
        }
        .sorted { $0.date > $1.date }
    }
}

extension ToughDayMomentTransformer.Trigger: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/ToughDayMomentTransformerTests \
  test 2>&1 | tail -20
```

Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/ToughDayMomentTransformer.swift \
        MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/ToughDayMomentTransformerTests.swift
git commit -m "[reflection] Add ToughDayMomentTransformer

Detects hard days from three signals: nausea >= 3, calories < 1200,
or three consecutive days of protein below 70% of target. Multiple
triggers on the same day dedupe to one moment (softest-first:
nausea, low cal, protein miss). Copy is always validating, never
clinical.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: `MilestoneMomentTransformer` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/MilestoneMomentTransformer.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/MilestoneMomentTransformerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MemoryAisle2

final class MilestoneMomentTransformerTests: XCTestCase {

    private let sut = MilestoneMomentTransformer()

    func test_lossGoal_fivePoundCrossing_fires() throws {
        // Start 200, goal 175. Current 195 → crossed 5 lbs down.
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 195)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let moments = try sut.moments(from: records)
        XCTAssertTrue(moments.contains { $0.title == "5 pounds down" })
    }

    func test_gainGoal_fivePoundCrossing_fires() throws {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 155)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 161)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 155, goalWeightLbs: 175)
        )
        let moments = try sut.moments(from: records)
        XCTAssertTrue(moments.contains { $0.title == "5 pounds up" })
    }

    func test_tenPoundCrossing_hasDoubleDigitsCopy() throws {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 60, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 189)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let tenMoment = try sut.moments(from: records)
            .first { $0.title == "10 pounds down" }
        XCTAssertNotNil(tenMoment)
        XCTAssertEqual(tenMoment?.description, "Double digits. That is a real one.")
    }

    func test_firstPhotoMilestone_fires() throws {
        let data = Data([0xFF])
        let bc = ReflectionTestFixtures.bodyComp(photo: data)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moments = try sut.moments(from: records)
        XCTAssertTrue(moments.contains { $0.id == "milestoneFirstPhoto" })
    }

    func test_noPhoto_noFirstPhotoMilestone() throws {
        let bc = ReflectionTestFixtures.bodyComp(photo: nil)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moments = try sut.moments(from: records)
        XCTAssertFalse(moments.contains { $0.id == "milestoneFirstPhoto" })
    }

    func test_goalReached_fires() throws {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 120, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 175)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let atGoal = try sut.moments(from: records)
            .first { $0.description == "You hit your goal." }
        XCTAssertNotNil(atGoal)
    }

    func test_noDoubleFiring() throws {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let mid1 = ReflectionTestFixtures.bodyComp(daysAgo: 15, weightLbs: 195)
        let mid2 = ReflectionTestFixtures.bodyComp(daysAgo: 10, weightLbs: 193)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 190)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, mid1, mid2, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let fivePound = try sut.moments(from: records)
            .filter { $0.title == "5 pounds down" }
        XCTAssertEqual(fivePound.count, 1)
    }
}
```

- [ ] **Step 2: Run test, verify compile failure**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```

Expected: build fails.

- [ ] **Step 3: Implement `MilestoneMomentTransformer`**

```swift
import Foundation

struct MilestoneMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        var result: [ReflectionMoment] = []

        let sortedRecords = records.bodyCompositions.sorted { $0.date < $1.date }

        // First-photo milestone
        if let firstPhoto = sortedRecords.first(where: { $0.photoData != nil }) {
            result.append(
                ReflectionMoment(
                    id: "milestoneFirstPhoto",
                    date: firstPhoto.date,
                    type: .milestone,
                    category: .milestone,
                    title: "Day 1",
                    description: "Where the journey starts.",
                    photoData: firstPhoto.photoData
                )
            )
        }

        // Weight-toward-goal milestones
        guard let profile = records.userProfile,
              let goal = profile.goalWeightLbs,
              let startingWeight = sortedRecords.first?.weightLbs ?? profile.weightLbs
        else {
            return result
        }

        let isLossGoal = goal < startingWeight
        let isGainGoal = goal > startingWeight
        guard isLossGoal || isGainGoal else { return result }

        let direction = isLossGoal ? "down" : "up"

        // Find every 5-lb milestone that has been crossed by the most recent record
        let mostRecent = sortedRecords.last?.weightLbs ?? startingWeight
        let deltaToward: Double
        if isLossGoal {
            deltaToward = max(0, startingWeight - mostRecent)
        } else {
            deltaToward = max(0, mostRecent - startingWeight)
        }
        let maxMilestone = Int(deltaToward / 5) * 5

        guard maxMilestone >= 5 else { return result }

        for lbs in stride(from: 5, through: maxMilestone, by: 5) {
            // Find the first record that crossed this milestone
            let targetWeight = isLossGoal
                ? startingWeight - Double(lbs)
                : startingWeight + Double(lbs)
            let crossingRecord: BodyComposition? = sortedRecords.first { rec in
                isLossGoal ? rec.weightLbs <= targetWeight : rec.weightLbs >= targetWeight
            }
            guard let crossing = crossingRecord else { continue }

            result.append(
                ReflectionMoment(
                    id: "milestoneWeight-\(lbs)",
                    date: crossing.date,
                    type: .milestone,
                    category: .milestone,
                    title: "\(lbs) pounds \(direction)",
                    description: milestoneDescription(lbs: lbs, goal: Int(goal), startingWeight: startingWeight, isLossGoal: isLossGoal),
                    photoData: crossing.photoData
                )
            )
        }

        // Check if goal was reached
        let goalReached = isLossGoal ? mostRecent <= goal : mostRecent >= goal
        if goalReached, let reachRecord = sortedRecords.first(where: { rec in
            isLossGoal ? rec.weightLbs <= goal : rec.weightLbs >= goal
        }) {
            result.append(
                ReflectionMoment(
                    id: "milestoneGoalReached",
                    date: reachRecord.date,
                    type: .milestone,
                    category: .milestone,
                    title: "You hit your goal.",
                    description: "You hit your goal.",
                    photoData: reachRecord.photoData
                )
            )
        }

        return result
    }

    private func milestoneDescription(
        lbs: Int,
        goal: Int,
        startingWeight: Double,
        isLossGoal: Bool
    ) -> String {
        if lbs == 5 {
            return "First milestone on the way to \(goal) lbs."
        } else if lbs == 10 {
            return "Double digits. That is a real one."
        }
        let totalDelta = abs(Int(startingWeight) - goal)
        if totalDelta > 0 && Double(lbs) >= Double(totalDelta) * 0.5 && Double(lbs) < Double(totalDelta) {
            return "Halfway there."
        }
        return "\(lbs) pounds closer."
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/MilestoneMomentTransformerTests \
  test 2>&1 | tail -20
```

Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/MilestoneMomentTransformer.swift \
        MemoryAisle2/MemoryAisle2Tests/Reflection/Transformers/MilestoneMomentTransformerTests.swift
git commit -m "[reflection] Add MilestoneMomentTransformer

Produces weight-toward-goal milestones (every 5 lbs), the first-
photo milestone, and a goal-reached milestone when the user hits
their target. Works for both loss and gain goals. Stable IDs
prevent double-firing across renders.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Empty stubs for `MealMomentTransformer` and `FeelingMomentTransformer`

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/MealMomentTransformer.swift`
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/FeelingMomentTransformer.swift`

These transformers structurally implement the protocol but return `[]` in v1. Their sources (meal-with-photo data, persisted Mira chats) do not exist yet. Leaving these stubs in place means filter chips work day one, and when the sources land in a future feature, filling in the body is the only change required.

- [ ] **Step 1: Create `MealMomentTransformer.swift`**

```swift
import Foundation

struct MealMomentTransformer: MomentTransformer {

    // Returns [] in v1. When saved recipes (task #11 — Mira recipe browser)
    // and cooked-meal tracking (Meal.photoData + Meal.wasEaten) land, this
    // body will query those fields and emit meal moments.
    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        []
    }
}
```

- [ ] **Step 2: Create `FeelingMomentTransformer.swift`**

```swift
import Foundation

struct FeelingMomentTransformer: MomentTransformer {

    // Returns [] in v1. When Mira chat persistence lands, this body will
    // query stored messages for emotionally significant moments and quote
    // the user's own words back into the timeline.
    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        []
    }
}
```

- [ ] **Step 3: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/MealMomentTransformer.swift \
        MemoryAisle2/MemoryAisle2/Services/Reflection/Transformers/FeelingMomentTransformer.swift
git commit -m "[reflection] Add empty Meal and Feeling transformer stubs

Structural placeholders that return [] today and fill in when
their backing data sources land (task #11 recipe browser for
meals, future Mira chat persistence for feelings). Keeps the
Meals and Feelings filter chips wired without showing placecards.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: `ReflectionMomentService` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/ReflectionMomentService.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/ReflectionMomentServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MemoryAisle2

@MainActor
final class ReflectionMomentServiceTests: XCTestCase {

    func test_emptyRecords_returnsEmpty() {
        let service = ReflectionMomentService()
        let result = service.moments(for: .all, from: ReflectionSourceRecords())
        XCTAssertEqual(result, [])
    }

    func test_allFilter_mergesAllTransformerOutputs() {
        let service = ReflectionMomentService()
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0)
        let session = ReflectionTestFixtures.session(daysAgo: 1)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            trainingSessions: [session],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = service.moments(for: .all, from: records)
        XCTAssertTrue(result.contains { $0.type == .checkIn })
        XCTAssertTrue(result.contains { $0.type == .gym })
    }

    func test_sortedByDateDescending() {
        let service = ReflectionMomentService()
        let oldBC = ReflectionTestFixtures.bodyComp(daysAgo: 10)
        let newSession = ReflectionTestFixtures.session(daysAgo: 1)
        let records = ReflectionSourceRecords(
            bodyCompositions: [oldBC],
            trainingSessions: [newSession],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = service.moments(for: .all, from: records)
        XCTAssertGreaterThanOrEqual(result.count, 2)
        for i in 0..<(result.count - 1) {
            XCTAssertGreaterThanOrEqual(result[i].date, result[i + 1].date)
        }
    }

    func test_photosFilter_onlyPhotosSurvive() {
        let service = ReflectionMomentService()
        let withPhoto = ReflectionTestFixtures.bodyComp(daysAgo: 0, photo: Data([0xFF]))
        let withoutPhoto = ReflectionTestFixtures.bodyComp(daysAgo: 1, photo: nil)
        let session = ReflectionTestFixtures.session(daysAgo: 2)
        let records = ReflectionSourceRecords(
            bodyCompositions: [withPhoto, withoutPhoto],
            trainingSessions: [session],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = service.moments(for: .photos, from: records)
        for moment in result {
            XCTAssertNotNil(moment.photoData)
        }
        XCTAssertTrue(result.contains { $0.type == .checkIn })
    }

    func test_gymFilter_onlyGymTypeSurvives() {
        let service = ReflectionMomentService()
        let session = ReflectionTestFixtures.session(daysAgo: 0)
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 1)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            trainingSessions: [session],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = service.moments(for: .gym, from: records)
        XCTAssertTrue(result.allSatisfy { $0.type == .gym })
    }

    func test_mealsFilter_emptyInV1() {
        let service = ReflectionMomentService()
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(service.moments(for: .meals, from: records), [])
    }

    func test_feelingsFilter_emptyInV1() {
        let service = ReflectionMomentService()
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(service.moments(for: .feelings, from: records), [])
    }

    func test_oneBrokenTransformer_othersStillRun() {
        struct BrokenTransformer: MomentTransformer {
            func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
                struct SomeError: Error {}
                throw SomeError()
            }
        }
        let service = ReflectionMomentService(
            transformers: [BrokenTransformer(), GymMomentTransformer()]
        )
        let session = ReflectionTestFixtures.session(daysAgo: 0)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        let result = service.moments(for: .all, from: records)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .gym)
    }
}
```

- [ ] **Step 2: Run test, verify compile failure**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```

Expected: build fails — `ReflectionMomentService` undefined.

- [ ] **Step 3: Implement `ReflectionMomentService`**

```swift
import Foundation

@MainActor
final class ReflectionMomentService {

    private let transformers: [MomentTransformer]

    init(transformers: [MomentTransformer] = ReflectionMomentService.defaultTransformers()) {
        self.transformers = transformers
    }

    static func defaultTransformers() -> [MomentTransformer] {
        [
            CheckInMomentTransformer(),
            GymMomentTransformer(),
            ProteinStreakMomentTransformer(),
            ToughDayMomentTransformer(),
            MilestoneMomentTransformer(),
            MealMomentTransformer(),
            FeelingMomentTransformer()
        ]
    }

    func moments(
        for filter: ReflectionFilter,
        from records: ReflectionSourceRecords
    ) -> [ReflectionMoment] {
        let all = transformers.flatMap { transformer -> [ReflectionMoment] in
            do {
                return try transformer.moments(from: records)
            } catch {
                // Log and continue — one broken transformer never blanks
                // the whole timeline.
                print("[Reflection] Transformer failed: \(error)")
                return []
            }
        }
        let sorted = all.sorted { $0.date > $1.date }
        return sorted.filter { filter.matches($0) }
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/ReflectionMomentServiceTests \
  test 2>&1 | tail -20
```

Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/ReflectionMomentService.swift \
        MemoryAisle2/MemoryAisle2Tests/Reflection/ReflectionMomentServiceTests.swift
git commit -m "[reflection] Add ReflectionMomentService orchestrator

Aggregates all source transformers, sorts by date desc, applies
the active filter predicate. Broken transformers log and are
skipped so the timeline never blanks. Default transformer list
is constructed via a static factory so tests can inject custom
lists easily.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: `TransformationStatsService` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/TransformationStatsService.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/TransformationStatsServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MemoryAisle2

final class TransformationStatsServiceTests: XCTestCase {

    private let sut = TransformationStatsService()

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "journeyStartDate")
    }

    func test_lossGoal_computesLbsLost() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 188)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let stats = sut.stats(from: records)
        XCTAssertEqual(stats.lbsDelta, 12)
        XCTAssertEqual(stats.direction, .lost)
    }

    func test_gainGoal_computesLbsGained() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 155)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 162)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 155, goalWeightLbs: 175)
        )
        let stats = sut.stats(from: records)
        XCTAssertEqual(stats.lbsDelta, 7)
        XCTAssertEqual(stats.direction, .gained)
    }

    func test_lossGoalButGained_clampsToZero() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 205)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let stats = sut.stats(from: records)
        XCTAssertEqual(stats.lbsDelta, 0)
        XCTAssertEqual(stats.direction, .lost)
    }

    func test_leanMassDelta_computedWhenAvailable() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200, leanMass: 140)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 188, leanMass: 138)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(sut.stats(from: records).leanDelta, -2)
    }

    func test_leanMassDelta_nilWhenUncomputable() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 188)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertNil(sut.stats(from: records).leanDelta)
    }

    func test_daysFromUserDefaults() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        UserDefaults.standard.set(thirtyDaysAgo, forKey: "journeyStartDate")
        let records = ReflectionSourceRecords(userProfile: ReflectionTestFixtures.profile())
        XCTAssertEqual(sut.stats(from: records).days, 30)
    }

    func test_daysFallsBackToEarliestBodyComposition() {
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 14, weightLbs: 200)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(sut.stats(from: records).days, 14)
    }

    func test_noAnchor_daysIsNil() {
        let records = ReflectionSourceRecords(userProfile: ReflectionTestFixtures.profile())
        XCTAssertNil(sut.stats(from: records).days)
    }
}
```

- [ ] **Step 2: Run test, verify compile failure**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```

Expected: build fails.

- [ ] **Step 3: Implement `TransformationStatsService`**

```swift
import Foundation

struct TransformationStats: Equatable {
    let lbsDelta: Double?
    let direction: Direction
    let leanDelta: Double?
    let days: Int?

    enum Direction: Equatable {
        case lost
        case gained
        case none
    }
}

struct TransformationStatsService {

    func stats(from records: ReflectionSourceRecords) -> TransformationStats {
        let sorted = records.bodyCompositions.sorted { $0.date < $1.date }
        let profile = records.userProfile

        let starting: Double? = sorted.first?.weightLbs ?? profile?.weightLbs
        let current: Double? = sorted.last?.weightLbs ?? starting
        let goal = profile?.goalWeightLbs

        let (lbsDelta, direction) = computeLbsDelta(
            starting: starting,
            current: current,
            goal: goal
        )
        let leanDelta = computeLeanDelta(records: sorted)
        let days = computeDays(records: sorted)

        return TransformationStats(
            lbsDelta: lbsDelta,
            direction: direction,
            leanDelta: leanDelta,
            days: days
        )
    }

    private func computeLbsDelta(
        starting: Double?,
        current: Double?,
        goal: Double?
    ) -> (Double?, TransformationStats.Direction) {
        guard let start = starting, let now = current, let g = goal else {
            return (nil, .none)
        }
        if g < start {
            return (max(0, start - now), .lost)
        } else if g > start {
            return (max(0, now - start), .gained)
        } else {
            return (abs(now - start), .none)
        }
    }

    private func computeLeanDelta(records: [BodyComposition]) -> Double? {
        guard records.count >= 2 else { return nil }
        let first = records.first!
        let last = records.last!
        let hasFirstLean = first.leanMassLbs != nil || first.bodyFatPercent != nil
        let hasLastLean = last.leanMassLbs != nil || last.bodyFatPercent != nil
        guard hasFirstLean && hasLastLean else { return nil }
        return last.computedLeanMass - first.computedLeanMass
    }

    private func computeDays(records: [BodyComposition]) -> Int? {
        if let stored = UserDefaults.standard.object(forKey: "journeyStartDate") as? Date {
            return daysBetween(stored, .now)
        }
        if let earliest = records.first?.date {
            return daysBetween(earliest, .now)
        }
        return nil
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/TransformationStatsServiceTests \
  test 2>&1 | tail -20
```

Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/TransformationStatsService.swift \
        MemoryAisle2/MemoryAisle2Tests/Reflection/TransformationStatsServiceTests.swift
git commit -m "[reflection] Add TransformationStatsService

Computes (lbsDelta, direction, leanDelta, days) for the hero stats
row. Works for loss, gain, and maintenance goals. Clamps negative
progress to 0. leanDelta requires both earliest and latest records
to have either leanMassLbs or bodyFatPercent; otherwise nil and
the row collapses. Days reads journeyStartDate from UserDefaults
with fallback to earliest BodyComposition.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: `HeroPhotosService` with tests

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Services/Reflection/HeroPhotosService.swift`
- Create: `MemoryAisle2/MemoryAisle2Tests/Reflection/HeroPhotosServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MemoryAisle2

final class HeroPhotosServiceTests: XCTestCase {

    private let sut = HeroPhotosService()

    func test_noRecords_returnsNilTuple() {
        let records = ReflectionSourceRecords()
        let photos = sut.photos(from: records)
        XCTAssertNil(photos.day1)
        XCTAssertNil(photos.today)
    }

    func test_singleRecordWithPhoto_returnsSameForBoth() {
        let data = Data([0xFF, 0xD8])
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0, photo: data)
        let records = ReflectionSourceRecords(bodyCompositions: [bc])
        let photos = sut.photos(from: records)
        XCTAssertEqual(photos.day1, data)
        XCTAssertEqual(photos.today, data)
    }

    func test_multipleRecords_returnsEarliestAndLatest() {
        let old = Data([0xAA])
        let new = Data([0xBB])
        let older = ReflectionTestFixtures.bodyComp(daysAgo: 30, photo: old)
        let newer = ReflectionTestFixtures.bodyComp(daysAgo: 0, photo: new)
        let records = ReflectionSourceRecords(bodyCompositions: [newer, older])
        let photos = sut.photos(from: records)
        XCTAssertEqual(photos.day1, old)
        XCTAssertEqual(photos.today, new)
    }

    func test_recordsWithoutPhotoDataIgnored() {
        let data = Data([0xCC])
        let withoutPhoto = ReflectionTestFixtures.bodyComp(daysAgo: 30, photo: nil)
        let withPhoto = ReflectionTestFixtures.bodyComp(daysAgo: 0, photo: data)
        let records = ReflectionSourceRecords(bodyCompositions: [withoutPhoto, withPhoto])
        let photos = sut.photos(from: records)
        XCTAssertEqual(photos.day1, data)
        XCTAssertEqual(photos.today, data)
    }
}
```

- [ ] **Step 2: Run test, verify compile failure**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```

Expected: build fails.

- [ ] **Step 3: Implement `HeroPhotosService`**

```swift
import Foundation

struct HeroPhotos {
    let day1: Data?
    let today: Data?
    let day1Date: Date?
    let todayDate: Date?
    let day1Weight: Double?
    let todayWeight: Double?
}

struct HeroPhotosService {

    func photos(from records: ReflectionSourceRecords) -> HeroPhotos {
        let withPhotos = records.bodyCompositions
            .filter { $0.photoData != nil }
            .sorted { $0.date < $1.date }

        guard let first = withPhotos.first, let last = withPhotos.last else {
            return HeroPhotos(
                day1: nil, today: nil,
                day1Date: nil, todayDate: nil,
                day1Weight: nil, todayWeight: nil
            )
        }

        return HeroPhotos(
            day1: first.photoData,
            today: last.photoData,
            day1Date: first.date,
            todayDate: last.date,
            day1Weight: first.weightLbs,
            todayWeight: last.weightLbs
        )
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisle2Tests/HeroPhotosServiceTests \
  test 2>&1 | tail -20
```

Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Services/Reflection/HeroPhotosService.swift \
        MemoryAisle2/MemoryAisle2Tests/Reflection/HeroPhotosServiceTests.swift
git commit -m "[reflection] Add HeroPhotosService

Selects earliest and latest BodyComposition records with photoData
for the Day 1 vs Today hero. Returns a HeroPhotos struct carrying
both image data and corresponding date/weight for overlay labels.
Records without photos are ignored.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: `MomentBadge` component

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Features/Reflection/MomentBadge.swift`

Pure SwiftUI view. No tests (views stay thin per CLAUDE.md).

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct MomentBadge: View {
    enum Variant {
        case milestone
        case toughDay
        case personalBest
    }

    let variant: Variant

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .tracking(0.5)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: Theme.glassBorderWidth)
            )
            .accessibilityLabel(label)
    }

    private var label: String {
        switch variant {
        case .milestone: return "milestone"
        case .toughDay: return "tough day"
        case .personalBest: return "personal best"
        }
    }

    private var textColor: Color {
        switch variant {
        case .milestone, .personalBest: return Theme.Semantic.onTrack(for: scheme)
        case .toughDay: return Theme.Semantic.warning(for: scheme)
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .milestone, .personalBest: return Theme.Semantic.onTrackBackground(for: scheme)
        case .toughDay: return Theme.Semantic.warningBackground(for: scheme)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .milestone, .personalBest: return Theme.Semantic.onTrackBorder(for: scheme)
        case .toughDay: return Theme.Semantic.warningBorder(for: scheme)
        }
    }
}
```

**Important:** Before building, verify that `Theme.Semantic.onTrack`, `onTrackBackground`, `onTrackBorder`, `warning`, `warningBackground`, `warningBorder` exist on the existing `Theme` struct. If they do not, either use the closest available color tokens (`Color(hex:)` literals matching spec values from `DESIGN-SYSTEMMemoryAisle.md`) or add them. Check with:

```bash
grep -n "onTrack\|warning" MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift
```

If the tokens are missing, add them to `Theme.Semantic` in a separate commit before proceeding with this task. Do not hardcode hex colors in view code.

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Reflection/MomentBadge.swift
git commit -m "[reflection] Add MomentBadge pill component

Small reusable pill for milestone, tough day, and personal best
moment card variants. Colors dispatched from MomentBadge.Variant
via Theme.Semantic tokens. 10pt text, capsule shape, 0.5px border.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 19: `MomentCard` component

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Features/Reflection/MomentCard.swift`

Unified card that dispatches its background/border/badge based on `moment.category`.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct MomentCard: View {
    let moment: ReflectionMoment

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topRow
            photoIfPresent
            Text(moment.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
            if let description = moment.description {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .lineSpacing(3)
            }
            if let quote = moment.quote {
                quoteBlock(quote)
            }
            if let metadata = moment.metadataLabel {
                metadataFootnote(metadata)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorder, lineWidth: Theme.glassBorderWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(moment.title). \(moment.description ?? "")")
    }

    private var topRow: some View {
        HStack {
            Text(formattedDate)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(Theme.Text.hint(for: scheme))
            Spacer()
            if let badgeVariant = badgeVariant {
                MomentBadge(variant: badgeVariant)
            }
        }
    }

    @ViewBuilder
    private var photoIfPresent: some View {
        if let photoData = moment.photoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .aspectRatio(4 / 3, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func quoteBlock(_ quote: String) -> some View {
        Text("\u{201C}\(quote)\u{201D}")
            .font(.system(size: 13, design: .serif).italic())
            .foregroundStyle(Theme.Text.secondary(for: scheme))
            .padding(.top, 4)
    }

    private func metadataFootnote(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .tracking(1.0)
            .foregroundStyle(Theme.Text.hint(for: scheme))
            .padding(.top, 2)
    }

    private var cardBackground: Color {
        switch moment.category {
        case .standard, .personalBest:
            return Theme.Surface.glass(for: scheme)
        case .milestone:
            return Theme.Semantic.onTrackBackground(for: scheme)
        case .toughDay:
            return Theme.Semantic.warningBackground(for: scheme)
        }
    }

    private var cardBorder: Color {
        switch moment.category {
        case .standard, .personalBest:
            return Theme.Border.glass(for: scheme)
        case .milestone:
            return Theme.Semantic.onTrackBorder(for: scheme)
        case .toughDay:
            return Theme.Semantic.warningBorder(for: scheme)
        }
    }

    private var badgeVariant: MomentBadge.Variant? {
        switch moment.category {
        case .standard: return nil
        case .milestone: return .milestone
        case .toughDay: return .toughDay
        case .personalBest: return .personalBest
        }
    }

    private var formattedDate: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: moment.date).uppercased()
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Reflection/MomentCard.swift
git commit -m "[reflection] Add MomentCard unified component

Single card that dispatches background, border, and badge by
moment.category (standard, milestone, toughDay, personalBest).
Renders photo, title, description, optional user quote, and
optional metadata footnote. 16pt corner radius, 0.5px border
matching glass card spec. Accessibility combines children into
one readable label.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: `ReflectionFilterChipRow` component

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionFilterChipRow.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct ReflectionFilterChipRow: View {
    @Binding var selected: ReflectionFilter

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ReflectionFilter.allCases) { filter in
                    chip(for: filter)
                }
            }
            .padding(.horizontal, 28)
        }
    }

    private func chip(for filter: ReflectionFilter) -> some View {
        let isActive = filter == selected
        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.18)) {
                selected = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 13))
                .foregroundStyle(isActive
                    ? Color.violet
                    : Theme.Text.secondary(for: scheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive
                            ? Color.violet.opacity(0.08)
                            : Theme.Surface.glass(for: scheme))
                )
                .overlay(
                    Capsule()
                        .stroke(isActive
                            ? Color.violet.opacity(0.25)
                            : Theme.Border.glass(for: scheme),
                            lineWidth: Theme.glassBorderWidth)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.rawValue)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionFilterChipRow.swift
git commit -m "[reflection] Add ReflectionFilterChipRow

Horizontal scroll of 5 filter chips (All, Photos, Meals, Gym,
Feelings) with selection state, selection haptics, ease-out
animation on change, and violet accent for active chip.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 21: `TransformationStatsRow` component

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Features/Reflection/TransformationStatsRow.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct TransformationStatsRow: View {
    let stats: TransformationStats

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            if let lbsDelta = stats.lbsDelta {
                statCell(
                    value: formatted(lbsDelta),
                    label: lbsLabel,
                    color: Theme.Text.primary
                )
                divider
            }
            if let leanDelta = stats.leanDelta {
                statCell(
                    value: formatted(abs(leanDelta)),
                    label: "LEAN",
                    color: Theme.Semantic.onTrack(for: scheme)
                )
                divider
            }
            if let days = stats.days {
                statCell(
                    value: "\(days)",
                    label: "DAYS",
                    color: Theme.Text.primary
                )
            }
        }
        .padding(.horizontal, 28)
    }

    private var lbsLabel: String {
        switch stats.direction {
        case .lost: return "LBS LOST"
        case .gained: return "LBS GAINED"
        case .none: return "LBS CHANGED"
        }
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Theme.Text.hint(for: scheme))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Border.glass(for: scheme))
            .frame(width: Theme.glassBorderWidth, height: 28)
    }

    private func formatted(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Reflection/TransformationStatsRow.swift
git commit -m "[reflection] Add TransformationStatsRow

Three-stat horizontal row (LBS | LEAN | DAYS) with SF Mono values
and tiny tracked labels. Lean stat hides gracefully when not
computable; row collapses to two stats without layout jank.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 22: `ReflectionEmptyState` component

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionEmptyState.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct ReflectionEmptyState: View {
    let filter: ReflectionFilter

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 14) {
            MiraWaveform(state: .idle, size: .small)
                .frame(height: 28)
                .padding(.bottom, 4)
            Text(headline)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var headline: String {
        switch filter {
        case .all:      return "Your moments will live here."
        case .photos:   return "Photo moments appear here."
        case .meals:    return "Meal moments appear here."
        case .gym:      return "Gym moments appear here."
        case .feelings: return "Your own words live here."
        }
    }

    private var body: String {
        switch filter {
        case .all:
            return "As you check in and show up for yourself, this space fills in on its own."
        case .photos:
            return "Every check-in photo becomes part of your story."
        case .meals:
            return "Recipes you save and meals you cook become part of your story."
        case .gym:
            return "Every session you log shows up here. From first squat to first mile."
        case .feelings:
            return "Words you share with Mira become part of your journey. Wins, hard days, real thoughts, all of it."
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionEmptyState.swift
git commit -m "[reflection] Add ReflectionEmptyState per-filter messaging

One view, five filter-specific copy blocks. All strings reviewed
against Mira voice rules: warm invitations, no banned vocabulary,
no directives. Centered layout with MiraWaveform at top.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 23: `ReflectionHeroCard` and `ReflectionHeroInviteCard`

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionHeroCard.swift`
- Create: `MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionHeroInviteCard.swift`

Two hero variants: real photo comparison, or Mira invitation to set Day 1.

- [ ] **Step 1: Create `ReflectionHeroCard.swift`**

```swift
import SwiftUI

struct ReflectionHeroCard: View {
    let photos: HeroPhotos

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            photoTile(
                data: photos.day1,
                label: "DAY 1",
                labelColor: Theme.Text.tertiary(for: scheme),
                weight: photos.day1Weight,
                date: photos.day1Date,
                background: Theme.Surface.glass(for: scheme),
                border: Theme.Border.glass(for: scheme)
            )
            photoTile(
                data: photos.today,
                label: "TODAY",
                labelColor: Color.violet,
                weight: photos.todayWeight,
                date: photos.todayDate,
                background: Theme.Surface.glassElevated(for: scheme),
                border: Theme.Border.glassElevated(for: scheme)
            )
        }
        .padding(.horizontal, 28)
    }

    private func photoTile(
        data: Data?,
        label: String,
        labelColor: Color,
        weight: Double?,
        date: Date?,
        background: Color,
        border: Color
    ) -> some View {
        ZStack(alignment: .bottom) {
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(background)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(labelColor)
                HStack(spacing: 8) {
                    if let weight {
                        Text("\(formatted(weight)) lbs")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Color.white)
                    }
                    if let date {
                        Text(shortDate(date))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.7))
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(border, lineWidth: Theme.glassBorderWidth)
        )
        .accessibilityLabel("\(label) photo")
    }

    private func formatted(_ lbs: Double) -> String {
        String(format: "%.1f", lbs)
    }

    private func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}
```

- [ ] **Step 2: Create `ReflectionHeroInviteCard.swift`**

```swift
import PhotosUI
import SwiftUI

struct ReflectionHeroInviteCard: View {
    let onPhotoChosen: (Data) -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    @State private var showSourceChoice = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var cameraImageData: Data?
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                MiraWaveform(state: .idle, size: .small)
                    .frame(width: 32, height: 32)
                Spacer()
            }
            Text("Day 1 hasn't started yet.")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Text.primary)
            Text("When you're ready, set your starting photo. It is how the story begins. You can always change it later.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .lineSpacing(4)
            HStack(spacing: 10) {
                Button {
                    HapticManager.light()
                    showSourceChoice = true
                } label: {
                    Text("Set Day 1 photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.violet)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(Color.violet.opacity(0.12))
                        )
                        .overlay(
                            Capsule().stroke(Color.violet.opacity(0.3),
                                             lineWidth: Theme.glassBorderWidth)
                        )
                }
                .buttonStyle(.plain)
                Button {
                    HapticManager.light()
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.Surface.glassElevated(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.Border.glassElevated(for: scheme),
                        lineWidth: Theme.glassBorderWidth)
        )
        .padding(.horizontal, 28)
        .confirmationDialog(
            "Starting photo",
            isPresented: $showSourceChoice,
            titleVisibility: .visible
        ) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(imageData: $cameraImageData)
                .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showLibrary,
            selection: $libraryItem,
            matching: .images
        )
        .onChange(of: cameraImageData) { _, newValue in
            guard let newValue else { return }
            onPhotoChosen(newValue)
            cameraImageData = nil
        }
        .onChange(of: libraryItem) { _, newValue in
            guard let newValue else { return }
            Task { @MainActor in
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    onPhotoChosen(data)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionHeroCard.swift \
        MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionHeroInviteCard.swift
git commit -m "[reflection] Add hero card and invite card

ReflectionHeroCard renders the real Day 1 vs Today side-by-side
photo comparison. ReflectionHeroInviteCard is the Mira-voiced
invitation shown when the user has no photos yet; it opens the
same camera/library picker as PhotoCheckInView and dismisses via
a callback so ReflectionView can store the 30-day cooldown.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 24: Assemble `ReflectionView`

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionView.swift`

The main container that composes everything. Reads `@Query` properties for live updates, bundles into `ReflectionSourceRecords`, and hands to services. Handles the 30-day invite card cooldown.

- [ ] **Step 1: Create the file**

```swift
import SwiftData
import SwiftUI

struct ReflectionView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BodyComposition.date) private var bodyCompositions: [BodyComposition]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \NutritionLog.date) private var nutritionLogs: [NutritionLog]
    @Query(sort: \SymptomLog.date) private var symptomLogs: [SymptomLog]
    @Query private var userProfiles: [UserProfile]

    @State private var selectedFilter: ReflectionFilter = .all
    @State private var inviteDismissed = false

    private let momentService = ReflectionMomentService()
    private let statsService = TransformationStatsService()
    private let heroService = HeroPhotosService()
    private let saveService = CheckInSaveService()

    private let inviteDismissKey = "reflectionHeroInviteDismissedUntil"

    var body: some View {
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

        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                sectionLabel("REFLECTION")
                    .padding(.top, 8)
                Text("Look how far you've come.")
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.Text.primary)
                    .multilineTextAlignment(.center)

                heroSlot(photos: heroPhotos)

                TransformationStatsRow(stats: stats)
                    .padding(.top, 4)

                ReflectionFilterChipRow(selected: $selectedFilter)
                    .padding(.top, 8)

                sectionLabel("YOUR MOMENTS")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)

                if moments.isEmpty {
                    ReflectionEmptyState(filter: selectedFilter)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(moments) { moment in
                            MomentCard(moment: moment)
                                .padding(.horizontal, 28)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .themeBackground()
        .onAppear {
            refreshInviteDismissState()
        }
    }

    @ViewBuilder
    private func heroSlot(photos: HeroPhotos) -> some View {
        if photos.day1 != nil {
            ReflectionHeroCard(photos: photos)
        } else if !inviteDismissed {
            ReflectionHeroInviteCard(
                onPhotoChosen: handleInvitePhoto,
                onDismiss: dismissInvite
            )
        }
    }

    private func handleInvitePhoto(_ data: Data) {
        let weight = userProfiles.first?.weightLbs ?? 0
        try? saveService.save(weight: weight, photoData: data, in: modelContext)
    }

    private func dismissInvite() {
        let until = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        UserDefaults.standard.set(until, forKey: inviteDismissKey)
        inviteDismissed = true
    }

    private func refreshInviteDismissState() {
        if let until = UserDefaults.standard.object(forKey: inviteDismissKey) as? Date {
            inviteDismissed = Date() < until
        } else {
            inviteDismissed = false
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .tracking(1.5)
            .foregroundStyle(Color.violet.opacity(0.5))
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/Features/Reflection/ReflectionView.swift
git commit -m "[reflection] Add ReflectionView main container

Composes header, hero (real or invite), transformation stats,
filter chips, and moments timeline. Uses @Query for live updates,
bundles into ReflectionSourceRecords, hands off to services.
Invite-card dismiss stores a 30-day cooldown in UserDefaults.
Invite photo write goes through CheckInSaveService so the same
path as weekly check-ins is exercised.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 25: Wire Reflection into the menu and reorder Progress

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/App/MainTabView.swift`

- [ ] **Step 1: Add `.reflection` to the `MenuDestination` enum**

Locate the enum at the bottom of `MainTabView.swift` (around line 158). Replace:

```swift
enum MenuDestination: String, Identifiable, Hashable {
    case profile, recipes, scan, calendar, pantry, safeSpace, progress, subscribe, settings
    var id: String { rawValue }
}
```

with:

```swift
enum MenuDestination: String, Identifiable, Hashable {
    case profile, progress, recipes, scan, calendar, pantry, safeSpace, reflection, subscribe, settings
    var id: String { rawValue }
}
```

- [ ] **Step 2: Add the `.reflection` case to `destinationView(_:)`**

Locate the switch around line 143 and add one case:

```swift
@ViewBuilder
private func destinationView(_ dest: MenuDestination) -> some View {
    switch dest {
    case .profile: JourneyProfileView()
    case .progress: ProgressDashboardView()
    case .recipes: RecipesView()
    case .scan: ScanView()
    case .calendar: CalendarView()
    case .pantry: PantryView()
    case .safeSpace: SafeSpaceView()
    case .reflection: ReflectionView()
    case .subscribe: PaywallView()
    case .settings: ProfileView()
    }
}
```

- [ ] **Step 3: Reorder the menu rows**

Locate the `menuSheet` body (around lines 60–84). Replace the existing menu row block with:

```swift
VStack(spacing: 4) {
    menuRow("My Journey", icon: "person.fill", color: Color.violet) {
        activeSheet = .destination(.profile)
    }
    menuRow("Progress", icon: "chart.line.uptrend.xyaxis", color: Color(hex: 0x34D399)) {
        activeSheet = .destination(.progress)
    }
    menuRow("Recipes", icon: "book.fill", color: Color(hex: 0xFBBF24)) {
        activeSheet = .destination(.recipes)
    }
    menuRow("Scan", icon: "barcode.viewfinder", color: Color(hex: 0x60A5FA)) {
        activeSheet = .destination(.scan)
    }
    menuRow("Smart Calendar", icon: "calendar", color: Color(hex: 0x38BDF8)) {
        activeSheet = .destination(.calendar)
    }
    menuRow("Pantry", icon: "refrigerator.fill", color: Color(hex: 0x4ADE80)) {
        activeSheet = .destination(.pantry)
    }
    menuRow("My Safe Space", icon: "lock.shield.fill", color: Color(hex: 0x6B6B88)) {
        activeSheet = .destination(.safeSpace)
    }
    menuRow("Reflection", icon: "square.and.pencil", color: Color.violet) {
        activeSheet = .destination(.reflection)
    }
    menuRow("Subscribe", icon: "star.fill", color: Color(hex: 0xFBBF24)) {
        activeSheet = .destination(.subscribe)
    }

    Divider()
        .background(Theme.Border.glass(for: scheme))
        .padding(.vertical, 8)

    menuRow("Settings", icon: "gearshape.fill", color: Theme.Text.tertiary(for: scheme)) {
        activeSheet = .destination(.settings)
    }
}
.padding(.horizontal, 20)
```

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/App/MainTabView.swift
git commit -m "[reflection] Wire Reflection into menu, reorder Progress up

New Reflection menu row at position 8 (square.and.pencil icon,
violet). Progress moved from position 7 to position 2, just after
My Journey. New menu order: My Journey, Progress, Recipes, Scan,
Smart Calendar, Pantry, My Safe Space, Reflection, Subscribe.
Settings remains below the divider.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 26: Full build + test sweep and manual smoke test

**Files:** None (verification only)

- [ ] **Step 1: Run the full test suite**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  test 2>&1 | tail -40
```

Expected: all tests pass, including the new Reflection test classes (`CheckInSaveServiceTests`, `ReflectionMomentServiceTests`, `TransformationStatsServiceTests`, `HeroPhotosServiceTests`, `CheckInMomentTransformerTests`, `GymMomentTransformerTests`, `ProteinStreakMomentTransformerTests`, `ToughDayMomentTransformerTests`, `MilestoneMomentTransformerTests`).

If any test fails, open that test class, read the failure message, and fix — do not paper over the issue by disabling the test.

- [ ] **Step 2: Clean build**

```bash
xcodebuild -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **` with zero warnings. Warnings are errors per CLAUDE.md — fix any that appear.

- [ ] **Step 3: Manual smoke test in the simulator**

Launch the app in the simulator and walk through:

**(a) Fresh onboarding with photo**
- Delete the app from the simulator first to start with a clean slate
- Reinstall and launch
- Complete the onboarding flow: tap through intro → goals → training → dietary → age → sex → height/weight → **starting photo (take a photo or pick from library)** → medication → ready → "Take me home"
- Verify the app lands on Home

**(b) Navigate to Reflection**
- Tap the hamburger menu
- Verify the menu order is: My Journey, Progress, Recipes, Scan, Smart Calendar, Pantry, My Safe Space, **Reflection**, Subscribe, then Settings below the divider
- Tap Reflection
- Verify the hero shows your starting photo labeled "DAY 1" (paired with itself as "TODAY" since it's the only record)
- Verify the transformation stats show: `LBS CHANGED 0`, `DAYS 0`
- Verify the moment timeline shows a "First check-in" card (if onboarding completes it as a BodyComposition with .manual source — which it does)

**(c) Empty filter chips**
- Tap "Photos" chip → verify your one check-in card shows (it has a photo)
- Tap "Meals" chip → verify the "Meal moments appear here." empty state renders
- Tap "Gym" chip → verify the "Gym moments appear here." empty state
- Tap "Feelings" chip → verify the "Your own words live here." empty state
- Tap "All moments" chip → back to full timeline

**(d) Fresh onboarding without photo (invite card path)**
- Delete the app again
- Reinstall and complete onboarding but tap "Skip for now" on the starting photo step
- Navigate to Reflection
- Verify the hero slot shows the **Mira invite card** ("Day 1 hasn't started yet.") instead of the photo comparison
- Tap "Set Day 1 photo" → take or pick a photo
- Verify the invite card disappears and is replaced by the real hero
- Verify a "First check-in" moment appears in the timeline

**(e) Invite card dismiss**
- Delete the app, reinstall, skip the photo, navigate to Reflection
- Tap "Not now" on the invite card
- Verify the card disappears (replaced by nothing — hero slot is empty until a photo exists)
- Force-quit the app and reopen → navigate to Reflection → verify the invite card does NOT reappear (30-day cooldown in effect)

**(f) Weekly check-in fix verification**
- From Home (or My Journey), open the weekly check-in sheet
- Verify the "Save check-in" button is disabled (50% opacity) when weight is empty
- Type a weight → verify the button enables
- Take or pick a photo
- Tap Save → verify confirmation renders
- Navigate back to Reflection → verify a new check-in moment has appeared with the new photo and weight

- [ ] **Step 4: Commit the final state**

If any small fixes were needed during the smoke test, commit them with appropriate messages before wrapping up.

If nothing needed fixing, there is nothing to commit for this task. Log the green smoke test as the completion signal.

---

## Self-review

### Spec coverage

Walked through `docs/superpowers/specs/2026-04-13-reflection-page-design.md` section by section:

- **Section 1 Purpose** — implicit in every task
- **Section 2 Scope** — all in-scope items have tasks; all v2+ items stay untouched
- **Section 3 Architecture** — Tasks 7, 8, 15 cover value types, fixtures, service
- **Section 4 Source transformers** — Tasks 9, 10, 11, 12, 13, 14 (one per transformer + empty stubs)
- **Section 5 Transformation stats math** — Task 16
- **Section 6 Data layer changes** — Tasks 1, 2, 3 (CheckInSaveService + PhotoCheckInView fix)
- **Section 7 Onboarding changes** — Tasks 4, 5, 6 (profile field, MiraOnboardingView extension, completeOnboarding)
- **Section 8 View structure** — Task 24 (ReflectionView assembly)
- **Section 9 UI components** — Tasks 18, 19, 20, 21, 22, 23
- **Section 10 Mira voice compliance** — enforced inline in every transformer, hero, and empty-state task
- **Section 11 Menu integration** — Task 25
- **Section 12 Testing strategy** — test files paired with every service and transformer task
- **Section 13 Open questions** — flagged in spec, deliberately not mechanical tasks
- **Section 14 Implementation order** — reflected in task ordering
- **Section 15 Dependencies** — none required, satisfied by using Apple frameworks only

### Placeholder scan

No "TBD", "TODO", "implement later", "fill in details", "add appropriate error handling", "similar to Task N", or "write tests for the above" anywhere. Every test step shows actual test code. Every implementation step shows actual implementation code. Every build/test step has the exact command to run.

### Type consistency

- `ReflectionMoment` fields used in transformers (Task 9 onward) match the struct defined in Task 7
- `ReflectionSourceRecords` initializer used consistently in fixtures (Task 8) and every transformer test
- `MomentCategory.toughDay` used in both `ToughDayMomentTransformer` (Task 12) and `MomentCard`/`MomentBadge` dispatch (Tasks 18, 19)
- `CheckInSaveService.save(weight:photoData:in:)` signature consistent between definition (Task 1), usage in `PhotoCheckInView` (Task 2), and usage in `ReflectionView` invite flow (Task 24)
- `ReflectionFilter.matches(_:)` defined in Task 7, used in Task 15 service
- `HeroPhotos` struct (Task 17) matches fields consumed by `ReflectionHeroCard` (Task 23)
- `TransformationStats` struct (Task 16) matches fields consumed by `TransformationStatsRow` (Task 21)

### Known verification points

- **Task 18 (`MomentBadge`):** includes an explicit check for `Theme.Semantic` token existence. If the tokens are missing, the task instructs to add them before proceeding rather than hardcoding colors.
- **Task 25 menu integration:** uses existing `Color(hex:)` helpers and `Theme.Text.tertiary` which are already in the codebase.
- **Task 26 smoke test:** covers the six user-flow paths most likely to have regressions.

---

*Plan complete.*
