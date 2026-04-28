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

        // MARK: Typography (system fonts only — serif + monospaced design)

        enum Typography {

            static func wordmark() -> Font {
                .system(size: 11, weight: .medium, design: .serif)
            }

            static func caps(_ size: CGFloat = 9, weight: Font.Weight = .semibold) -> Font {
                .system(size: size, weight: weight, design: .monospaced)
            }

            static func capsBold(_ size: CGFloat = 10) -> Font {
                .system(size: size, weight: .heavy, design: .monospaced)
            }

            static func displayHero() -> Font {
                .system(size: 46, weight: .medium, design: .serif)
            }

            static func displayHeroItalic() -> Font {
                .system(size: 46, weight: .regular, design: .serif)
            }

            static func displaySmall() -> Font {
                .system(size: 38, weight: .medium, design: .serif)
            }

            static func body() -> Font {
                .system(size: 14, weight: .medium, design: .serif)
            }

            static func mealName() -> Font {
                .system(size: 19, weight: .medium, design: .serif)
            }

            static func dataValue() -> Font {
                .system(size: 12, weight: .heavy, design: .monospaced)
            }

            static func miraBody() -> Font {
                .system(size: 12, weight: .medium, design: .serif).italic()
            }
        }
    }
}
