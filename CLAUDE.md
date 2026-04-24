# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
*** Never delete or purge user data without explicit approval. MemoryAisle is a longitudinal journey app. Data preservation across sign-out is the product, not a bug.***

MemoryAisle is a native iOS app (Swift 6, SwiftUI, iOS 17+) for GLP-1 medication users focused on body-composition-first nutrition. The core problem: 39% of weight lost on GLP-1s is lean mass. The app adapts meals, portions, grocery lists, and guidance based on appetite suppression, symptoms, medication phase/modality, training schedule, and protein shortfall risk.

The AI assistant "Mira" (Claude Sonnet via Amazon Bedrock) is the primary interface — she drives onboarding, meal planning, barcode verdicts, and recovery suggestions.

Active Xcode project: `MemoryAisle2/MemoryAisle2.xcodeproj` (the original `MemoryAisle/` tree was deleted; only `MemoryAisle2` is live).
Full product spec: `CLAUDE-MemoryAisle.md`
Design system spec: `DESIGN-SYSTEMMemoryAisle.md` (canonical; an older `DESIGN-SYSTEM-MemoryAisle.md` exists at the root but is superseded)
Legal/privacy spec: `LEGAL-MemoryAisle.md`
Security spec: `SECURITY-MemoryAisle.md`
Housekeeping rules: `RULES.md`

### Common entry points (so future sessions don't have to hunt)
- Theme + tokens: `MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift`
- Mira prompt construction: `MemoryAisle2/MemoryAisle2/Services/AI/MiraEngine.swift`
- App entry / tab shell: `MemoryAisle2/MemoryAisle2/App/MemoryAisleApp.swift`, `MainTabView.swift`, `AppState.swift`
- Test plan: `MemoryAisle2/MemoryAisle2.xctestplan`

## Build & Test Commands

All commands run from the repo root. Scheme is `MemoryAisle2` (singular target/scheme — there is no plain `MemoryAisle` scheme). SourceKit/Xcode indexer noise is chronic in this project, so `xcodebuild` output is the source of truth, not editor diagnostics.

```bash
# Build (zero warnings required — treat warnings as errors)
xcodebuild -project MemoryAisle2/MemoryAisle2.xcodeproj \
  -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run all tests
xcodebuild -project MemoryAisle2/MemoryAisle2.xcodeproj \
  -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Run a single test class (note the MemoryAisle2Tests target name)
xcodebuild -project MemoryAisle2/MemoryAisle2.xcodeproj \
  -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MemoryAisle2Tests/ProteinCalculatorTests test

# Run with the shared test plan (controls which test bundles execute)
xcodebuild -project MemoryAisle2/MemoryAisle2.xcodeproj \
  -scheme MemoryAisle2 \
  -testPlan MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Targets in the project: `MemoryAisle2` (app), `MemoryAisle2Tests` (unit), `MemoryAisle2UITests` (UI), `MemoryAisleWidgetsExtension` (widget extension; sources live in `MemoryAisle2/MemoryAisleWidgets/`).

### Infrastructure (CDK + Lambda)

Run from `Infrastructure/CDK/`:

```bash
npm run build    # tsc
npm run synth    # cdk synth
npm run diff     # cdk diff
npm run deploy   # cdk deploy --all
```

Lambdas live at `Infrastructure/lambda/<name>/` and ship as zips — `node_modules/` and `*.zip` under each function are gitignored, so they are built and uploaded out-of-band (not committed).

## Branch Rules

- **Default workflow:** prefer `dev` or `feature/*` for non-trivial work; merge to `main` after build succeeds with zero warnings and a manual device test. Simulator is not sufficient — real audio, camera, and HealthKit bugs only surface on device.
- MemoryAisle is **LIVE on the App Store** (as of 2026-04-23). Post-launch, treat `main` as shipping code: no more direct `[review]` commits, no rushed fixes — land work through `dev`/`feature/*` and verify on device before merging.
- Commit format: `[area] short description` (e.g., `[nutrition] implement protein calculator with lean mass input`).
- **Always remember to deploy and push.** Local commits don't ship the app or update the remote — after committing, push (`git push`) and, when relevant, deploy (App Store Connect upload, CDK deploy, etc.). Don't end a session with unpushed commits sitting on `main`.

## Architecture

### Layer Structure
All Swift sources live under `MemoryAisle2/MemoryAisle2/`. Tests live under `MemoryAisle2/MemoryAisle2Tests/` and mirror the service folder names. Infrastructure lives at the repo root.

```
MemoryAisle2/MemoryAisle2/
  App/            Entry point + tab shell (MemoryAisleApp.swift, MainTabView.swift, AppState.swift)
  Features/       SwiftUI screens by feature: Auth, Onboarding, Home, Meals, Scan, Mira,
                  Progress, Profile, Calendar, Recipes, Reflection, SafeSpace, Subscription
  Services/       Business logic: AI, Nutrition, Medication, BodyComp, Grocery, Health,
                  Cloud, Progress, Reflection, Subscription, System
  Models/         SwiftData models (UserProfile, MealPlan, Meal, FoodItem, SymptomLog,
                  GIToleranceRecord, MedicationProfile, BodyComposition, etc.)
  DesignSystem/   Reusable UI: GlassCard, VioletButton, ThemeColors, MiraWaveform,
                  HeroHeader, SectionCard, etc.
  Widgets/        WidgetKit sources for the MemoryAisleWidgets extension
                  (protein, hydration, today's meal) + AppGroupDataProvider bridge
  Assets.xcassets, MemoryAisle2.entitlements, MemoryAisleProducts.storekit, PrivacyInfo.xcprivacy

MemoryAisle2/MemoryAisle2Tests/         Unit tests grouped by service area (Reflection/, Nutrition/, Progress/, ...)
MemoryAisle2/MemoryAisle2UITests/       UI tests
MemoryAisle2/MemoryAisleWidgets/        Widget extension sources (consumed by the
                                        MemoryAisleWidgetsExtension target)
Infrastructure/CDK/                     AWS CDK stacks (TypeScript) — bin/, lib/, cdk.json
Infrastructure/lambda/                  Lambda function sources (miraGenerate, miraSpeak,
                                        providerReport, syncData, appStoreNotifications)
website/, docs/                         Marketing site and product docs
```

### Key Services
- **MiraEngine** (`Services/AI/`): Builds context-aware prompts from user profile, logs, symptoms, and medication phase, then sends to Bedrock Claude. This is the core decision engine.
- **MedicationManager** (`Services/Medication/`): Tracks medication modality (injectable, oral+fasting, oral no-fasting), dose phases, and appetite/nausea predictions by cycle day.
- **ProteinCalculator** (`Services/Nutrition/`): Computes targets from lean mass + goals. Wrong targets = wrong guidance = harm. Test thoroughly.
- **GIToleranceEngine** (`Services/Nutrition/`): Tracks food-to-symptom correlations to avoid triggering foods.

### Product Modes
Users switch between: Everyday GLP-1, Sensitive Stomach, Muscle Preservation, Training Performance, Maintenance/Taper. Mode affects meal plans, portion sizes, UI emphasis, and Mira's behavior.

### Backend
Cognito auth (Amplify Swift SDK v2) -> API Gateway -> Lambda (VPC) -> Aurora Serverless v2 (PostgreSQL 16). Bedrock Claude for Mira. CDK (TypeScript) for IaC.

### Cloud Sync (since 1.0.3)

Longitudinal data pushes to the backend so a device switch or app reinstall restores the user's history.

**Allowlist is compile-time.** `Services/Cloud/CloudSyncable.swift` declares a marker protocol that extends `PersistentModel`. Exactly these four models conform: `UserProfile`, `NutritionLog`, `SymptomLog`, `PantryItem`. Every fetch inside `CloudSyncManager.pushAll` flows through `fetchSyncable<T: CloudSyncable>`, so a non-conforming type cannot reach the network without a compile error. Adding a new syncable model means adding conformance *and* updating the `CloudSyncableTests` allowlist count in the same commit — both halves are required.

**Safe Space is an explicit non-sync zone.** `SafeSpaceEntry` is a local-only `Codable` struct (not `@Model`), FaceID-gated on view, stored at `Documents/.safespace.json` with `.completeFileProtection`. It is *never* allowed to leave the device. The privacy invariant is defended by three independent gates: (1) it's not a `PersistentModel`, (2) it's not on the `CloudSyncable` allowlist, (3) its init is inferred `@MainActor` so a nonisolated async push path can't instantiate it. `CloudSyncableTests.testSafeSpaceEntryRemainsLocalOnlyStruct` pins the struct shape so converting it to a class triggers a deliberate review.

**Hook points:**
- **Sign-out (blocking push):** `CognitoAuthManager.signOutEverywhere` awaits `pushAll` *before* clearing the session and before `appState.authStatus` flips — the container rebuild in `RootView` would otherwise swap in the anonymous store mid-push. Blocking is deliberate: sign-out is an explicit user action and correctness outranks UX here.
- **Backgrounding (best-effort push):** `RootView` observes `scenePhase == .background` and wraps `pushAll` in `UIApplication.beginBackgroundTask` to buy up to ~30s past suspension. If iOS kills us mid-push, the next sign-out or next backgrounding catches up — logs delayed, not lost.
- **Sign-in (fire-and-forget pull):** `AuthFlowView.handlePostSignIn` kicks off `pullAll` in a Task. `pullAll` currently returns the server payload but does not yet restore into SwiftData — the local store is authoritative on this device. The restore-to-local path is deferred to a later version.
- **Manual fallback:** the "Sync to Cloud" button in `ProfileView` stays wired to `pushAll` unchanged, for users who want to force a sync between the automatic ones.

## Hard Constraints

### Dependencies
- **Allowed:** Apple frameworks only + `aws-amplify/amplify-swift` for Cognito auth.
- **Not allowed:** Any other Swift package, CocoaPod, or Carthage dependency without explicit approval. If it can be done with Apple frameworks, do it that way.

### Code Rules
- Max 300 lines per file. Max 50 lines per function. One type per file.
- Swift 6 strict concurrency. All `Sendable` violations must be fixed, not suppressed.
- `async/await` only — no completion handlers.
- No force unwraps (`!`), `try!`, or `as!` outside of tests.
- No hardcoded colors — use `Theme.swift`. No custom fonts — SF Pro system fonts only.
- All UI must work in both dark and light mode using `Theme.swift` adaptive colors.
- Accessibility labels on all interactive elements. Dynamic Type on all text.
- No `TODO`/`FIXME` comments — fix it now or don't touch it.
- No em dashes in any UI copy, Mira prompts, or Mira-generated text. This applies to `MiraEngine` system prompts and any string that could end up rendered in the app.
- No `print(...)` — use `os.Logger` for debug output. Any `print` is a regression.

### Data Safety
- Medication data encrypted in SwiftData. Never logged to console.
- API keys in Keychain only at runtime. Never in source code or Info.plist. For build-time config, use `.xcconfig` files (gitignored — `*.xcconfig` is in `.gitignore`).
- HealthKit data stays in HealthKit — read-only, never cached without consent.
- Mira never diagnoses, never recommends medication changes, always defers to prescriber.

### Testing
- Every service file needs a corresponding test file.
- Test all calculation logic, state machines, data transformations, and edge cases.
- Don't test SwiftUI views — test view models instead. Mock the API client for network calls.

## Design System: Ultraviolet Liquid Glass

Dark mode primary (`#0A0914` background), violet accent (`#A78BFA`). Frosted translucent glass panels with 0.5px borders. Every interactive card scales to 0.98 on press with increased opacity.

**Mira's avatar:** 5 vertical bars + 1 four-point star. No circle, no orb, no container, no face. States: speaking (animated heights), idle (40% height), thinking (pulsing).

Semantic colors: Protein=violet, Water=sky blue, Fiber=amber, Calories=neutral gray, On-track=green, Behind=amber, Warning=red.

## Session Workflow (per RULES.md §2)

The user follows a checkpoint discipline that future Claude sessions must respect:
- Each session begins with a `pre-claude-code checkpoint` commit capturing the working state. If you see one, do not amend or rewrite it — it's a known-good revert target.
- One task per session. If you notice unrelated work that "should" be cleaned up, surface it but don't do it without approval.
- If a build break appears mid-session, do NOT pile fixes on top — stop and offer to revert to the checkpoint.

## Things Claude Code Must NOT Do Without Approval

- Add/remove Swift packages or modify build settings/schemes
- Change deployment target or Info.plist entitlements
- Touch Cognito/auth config or CDK infrastructure
- Change SwiftData model schema (requires migration planning)
- Delete files or rename public APIs/model properties
- Refactor working code outside the current task scope
- Suppress warnings with `@available` or `#if`
