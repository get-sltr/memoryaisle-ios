import Foundation
import SwiftUI

/// Centralized free-tier limits so we don't sprinkle magic numbers
/// across the codebase. Update here if the gating strategy changes.
enum FreeTierLimits {
    static let miraRequestsPerDay = 3
    static let barcodeScansPerDay = 3
}

/// Stable UserDefaults keys for the trackers. Versioned so a future
/// migration can bump them without colliding with old values.
enum UsageTrackerKeys {
    static let mira = "ma_mira_usage"
    static let barcode = "ma_barcode_usage"
}

/// Shared persistence helpers for daily usage counters. Both
/// `MiraUsageTracker` and `BarcodeUsageTracker` delegate here so the
/// rollover / read / write logic lives in one place. Two distinct
/// `@Observable` classes wrap these helpers because SwiftUI's
/// environment lookup is type-based — injecting two instances of the
/// same class would collide.
enum DailyUsageStore {
    /// Resets the stored count if the day has rolled over and returns
    /// the current count for `key`.
    static func refresh(key: String) -> Int {
        let today = todayString()
        let savedDate = UserDefaults.standard.string(forKey: dateKey(key))
        if savedDate != today {
            UserDefaults.standard.set(0, forKey: countKey(key))
            UserDefaults.standard.set(today, forKey: dateKey(key))
            return 0
        }
        return UserDefaults.standard.integer(forKey: countKey(key))
    }

    /// Increments the count for `key` and returns the new value.
    static func record(key: String) -> Int {
        let current = refresh(key: key)
        let next = current + 1
        UserDefaults.standard.set(next, forKey: countKey(key))
        return next
    }

    /// Test/debug helper. Resets today's count to zero without touching
    /// the date marker. Not used in production code paths.
    static func resetForToday(key: String) {
        UserDefaults.standard.set(0, forKey: countKey(key))
    }

    private static func todayString() -> String {
        let date = Calendar.current.startOfDay(for: .now)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func countKey(_ key: String) -> String { "\(key)_count_v1" }
    private static func dateKey(_ key: String) -> String { "\(key)_date_v1" }
}

/// Tracks how many Mira requests the free user has spent today. Reset
/// at midnight local time. Pro users bypass this entirely.
@Observable
final class MiraUsageTracker {
    let dailyFreeLimit = FreeTierLimits.miraRequestsPerDay
    private(set) var countToday: Int = 0
    private let key = UsageTrackerKeys.mira

    init() {
        refresh()
    }

    var remainingToday: Int {
        max(0, dailyFreeLimit - countToday)
    }

    var hasReachedLimit: Bool {
        countToday >= dailyFreeLimit
    }

    func refresh() {
        countToday = DailyUsageStore.refresh(key: key)
    }

    func record() {
        countToday = DailyUsageStore.record(key: key)
    }
}

/// Tracks how many barcode scans the free user has spent today. Reset
/// at midnight local time. Pro users bypass this entirely.
@Observable
final class BarcodeUsageTracker {
    let dailyFreeLimit = FreeTierLimits.barcodeScansPerDay
    private(set) var countToday: Int = 0
    private let key = UsageTrackerKeys.barcode

    init() {
        refresh()
    }

    var remainingToday: Int {
        max(0, dailyFreeLimit - countToday)
    }

    var hasReachedLimit: Bool {
        countToday >= dailyFreeLimit
    }

    func refresh() {
        countToday = DailyUsageStore.refresh(key: key)
    }

    func record() {
        countToday = DailyUsageStore.record(key: key)
    }
}
