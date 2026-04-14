import Foundation

/// Orchestrates the source transformers, merges their output, sorts by
/// date descending, and applies the active filter. Pure read — never
/// mutates state, no caching. Caller (the SwiftUI view) provides typed
/// arrays via @Query and the service does the rest.
///
/// Error handling: if one transformer throws, it's logged and skipped.
/// One broken transformer never blanks the whole timeline.
@MainActor
final class ReflectionMomentService {

    private let transformers: [MomentTransformer]

    init(transformers: [MomentTransformer] = ReflectionMomentService.defaultTransformers()) {
        self.transformers = transformers
    }

    static func defaultTransformers() -> [MomentTransformer] {
        [
            CheckInMomentTransformer(),
            GymMomentTransformer(),
            ProteinStreakMomentTransformer(),
            ToughDayMomentTransformer(),
            MilestoneMomentTransformer(),
            MealMomentTransformer(),
            FeelingMomentTransformer()
        ]
    }

    func moments(
        for filter: ReflectionFilter,
        from records: ReflectionSourceRecords
    ) -> [ReflectionMoment] {
        let all = transformers.flatMap { transformer -> [ReflectionMoment] in
            do {
                return try transformer.moments(from: records)
            } catch {
                print("[Reflection] Transformer failed: \(error)")
                return []
            }
        }
        let sorted = all.sorted { $0.date > $1.date }
        return sorted.filter { filter.matches($0) }
    }
}
