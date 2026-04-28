# Weekly Meal Plan Generation — Legal/Medical Review

**Status:** READY FOR REVIEW
**Owner:** Kevin (sltrdigital)
**Last updated:** 2026-04-27
**Reviewers needed:** Medical advisor, legal counsel
**Maps to:** `LEGAL-MemoryAisle.md`, `SECURITY-MemoryAisle.md`, `CLAUDE-MemoryAisle.md` (Mira six roles)

---

## Summary

When a user completes signup or returns without a future meal plan, Mira automatically generates 7 days of meal plans tailored to their dietary restrictions, medication, cycle phase, and product mode. This document describes the prompt, the output bounds, and the safety scaffolding so reviewers can confirm the surface stays inside Mira's hard lines.

---

## Trigger surface

Weekly generation fires from one of three triggers:

| Trigger | When | Frequency cap | Quota gate |
|---|---|---|---|
| `signup` | After `OnboardingFlow.completeOnboarding` saves the `UserProfile` | Once per device, ever | `WeeklyMealUsageGate.canStart(.signup)` |
| `backfill` | On app launch when `MainTabView` first appears AND the user has no active `MealPlan` for the next 7 days | Once per 7-day cooldown | `WeeklyMealUsageGate.canStart(.backfill)` |
| `manual` | Tap "GENERATE THIS WEEK" on the editorial Meals empty/failure state | Pro: unlimited. Free: 1 per 24h | `WeeklyMealUsageGate.canStart(.manual)` |

All three paths route through `WeeklyMealPlanOrchestrator.startWeekly`, which checks (a) `FeatureFlags.weeklyMealPlan`, (b) the quota gate above, (c) an in-flight job dedup. Rejected requests never reach Bedrock.

---

## What Mira receives (prompt)

For each of the 7 days (sequential calls — one Bedrock invocation per day so each fits the 29s API gateway timeout), Mira gets:

1. **System prompt** — `MiraEngine.buildSystemPrompt(profile, cyclePhase, giTriggers, pantryItems)`. The system prompt enforces Mira's hard lines: never prescribe, never administer, never distribute, defer to prescriber for dose questions.
2. **Anonymized medication context** — `MedicationAnonymizer.anonymize(...)` produces a `MiraContext` with:
   - `medicationClass` (semaglutide / tirzepatide / orforglipron / unknown — never the brand name)
   - `doseTier` (low / mid / high — never milligrams)
   - `daysSinceDose`
   - `phase` (cycle phase string)
   - `mode` (product mode)
   - Protein / calorie targets, dietary restrictions
3. **Daily request** containing:
   - "Generate N meals for today. Protein target Xg. Calorie target Y."
   - Cycle phase + protein strategy for the day
   - Dietary restrictions verbatim
   - Pantry items if any
   - "Already planned earlier this week (vary protein source and meal style and do NOT repeat exactly): [list]" — for cross-day dedup

The brand name of the user's medication is never sent. The exact dose in milligrams is never sent. The user's name is never sent. The medication context is anonymized to drug class + tier per `MedicationAnonymizer`.

---

## What Mira returns (output bounds)

Mira's response is a list of pipe-delimited meal lines parsed by `MealGenerator.parseMeals`:

```
MEAL|type|name|protein_g|calories|carbs_g|fat_g|fiber_g|prep_minutes|nausea_safe|ingredients|instructions
```

The parser enforces:
- Meals must have ≥10 fields; malformed lines are dropped silently (verified in `MealGeneratorParserTests`)
- Unknown meal types fall back to `.snack`
- Non-numeric protein/calories default to 0
- Empty or unparseable response triggers `fallbackMeals` — four hand-coded high-protein placeholders, never a misleading "I couldn't reach Mira" silence

The meals are stored as `Meal` SwiftData rows attached to a `MealPlan` for that date. They are presented to the user in the editorial Meals tab; tapping a meal reveals ingredients and instructions.

---

## What Mira will NOT produce in this surface

This needs to be confirmed in the system prompt + observed in production. Hard lines (per `project_mira_strategy` memory and `LEGAL-MemoryAisle.md`):

1. **No dose-related advice.** "Eat this if you titrate up to X mg next week" is never produced. The dose is anonymized away from the prompt before Mira sees it.
2. **No medication-changing recommendations.** "Skip your shot to enjoy this dinner" or any phrasing that suggests modifying the prescriber's plan must be refused. The system prompt's hard-line block enforces this.
3. **No diagnostic claims.** Meals labeled `nausea_safe: true` are *suggestions for tolerance*, not diagnoses. The Meal model carries `isNauseaSafe` as a hint to the UI; it is never rendered as "this will cure your nausea."
4. **No medication assistance financial advice in this surface.** That role (manufacturer programs, appeal templates) belongs to the chat MIRA tab, not the meal planner.
5. **No specific micronutrient claims.** Fiber and protein grams come from Mira's estimate; no "this prevents [condition]" copy ships in the meal output.
6. **No supplement recommendations** are emitted as meals.

**Open verification action for the reviewer:** spot-check 20 generated weekly plans across product modes (everyday / sensitive stomach / muscle preservation / training performance / maintenance taper) and confirm none of the above lines are crossed. The os.Logger trail under subsystem `com.memoryaisle.MealGen` captures every generation; a `xcrun simctl spawn ...` log dump or CloudWatch query (lambda-side) can produce the corpus.

---

## Failure modes and user-facing copy

| Mode | Trigger | Copy shown |
|---|---|---|
| Network timeout / Bedrock 5xx | Per-day call exhausts 3 retries (2s/4s/8s backoff) | Day shows "MIRA COULDN'T REACH THIS DAY" with "RETRY THIS WEEK" button |
| Quota exhausted | `WeeklyMealUsageGate` rejects | Free: "FREE WEEKLY REGEN AVAILABLE ONCE PER DAY. UPGRADE FOR UNLIMITED." Pro: "MIRA IS CATCHING UP, TRY AGAIN IN A MOMENT." |
| Feature flag off | Flag disabled mid-launch | "WEEKLY PLANS ARE PAUSED. PLEASE CHECK BACK SOON." |
| App killed mid-generation | `MealGenerationJob.status == running` past 5min stale window | `WeeklyMealPlanOrchestrator.reconcileOrphanedJobs` marks `failed`, user sees "RETRY THIS WEEK" |

All failure copy is monospace caps editorial style — terse, no diagnostic framing, no medical reassurance language.

---

## Persistence and observability

- `MealGenerationJob` SwiftData rows persist across launches (jobId, requestedAt, completedAt, status, daysCompleted, daysFailed, lastError, trigger). One row per generation attempt.
- Logs flow through `os.Logger(subsystem: "com.memoryaisle.MealGen", category: "Generator" | "Orchestrator" | "Quota" | ...)` and are visible in Console.app on device and `xcrun simctl spawn booted log stream`.
- Lambda side (`miraGenerate`) logs to CloudWatch — see `Infrastructure/lambda/miraGenerate/` for that surface. Tying client jobId to lambda invocation id is a follow-up.

---

## Tests covering the safety surface

| Concern | Test | Status |
|---|---|---|
| Parser drops malformed lines | `MealGeneratorParserTests.test_lineWithFewerThan10Pipes_isSkipped` | green |
| Parser falls back on empty Bedrock response | `MealGeneratorParserTests.test_emptyResponse_returnsFallback` | green |
| Quota: signup once per lifetime | `WeeklyMealUsageGateTests.test_signup_isRejectedAfterRecording` | green |
| Quota: backfill cooldown | `WeeklyMealUsageGateTests.test_backfill_isRejectedDuringCooldown` | green |
| Quota: free-tier manual cooldown | `WeeklyMealUsageGateTests.test_manual_freeUser_rejectedDuringCooldown` | green |
| Cycle phase per-day correctness | `InjectionCyclePhaseTests.test_phasesShiftCorrectlyAcrossSevenConsecutiveDays` | green |
| Job lifecycle invariants | `MealGenerationJobTests.test_*` | green |

Real Bedrock-call tests are not run in CI — they would burn quota and be non-deterministic. Live validation happens via on-device QA per `docs/weekly-meal-plan-device-test.md`.

---

## Required reviewer sign-offs before broad rollout

- [ ] Medical advisor — confirms the prompt + output bounds stay inside the six-roles framework and don't drift into prescriber territory.
- [ ] Legal — confirms the manufactured 7-day plans don't constitute medical advice under the relevant practice-of-medicine statutes for the user's jurisdiction.
- [ ] Kevin — confirms 20-plan spot check shows no hard-line violations across all 5 product modes.

Until all three boxes are checked, `FeatureFlags.weeklyMealPlan` should remain off in production builds.
