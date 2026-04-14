import Foundation

/// Returns [] in v1. Structural placeholder so the Reflection "Feelings"
/// filter chip is wired and ready to populate when Mira chat persistence
/// lands and the user's own words can be quoted back from past
/// conversations. Kept as a real type so the service layer doesn't need
/// to special-case the filter and so the empty list is a forward-compat
/// guarantee, not a placecard.
struct FeelingMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        // Returns [] until Mira chat history is persisted and we can pull
        // emotionally significant moments out of past conversations. When
        // that lands, this body queries the chat store and emits a moment
        // per quoted user reflection.
        []
    }
}
