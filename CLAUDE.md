# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MemoryAisle is a native iOS app (Swift 6, SwiftUI, iOS 17+) for GLP-1 medication users focused on body-composition-first nutrition. The core problem: 39% of weight lost on GLP-1s is lean mass. The app adapts meals, portions, grocery lists, and guidance based on appetite suppression, symptoms, medication phase/modality, training schedule, and protein shortfall risk.

The AI assistant "Mira" (Claude Sonnet via Amazon Bedrock) is the primary interface — she drives onboarding, meal planning, barcode verdicts, and recovery suggestions.

Full product spec: `CLAUDE-MemoryAisle.md`
Housekeeping rules: `RULES.md`

## Build & Test Commands

```bash
# Build (zero warnings required — treat warnings as errors)
xcodebuild -scheme MemoryAisle -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Run all tests
xcodebuild -scheme MemoryAisle -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test

# Run a single test file
xcodebuild -scheme MemoryAisle -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MemoryAisleTests/ProteinCalculatorTests test
```

## Branch Rules

- **Never commit to `main`.** Work on `dev` or `feature/*` branches only.
- `feature/*` branches merge to `dev` after build succeeds with zero warnings.
- `dev` merges to `main` only after manual device testing.
- Commit format: `[area] short description` (e.g., `[nutrition] implement protein calculator with lean mass input`)

## Architecture

### Layer Structure
```
Features/       SwiftUI views organized by feature (Onboarding, Home, Meals, Scan, Mira, Progress, Profile, Auth)
Services/       Business logic (AI, Nutrition, Medication, BodyComp, Grocery, Health, Cloud, System)
Models/         SwiftData models (UserProfile, MealPlan, Meal, FoodItem, NutritionLog, SymptomLog, etc.)
DesignSystem/   Reusable UI components (Theme, GlassCard, VioletButton, Typography, MiraWaveform, etc.)
Widgets/        WidgetKit extensions (protein, hydration, today's meal)
Extensions/     Swift type extensions
Tests/          Mirrors Services/ structure (NutritionTests, MedicationTests, BodyCompTests, IntegrationTests)
Infrastructure/ AWS CDK stacks and Lambda functions (TypeScript)
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
- No em dashes in any UI copy or generated text.

### Data Safety
- Medication data encrypted in SwiftData. Never logged to console.
- API keys in Keychain only, never in source code or Info.plist.
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

## Things Claude Code Must NOT Do Without Approval

- Add/remove Swift packages or modify build settings/schemes
- Change deployment target or Info.plist entitlements
- Touch Cognito/auth config or CDK infrastructure
- Change SwiftData model schema (requires migration planning)
- Delete files or rename public APIs/model properties
- Refactor working code outside the current task scope
- Suppress warnings with `@available` or `#if`
