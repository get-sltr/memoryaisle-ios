import OSLog
import SwiftData
import SwiftUI

/// Editorial Today dashboard. Replaces the older single-screen `HomeView`
/// with a richer scrolling surface: hero, three expandable sections (Daily
/// Targets, Meals, Feeling), Mira meal recommendation carousel, and three
/// pop-out action cards (Log / Order / Mira).
///
/// All cycle, target, and consumption numbers come from real SwiftData
/// queries. The recommendations carousel still uses static demo data —
/// the meal-recommendation generation pipeline is a separate Bedrock
/// feature (TODO) that will live in a follow-up.
///
/// Backgrounds (gradient + fireflies) are owned by `EditorialBackground`
/// at the app shell (`MainTabView`), so this view paints no background
/// of its own. Mode is passed in via the `mode` parameter and is the same
/// `MAMode` value that drives the rest of the editorial canvas.
struct TodayDashboardView: View {
    let mode: MAMode
    let onTapWordmark: () -> Void
    var onPresentScan: (ScanView.ScanMode) -> Void = { _ in }

    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyCompRecords: [BodyComposition]
    @Query(sort: \NutritionLog.date, order: .reverse) private var nutritionLogs: [NutritionLog]
    @Query(sort: \MedicationProfile.startDate, order: .reverse) private var medications: [MedicationProfile]
    @Query private var pantry: [PantryItem]

    @State private var openSections: Set<DashboardSection> = [.dailyTargets]
    @State private var recoIndex: Int = 0
    @State private var activeCard: DashboardCard?
    @State private var feeling: Feeling?

    /// Bedrock-generated recommendations for the current meal window.
    /// Cached in-memory by `cachedWindow` so the dashboard only hits the
    /// Lambda once per window per app session — without this the carousel
    /// would re-fetch on every Today tab activation, costing ~$0.013/fetch.
    @State private var recommendations: [MealRecommendation] = []
    @State private var recommendationsLoading: Bool = false
    @State private var recommendationsError: String?
    @State private var cachedWindow: MealWindow?

    private let api = MiraAPIClient()
    private let logger = Logger(subsystem: "com.sltrdigital.MemoryAisle2", category: "Dashboard")

    private var profile: UserProfile? { profiles.first }
    private var medication: MedicationProfile? { medications.first }

    private let miraFollowUps = [
        "Can I swap chicken for tofu?",
        "Show me something heartier.",
        "Why is this dose-day friendly?"
    ]

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Masthead(
                        wordmark: "MEMORY AISLE",
                        trailing: mastheadTrailing,
                        onTapWordmark: onTapWordmark
                    )
                    .padding(.bottom, 18)

                    DashboardHero(
                        dayNumber: cycleDayNumber,
                        medication: medicationName,
                        dose: medicationDose,
                        focus: focusLabel,
                        startWeight: startWeight,
                        goalWeight: goalWeight,
                        timelineMonths: timelineMonths
                    )

                    expandables
                    recommendation
                }
                .padding(.horizontal, Theme.Editorial.Spacing.pad)
                .padding(.top, Theme.Editorial.Spacing.topInset)
                .padding(.bottom, Theme.Editorial.Spacing.bottomBuffer)
            }
            .scrollIndicators(.hidden)

            cardOverlay
        }
        .task(id: MealWindow.current()) {
            await loadRecommendations()
        }
    }

    // MARK: - Masthead trailing

    private var mastheadTrailing: String {
        switch mode {
        case .day:   RomanNumeral.dateString(from: Date())
        case .night: RomanNumeral.eveningString(from: Date())
        }
    }

    // MARK: - Cycle / hero values (real data)

    private var cycleDayNumber: Int {
        let start = medication?.startDate ?? profile?.createdAt
        guard let start else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0
        return max(1, days + 1)
    }

    private var medicationName: String {
        medication?.medication.rawValue ?? ""
    }

    private var medicationDose: String {
        medication?.doseAmount ?? ""
    }

    private var focusLabel: String {
        let pmode = profile?.productMode ?? .everyday
        switch pmode {
        case .everyday:             return "Protein"
        case .sensitiveStomach:     return "Gentle"
        case .musclePreservation:   return "Lean Mass"
        case .trainingPerformance:  return "Performance"
        case .maintenanceTaper:     return "Maintain"
        }
    }

    private var startWeight: Int {
        guard let weight = profile?.weightLbs else { return 0 }
        return Int(weight.rounded())
    }

    private var goalWeight: Int {
        guard let weight = profile?.goalWeightLbs else { return 0 }
        return Int(weight.rounded())
    }

    private var timelineMonths: Int {
        // Placeholder: the timeline-months value isn't on UserProfile yet.
        // Render a sensible default until a real `goalTimelineMonths` field
        // exists; the hero drops the line when start/goal are zero, so this
        // only shows once real weight goals are set.
        9
    }

    // MARK: - Daily Targets values (real data)

    private var todaysLogs: [NutritionLog] {
        nutritionLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var calorieTarget: Int {
        profile?.calorieTarget ?? 0
    }

    private var caloriesConsumed: Int {
        Int(todaysLogs.reduce(0.0) { $0 + $1.caloriesConsumed }.rounded())
    }

    private var calorieDelta: Int {
        caloriesConsumed - calorieTarget  // negative = below baseline
    }

    private var proteinTarget: Int {
        profile?.proteinTargetGrams ?? 0
    }

    private var proteinConsumed: Int {
        Int(todaysLogs.reduce(0.0) { $0 + $1.proteinGrams }.rounded())
    }

    private var fiberConsumed: Int {
        Int(todaysLogs.reduce(0.0) { $0 + $1.fiberGrams }.rounded())
    }

    private var waterConsumed: Double {
        todaysLogs.reduce(0.0) { $0 + $1.waterLiters }
    }

    private var dailyTargetsSummary: String {
        let cal = calorieTarget > 0 ? "\(calorieTarget) cal" : "\(caloriesConsumed) cal"
        let prot = proteinTarget > 0 ? "\(proteinTarget)g protein" : "\(proteinConsumed)g protein"
        return "\(cal) · \(prot)"
    }

    private var mealsSummary: String {
        let count = todaysLogs.count
        return count == 0 ? "Nothing logged yet." : "\(count) logged today."
    }

    // MARK: - Expandable sections

    private var expandables: some View {
        VStack(spacing: 0) {
            DashboardExpandableSection(
                label: DashboardSection.dailyTargets.label,
                summary: dailyTargetsSummary,
                isOpen: binding(for: .dailyTargets)
            ) {
                DailyTargetsContent(
                    calories: calorieTarget > 0 ? calorieTarget : caloriesConsumed,
                    calorieDelta: calorieDelta,
                    proteinG: proteinConsumed,
                    fiberG: fiberConsumed,
                    waterL: waterConsumed
                )
            }

            DashboardExpandableSection(
                label: DashboardSection.meals.label,
                summary: mealsSummary,
                summaryItalic: todaysLogs.isEmpty,
                isOpen: binding(for: .meals)
            ) {
                MealsEmptyContent {
                    logger.log("Tapped meal-snap shortcut")
                    activeCard = .log
                }
            }

            DashboardExpandableSection(
                label: DashboardSection.feeling.label,
                summary: "Tap to share with Mira.",
                summaryItalic: true,
                isOpen: binding(for: .feeling)
            ) {
                FeelingContent(selected: $feeling)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Editorial.hairline).frame(height: 0.5)
        }
    }

    private func binding(for section: DashboardSection) -> Binding<Bool> {
        Binding(
            get: { openSections.contains(section) },
            set: { newValue in
                if newValue { openSections.insert(section) }
                else { openSections.remove(section) }
            }
        )
    }

    // MARK: - Recommendation

    @ViewBuilder
    private var recommendation: some View {
        if recommendations.isEmpty {
            recommendationPlaceholder
        } else {
            MiraRecommendationView(
                recommendations: recommendations,
                window: MealWindow.current(),
                currentIndex: $recoIndex,
                onAction: handleRecommendationAction
            )
        }
    }

    /// Loading / error stand-in shown above the card row before Bedrock
    /// returns. Mirrors the visual frame of `MiraRecommendationView`
    /// (eyebrow + bordered block) so layout doesn't jump when content
    /// finally arrives.
    private var recommendationPlaceholder: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("— \(MealWindow.current().eyebrowText)")
                .font(Theme.Editorial.Typography.capsBold(8))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurface)

            if let error = recommendationsError {
                Text(error)
                    .font(Theme.Editorial.Typography.miraBody())
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.85))
                Button {
                    Task { await loadRecommendations(force: true) }
                } label: {
                    Text("TAP TO RETRY")
                        .font(Theme.Editorial.Typography.capsBold(9))
                        .tracking(1.8)
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Theme.Editorial.onSurface)
                                .frame(height: 0.5)
                                .offset(y: 3)
                        }
                }
                .buttonStyle(.plain)
            } else {
                Text("Mira is putting together your options...")
                    .font(Theme.Editorial.Typography.miraBody())
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.hairline).frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Editorial.hairline).frame(height: 0.5)
        }
        .padding(.top, 22)
    }

    private func handleRecommendationAction(_ card: DashboardCard) {
        logger.log("Recommendation action: \(card.rawValue, privacy: .public)")
        withAnimation(.easeInOut(duration: 0.28)) {
            activeCard = card
        }
    }

    // MARK: - Bedrock recommendation fetch

    /// Loads 3 fresh recommendations for the current meal window. No-op
    /// if we already have cached results for the same window unless
    /// `force` is true (manual retry button).
    private func loadRecommendations(force: Bool = false) async {
        let window = MealWindow.current()
        if !force, !recommendations.isEmpty, cachedWindow == window {
            return
        }
        recommendationsLoading = true
        recommendationsError = nil
        defer { recommendationsLoading = false }

        let context = buildRecommendationContext()
        let recent = recentMealNames()
        let pantryNames = pantry.prefix(20).map(\.name).filter { !$0.isEmpty }

        do {
            let recs = try await api.recommendMeals(
                context: context,
                mealWindow: window.rawValue,
                recentMeals: recent,
                pantryItems: pantryNames
            )
            recommendations = recs
            cachedWindow = window
            recoIndex = 0
        } catch {
            logger.error("Recommendation fetch failed: \(error.localizedDescription, privacy: .public)")
            recommendationsError = "Couldn't reach Mira. Try again in a moment."
        }
    }

    /// Builds the anonymized MiraContext from the dashboard's SwiftData
    /// queries. Mirrors the pattern in MiraChatView.sendMessage so the
    /// recommendation Lambda gets the same shape of context the chat
    /// surface produces.
    private func buildRecommendationContext() -> MiraAPIClient.MiraContext {
        guard let p = profile else {
            return MiraAPIClient.MiraContext(
                medicationClass: nil, doseTier: nil, daysSinceDose: nil,
                phase: nil, symptomState: nil, mode: nil,
                proteinTarget: nil, proteinToday: nil, waterToday: nil,
                trainingLevel: nil, trainingToday: nil, calorieTarget: nil,
                dietaryRestrictions: nil
            )
        }
        let anon = MedicationAnonymizer.anonymize(
            profile: p,
            cyclePhase: nil,
            symptomState: "unknown",
            proteinConsumed: proteinConsumed,
            waterConsumed: waterConsumed,
            isTrainingDay: false
        )
        return MiraAPIClient.MiraContext(
            medicationClass: anon.medicationClass,
            doseTier: anon.doseTier,
            daysSinceDose: anon.daysSinceDose,
            phase: anon.phase,
            symptomState: anon.symptomState,
            mode: anon.productMode,
            proteinTarget: anon.proteinTargetGrams,
            proteinToday: anon.proteinConsumedGrams,
            waterToday: anon.waterConsumedLiters,
            trainingLevel: anon.trainingLevel,
            trainingToday: anon.trainingToday,
            calorieTarget: anon.calorieTarget,
            dietaryRestrictions: anon.dietaryRestrictions
        )
    }

    /// Distinct meal names from the last 7 days, capped at 10. Sent to the
    /// Lambda so Mira's recommendations don't repeat what the user just ate.
    private func recentMealNames() -> [String] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) else {
            return []
        }
        var seen = Set<String>()
        var ordered: [String] = []
        for log in nutritionLogs where log.date >= cutoff {
            guard let raw = log.foodName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { continue }
            let key = raw.lowercased()
            if seen.insert(key).inserted {
                ordered.append(raw)
                if ordered.count >= 10 { break }
            }
        }
        return ordered
    }

    // MARK: - Card overlay

    @ViewBuilder
    private var cardOverlay: some View {
        if let card = activeCard {
            VStack {
                Spacer()
                cardView(for: card)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 88) // clears the floating tab bar
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            .ignoresSafeArea(.keyboard)
            .background(
                Color.black.opacity(0.001)
                    .onTapGesture { dismissCard() }
            )
        }
    }

    @ViewBuilder
    private func cardView(for card: DashboardCard) -> some View {
        let current = recommendations.indices.contains(recoIndex)
            ? recommendations[recoIndex]
            : recommendations.first ?? .placeholder

        switch card {
        case .log:
            LogMealCard(
                recommendation: current,
                onPhoto:   { handleLogPhoto(current) },
                onBarcode: { handleLogBarcode(current) },
                onClose:   dismissCard
            )
        case .order:
            OrderMealCard(
                recommendation: current,
                installedApps: installedDeliveryApps(),
                onTapApp: { app in handleOrderTap(app: app, query: current.name) },
                onClose: dismissCard
            )
        case .mira:
            MiraTellMeMoreCard(
                recommendation: current,
                followUps: miraFollowUps,
                onFollowUp: handleMiraFollowUp,
                onClose: dismissCard
            )
        }
    }

    private func dismissCard() {
        withAnimation(.easeInOut(duration: 0.22)) {
            activeCard = nil
        }
    }

    // MARK: - Action handlers

    private func handleLogPhoto(_ recommendation: MealRecommendation) {
        logger.log("Log via photo: \(recommendation.name, privacy: .public)")
        dismissCard()
        onPresentScan(.photo)
    }

    private func handleLogBarcode(_ recommendation: MealRecommendation) {
        logger.log("Log via barcode: \(recommendation.name, privacy: .public)")
        dismissCard()
        onPresentScan(.barcode)
    }

    private func handleOrderTap(app: DeliveryApp, query: String) {
        logger.log("Order via \(app.id, privacy: .public): \(query, privacy: .public)")
        guard let url = app.deepLinkURL(for: query) else {
            logger.error("Failed to build delivery URL for \(app.id, privacy: .public)")
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                self.logger.error("Failed to open \(app.id, privacy: .public)")
            }
        }
        dismissCard()
    }

    private func handleMiraFollowUp(_ question: String) {
        logger.log("Mira follow-up: \(question, privacy: .public)")
        dismissCard()
        appState.pendingMiraPrompt = question
    }

    // MARK: - Delivery app detection

    /// Returns the supported delivery apps that are installed on this device.
    /// Requires the URL schemes to be whitelisted in `LSApplicationQueriesSchemes`
    /// in Info.plist. Without that whitelist (current state) this method
    /// returns an empty list and the Order card degrades to "No supported
    /// delivery apps detected on this device."
    private func installedDeliveryApps() -> [DeliveryApp] {
        DeliveryApp.supported.filter { app in
            guard let url = URL(string: "\(app.urlScheme)://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }
}

// MARK: - Placeholder fallback

private extension MealRecommendation {
    static let placeholder = MealRecommendation(
        name: "No recommendation available.",
        calories: 0, proteinG: 0, fatG: 0,
        reasoning: "Tap Mira for help."
    )
}
