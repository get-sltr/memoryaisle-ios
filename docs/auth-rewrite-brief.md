# Auth Rewrite — Integration Brief

**Status:** Draft for Kevin's review. Replaces `MemoryAisleAuth-IntegrationBrief.md` from the reference paste.
**Branch:** `feature/auth-rewrite-brief` (this doc only). Implementation will land on `feature/auth-rewrite` off `main`.
**Reference files:** `/Users/KMiI/Desktop/filesDesktop/MAAuth*.swift` — visual/UX reference only.

## What this is

Rewrite of the production auth surface to the editorial Day-mode design (gold gradient, MEMORYAISLE wordmark with sized-up M and A, hairline-underline fields, monospaced caps subtitles, two-line serif heroes). Adds a missing **Welcome screen as first-run gate**, a missing **Forgot Password / Reset Password flow**, and a **Check Email confirmation step** between request and reset. Keeps every production hardening already in place (native Apple Sign-In, no-wipe sign-out, Pro tier gating, session restore, App Reviewer seed, cloud sync hooks).

The reference files in `~/Desktop/filesDesktop/` are **design reference, not source.** They were drafted against an earlier draft codebase (different token namespace, `Amplify.Auth.*` direct calls, Hosted UI federated Apple) and would regress production if installed verbatim. This brief is written against the running codebase: `Theme.Editorial.*` tokens, `CognitoAuthManager` (raw URLRequest), and native `SignInWithAppleButton`.

## What's actually changing

| | Before | After |
|---|---|---|
| Welcome | First-run gate inside `RootView` (`ma_seen_welcome` UserDefault) | Welcome becomes the first screen of `MAAuthFlow`, replaces RootView's inline welcome |
| Sign In | `AuthFlowView.signInView` (state-machine switch, dark theme, `OnboardingLogo`) | `SignInScreen` in NavigationStack, editorial gradient, MEMORYAISLE wordmark |
| Sign Up | `AuthFlowView.signUpView` (email + password) | `SignUpScreen` (name + email + password) |
| Verify | `AuthFlowView.verifyView` (post-signup email confirmation) | Folded into SignUp success path; the new `CheckEmailScreen` is reset-flow only |
| Forgot Password | **Doesn't exist** | New `ForgotPasswordScreen` |
| Check Email | **Doesn't exist** | New `CheckEmailScreen` (reset-code-sent confirmation, RESEND, USE A DIFFERENT EMAIL) |
| Reset Password | **Doesn't exist** | New `ResetPasswordScreen` (code + new password + confirm + match indicator) |
| Apple Sign-In | Native `SignInWithAppleButton` from `AuthenticationServices`, persisted across cold launches | **Stay native — do not adopt the brief's Hosted UI federated path or its custom-styled black capsule** |
| Auth state | `AppState.authStatus` enum (`.unknown / .signedOut / .signedIn`) drives `RootView` | **Unchanged** — new flow plugs into the existing state machine |
| Cognito client | `CognitoAuthManager` (raw URLRequest, no Amplify SDK runtime calls) | **Unchanged** — extend with `resetPassword` and `confirmResetPassword` methods rather than introducing parallel `Amplify.Auth.*` calls |
| Post-signin hook | `handlePostSignIn(email:)` calls `AppReviewerSeedService.handleSignIn(...)` and `subscriptionManager.refreshOverrides()` | **Must call from every success path in the new flow** — Apple, email signin, signup confirm, password reset signin |

## File map (actual paths)

Drop the new screens into `MemoryAisle2/MemoryAisle2/Features/Auth/`. The directory uses Xcode 16 synchronized groups, so new files are auto-picked-up — no `.pbxproj` edit needed.

```
MemoryAisle2/MemoryAisle2/Features/Auth/
  AuthFlowView.swift              [DELETE after MAAuthFlow ships and replaces it in RootView]
  LegalView.swift                 [keep — referenced by the new legal footer]
  MAAuthFlow.swift                [new — NavigationStack router + bridge to CognitoAuthManager]
  MAAuthAtoms.swift               [new — shared atoms; see token translation below]
  Welcome/
    WelcomeScreen.swift           [new]
  SignIn/
    SignInScreen.swift            [new]
  SignUp/
    SignUpScreen.swift            [new]
  Reset/
    ForgotPasswordScreen.swift    [new]
    CheckEmailScreen.swift        [new]
    ResetPasswordScreen.swift     [new]
```

Per-file line caps: 600 lines / file, 50 lines / function (per `CLAUDE.md` ➜ Code Rules). The reference files all fit under both.

## Editorial tokens used

Every visual the new auth screens need already exists in `Theme.Editorial.*` (defined in `DesignSystem/Editorial/Theme+Editorial.swift`). No new color or spacing tokens are introduced.

| Surface use | Token |
|---|---|
| Full-bleed gradient background | `Theme.Editorial.dayGradient` |
| Horizontal page padding (28pt) | `Theme.Editorial.Spacing.pad` |
| Hero serif (38pt, second line italic) | `Theme.Editorial.Typography.displaySmall()` + `.italic()` |
| Monospaced caps subtitle / field labels | `Theme.Editorial.Typography.caps(_:weight:)` and `.capsBold(_:)` |
| Wordmark serif (small letters in MEMORYAISLE) | `Theme.Editorial.Typography.wordmark()` |
| White type (primary) | `Theme.Editorial.onSurface` |
| White type 85% (secondary) | `Theme.Editorial.onSurfaceMuted` |
| White type 55% (faint / disabled) | `Theme.Editorial.onSurfaceFaint` |
| Hairline strokes (45%) | `Theme.Editorial.hairline` |
| Hairline strokes (35%, softer) | `Theme.Editorial.hairlineSoft` |

The MEMORYAISLE wordmark with sized-up M and A is the only new typographic pattern. Add a `MAWordmark` view under `DesignSystem/Editorial/`, or extend the existing `Masthead` with a `wordmark: .full("MEMORYAISLE")` variant — pick whichever reads cleaner during implementation. Both M and A are 15pt serif medium; the rest of the letters are `Theme.Editorial.Typography.wordmark()` (11pt). All hairlines, gradients, and on-surface tints come from the table above.

## Apple Sign-In: keep native, ignore the brief's federated path

The reference brief proposes `Amplify.Auth.signInWithWebUI(for: .apple, presentationAnchor:)` plus a custom `AppleSignInButton` (black capsule with apple logo). **Both are regressions** for this codebase:

1. Production uses **native `ASAuthorization`** via Apple's official `SignInWithAppleButton` view (see `AuthFlowView.swift:102–110`). Three production commits hardened it: `6ae52e0` (HIG), `a40b0a9` (375pt cap), `8f10ac5` (cold-launch persistence).
2. The official `SignInWithAppleButton` already renders to HIG; a custom capsule is App Store review risk.
3. Hosted UI federated requires CDK changes (Apple as federated provider, callback URL, OAuth scopes), an Info.plist URL scheme, and a webview round-trip. Native uses `AuthenticationServices` framework only and stays in-process.

**Action:** in the new screens, the Apple button is `SignInWithAppleButton(.signIn) { request in ... } onCompletion: { result in handleAppleSignIn(result) }` styled to fit the editorial design. The handler is the existing `handleAppleSignIn(_ result:)` from `AuthFlowView.swift:356–383` — extract it into `MAAuthFlow` (or a sibling `AppleSignInHandler` if it's reused across screens).

The custom-styled `AppleSignInButton` from the reference can stay around for visual reference, but **do not ship it.**

## Extend CognitoAuthManager — don't bypass it

The reference `MAAuthViewModel` calls `Amplify.Auth.signIn`, `signUp`, `confirmSignUp`, `resetPassword`, `confirmResetPassword`, `signInWithWebUI`, `signOut` directly. Production routes all Cognito interactions through `CognitoAuthManager` (raw URLRequest against the Cognito User Pool API, not Amplify SDK runtime calls).

**What CognitoAuthManager already exposes** (`Services/Cloud/CognitoAuthManager.swift`):
```swift
@MainActor @Observable final class CognitoAuthManager {
    private(set) var isSignedIn: Bool
    private(set) var isLoading: Bool
    private(set) var userId: String?
    private(set) var email: String?
    private(set) var accessToken: String?
    var error: String?

    func signUp(email: String, password: String) async -> Bool
    func confirmSignUp(email: String, code: String) async -> Bool
    func signIn(email: String, password: String) async -> Bool
    func signOut()
    static func signOutEverywhere(...)
    func restoreSession() async
    nonisolated static func currentUserUUID() -> UUID?
    nonisolated static func currentUserGroups() -> [String]
}
```

**What to add** (extend the existing class, don't fork it):
```swift
extension CognitoAuthManager {
    func resetPassword(email: String) async -> Bool
    func confirmResetPassword(email: String, code: String, newPassword: String) async -> Bool
}
```

Both should follow the same `cognitoRequest(action:body:)` pattern already in the file. Cognito actions are `ForgotPassword` and `ConfirmForgotPassword`. The existing `parseError(_:)` translates Cognito error codes; reuse it instead of porting the brief's `friendlyMessage(for: AuthError)` table.

**Therefore:** the new `MAAuthFlow` does not need its own `MAAuthViewModel`. Inject `CognitoAuthManager` as `@State` (matching `AuthFlowView.swift:16`) and pass it down via parameter or `@Environment` if needed by deeper screens. Drop `@StateObject` / `ObservableObject` — the project is on `@Observable` everywhere else (Swift 6 strict concurrency).

## Production invariants to preserve

These are non-negotiable for any auth rewrite. CLAUDE.md's opening line names the first one explicitly.

1. **No-wipe on sign-out.** `[revert] Stop wiping local data on sign-out — MemoryAisle is longitudinal` (commit `7b22382`). `CognitoAuthManager.signOut()` clears keychain + auth state but does **not** touch SwiftData. Any new sign-out path must do the same. Do not add cleanup helpers that purge `modelContext`.

2. **`handlePostSignIn(email:)` runs after every success path.** Apple, email sign-in, signup auto-sign-in, and reset-password auto-sign-in all need it. It currently does:
   - `AppReviewerSeedService.handleSignIn(email: email, modelContext: modelContext)` — App Reviewer Pro override + demo seed
   - `subscriptionManager.refreshOverrides()` — Pro tier visibility update
   Skipping it on any path will break Pro gating and the App Review demo seed.

3. **`appState.authStatus = .signedIn`** is the bridge to `RootView`. Setting it routes to `MainTabView` (or `OnboardingFlow` if not yet onboarded). The new flow must set it on every success.

4. **Session restore on launch.** `RootView.onAppear` (`App/MemoryAisleApp.swift:94–109`) creates a transient `CognitoAuthManager`, calls `restoreSession()`, sets `appState.authStatus`. The new flow doesn't replace this — it runs *after* RootView decides we're `.signedOut`.

5. **Cloud sync hooks.** `[sync] auto-sync on sign-out, sign-in, and backgrounding` (commit `673600d`) wires sync to auth events. If any wiring lives inside `AuthFlowView`, port it to the new flow. (TODO: confirm location during implementation; may live in `CognitoAuthManager.signOut` or a separate `CloudSyncManager`.)

## Em-dash conflict

The reference subtitle pattern is `"— A QUESTION TO BEGIN WITH"`, `"— WELCOME BACK"`, `"— RESET YOUR PASSWORD"`, `"— A NEW ACCOUNT"`, `"— CODE SENT"`, `"— ALMOST THERE"`. CLAUDE.md says: *"No em dashes in any UI copy, Mira prompts, or Mira-generated text."*

This is a real conflict, and the em-dash usage is intentional (editorial subtitle treatment, pairs with the serif hero). Two options:

(a) **Keep em dashes**, ratify an exception in CLAUDE.md for the editorial subtitle pattern only (Theme.Editorial surfaces).
(b) **Substitute** with bullet (`·`), en dash (`–`), or vertical bar (`|`). E.g. `"· A QUESTION TO BEGIN WITH"`.

**Needs Kev's call before implementation.** I'd lean (a) — the em dash is doing real typographic work in the reference and substituting weakens the design.

## Legal footer — five docs, not two

The reference's `MAAuthLegal` shows TERMS · PRIVACY POLICY. Production shows **five** documents: Terms, Privacy, Medical, Community, Data Policy (`AuthFlowView.swift:330` — `legalLinksNotice`).

**Action:** extend `MAAuthLegal` to accept an array of `(label: String, page: LegalPage)` tuples and render them on multiple lines if needed. Reuse the existing `LegalPage` enum and `LegalView` sheet from `Features/Auth/LegalView.swift`. Don't drop documents — Apple Review checks for the medical disclaimer specifically.

## App entry wiring

`RootView` (`App/MemoryAisleApp.swift:61–110`) is the integration point. Today it does:

```swift
case .signedOut:
    AuthFlowView()
```

After the rewrite:

```swift
case .signedOut:
    MAAuthFlow(authManager: authManager) {
        // onAuthSuccess — already handled inside the flow's per-screen
        // success paths via handlePostSignIn + appState.authStatus,
        // so this closure is only needed if MAAuthFlow chooses to
        // delegate the appState write to the host. Pick one pattern,
        // not both.
    }
```

The `welcomeScreen` currently inside `RootView` (`App/MemoryAisleApp.swift:114–169`) **moves into `MAAuthFlow` as the first NavigationStack destination**, gated by the `ma_seen_welcome` UserDefault. RootView's inline welcome can be deleted in the same PR; nothing else references it.

## What is NOT changing (no approval needed)

Because we're staying on **native Apple Sign-In** (not Hosted UI federated), the following are **not** required:

- ❌ Info.plist `CFBundleURLTypes` — not needed for native ASAuthorization
- ❌ Sign In with Apple capability — already enabled in production for the existing native flow
- ❌ CDK / Cognito infrastructure changes — Cognito is already configured for the existing native flow; password policy and email verification work as-is
- ❌ Backend Lambda changes — none of the new screens introduce new backend behavior
- ❌ New SPM dependencies — `AuthenticationServices` is a system framework

If we ever need to add a federated provider in the future (Google, etc.), that's a separate explicit-approval task with a different brief.

## Implementation plan (when Kev gives go)

On `feature/auth-rewrite` off `main`:

1. **Foundation** — extend `CognitoAuthManager` with `resetPassword` + `confirmResetPassword`. Unit-test against mock URLProtocol. *(does not touch UI)*
2. **Atoms** — create `Features/Auth/MAAuthAtoms.swift` with the translated tokens. Build to confirm compile.
3. **Welcome** — port `WelcomeScreen` with `Theme.Editorial.dayGradient` and the new `MAWordmark` component.
4. **MAAuthFlow router** — NavigationStack with state-driven destinations. Wire `handlePostSignIn` + `appState.authStatus` into each success path.
5. **Sign In + Sign Up** — port screens, wire to extended `CognitoAuthManager`. Keep native `SignInWithAppleButton` (steal the rendering from `AuthFlowView.swift:102–110`).
6. **Forgot / Check Email / Reset** — three new screens against the new CognitoAuthManager extension methods.
7. **Wire into `RootView`** — replace `AuthFlowView()` with `MAAuthFlow(...)`. Move welcome out of RootView.
8. **Delete `AuthFlowView.swift`** — only after all callers are switched and a clean build.
9. **Build + on-device test** — build with zero warnings (per `-warnings-as-errors`), then run on a real iPhone (per CLAUDE.md branch rules: simulator alone is insufficient for HealthKit/audio/keychain).

Each step is its own commit using `[auth] ...` format.

## Build verification (per CLAUDE.md)

Before declaring done:
1. `xcodebuild -project MemoryAisle2/MemoryAisle2.xcodeproj -scheme MemoryAisle2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` — zero warnings
2. SwiftUI previews render for all 6 screens individually plus the full `MAAuthFlow`
3. Native Apple button renders HIG-compliant (375pt cap, system font, system fill)
4. End-to-end on real iPhone: Welcome → Sign In → Forgot Password → Check Email → Reset Password → auto-sign-in → MainTabView
5. Sign in with real Apple ID — federated webview is gone, native sheet appears, keychain persists across cold launch
6. Sign out, then sign back in — SwiftData longitudinal data still present (the no-wipe invariant)
7. Pro tier visibility — sign in as the App Reviewer email, verify Pro features unlock without StoreKit purchase

## Open questions for Kev

1. **Em dash subtitle pattern** — keep (ratify CLAUDE.md exception) or substitute? (My pick: keep.)
2. **Welcome screen on every cold launch, or first-run only?** Current production is first-run only (`ma_seen_welcome` UserDefault). The new flow could either preserve that gate or always show Welcome before sign-in. (My pick: preserve first-run-only — keeps cold-launch latency low for returning users.)
3. **`MAAuthViewModel` vs `CognitoAuthManager` directly** — happy to drop the standalone viewmodel and have screens consume `CognitoAuthManager` via `@State` / `@Environment`? (My pick: drop the viewmodel.)
4. **Day vs Night gradient on auth surfaces** — the editorial app honors `MAMode.auto` (day vs night). Auth screens are pre-onboarding so the user has no preference yet. Lock to day gradient, or honor system time-of-day? (My pick: lock to day — matches the reference, keeps auth surface consistent.)

Once you ratify those four, I can start step 1 (CognitoAuthManager extension + tests) on `feature/auth-rewrite`.
