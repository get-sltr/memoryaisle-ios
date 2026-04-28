import Foundation

/// Curated, FDA-PI-grounded drug facts. Populated only with entries that
/// have been reviewed by Kevin and/or a medical advisor against the relevant
/// FDA package insert (or peer-reviewed source for compounded variants).
///
/// The store ships intentionally **empty**. Mira's `lookupDrugFact` tool
/// returns a "no curated data" message until reviewed entries land. This is
/// the correct default for a medical-adjacent app — it forces Mira to defer
/// to the prescriber/PI rather than fabricate.
///
/// Population workflow (do not skip):
///   1. Pick a drug class + topic from the enums below
///   2. Sourced statement is verified against the live FDA PI for that drug
///      (or compounded-variant equivalent)
///   3. Source URL is checked to be live and authoritative
///   4. Kevin or medical advisor sign-off recorded in the review doc
///   5. Entry added to `CuratedDrugFacts.entries` with `reviewedAt: Date`
///
/// Entries are typed; fabricating an entry without an FDA PI source is
/// considered a regression and should fail review.
enum CuratedDrugFacts {

    /// Master list. Empty by design until medical review lands.
    static let entries: [DrugFact] = []

    /// Looks up a fact for the given anonymized drug class + topic.
    /// Returns `nil` if no curated entry exists; callers must treat nil as
    /// "defer to prescriber / PI."
    static func lookup(drugClass: DrugClass, topic: DrugFactTopic) -> DrugFact? {
        entries.first { $0.drugClass == drugClass && $0.topic == topic }
    }
}

struct DrugFact: Sendable, Equatable {
    let drugClass: DrugClass
    let topic: DrugFactTopic
    /// Human-readable statement Mira can quote. Should be a single short
    /// sentence with the specific number/range, NOT a paragraph.
    let statement: String
    /// FDA package insert URL or other authoritative source the statement
    /// was verified against.
    let sourceURL: URL
    /// Date the curator (Kevin / medical advisor) last verified this entry
    /// against the live source. Stale entries should be re-reviewed annually.
    let reviewedAt: Date
}

enum DrugFactTopic: String, Sendable, CaseIterable, Codable {
    case sideEffectPrevalence
    case halfLife
    case dosingSchedule
    case contraindications
    case warnings
    case interactions
    case adjustmentForRenalImpairment
    case adjustmentForHepaticImpairment
    case other
}
