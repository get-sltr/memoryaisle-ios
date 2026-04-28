import Foundation

enum MATab: String, CaseIterable, Identifiable, Sendable {
    case today, meals, scan, mira, reflect

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:   "TODAY"
        case .meals:   "MEALS"
        case .scan:    "SCAN"
        case .mira:    "MIRA"
        case .reflect: "REFLECT"
        }
    }

    /// Pro-gated tabs route to the paywall for free users.
    var requiresPro: Bool {
        self == .reflect
    }
}
