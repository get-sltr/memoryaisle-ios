# RULES.md -- MemoryAisle iOS Housekeeping Rules
# These rules are non-negotiable. Every commit, every PR, every Claude Code session must follow them.

---

## Why These Rules Exist

The previous MemoryAisle (React Native/Expo) was destroyed by:
- Claude Code introducing regressions faster than they could be fixed
- No branching strategy, changes going straight to main
- No testing, so broken code shipped silently
- Build tooling failures (EAS/Expo) that wasted weeks
- Luminetic scan score dropping from 29 to 10 because of accumulated damage
- No clear boundaries on what Claude Code could and could not touch

These rules prevent that from ever happening again.

---

## 1. Branch Rules

```
main              PROTECTED. Never commit directly. Never force push.
                  This branch must always build and run.

dev               Active development branch. All work happens here.
                  Merge to main ONLY after manual testing on device.

feature/*         Feature branches off dev. One feature per branch.
                  Examples: feature/mira-onboarding, feature/barcode-scanner
                  Merge to dev when feature is complete and tested.

hotfix/*          Emergency fixes off main. Merge to both main and dev.
```

**Rules:**
- Claude Code works ONLY on `dev` or `feature/*` branches. NEVER on `main`.
- Before merging any feature branch to dev: build must succeed, no warnings, no crashes on launch.
- Before merging dev to main: full manual test on physical device. Not simulator. Device.
- Tag every main merge with a version: v0.1.0, v0.2.0, etc.

---

## 2. Claude Code Session Rules

**Before every Claude Code session:**
1. Pull latest from your branch
2. Make sure the app builds and runs BEFORE Claude Code touches anything
3. Commit the current working state with message "pre-claude-code checkpoint"
4. Tell Claude Code which specific task to work on (one task per session)

**During the session:**
- ONE task per session. Not two. Not "and also fix this." ONE.
- If Claude Code wants to refactor something unrelated to the task, say NO.
- If Claude Code suggests changing a file it wasn't asked to change, say NO.
- If Claude Code deletes code without explaining why, STOP and revert.
- If the build breaks, STOP. Do not let Claude Code "fix" a break it caused by making more changes. Revert to checkpoint and try again.

**After every Claude Code session:**
1. Build the app. Does it compile? If no, revert to checkpoint.
2. Run the app on simulator. Does it launch? If no, revert to checkpoint.
3. Test the specific feature that was changed. Does it work? If no, revert to checkpoint.
4. Run existing tests. Do they pass? If no, revert to checkpoint.
5. If everything passes, commit with a clear message describing what changed.

**The revert rule is absolute.** If Claude Code breaks the build and you can't fix it in 10 minutes, revert. Do not spend hours debugging AI-generated regressions. That's what killed the last codebase.

---

## 3. File Rules

```
Maximum file length:     300 lines. No exceptions.
Maximum function length: 50 lines. If longer, extract.
One type per file:       One struct/class/enum per .swift file.
Naming:                  Files named exactly after their primary type.
                         UserProfile.swift contains struct UserProfile.
No dead code:            Delete unused functions, commented-out blocks, TODOs older than 1 week.
No print statements:     Use os.Logger for debug output. Remove before merge to main.
```

---

## 4. Dependency Rules

```
ALLOWED:
  - Apple frameworks (SwiftUI, SwiftData, AVFoundation, HealthKit, Vision, Speech,
    StoreKit, WidgetKit, Charts, CoreHaptics, PDFKit, etc.)
  - aws-amplify/amplify-swift (Cognito auth + API)

NOT ALLOWED without explicit approval:
  - Any other Swift package
  - Any CocoaPods
  - Any Carthage dependency
  - Any vendored framework

If Claude Code tries to add a dependency, ask: "Can this be done with Apple frameworks?"
The answer is almost always yes.
```

---

## 5. Testing Rules

```
Every service file must have a corresponding test file.
  Services/Nutrition/ProteinCalculator.swift
  Tests/NutritionTests/ProteinCalculatorTests.swift

Test before merge:
  - All unit tests must pass before merging feature -> dev
  - All unit tests must pass before merging dev -> main
  - No skipped tests. Fix or delete.

What to test:
  - All calculation logic (protein targets, macro tracking, meal timing, dose phases)
  - All state machines (medication cycle, product modes, onboarding flow)
  - All data transformations (API responses -> models, models -> UI state)
  - All edge cases (zero values, nil optionals, empty arrays, max values)

What NOT to test:
  - SwiftUI views (test the view models instead)
  - Network calls (mock the API client)
  - Third-party SDK behavior
```

---

## 6. Build Rules

```
Zero warnings policy:    The project must compile with ZERO warnings.
                         Treat warnings as errors in build settings.

Swift 6 strict:          Strict concurrency checking enabled.
                         All Sendable violations must be fixed, not suppressed.

Scheme:                  One scheme: MemoryAisle (Debug + Release)
                         No test schemes that diverge from main scheme.

Minimum deployment:      iOS 17.0. Do not use iOS 18+ only APIs without
                         availability checks.

Simulator test:          Every build must launch on iPhone 15 Pro simulator
                         without crashing within first 10 seconds.

Device test:             Before any merge to main, test on a physical device.
                         Simulator hides real audio, camera, and HealthKit issues.
```

---

## 7. Git Commit Rules

```
Format:     [area] short description

Examples:
  [onboarding] add medication selection screen
  [nutrition] implement protein calculator with lean mass input
  [scan] integrate Apple Vision barcode reader
  [mira] connect Bedrock Claude for meal generation
  [fix] resolve crash on nil medication profile
  [design] implement glass card component with press effect

Rules:
  - Every commit must compile. No "WIP" commits on dev or main.
  - One logical change per commit. Not "updated a bunch of stuff."
  - If reverting, commit message: [revert] description of what was reverted and why
```

---

## 8. Data Safety Rules

```
Medication data:         Always encrypted in SwiftData (use .transformable with encryption)
                         Never log medication names or doses to console
                         Never include in analytics or crash reports

API keys:                Keychain only. Never in source code. Never in Info.plist.
                         Use .xcconfig files excluded from git for local development.

User health data:        HealthKit data stays in HealthKit. Read-only unless explicit permission.
                         Never cache HealthKit data in SwiftData without user consent.

Bedrock prompts:         Never include user's full name in prompts to Claude.
                         Use anonymized profile data only.
                         Never log full prompt/response pairs in production.

.gitignore must include:
  - *.xcconfig (local config with keys)
  - .env
  - Secrets/
  - *.ipa
  - DerivedData/
```

---

## 9. Design System Rules

```
Colors:                  ONLY use colors defined in Theme.swift.
                         No hardcoded hex values in views. Ever.
                         If you need a new color, add it to Theme.swift first.

Typography:              ONLY system fonts (SF Pro). No custom font files.
                         Use Typography.swift constants for all text styles.

Components:              ONLY use design system components (GlassCard, VioletButton, etc.)
                         No one-off styled views. If you need a new pattern, create a
                         reusable component in DesignSystem/ first.

Spacing:                 Use the spacing scale from Theme.swift.
                         No magic numbers for padding or margins.

Dark/Light mode:         EVERY view must work in both modes.
                         Test both modes before committing any UI change.
                         Use Theme.swift adaptive colors, not Color.white or Color.black.
```

---

## 10. Claude Code Specific Guardrails

Things Claude Code is NOT allowed to do without explicit approval:

```
- Add or remove Swift packages
- Modify the project's build settings or schemes
- Change the deployment target
- Modify Info.plist entitlements
- Touch Cognito/auth configuration
- Modify the CDK infrastructure stacks
- Change the SwiftData model schema (requires migration planning)
- Delete any file
- Rename any public API or model property (breaks existing code)
- "Refactor" working code that wasn't part of the task
- Add TODO or FIXME comments (fix it now or don't touch it)
- Suppress warnings with @available or #if instead of fixing them
- Use force unwraps (!) anywhere except in tests
- Use try! or as! anywhere except in tests
```

Things Claude Code IS expected to do:

```
- Follow the file structure in CLAUDE.md exactly
- Use the design system components, not inline styles
- Write tests for any new service or calculation
- Handle all optionals safely (guard let, if let, nil coalescing)
- Use async/await, not completion handlers
- Add accessibility labels to all interactive elements
- Keep files under 300 lines
- Commit after each completed task with a clear message
```

---

## 11. Weekly Maintenance

Every Sunday (or before any new sprint starts):

```
1. Pull main. Build. Run. Does it work? If not, fix before doing anything else.
2. Run all tests. Any failures? Fix them.
3. Check for any files over 300 lines. Split them.
4. Check for any dead code or unused imports. Delete them.
5. Check Xcode warnings. Fix all of them.
6. Check SwiftData model. Any pending migrations needed?
7. Update CHANGELOG.md with what shipped that week.
```

---

## 12. Emergency Protocol

If the codebase gets into a broken state and you can't fix it within 30 minutes:

```
1. STOP making changes.
2. git log --oneline -20     (find the last known good commit)
3. git checkout <good-commit> (go back to it)
4. git checkout -b recovery/$(date +%Y%m%d)  (new branch from good state)
5. Cherry-pick only the commits that were confirmed working.
6. Force-push to dev if needed. Protect main at all costs.
```

Never let a broken state persist for more than a day. The old MemoryAisle died because broken code sat unfixed while new broken code was added on top.

---

## 13. Luminetic Self-Check

Before any submission to the App Store:

```
1. Build the .ipa
2. Run it through your own Luminetic scanner
3. Score must be 70+ before submission
4. Fix every Critical and Major issue Luminetic flags
5. Re-scan after fixes to confirm score improved
6. Only submit when Luminetic gives a clean report
```

You built the scanner. Use it on yourself.

---

## Summary: The Three Laws

1. **Main must always work.** If it doesn't build and run, nothing else matters.
2. **One task per Claude Code session.** Scope creep is how regressions are born.
3. **Revert fast.** If something breaks and you can't fix it in 10 minutes, go back. Your time is worth more than any single commit.

---

*These rules are not suggestions. They are the operating contract for this codebase.*
*Break them and you end up with another 10/100 Luminetic score.*
