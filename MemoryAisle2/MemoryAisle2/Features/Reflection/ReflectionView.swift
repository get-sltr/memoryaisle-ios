import SwiftData
import SwiftUI

/// The Reflection page — the soul of the app. A results-driven scrapbook
/// that plays the user's journey back to them. Composes the header,
/// hero (real photo comparison or Mira invite when no photos exist),
/// transformation stats row, filter chip row, moments timeline, or
/// per-filter empty state. Uses @Query for live updates so any new
/// check-in, gym session, or symptom log instantly reflects in the
/// timeline without manual refresh.
struct ReflectionView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BodyComposition.date) private var bodyCompositions: [BodyComposition]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \NutritionLog.date) private var nutritionLogs: [NutritionLog]
    @Query(sort: \SymptomLog.date) private var symptomLogs: [SymptomLog]
    @Query private var userProfiles: [UserProfile]

    @State private var selectedFilter: ReflectionFilter = .all
    @State private var inviteDismissed = false

    private let momentService = ReflectionMomentService()
    private let statsService = TransformationStatsService()
    private let heroService = HeroPhotosService()
    private let saveService = CheckInSaveService()

    private let inviteDismissKey = "reflectionHeroInviteDismissedUntil"

    var body: some View {
        let records = ReflectionSourceRecords(
            bodyCompositions: bodyCompositions,
            trainingSessions: trainingSessions,
            nutritionLogs: nutritionLogs,
            symptomLogs: symptomLogs,
            userProfile: userProfiles.first
        )
        let moments = momentService.moments(for: selectedFilter, from: records)
        let stats = statsService.stats(from: records)
        let heroPhotos = heroService.photos(from: records)

        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                topBar
                sectionLabel("REFLECTION")
                    .padding(.top, 8)
                Text("Look how far you've come.")
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.Text.primary)
                    .multilineTextAlignment(.center)

                heroSlot(photos: heroPhotos)

                TransformationStatsRow(stats: stats)
                    .padding(.top, 4)

                ReflectionFilterChipRow(selected: $selectedFilter)
                    .padding(.top, 8)

                sectionLabel("YOUR MOMENTS")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)

                if moments.isEmpty {
                    ReflectionEmptyState(filter: selectedFilter)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(moments) { moment in
                            MomentCard(moment: moment)
                                .padding(.horizontal, 28)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .themeBackground()
        .onAppear {
            refreshInviteDismissState()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            CloseButton(action: { dismiss() })
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Hero routing

    @ViewBuilder
    private func heroSlot(photos: HeroPhotos) -> some View {
        if photos.day1 != nil {
            ReflectionHeroCard(photos: photos)
        } else if !inviteDismissed {
            ReflectionHeroInviteCard(
                onPhotoChosen: handleInvitePhoto,
                onDismiss: dismissInvite
            )
        }
    }

    private func handleInvitePhoto(_ data: Data) {
        let weight = userProfiles.first?.weightLbs ?? 0
        try? saveService.save(weight: weight, photoData: data, in: modelContext)
    }

    private func dismissInvite() {
        let until = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        UserDefaults.standard.set(until, forKey: inviteDismissKey)
        inviteDismissed = true
    }

    private func refreshInviteDismissState() {
        if let until = UserDefaults.standard.object(forKey: inviteDismissKey) as? Date {
            inviteDismissed = Date() < until
        } else {
            inviteDismissed = false
        }
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .tracking(1.5)
            .foregroundStyle(Color.violet.opacity(0.5))
    }
}
