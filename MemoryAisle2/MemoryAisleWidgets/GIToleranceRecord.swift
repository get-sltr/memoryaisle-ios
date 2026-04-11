import Foundation
import SwiftData

@Model
final class GIToleranceRecord {
    var foodName: String
    var date: Date
    var triggeredNausea: Bool
    var triggeredBloating: Bool
    var triggeredConstipation: Bool
    var triggeredAversion: Bool
    var severity: Int // 1-5
    var notes: String?

    init(
        foodName: String,
        triggeredNausea: Bool = false,
        triggeredBloating: Bool = false,
        triggeredConstipation: Bool = false,
        triggeredAversion: Bool = false,
        severity: Int = 1,
        notes: String? = nil
    ) {
        self.foodName = foodName
        self.date = .now
        self.triggeredNausea = triggeredNausea
        self.triggeredBloating = triggeredBloating
        self.triggeredConstipation = triggeredConstipation
        self.triggeredAversion = triggeredAversion
        self.severity = severity
        self.notes = notes
    }
}
