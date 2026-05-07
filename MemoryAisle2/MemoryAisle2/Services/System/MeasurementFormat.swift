import Foundation

/// Single source of truth for rendering weight values. Storage stays in
/// pounds (matches `UserProfile.weightLbs` / `goalWeightLbs`); this layer
/// converts to the user's preferred system at the display boundary.
///
/// All conversions use the WHO-standard 0.45359237 kg/lb factor.
enum WeightFormat {
    /// "173 lbs" or "78 kg". Rounds to the nearest whole unit because that
    /// matches how every progress + onboarding screen renders today.
    static func display(_ pounds: Double, system: UnitSystem) -> String {
        switch system {
        case .imperial:
            return "\(Int(pounds.rounded())) lbs"
        case .metric:
            let kg = pounds * 0.45359237
            return "\(Int(kg.rounded())) kg"
        }
    }

    /// Whole-unit value only ("173", "78"). Used when the unit suffix is
    /// rendered separately (e.g. a stat tile with the unit on its own line).
    static func displayValue(_ pounds: Double, system: UnitSystem) -> Int {
        switch system {
        case .imperial: return Int(pounds.rounded())
        case .metric:   return Int((pounds * 0.45359237).rounded())
        }
    }

    /// Unit suffix without the value: "lbs" / "kg".
    static func unit(system: UnitSystem) -> String {
        switch system {
        case .imperial: return "lbs"
        case .metric:   return "kg"
        }
    }

    /// Reverse — the user typed in a value in their preferred system and
    /// we need to persist it as pounds.
    static func toCanonical(_ value: Double, from system: UnitSystem) -> Double {
        switch system {
        case .imperial: return value
        case .metric:   return value / 0.45359237
        }
    }
}

/// Single source of truth for rendering height values. Storage stays in
/// inches (matches `UserProfile.heightInches`); display converts to the
/// user's preferred system.
enum HeightFormat {
    /// `"5'9\""` for imperial, `"175 cm"` for metric.
    static func display(_ inches: Int, system: UnitSystem) -> String {
        switch system {
        case .imperial:
            let feet = inches / 12
            let remaining = inches % 12
            return "\(feet)'\(remaining)\""
        case .metric:
            let cm = Double(inches) * 2.54
            return "\(Int(cm.rounded())) cm"
        }
    }

    /// Unit suffix only: "in" / "cm".
    static func unit(system: UnitSystem) -> String {
        switch system {
        case .imperial: return "in"
        case .metric:   return "cm"
        }
    }
}
