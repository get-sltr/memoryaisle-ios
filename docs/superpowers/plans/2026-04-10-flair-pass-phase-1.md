# Flair Pass Phase 1 — Design System Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the section-color design system foundation — new named colors, `SectionPalette`, `MeshGradientView`, 7 new view components, and section-aware refactors of existing buttons/cards — with zero visible change to feature views and a backward-compatible API.

**Architecture:** Extend `Theme.swift` with a `Theme.Section` namespace and section-aware variants of `Surface` / `Border`. Add a `SectionID` enum + `@Environment(\.sectionID)` so nested components inherit section context without prop drilling. Create new `StatTile`, `SectionCard`, `HeroHeader`, `CloseButton`, `DismissButton`, `IconButton`, `SegmentedPill`, `MeshGradientView`, and `ShimmerModifier`. Refactor `VioletButton`, `GhostButton`, `GlowButton`, `GlassCard`, `GlassCardStrong` to accept an optional section, defaulting to `.home` (violet) so every existing call site keeps working untouched.

**Tech Stack:** Swift 6, SwiftUI, iOS 17+. Apple frameworks only. No new packages. Design system lives in `MemoryAisle2/MemoryAisle2/DesignSystem/`.

**Spec reference:** `docs/superpowers/specs/2026-04-10-flair-pass-design.md`

**Phase scope:** This plan is Phase 1 of 3 from the spec. Phase 1 ships the foundation only — no feature views change. Phase 2 (priority page migrations) and Phase 3 (universal treatment + repo-wide sweep) get their own plans written after Phase 1 merges to `dev`.

**Verification loop (TDD adapted for SwiftUI views):** `CLAUDE.md` forbids unit-testing SwiftUI views directly. For every task, the verification step is (1) `xcodebuild` with zero warnings and zero errors, and (2) `#Preview` renders produced by the new component. Engineers should open the file in Xcode and confirm previews render in both dark and light mode before committing.

**Build command (used at every verification step):**
```bash
xcodebuild -project MemoryAisle2/MemoryAisle2.xcodeproj \
  -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```
Expected output on success: `** BUILD SUCCEEDED **` on the last line, no lines containing `warning:` or `error:`.

**Branch:** `feature/flair-pass` (already created from `feature/missing-services-models`). All commits in Phase 1 land on this branch. Merge to `dev` only after all 17 tasks complete and the final build is clean.

---

## File Structure

**Modified files (6):**
- `MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift` — add named colors, `Theme.Section` namespace, section-aware `Surface`/`Border` variants
- `MemoryAisle2/MemoryAisle2/DesignSystem/VioletButton.swift` — accept optional `section:`, add press glow pulse
- `MemoryAisle2/MemoryAisle2/DesignSystem/GhostButton.swift` — section-aware border, inner shadow on press
- `MemoryAisle2/MemoryAisle2/DesignSystem/GlowButton.swift` — section-aware halo + pulse-on-appear
- `MemoryAisle2/MemoryAisle2/DesignSystem/GlassCard.swift` — section-aware pastel tint
- `MemoryAisle2/MemoryAisle2/DesignSystem/GlassCardStrong.swift` — section-aware mild glow

**New files (11):**
- `MemoryAisle2/MemoryAisle2/DesignSystem/SectionPalette.swift` — `SectionID` enum + `SectionStyle` struct + environment key
- `MemoryAisle2/MemoryAisle2/DesignSystem/MeshGradient.swift` — animated mesh gradient view
- `MemoryAisle2/MemoryAisle2/DesignSystem/ShimmerModifier.swift` — loading shimmer modifier
- `MemoryAisle2/MemoryAisle2/DesignSystem/CloseButton.swift` — universal X
- `MemoryAisle2/MemoryAisle2/DesignSystem/DismissButton.swift` — back/exit pill
- `MemoryAisle2/MemoryAisle2/DesignSystem/IconButton.swift` — circular icon button
- `MemoryAisle2/MemoryAisle2/DesignSystem/SegmentedPill.swift` — animated segmented control
- `MemoryAisle2/MemoryAisle2/DesignSystem/StatTile.swift` — bold stat card
- `MemoryAisle2/MemoryAisle2/DesignSystem/SectionCard.swift` — pastel list-row container
- `MemoryAisle2/MemoryAisle2/DesignSystem/HeroHeader.swift` — top-of-page mesh header

**Project file note:** Every new `.swift` file in `MemoryAisle2/MemoryAisle2/DesignSystem/` must be added to the `MemoryAisle2` target in `MemoryAisle2.xcodeproj`. The easiest way is to add the file from Xcode, which handles the `project.pbxproj` update. If operating headlessly, add the file references to `project.pbxproj` under the `DesignSystem` group. The build step will fail with "Cannot find 'X' in scope" if a file isn't in the target, which is the signal to add it.

---

## Task 1: Add section named colors to Theme.swift

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift`

- [ ] **Step 1: Add named colors for each section hue**

Use the `Edit` tool on `MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift`.

`old_string`:
```swift
// MARK: - Named Colors

extension Color {
    nonisolated static let violet = Color(hex: 0xA78BFA)
    nonisolated static let violetDeep = Color(hex: 0x7C3AED)
    nonisolated static let violetMid = Color(hex: 0x8B5CF6)
    nonisolated static let lavender = Color(hex: 0xC4B5FD)
    nonisolated static let indigoBlack = Color(hex: 0x0A0914)
}
```

`new_string`:
```swift
// MARK: - Named Colors

extension Color {
    // Brand anchor
    nonisolated static let violet = Color(hex: 0xA78BFA)
    nonisolated static let violetDeep = Color(hex: 0x7C3AED)
    nonisolated static let violetMid = Color(hex: 0x8B5CF6)
    nonisolated static let lavender = Color(hex: 0xC4B5FD)
    nonisolated static let indigoBlack = Color(hex: 0x0A0914)

    // Pantry — emerald
    nonisolated static let emerald = Color(hex: 0x10B981)
    nonisolated static let emeraldDeep = Color(hex: 0x047857)
    nonisolated static let emeraldMid = Color(hex: 0x059669)
    nonisolated static let emeraldSoft = Color(hex: 0x6EE7B7)

    // Recipes — amber
    nonisolated static let amber = Color(hex: 0xF59E0B)
    nonisolated static let amberDeep = Color(hex: 0xB45309)
    nonisolated static let amberMid = Color(hex: 0xD97706)
    nonisolated static let amberSoft = Color(hex: 0xFCD34D)

    // Scanner — cyan
    nonisolated static let cyan = Color(hex: 0x06B6D4)
    nonisolated static let cyanDeep = Color(hex: 0x0E7490)
    nonisolated static let cyanMid = Color(hex: 0x0891B2)
    nonisolated static let cyanSoft = Color(hex: 0x67E8F9)

    // Grocery — sky
    nonisolated static let sky = Color(hex: 0x0EA5E9)
    nonisolated static let skyDeep = Color(hex: 0x0369A1)
    nonisolated static let skyMid = Color(hex: 0x0284C7)
    nonisolated static let skySoft = Color(hex: 0x7DD3FC)

    // Calendar — rose
    nonisolated static let rose = Color(hex: 0xF472B6)
    nonisolated static let roseDeep = Color(hex: 0xBE185D)
    nonisolated static let roseMid = Color(hex: 0xDB2777)
    nonisolated static let roseSoft = Color(hex: 0xFBCFE8)

    // Progress — lime
    nonisolated static let lime = Color(hex: 0x84CC16)
    nonisolated static let limeDeep = Color(hex: 0x4D7C0F)
    nonisolated static let limeMid = Color(hex: 0x65A30D)
    nonisolated static let limeSoft = Color(hex: 0xBEF264)
}
```

- [ ] **Step 2: Build to confirm zero warnings**

Run the build command above. Expected: `** BUILD SUCCEEDED **`, no `warning:` or `error:` lines. The new colors aren't used yet, so the build only verifies syntax.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift
git commit -m "[design] add section named colors for flair pass"
```

---

## Task 2: Create SectionPalette.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/SectionPalette.swift`

- [ ] **Step 1: Write the new file**

Use the `Write` tool with this exact content:

```swift
import SwiftUI

// MARK: - Section Identity

enum SectionID: String, CaseIterable, Sendable {
    case home
    case pantry
    case recipes
    case scanner
    case grocery
    case calendar
    case progress
    case mira
}

// MARK: - Section Style Lookups

enum SectionPalette {

    // Primary hue for the section. Used for tile glows, chip fills, accent rings.
    static func primary(_ id: SectionID, for scheme: ColorScheme) -> Color {
        switch id {
        case .home, .mira: return scheme == .dark ? .violet : .violetDeep
        case .pantry:      return scheme == .dark ? .emerald : .emeraldDeep
        case .recipes:     return scheme == .dark ? .amber : .amberDeep
        case .scanner:     return scheme == .dark ? .cyan : .cyanDeep
        case .grocery:     return scheme == .dark ? .sky : .skyDeep
        case .calendar:    return scheme == .dark ? .rose : .roseDeep
        case .progress:    return scheme == .dark ? .lime : .limeDeep
        }
    }

    // Mid tone used for gradient stops.
    static func mid(_ id: SectionID, for scheme: ColorScheme) -> Color {
        switch id {
        case .home, .mira: return .violetMid
        case .pantry:      return .emeraldMid
        case .recipes:     return .amberMid
        case .scanner:     return .cyanMid
        case .grocery:     return .skyMid
        case .calendar:    return .roseMid
        case .progress:    return .limeMid
        }
    }

    // Soft tone used for readable labels on dark surfaces and for chips.
    static func soft(_ id: SectionID) -> Color {
        switch id {
        case .home, .mira: return .lavender
        case .pantry:      return .emeraldSoft
        case .recipes:     return .amberSoft
        case .scanner:     return .cyanSoft
        case .grocery:     return .skySoft
        case .calendar:    return .roseSoft
        case .progress:    return .limeSoft
        }
    }

    // Hero mesh: returns the 3 tones used by MeshGradientView.
    // For Mira, returns the Aurora trio (violet + cyan + rose).
    static func meshTones(_ id: SectionID, for scheme: ColorScheme) -> (Color, Color, Color) {
        switch id {
        case .mira:
            return (
                scheme == .dark ? .violet : .violetDeep,
                scheme == .dark ? .cyan : .cyanMid,
                scheme == .dark ? .rose : .roseMid
            )
        case .home:
            return (.violet, .violetMid, .lavender)
        case .pantry:
            return (.emerald, .cyan, .emeraldSoft)
        case .recipes:
            return (.amber, .rose, .amberSoft)
        case .scanner:
            return (.cyan, .violet, .cyanSoft)
        case .grocery:
            return (.sky, .violet, .skySoft)
        case .calendar:
            return (.rose, .violet, .roseSoft)
        case .progress:
            return (.lime, .violet, .limeSoft)
        }
    }
}

// MARK: - Environment Key

private struct SectionIDKey: EnvironmentKey {
    static let defaultValue: SectionID = .home
}

extension EnvironmentValues {
    var sectionID: SectionID {
        get { self[SectionIDKey.self] }
        set { self[SectionIDKey.self] = newValue }
    }
}

extension View {
    // Sets the section identity for all descendant views.
    func section(_ id: SectionID) -> some View {
        environment(\.sectionID, id)
    }
}
```

- [ ] **Step 2: Add the file to the Xcode target**

Open `MemoryAisle2/MemoryAisle2.xcodeproj` in Xcode and add `SectionPalette.swift` to the `MemoryAisle2` target under the `DesignSystem` group. Alternatively, if editing `project.pbxproj` directly, add a `PBXFileReference` for `SectionPalette.swift` under the `DesignSystem` group and a `PBXBuildFile` entry in the `Sources` build phase of the `MemoryAisle2` target.

- [ ] **Step 3: Build to confirm zero warnings**

Run the build command. Expected: `** BUILD SUCCEEDED **`. If the build fails with "Cannot find 'SectionPalette' in scope" or "Cannot find 'SectionID' in scope," the file is not in the target — fix via step 2.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/SectionPalette.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add SectionPalette with SectionID and environment key"
```

---

## Task 3: Extend Theme.Surface with section-aware variants

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift`

- [ ] **Step 1: Replace the Surface namespace**

Use `Edit` on `Theme.swift`.

`old_string`:
```swift
    // MARK: Surface (Glass)

    enum Surface {
        static let glass = Color.violet.opacity(0.04)
        static let strong = Color.violet.opacity(0.07)
        static let pressed = Color.violet.opacity(0.12)

        static func glass(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.04)
                : Color.lavender.opacity(0.12)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.07)
                : Color.lavender.opacity(0.18)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.12)
                : Color.lavender.opacity(0.25)
        }
    }
```

`new_string`:
```swift
    // MARK: Surface (Glass)

    enum Surface {
        static let glass = Color.violet.opacity(0.04)
        static let strong = Color.violet.opacity(0.07)
        static let pressed = Color.violet.opacity(0.12)

        // Backward-compatible (violet only) — existing call sites keep working.
        static func glass(for scheme: ColorScheme) -> Color {
            glass(section: .home, for: scheme)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            strong(section: .home, for: scheme)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            pressed(section: .home, for: scheme)
        }

        // Pastel tinted glass for list rows and secondary cards.
        static func glass(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.08) : base.opacity(0.10)
        }

        static func strong(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.14) : base.opacity(0.18)
        }

        static func pressed(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.22) : base.opacity(0.28)
        }

        // Bold tile glow — RadialGradient for StatTile backgrounds.
        static func tile(section: SectionID, for scheme: ColorScheme) -> RadialGradient {
            let hue = SectionPalette.primary(section, for: scheme)
            return RadialGradient(
                colors: [
                    hue.opacity(0.55),
                    hue.opacity(0.0)
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 260
            )
        }
    }
```

- [ ] **Step 2: Build to confirm zero warnings**

Run the build command. Expected: `** BUILD SUCCEEDED **`, no warnings. All existing violet-only call sites still work because the zero-arg variants delegate to the `.home` section.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift
git commit -m "[design] extend Theme.Surface with section-aware variants"
```

---

## Task 4: Extend Theme.Border with section-aware variants + add Theme.Section namespace

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift`

- [ ] **Step 1: Replace the Border namespace**

Use `Edit` on `Theme.swift`.

`old_string`:
```swift
    // MARK: Border

    enum Border {
        static func glass(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.10)
                : Color.lavender.opacity(0.2)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.14)
                : Color.lavender.opacity(0.3)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.25)
                : Color.lavender.opacity(0.35)
        }
    }
```

`new_string`:
```swift
    // MARK: Border

    enum Border {
        // Backward-compatible — existing call sites keep working (violet).
        static func glass(for scheme: ColorScheme) -> Color {
            glass(section: .home, for: scheme)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            strong(section: .home, for: scheme)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            pressed(section: .home, for: scheme)
        }

        // Pastel border for content (list rows, inline cards).
        static func glass(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.22) : base.opacity(0.28)
        }

        static func strong(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.32) : base.opacity(0.40)
        }

        static func pressed(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.45) : base.opacity(0.55)
        }

        // Bright tile border — higher opacity for the hero moments.
        static func glow(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.40) : base.opacity(0.50)
        }
    }
```

- [ ] **Step 2: Add `Theme.Section` convenience namespace**

Use `Edit` on `Theme.swift` to add a new namespace right after the `Border` enum and before `Text`.

`old_string`:
```swift
    // MARK: Text
```

`new_string`:
```swift
    // MARK: Section (convenience wrappers)

    enum Section {
        static func tile(_ id: SectionID, for scheme: ColorScheme) -> RadialGradient {
            Surface.tile(section: id, for: scheme)
        }

        static func glass(_ id: SectionID, for scheme: ColorScheme) -> Color {
            Surface.glass(section: id, for: scheme)
        }

        static func border(_ id: SectionID, for scheme: ColorScheme) -> Color {
            Border.glass(section: id, for: scheme)
        }

        static func glow(_ id: SectionID, for scheme: ColorScheme) -> Color {
            Border.glow(section: id, for: scheme)
        }

        static func primary(_ id: SectionID, for scheme: ColorScheme) -> Color {
            SectionPalette.primary(id, for: scheme)
        }
    }

    // MARK: Text
```

- [ ] **Step 3: Build to confirm zero warnings**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/Theme.swift
git commit -m "[design] extend Theme.Border and add Theme.Section wrappers"
```

---

## Task 5: Create MeshGradient.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/MeshGradient.swift`

- [ ] **Step 1: Write the file**

Use the `Write` tool with this content:

```swift
import SwiftUI

// Animated mesh gradient for hero headers and Mira's chat surface.
// Three radial gradients slowly drift between anchor positions on an 8s cycle.
// Battery-safe: uses TimelineView(.animation) which pauses when off-screen.
struct MeshGradientView: View {
    @Environment(\.colorScheme) private var scheme
    let section: SectionID
    var intensity: Double = 0.55

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: 8.0)) / 8.0
                let (a, b, c) = SectionPalette.meshTones(section, for: scheme)

                canvas.blendMode = .normal
                canvas.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color.indigoBlack)
                )

                drawGradientBlob(
                    canvas: &canvas,
                    size: size,
                    color: a.opacity(intensity),
                    normCenter: blobCenter(phase, base: CGPoint(x: 0.15, y: 0.25), amp: 0.08),
                    normRadius: 0.75
                )
                drawGradientBlob(
                    canvas: &canvas,
                    size: size,
                    color: b.opacity(intensity * 0.85),
                    normCenter: blobCenter(phase + 0.33, base: CGPoint(x: 0.80, y: 0.35), amp: 0.10),
                    normRadius: 0.70
                )
                drawGradientBlob(
                    canvas: &canvas,
                    size: size,
                    color: c.opacity(intensity * 0.75),
                    normCenter: blobCenter(phase + 0.66, base: CGPoint(x: 0.55, y: 0.90), amp: 0.07),
                    normRadius: 0.80
                )
            }
        }
        .overlay(
            LinearGradient(
                colors: [.clear, Color.indigoBlack.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .drawingGroup()
    }

    private func blobCenter(_ phase: Double, base: CGPoint, amp: Double) -> CGPoint {
        let wrapped = phase.truncatingRemainder(dividingBy: 1.0)
        let angle = wrapped * 2 * .pi
        let dx = CGFloat(cos(angle) * amp)
        let dy = CGFloat(sin(angle) * amp)
        return CGPoint(x: base.x + dx, y: base.y + dy)
    }

    private func drawGradientBlob(
        canvas: inout GraphicsContext,
        size: CGSize,
        color: Color,
        normCenter: CGPoint,
        normRadius: Double
    ) {
        let center = CGPoint(x: normCenter.x * size.width, y: normCenter.y * size.height)
        let radius = CGFloat(normRadius) * max(size.width, size.height)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [color, color.opacity(0)]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
        canvas.fill(Path(ellipseIn: rect), with: shading)
    }
}

#Preview("Dark — each section") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(SectionID.allCases, id: \.self) { id in
                MeshGradientView(section: id)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        Text(id.rawValue.capitalized)
                            .foregroundStyle(.white)
                            .font(.headline),
                        alignment: .bottomLeading
                    )
                    .padding(.horizontal)
            }
        }
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}

#Preview("Light — each section") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(SectionID.allCases, id: \.self) { id in
                MeshGradientView(section: id)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal)
            }
        }
    }
    .background(Color.white)
    .preferredColorScheme(.light)
}
```

- [ ] **Step 2: Add to Xcode target**

Same procedure as Task 2 step 2.

- [ ] **Step 3: Build to confirm zero warnings**

Run the build command. Expected: `** BUILD SUCCEEDED **`, no warnings.

- [ ] **Step 4: Verify previews render**

Open `MeshGradient.swift` in Xcode. Click the "Resume" button in the Canvas. The "Dark — each section" preview should show 8 animated blobs in distinct hues (violet, emerald, amber, cyan, sky, rose, lime, and aurora for Mira). The "Light — each section" preview should show 8 hero-ish cards with paler mesh. Confirm no stuttering — the 8s cycle should feel slow and atmospheric.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/MeshGradient.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add MeshGradientView with 8s animated drift"
```

---

## Task 6: Create ShimmerModifier.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/ShimmerModifier.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

// Loading shimmer effect for placeholder content.
// Uses a linear gradient highlight that sweeps across the target view.
struct ShimmerModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0), location: 0.0),
                            .init(color: .white.opacity(scheme == .dark ? 0.12 : 0.18), location: 0.5),
                            .init(color: .white.opacity(0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                    .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    // Applies a loading shimmer highlight that sweeps left to right on a 1.4s loop.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview("Shimmer on section cards") {
    VStack(spacing: 16) {
        ForEach(SectionID.allCases, id: \.self) { id in
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Section.glass(id, for: .dark))
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Section.border(id, for: .dark), lineWidth: 0.5)
                )
                .shimmer()
        }
    }
    .padding()
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Add to Xcode target**

Same as Task 2 step 2.

- [ ] **Step 3: Build to confirm zero warnings**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify preview**

Open `ShimmerModifier.swift` in Xcode. The preview should show 8 pastel section-colored cards with a soft highlight sweeping left to right on each.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/ShimmerModifier.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add ShimmerModifier for loading placeholders"
```

---

## Task 7: Create CloseButton.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/CloseButton.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

// Universal close affordance. Use anywhere a sheet/cover/detail needs a dismiss X.
// 44×44 tap target, 22×22 visual, glass circle background, haptic light on tap.
struct CloseButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(.label))
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(Theme.Section.glass(sectionID, for: scheme))
                )
                .overlay(
                    Circle().stroke(
                        Theme.Section.border(sectionID, for: scheme),
                        lineWidth: Theme.glassBorderWidth
                    )
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

#Preview("CloseButton — each section, dark") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SectionID.allCases, id: \.self) { id in
                HStack {
                    Text(id.rawValue.capitalized)
                        .foregroundStyle(.white)
                    Spacer()
                    CloseButton(action: {}).section(id)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}

#Preview("CloseButton — light") {
    VStack {
        CloseButton(action: {}).section(.pantry)
        CloseButton(action: {}).section(.recipes)
    }
    .padding()
    .background(Color.white)
    .preferredColorScheme(.light)
}
```

- [ ] **Step 2: Add to Xcode target**

Same as Task 2 step 2.

- [ ] **Step 3: Build to confirm zero warnings**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify previews render**

Open `CloseButton.swift` in Xcode. Confirm the dark preview shows 8 close buttons, each with a pastel circle background in the section's color. The light preview should show two distinct pastels.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/CloseButton.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add universal CloseButton component"
```

---

## Task 8: Create DismissButton.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/DismissButton.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

// Universal back/dismiss affordance. Chevron-left inside a glass pill.
// 44pt tap target height, haptic light on tap, section-aware.
struct DismissButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID
    let label: String?
    let action: () -> Void

    init(label: String? = nil, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                if let label {
                    Text(label)
                        .font(Typography.bodyMediumBold)
                }
            }
            .foregroundStyle(Color(.label))
            .padding(.horizontal, label == nil ? 0 : 12)
            .frame(minWidth: 32, minHeight: 32)
            .background(
                Capsule().fill(Theme.Section.glass(sectionID, for: scheme))
            )
            .overlay(
                Capsule().stroke(
                    Theme.Section.border(sectionID, for: scheme),
                    lineWidth: Theme.glassBorderWidth
                )
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "Back")
    }
}

#Preview("DismissButton — icon only + labeled") {
    VStack(spacing: 16) {
        ForEach(SectionID.allCases, id: \.self) { id in
            HStack(spacing: 12) {
                DismissButton(action: {}).section(id)
                DismissButton(label: "Back", action: {}).section(id)
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    .padding(.vertical)
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Add to Xcode target**

Same as Task 2 step 2.

- [ ] **Step 3: Build to confirm zero warnings**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/DismissButton.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add universal DismissButton component"
```

---

## Task 9: Create IconButton.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/IconButton.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

// Generic circular icon button — filter, more, search, settings, etc.
// 44×44 tap target, 40×40 visual, section-aware glass + border.
struct IconButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    init(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SectionPalette.primary(sectionID, for: scheme))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(Theme.Section.glass(sectionID, for: scheme))
                )
                .overlay(
                    Circle().stroke(
                        Theme.Section.border(sectionID, for: scheme),
                        lineWidth: Theme.glassBorderWidth
                    )
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("IconButton — each section") {
    VStack(spacing: 12) {
        ForEach(SectionID.allCases, id: \.self) { id in
            HStack(spacing: 12) {
                IconButton(systemName: "magnifyingglass", accessibilityLabel: "Search", action: {}).section(id)
                IconButton(systemName: "line.3.horizontal.decrease", accessibilityLabel: "Filter", action: {}).section(id)
                IconButton(systemName: "ellipsis", accessibilityLabel: "More", action: {}).section(id)
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    .padding(.vertical)
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Add to Xcode target.** Same as Task 2 step 2.

- [ ] **Step 3: Build.** Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/IconButton.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add generic section-aware IconButton"
```

---

## Task 10: Create SegmentedPill.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/SegmentedPill.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

// Animated segmented control with a matched-geometry selection indicator
// that slides between options. Section-aware.
struct SegmentedPill<Value: Hashable>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID
    @Namespace private var selectionNS

    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button(action: {
                    guard option.value != selection else { return }
                    HapticManager.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = option.value
                    }
                }) {
                    Text(option.label)
                        .font(Typography.bodyMediumBold)
                        .foregroundStyle(
                            option.value == selection
                                ? Color.white
                                : SectionPalette.primary(sectionID, for: scheme)
                        )
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background {
                            if option.value == selection {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                SectionPalette.primary(sectionID, for: scheme),
                                                SectionPalette.mid(sectionID, for: scheme)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "pill", in: selectionNS)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(option.value == selection ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(
            Capsule().fill(Theme.Section.glass(sectionID, for: scheme))
        )
        .overlay(
            Capsule().stroke(
                Theme.Section.border(sectionID, for: scheme),
                lineWidth: Theme.glassBorderWidth
            )
        )
    }
}

#Preview("SegmentedPill — each section") {
    struct Host: View {
        @State var selection = "day"
        var body: some View {
            VStack(spacing: 16) {
                ForEach(SectionID.allCases, id: \.self) { id in
                    SegmentedPill(
                        options: [("day", "Day"), ("week", "Week"), ("month", "Month")],
                        selection: $selection
                    )
                    .section(id)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    return Host()
        .background(Color.indigoBlack)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Add to Xcode target.** Same as Task 2 step 2.

- [ ] **Step 3: Build.** Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify preview.** In Xcode's preview canvas, tap between Day/Week/Month — the pill indicator should slide smoothly.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/SegmentedPill.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add animated SegmentedPill with matched geometry"
```

---

## Task 11: Create StatTile.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/StatTile.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

// Bold stat card — the "pop" element that goes on every dashboard.
// Big number + uppercase label + optional sub-caption.
// Reads section from environment unless overridden.
struct StatTile: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    let label: String
    let value: String
    let sub: String?
    let sectionOverride: SectionID?

    init(
        label: String,
        value: String,
        sub: String? = nil,
        section: SectionID? = nil
    ) {
        self.label = label
        self.value = value
        self.sub = sub
        self.sectionOverride = section
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Typography.label)
                .tracking(1.2)
                .foregroundStyle(SectionPalette.soft(effectiveSection))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(Color(.label))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 96)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Color.indigoBlack)
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.Section.tile(effectiveSection, for: scheme))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Section.glow(effectiveSection, for: scheme), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)\(sub.map { ", \($0)" } ?? "")")
    }
}

#Preview("StatTile grid — dark") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SectionID.allCases, id: \.self) { id in
                HStack(spacing: 12) {
                    StatTile(label: "Items", value: "24", sub: "3 expiring").section(id)
                    StatTile(label: "Protein", value: "128g", sub: "of 180").section(id)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}

#Preview("StatTile grid — light") {
    HStack(spacing: 12) {
        StatTile(label: "Items", value: "24", sub: "3 expiring").section(.pantry)
        StatTile(label: "Recipes", value: "12").section(.recipes)
    }
    .padding()
    .background(Color.white)
    .preferredColorScheme(.light)
}
```

- [ ] **Step 2: Add to Xcode target.** Same as Task 2 step 2.

- [ ] **Step 3: Build.** Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify preview.** Dark preview should show 16 tiles (2 per section) with distinct colored glows in the top-right of each tile.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/StatTile.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add StatTile bold stat card component"
```

---

## Task 12: Create SectionCard.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/SectionCard.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

// Pastel list-row container — the default wrapper for any list row
// or inline card on a feature page. Reads section from environment.
struct SectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    let sectionOverride: SectionID?
    let content: () -> Content

    init(
        section: SectionID? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionOverride = section
        self.content = content
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        content()
            .background(Theme.Section.glass(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Section.border(effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}

// Interactive variant — tap to perform an action.
struct InteractiveSectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    @State private var isPressed = false
    let sectionOverride: SectionID?
    let action: () -> Void
    let content: () -> Content

    init(
        section: SectionID? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionOverride = section
        self.action = action
        self.content = content
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            content()
                .background(
                    isPressed
                        ? Theme.Surface.pressed(section: effectiveSection, for: scheme)
                        : Theme.Section.glass(effectiveSection, for: scheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(
                            isPressed
                                ? Theme.Border.pressed(section: effectiveSection, for: scheme)
                                : Theme.Section.border(effectiveSection, for: scheme),
                            lineWidth: Theme.glassBorderWidth
                        )
                )
        }
        .buttonStyle(SectionCardPressStyle(isPressed: $isPressed))
    }
}

private struct SectionCardPressStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, new in
                isPressed = new
            }
    }
}

#Preview("SectionCard — rows per section") {
    ScrollView {
        VStack(spacing: 10) {
            ForEach(SectionID.allCases, id: \.self) { id in
                SectionCard {
                    HStack {
                        Text(id.rawValue.capitalized)
                            .foregroundStyle(Color(.label))
                            .font(Typography.bodyLargeBold)
                            .padding(16)
                        Spacer()
                    }
                }
                .section(id)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Add to Xcode target.** Same as Task 2 step 2.

- [ ] **Step 3: Build.** Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/SectionCard.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add SectionCard and InteractiveSectionCard"
```

---

## Task 13: Create HeroHeader.swift

**Files:**
- Create: `MemoryAisle2/MemoryAisle2/DesignSystem/HeroHeader.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

// Top-of-page hero header with animated mesh gradient background.
// Approximately 220pt tall, title + optional subtitle, optional trailing slot.
struct HeroHeader<Trailing: View>: View {
    @Environment(\.sectionID) private var sectionID
    let title: String
    let subtitle: String?
    let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MeshGradientView(section: sectionID)
                .frame(height: 220)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    }
                }
                Spacer()
                VStack {
                    trailing()
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 20)
        }
        .frame(height: 220)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                style: .continuous
            )
        )
    }
}

extension HeroHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

#Preview("HeroHeader — each section") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(SectionID.allCases, id: \.self) { id in
                HeroHeader(
                    title: id.rawValue.capitalized,
                    subtitle: "\(Int.random(in: 5...30)) items · updated just now"
                ) {
                    CloseButton(action: {})
                }
                .section(id)
            }
        }
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
    .ignoresSafeArea()
}
```

- [ ] **Step 2: Add to Xcode target.** Same as Task 2 step 2.

- [ ] **Step 3: Build.** Expected `** BUILD SUCCEEDED **`. Note: `UnevenRoundedRectangle` requires iOS 16+ — the project targets iOS 17+ per CLAUDE.md so this is fine.

- [ ] **Step 4: Verify preview.** Should show 8 hero headers, each with distinct mesh color + a close button in the top-right corner.

- [ ] **Step 5: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/HeroHeader.swift \
        MemoryAisle2/MemoryAisle2.xcodeproj/project.pbxproj
git commit -m "[design] add HeroHeader with mesh gradient background"
```

---

## Task 14: Refactor VioletButton for section awareness + glow pulse

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/DesignSystem/VioletButton.swift`

- [ ] **Step 1: Replace the file contents**

Use the `Write` tool to overwrite `MemoryAisle2/MemoryAisle2/DesignSystem/VioletButton.swift` with:

```swift
import SwiftUI

struct VioletButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection

    let title: String
    let icon: String?
    let isLoading: Bool
    let sectionOverride: SectionID?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        section: SectionID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.sectionOverride = section
        self.action = action
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            HapticManager.medium()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodyMediumBold)
                }

                Text(title)
                    .font(Typography.bodyLargeBold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        SectionPalette.primary(effectiveSection, for: scheme),
                        SectionPalette.mid(effectiveSection, for: scheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(VioletPressStyle(section: effectiveSection, scheme: scheme))
        .opacity(isLoading ? 0.8 : 1.0)
        .accessibilityLabel(title)
    }
}

// MARK: - Compact Variant

struct VioletButtonCompact: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection

    let title: String
    let icon: String?
    let sectionOverride: SectionID?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        section: SectionID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.sectionOverride = section
        self.action = action
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: Theme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodySmall)
                }
                Text(title)
                    .font(Typography.bodyMediumBold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(SectionPalette.primary(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(VioletPressStyle(section: effectiveSection, scheme: scheme))
        .accessibilityLabel(title)
    }
}

// MARK: - Press Style

private struct VioletPressStyle: ButtonStyle {
    let section: SectionID
    let scheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .shadow(
                color: SectionPalette.primary(section, for: scheme)
                    .opacity(configuration.isPressed ? 0.55 : 0.0),
                radius: configuration.isPressed ? 20 : 0,
                y: 0
            )
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

#Preview("VioletButton — each section") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SectionID.allCases, id: \.self) { id in
                VioletButton("Continue", icon: "arrow.right") {}
                    .section(id)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build to confirm zero warnings and that existing call sites still compile**

Run the build command. Expected: `** BUILD SUCCEEDED **`, no warnings.

Important: Because the new `section:` parameter has a default of `nil` and the env ambient defaults to `.home`, every existing `VioletButton("...") { ... }` call site continues to render violet exactly as before. Do not modify any existing call sites in this task.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/VioletButton.swift
git commit -m "[design] VioletButton section-aware with glow pulse on press"
```

---

## Task 15: Refactor GhostButton for section awareness + inner press shadow

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/DesignSystem/GhostButton.swift`

- [ ] **Step 1: Replace the file contents**

Use the `Write` tool to overwrite `MemoryAisle2/MemoryAisle2/DesignSystem/GhostButton.swift` with:

```swift
import SwiftUI

struct GhostButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection

    let title: String
    let icon: String?
    let sectionOverride: SectionID?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        section: SectionID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.sectionOverride = section
        self.action = action
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodyMedium)
                }
                Text(title)
                    .font(Typography.bodyLargeBold)
            }
            .foregroundStyle(SectionPalette.primary(effectiveSection, for: scheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.Section.glass(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Section.border(effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(GhostPressStyle(section: effectiveSection, scheme: scheme))
        .accessibilityLabel(title)
    }
}

struct GhostButtonCompact: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection

    let title: String
    let icon: String?
    let sectionOverride: SectionID?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        section: SectionID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.sectionOverride = section
        self.action = action
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: Theme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodySmall)
                }
                Text(title)
                    .font(Typography.bodyMediumBold)
            }
            .foregroundStyle(SectionPalette.primary(effectiveSection, for: scheme))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Section.glass(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(Theme.Section.border(effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(GhostPressStyle(section: effectiveSection, scheme: scheme))
        .accessibilityLabel(title)
    }
}

private struct GhostPressStyle: ButtonStyle {
    let section: SectionID
    let scheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .background(
                configuration.isPressed
                    ? Theme.Surface.pressed(section: section, for: scheme)
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(
                        SectionPalette.primary(section, for: scheme)
                            .opacity(configuration.isPressed ? 0.25 : 0),
                        lineWidth: 2
                    )
                    .blur(radius: 4)
                    .allowsHitTesting(false)
            )
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

#Preview("GhostButton — each section") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SectionID.allCases, id: \.self) { id in
                GhostButton("Learn more", icon: "info.circle") {}
                    .section(id)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build.** Expected `** BUILD SUCCEEDED **`, no warnings.

- [ ] **Step 3: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/GhostButton.swift
git commit -m "[design] GhostButton section-aware with inner press glow"
```

---

## Task 16: Refactor GlowButton for section hero halo

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/DesignSystem/GlowButton.swift`

- [ ] **Step 1: Replace the file contents**

Use the `Write` tool to overwrite `MemoryAisle2/MemoryAisle2/DesignSystem/GlowButton.swift` with:

```swift
import SwiftUI

// Hero CTA button — reserved for "moments" (finish onboarding, scan success,
// recipe save). Outer halo glow in the section hue + one-shot pulse on appear.
struct GlowButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    @State private var appeared = false

    let title: String
    let icon: String?
    let sectionOverride: SectionID?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        section: SectionID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.sectionOverride = section
        self.action = action
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            HapticManager.medium()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(GlowPressStyle(section: effectiveSection, scheme: scheme, appeared: appeared))
        .accessibilityLabel(title)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}

private struct GlowPressStyle: ButtonStyle {
    let section: SectionID
    let scheme: ColorScheme
    let appeared: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let hue = SectionPalette.primary(section, for: scheme)

        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(pressed ? 0.9 : 0.6))
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(hue.opacity(pressed ? 0.35 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        hue.opacity(pressed ? 0.7 : 0.4),
                        lineWidth: pressed ? 1 : 0.5
                    )
            )
            .shadow(
                color: hue.opacity(pressed ? 0.6 : (appeared ? 0.35 : 0.0)),
                radius: pressed ? 34 : 24,
                y: 4
            )
            .shadow(
                color: hue.opacity(appeared ? 0.15 : 0.0),
                radius: 48,
                y: 10
            )
            .scaleEffect(pressed ? 0.98 : 1.0)
            .brightness(pressed ? 0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

#Preview("GlowButton — hero per section") {
    ScrollView {
        VStack(spacing: 28) {
            ForEach(SectionID.allCases, id: \.self) { id in
                GlowButton("Continue", icon: "arrow.right") {}
                    .section(id)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 40)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build.** Expected `** BUILD SUCCEEDED **`, no warnings.

- [ ] **Step 3: Verify preview.** Each section's hero button should have a halo glow in that section's hue. Tapping a button in the preview canvas should intensify the halo.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/GlowButton.swift
git commit -m "[design] GlowButton section-aware hero halo with pulse-on-appear"
```

---

## Task 17: Refactor GlassCard and GlassCardStrong for section tinting

**Files:**
- Modify: `MemoryAisle2/MemoryAisle2/DesignSystem/GlassCard.swift`
- Modify: `MemoryAisle2/MemoryAisle2/DesignSystem/GlassCardStrong.swift`

- [ ] **Step 1: Replace GlassCard.swift**

Use the `Write` tool to overwrite `MemoryAisle2/MemoryAisle2/DesignSystem/GlassCard.swift` with:

```swift
import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    let sectionOverride: SectionID?
    let content: () -> Content

    init(
        section: SectionID? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionOverride = section
        self.content = content
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        content()
            .background(Theme.Section.glass(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Section.border(effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}

struct InteractiveGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    @State private var isPressed = false
    let sectionOverride: SectionID?
    let action: () -> Void
    let content: () -> Content

    init(
        section: SectionID? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionOverride = section
        self.action = action
        self.content = content
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            content()
                .background(
                    isPressed
                        ? Theme.Surface.pressed(section: effectiveSection, for: scheme)
                        : Theme.Section.glass(effectiveSection, for: scheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(
                            isPressed
                                ? Theme.Border.pressed(section: effectiveSection, for: scheme)
                                : Theme.Section.border(effectiveSection, for: scheme),
                            lineWidth: Theme.glassBorderWidth
                        )
                )
        }
        .buttonStyle(GlassPressStyle())
    }
}

// MARK: - Press Style

struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

// MARK: - View Modifier Variant

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID

    func body(content: Content) -> some View {
        content
            .background(Theme.Section.glass(sectionID, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Section.border(sectionID, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
```

- [ ] **Step 2: Replace GlassCardStrong.swift**

Use the `Write` tool to overwrite `MemoryAisle2/MemoryAisle2/DesignSystem/GlassCardStrong.swift` with:

```swift
import SwiftUI

struct GlassCardStrong<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    let sectionOverride: SectionID?
    let content: () -> Content

    init(
        section: SectionID? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionOverride = section
        self.content = content
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        content()
            .background(Theme.Surface.strong(section: effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Border.strong(section: effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}

struct InteractiveGlassCardStrong<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    let sectionOverride: SectionID?
    let action: () -> Void
    let content: () -> Content

    init(
        section: SectionID? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionOverride = section
        self.action = action
        self.content = content
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            content()
                .background(Theme.Surface.strong(section: effectiveSection, for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(Theme.Border.strong(section: effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
                )
        }
        .buttonStyle(GlassPressStyle())
    }
}

extension View {
    func glassCardStrong() -> some View {
        modifier(GlassCardStrongModifier())
    }
}

private struct GlassCardStrongModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID

    func body(content: Content) -> some View {
        content
            .background(Theme.Surface.strong(section: sectionID, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Border.strong(section: sectionID, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}
```

- [ ] **Step 3: Build.** Expected `** BUILD SUCCEEDED **`, no warnings. Every existing call site of `GlassCard { ... }` still compiles because `section:` defaults to `nil` → ambient `.home` → violet.

- [ ] **Step 4: Commit**

```bash
git add MemoryAisle2/MemoryAisle2/DesignSystem/GlassCard.swift \
        MemoryAisle2/MemoryAisle2/DesignSystem/GlassCardStrong.swift
git commit -m "[design] GlassCard and GlassCardStrong section-aware"
```

---

## Final Verification

After Task 17 is committed:

- [ ] **Full build one last time**

```bash
xcodebuild -project MemoryAisle2/MemoryAisle2.xcodeproj \
  -scheme MemoryAisle2 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`, zero lines containing `warning:` or `error:`.

- [ ] **Spot-check existing views still render**

Open the project in Xcode, run the app on the iPhone 15 Pro simulator, and navigate through at least Home, Meals, Scan, Profile. Nothing should look different — Phase 1 is pure foundation, no feature views changed. Any visible change is a regression that needs investigation before proceeding.

- [ ] **Check no file exceeds 300 lines**

```bash
find MemoryAisle2/MemoryAisle2/DesignSystem -name "*.swift" -exec wc -l {} \; | sort -rn | head -10
```

Expected: every file under 300 lines. If any exceeds, split before merging.

- [ ] **Phase 1 summary commit (optional, for branch history hygiene)**

If the committing author wants a summary marker:

```bash
git commit --allow-empty -m "[design] flair pass phase 1 complete — DS foundation"
```

---

## Notes for the Next Agent

**What Phase 1 explicitly does NOT do:**
- Touch any file in `MemoryAisle2/MemoryAisle2/Features/`
- Change any feature view's appearance
- Rename any existing public API
- Modify `Typography.swift`, `HapticManager.swift`, or any service file

**What ships after Phase 1:** A design system that can optionally paint in 7 new section colors, but nothing is painted yet. Existing screens look identical to `main`.

**Phase 2** (follow-up plan) migrates the 5 priority pages: Scanner, Grocery, Recipes, Calendar, Pantry. Each page gets a `HeroHeader`, a `StatTile` row, and `SectionCard` list rows, plus feature-specific flair per the spec.

**Phase 3** (follow-up plan) applies the universal treatment to the remaining ~15 pages and runs the repo-wide `CloseButton` / `DismissButton` sweep.

Do not start Phase 2 until Phase 1 is merged to `dev` and the author confirms visual regression testing passed.
