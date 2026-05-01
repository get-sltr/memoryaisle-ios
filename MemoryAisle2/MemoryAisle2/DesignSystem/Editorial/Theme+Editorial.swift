import SwiftUI

extension Theme {

    enum Editorial {

        // MARK: Day mode — gray to gold

        static let dayTop      = Color(red: 0.420, green: 0.420, blue: 0.447)
        static let dayUpperMid = Color(red: 0.541, green: 0.525, blue: 0.510)
        static let dayLowerMid = Color(red: 0.710, green: 0.647, blue: 0.518)
        static let dayBottom   = Color(red: 0.831, green: 0.631, blue: 0.282)

        static let dayGradient = LinearGradient(
            stops: [
                .init(color: dayTop,      location: 0.00),
                .init(color: dayUpperMid, location: 0.35),
                .init(color: dayLowerMid, location: 0.65),
                .init(color: dayBottom,   location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        // MARK: Night mode — dark gray to gold

        static let nightTop       = Color(red: 0.102, green: 0.102, blue: 0.114)
        static let nightUpperMid  = Color(red: 0.165, green: 0.165, blue: 0.180)
        static let nightMidBridge = Color(red: 0.271, green: 0.251, blue: 0.243)
        static let nightLowerMid  = Color(red: 0.502, green: 0.396, blue: 0.220)
        static let nightBottom    = Color(red: 0.769, green: 0.569, blue: 0.259)

        static let nightGradient = LinearGradient(
            stops: [
                .init(color: nightTop,        location: 0.00),
                .init(color: nightUpperMid,   location: 0.25),
                .init(color: nightMidBridge,  location: 0.55),
                .init(color: nightLowerMid,   location: 0.80),
                .init(color: nightBottom,     location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        // MARK: Foreground

        static let onSurface      = Color.white
        static let onSurfaceMuted = Color.white.opacity(0.85)
        static let onSurfaceFaint = Color.white.opacity(0.55)
        static let hairline       = Color.white.opacity(0.45)
        static let hairlineSoft   = Color.white.opacity(0.35)

        // MARK: Layout

        enum Spacing {
            static let pad: CGFloat = 28
            static let topInset: CGFloat = 50
            static let tabInset: CGFloat = 28
            static let bottomBuffer: CGFloat = 100
        }

        // MARK: Typography
        //
        // Display + body serif: bundled Libre Caslon Display (OFL).
        // Wordmark serif + everything monospaced: Apple system fonts.
        // The wordmark stays on the system serif (New York) because Caslon
        // reads thin and fragile at 11pt; New York is more legible at that
        // size and the wordmark mark is small enough that the typographic
        // character isn't doing the same work as the hero copy.

        enum Typography {

            /// PostScript name of the bundled Libre Caslon Display face.
            /// Verified by reading the font file's name table — do not
            /// change without re-checking via `UIFont.fontNames(forFamilyName:)`
            /// at runtime, otherwise `Font.custom` will silently fall back
            /// to the system sans-serif (NOT the system serif).
            private static let caslonRegular = "LibreCaslonDisplay-Regular"

            /// Libre Caslon Display at the given size. `Font.custom` returns
            /// a font that falls back to the iOS default sans-serif if the
            /// PostScript name isn't found — there's no built-in chain to
            /// `system(design: .serif)`. The mitigation is the bundled .ttf
            /// + the verified PostScript name above; if either drift, fix
            /// the source rather than catching the fallback at render time.
            private static func caslon(size: CGFloat) -> Font {
                Font.custom(caslonRegular, size: size)
                    .leading(.tight)
            }

            // MARK: Caps (monospaced — SF Mono)

            static func caps(_ size: CGFloat = 9, weight: Font.Weight = .semibold) -> Font {
                .system(size: size, weight: weight, design: .monospaced)
            }

            static func capsBold(_ size: CGFloat = 10) -> Font {
                .system(size: size, weight: .heavy, design: .monospaced)
            }

            // MARK: Display (serif — Caslon)

            static func displayHero() -> Font {
                caslon(size: 46)
            }

            /// True italic at displayHero size. Caslon ships only Regular,
            /// so `.italic()` on Caslon synthesizes a slant from the upright
            /// glyphs and reads "normal-ish" at 46pt. New York has a real
            /// italic cut (single-story `a`, true cursive `e`/`g`), which
            /// is the visible italic we want for hero emphasis words.
            static func displayHeroItalic() -> Font {
                .system(size: 46, weight: .regular, design: .serif).italic()
            }

            static func displaySmall() -> Font {
                caslon(size: 38)
            }

            /// True italic at displaySmall size — see `displayHeroItalic`
            /// for the Caslon-vs-system-serif rationale.
            static func displaySmallItalic() -> Font {
                .system(size: 38, weight: .regular, design: .serif).italic()
            }

            // MARK: Body (serif — Caslon; italic is synthesized — Libre Caslon
            // Display ships only Regular. Acceptable at display sizes; if the
            // synthesized slant reads mechanical at 12pt mira-body, we can
            // bundle Libre Caslon Text Italic specifically as a follow-up.)

            static func body() -> Font {
                caslon(size: 14)
            }

            static func mealName() -> Font {
                caslon(size: 19)
            }

            static func miraBody() -> Font {
                caslon(size: 12).italic()
            }

            // MARK: Wordmark (system serif intentionally — see header comment)

            static func wordmark() -> Font {
                .system(size: 11, weight: .medium, design: .serif)
            }

            // MARK: Data values (monospaced — SF Mono)

            static func dataValue() -> Font {
                .system(size: 12, weight: .heavy, design: .monospaced)
            }
        }
    }
}
