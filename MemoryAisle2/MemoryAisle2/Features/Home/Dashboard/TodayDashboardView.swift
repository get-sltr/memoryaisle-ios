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

    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyCompRecords: [BodyComposition]
    @Query(sort: \NutritionLog.date, order: .reverse) private var nutritionLogs: [NutritionLog]
    @Query(sort: \MedicationProfile.startDate, order: .reverse) private var medications: [MedicationProfile]

    @State private var openSections: Set<DashboardSection> = [.dailyTargets]
    @State private var recoIndex: Int = 0
    @State private var activeCard: DashboardCard?
    @State private var feeling: Feeling?

    private let logger = Logger(subsystem: "com.sltrdigital.MemoryAisle2", category: "Dashboard")

    private var profile: UserProfile? { profiles.first }
    private var medication: MedicationProfile? { medications.first }

    /// Static recommendation list. Real Bedrock-generated recommendations
    /// are tracked as a follow-up; the dashboard ships with a representative
    /// trio so the carousel + cards UX can be validated end-to-end.
    private let recommendations: [MealRecommendation] = [
        MealRecommendation(
            name: "Grilled chicken bowl with rice and avocado.",
            calories: 520, proteinG: 38, fatG: 14, carbsG: 52,
            reasoning: "Closes your protein gap for today.",
            ingredients: ["Chicken breast", "Jasmine rice", "½ avocado", "Lime", "Cilantro", "Olive oil", "Salt"]
        ),
        MealRecommendation(
            name: "Greek yogurt with berries and walnuts.",
            calories: 310, proteinG: 22, fatG: 12, carbsG: 24,
            reasoning: "Lighter option · still on target.",
            ingredients: ["Greek yogurt", "Mixed berries", "Walnuts", "Honey", "Cinnamon"]
        ),
        MealRecommendation(
            name: "Salmon, sweet potato, asparagus.",
            calories: 610, proteinG: 42, fatG: 26, carbsG: 38,
            reasoning: "Omega-3 boost · dose-day friendly.",
            ingredients: ["Salmon fillet", "Sweet potato", "Asparagus", "Lemon", "Olive oil", "Salt", "Pepper"],
            isDoseDayFriendly: true
        )
    ]

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

    private var recommendation: some View {
        MiraRecommendationView(
            recommendations: recommendations,
            window: MealWindow.current(),
            currentIndex: $recoIndex,
            onAction: handleRecommendationAction
        )
    }

    private func handleRecommendationAction(_ card: DashboardCard) {
        logger.log("Recommendation action: \(card.rawValue, privacy: .public)")
        withAnimation(.easeInOut(duration: 0.28)) {
            activeCard = card
        }
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

    // MARK: - Action handlers (TODO stubs)

    private func handleLogPhoto(_ recommendation: MealRecommendation) {
        logger.log("Log via photo: \(recommendation.name, privacy: .public)")
        // TODO: present AVCaptureSession for meal photo capture, run Bedrock
        // vision pipeline, return macros, present a confirm step before logging.
        dismissCard()
    }

    private func handleLogBarcode(_ recommendation: MealRecommendation) {
        logger.log("Log via barcode: \(recommendation.name, privacy: .public)")
        // TODO: present AVFoundation barcode scanner, look up UPC, log on confirm.
        dismissCard()
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
        // TODO: route into Mira chat with this prompt as the next user turn,
        // switch to the Mira tab. Needs a routing hook in MainTabView state.
        dismissCard()
    }

    // MARK: - Delivery app detection

    /// Returns the supported delivery apps that are installed on this device.
    /// Requires the URL schemes to be whitelisted in `LSApplicationQueriesSchemes`
    /// in Info.plist. Without that whitelist (current state) this method
    /// returns an empty list and the Order card degrades to "No supported
    /// delivery apps detected on this device."
    private func installedDeliveryApps() -> [DeliveryApp] {
        DeliveryApp.supported.filter { app in
            var components = URLComponents()
            components.scheme = app.urlScheme
            components.host = ""
            guard let url = components.url else { return false }
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
