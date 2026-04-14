import Foundation

/// A single derived moment in the user's Reflection timeline. Pure value
/// type — moments are computed per render from existing SwiftData records,
/// never persisted as their own model. Deleting the source record removes
/// the moment automatically.
struct ReflectionMoment: Identifiable, Hashable {
    let id: String
    let date: Date
    let type: MomentType
    let category: MomentCategory
    let title: String
    let description: String?
    let quote: String?
    let photoData: Data?
    let metadataLabel: String?

    init(
        id: String,
        date: Date,
        type: MomentType,
        category: MomentCategory = .standard,
        title: String,
        description: String? = nil,
        quote: String? = nil,
        photoData: Data? = nil,
        metadataLabel: String? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.category = category
        self.title = title
        self.description = description
        self.quote = quote
        self.photoData = photoData
        self.metadataLabel = metadataLabel
    }
}

enum MomentType: String, Hashable, CaseIterable {
    case checkIn
    case gym
    case proteinStreak
    case toughDay
    case milestone
    case mealMoment
    case feeling
}

enum MomentCategory: String, Hashable, CaseIterable {
    case standard
    case milestone
    case toughDay
    case personalBest
}

enum ReflectionFilter: String, CaseIterable, Identifiable {
    case all = "All moments"
    case photos = "Photos"
    case meals = "Meals"
    case gym = "Gym"
    case feelings = "Feelings"

    var id: String { rawValue }

    func matches(_ moment: ReflectionMoment) -> Bool {
        switch self {
        case .all:      return true
        case .photos:   return moment.photoData != nil
        case .meals:    return moment.type == .mealMoment
        case .gym:      return moment.type == .gym
        case .feelings: return moment.type == .feeling
        }
    }
}

/// Bundle of typed source records the transformers read from. The view
/// constructs this once per render from its @Query properties and hands it
/// to ReflectionMomentService and the supporting services.
struct ReflectionSourceRecords {
    let bodyCompositions: [BodyComposition]
    let trainingSessions: [TrainingSession]
    let nutritionLogs: [NutritionLog]
    let symptomLogs: [SymptomLog]
    let userProfile: UserProfile?

    init(
        bodyCompositions: [BodyComposition] = [],
        trainingSessions: [TrainingSession] = [],
        nutritionLogs: [NutritionLog] = [],
        symptomLogs: [SymptomLog] = [],
        userProfile: UserProfile? = nil
    ) {
        self.bodyCompositions = bodyCompositions
        self.trainingSessions = trainingSessions
        self.nutritionLogs = nutritionLogs
        self.symptomLogs = symptomLogs
        self.userProfile = userProfile
    }
}

/// Protocol every source transformer implements. Pure functions over typed
/// arrays — no ModelContext required, no state.
protocol MomentTransformer {
    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment]
}
