import Foundation
import SwiftData

/// Detects the dedicated App Store Review test account, grants it Pro
/// access without going through StoreKit, and seeds the user database
/// with a week of realistic nutrition / symptom / body-composition
/// data so reviewers can evaluate the full experience without manually
/// logging entries.
///
/// **How it works:** when the user signs in, `handleSignIn(email:...)`
/// checks if the email matches `reviewerEmail`. If so, it stores a
/// persistent flag in UserDefaults that `SubscriptionManager` reads to
/// grant Pro tier, then runs the seed routines exactly once (gated by
/// a separate flag so re-signins don't double-insert data).
enum AppReviewerSeedService {
    /// Email Apple's reviewer account uses. Provided to App Store
    /// Connect on the App Information page so reviewers can sign in.
    static let reviewerEmail = "appreview@memoryaisle.app"

    /// Cognito group the reviewer account must be a member of for the
    /// Pro override to apply. The email check alone is not enough,
    /// because the email is published on App Store Connect and could
    /// be squatted on by anyone signing up first. Group membership
    /// requires Cognito admin access, so it's a real security boundary.
    ///
    /// **Manual setup:** in the Cognito console, create a Group named
    /// `reviewers` in the user pool, then add the `appreview@memoryaisle.app`
    /// user to it. The group claim flows into the access token as
    /// `cognito:groups` automatically; no app-side or CDK config is
    /// needed beyond that.
    static let reviewerGroupName = "reviewers"

    private static let seedFlagKey = "ma_review_seed_done_v1"
    private static let reviewerFlagKey = "ma_is_app_reviewer_v1"

    /// True if the current device has been flagged as the reviewer
    /// account. `SubscriptionManager` reads this on init and during
    /// status refresh to grant Pro tier.
    static var isMarkedAsReviewer: Bool {
        UserDefaults.standard.bool(forKey: reviewerFlagKey)
    }

    /// Call after a successful sign-in. If the email matches the
    /// reviewer account, marks the device and seeds demo data once.
    ///
    /// Will **never** overwrite existing user data: if a `UserProfile`
    /// already exists when the reviewer email signs in (e.g. a real
    /// user used this device first), seeding is skipped entirely. The
    /// reviewer flag is still set so Pro is granted for this session,
    /// but the pre-existing data is left intact.
    static func handleSignIn(email: String?, userId: String? = nil, modelContext: ModelContext) {
        guard let email, email.lowercased() == reviewerEmail.lowercased() else { return }

        // Require the signed-in user to also be a member of the Cognito
        // `reviewers` group. Without this gate, anyone who signs up
        // with the published reviewer email gets free Pro forever; the
        // group adds a server-controlled boundary that only Cognito
        // admins can flip.
        let groups = CognitoAuthManager.currentUserGroups()
        guard groups.contains(reviewerGroupName) else { return }

        UserDefaults.standard.set(true, forKey: reviewerFlagKey)

        if !UserDefaults.standard.bool(forKey: seedFlagKey) {
            let existingProfile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first
            if existingProfile == nil {
                seedDemoData(userId: userId, into: modelContext)
            }
            // Mark seed-done either way so we don't keep retrying on
            // every sign-in of a reviewer landing on a device that
            // already has real data.
            UserDefaults.standard.set(true, forKey: seedFlagKey)
        }
    }

    /// Clears the reviewer Pro override. Call on sign-out so the next
    /// user on the same device is not granted Pro. `SubscriptionManager`
    /// re-evaluates tier from StoreKit entitlements plus this flag on
    /// every refresh, so clearing here is sufficient to drop tier.
    static func clearReviewerFlag() {
        UserDefaults.standard.removeObject(forKey: reviewerFlagKey)
        UserDefaults.standard.removeObject(forKey: seedFlagKey)
    }

    /// Test/debug helper to clear the reviewer flag and re-trigger
    /// seeding on next sign-in. Not called from production paths.
    static func resetForTesting() {
        clearReviewerFlag()
    }

    // MARK: - Seeding

    private static func seedDemoData(userId: String?, into context: ModelContext) {
        seedProfile(userId: userId, into: context)
        seedNutritionLogs(into: context)
        seedSymptomLogs(into: context)
        seedBodyComposition(into: context)
        try? context.save()
    }

    private static func seedProfile(userId: String?, into context: ModelContext) {
        // Caller has already verified there is no existing UserProfile.
        let profile = UserProfile()
        profile.userId = userId
        profile.name = "Alex"
        profile.age = 38
        profile.sex = .female
        profile.weightLbs = 178
        profile.heightInches = 65
        profile.goalWeightLbs = 150
        profile.medication = .ozempic
        profile.medicationModality = .injectable
        profile.doseAmount = "0.5 mg weekly"
        profile.injectionDay = 4
        profile.productMode = .musclePreservation
        profile.proteinTargetGrams = 140
        profile.calorieTarget = 1700
        profile.waterTargetLiters = 2.5
        profile.fiberTargetGrams = 28
        profile.trainingLevel = .lifts
        profile.hasCompletedOnboarding = true
        context.insert(profile)
    }

    private static func seedNutritionLogs(into context: ModelContext) {
        // 7 days of realistic logs ending today.
        let protein: [Double] = [128, 132, 145, 124, 138, 141, 130]
        let calories: [Double] = [1620, 1680, 1730, 1590, 1710, 1740, 1655]
        let water: [Double] = [2.1, 2.4, 2.3, 1.9, 2.5, 2.2, 2.0]
        let fiber: [Double] = [22, 26, 28, 19, 27, 25, 23]

        for i in 0..<7 {
            let date = dateOffset(daysAgo: 6 - i)
            let log = NutritionLog(
                date: date,
                proteinGrams: protein[i],
                caloriesConsumed: calories[i],
                waterLiters: water[i],
                fiberGrams: fiber[i]
            )
            context.insert(log)
        }
    }

    private static func seedSymptomLogs(into context: ModelContext) {
        // 7 days of mild symptoms with one rough day mid-week so the
        // pattern analysis surfaces something interesting.
        let nausea = [1, 1, 2, 3, 1, 0, 1]
        let energy = [4, 4, 3, 2, 4, 5, 4]
        let appetite = [3, 3, 2, 2, 3, 4, 3]

        for i in 0..<7 {
            let date = dateOffset(daysAgo: 6 - i)
            let log = SymptomLog(
                date: date,
                nauseaLevel: nausea[i],
                appetiteLevel: appetite[i],
                energyLevel: energy[i]
            )
            context.insert(log)
        }
    }

    private static func seedBodyComposition(into context: ModelContext) {
        // Slowly trending down over the week (~1.5 lbs net loss) so the
        // weight chart and provider report show a coherent story.
        let weights: [Double] = [179.4, 179.0, 178.6, 178.2, 178.0, 177.8, 177.9]
        let bodyFat: [Double] = [34.2, 34.0, 33.8, 33.7, 33.5, 33.4, 33.3]

        for i in 0..<7 {
            let date = dateOffset(daysAgo: 6 - i)
            let bc = BodyComposition(
                date: date,
                weightLbs: weights[i],
                bodyFatPercent: bodyFat[i]
            )
            context.insert(bc)
        }
    }

    private static func dateOffset(daysAgo: Int) -> Date {
        let base = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .day, value: -daysAgo, to: base) ?? base
    }
}
