import Foundation

/// State of Mira's voice surface in the editorial tab. Drives bar animation,
/// sparkle scale, the masthead-style label, and the secondary hint copy.
///
/// Distinct from `MiraState` (used by `MiraWaveform`) so the existing avatar
/// callers aren't forced to grow new cases. The editorial tab introduces
/// `.listening` (mic open) and `.checkIn` (Mira initiated) which the smaller
/// avatar widget never needs to depict.
enum MiraVoiceState: Sendable, Equatable {
    case idle, listening, thinking, speaking, checkIn

    var label: String {
        switch self {
        case .idle:      "LISTENING WHEN YOU NEED ME"
        case .listening: "I'M HERE"
        case .thinking:  "ONE MOMENT"
        case .speaking:  "MIRA"
        case .checkIn:   "CHECKING IN"
        }
    }

    var hint: String {
        switch self {
        case .idle:      "HOLD TO SPEAK"
        case .listening: "RELEASE WHEN DONE"
        case .thinking:  ""
        case .speaking:  "TAP TO INTERRUPT"
        case .checkIn:   "TAP TO RESPOND"
        }
    }
}
