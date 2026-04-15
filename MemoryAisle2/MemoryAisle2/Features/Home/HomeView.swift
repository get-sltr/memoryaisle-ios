import PhotosUI
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Binding var showMenu: Bool

    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyCompRecords: [BodyComposition]
    @Query(sort: \NutritionLog.date, order: .reverse) private var nutritionLogs: [NutritionLog]

    private var profile: UserProfile? { profiles.first }

    private var todaysLoggedMeals: [NutritionLog] {
        nutritionLogs.filter {
            Calendar.current.isDateInToday($0.date) && $0.foodName != nil
        }
    }

    // Starting photo capture
    @State private var showStartingSourceChoice = false
    @State private var showStartingCamera = false
    @State private var showStartingLibrary = false
    @State private var startingPhotoItem: PhotosPickerItem?
    @State private var startingCameraData: Data?

    // Get-started sheet routing
    @State private var showScanSheet = false
    @State private var showMealPhotoSheet = false
    @State private var showGrocerySheet = false
    @State private var showMiraMealPlanSheet = false

    // Mood capture
    @State private var pickedMood: Mood?

    private let saveService = CheckInSaveService()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                topBar
                welcomeHeader
                intoCard
                progressRow
                dailyTargetsCard
                todaysMealsCard
                moodCard
                getStartedCard
                footerNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .themeBackground()
        .navigationBarHidden(true)
        .confirmationDialog(
            "Starting photo",
            isPresented: $showStartingSourceChoice,
            titleVisibility: .visible
        ) {
            Button("Take Photo") { showStartingCamera = true }
            Button("Choose from Library") { showStartingLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showStartingCamera) {
            CameraPicker(imageData: $startingCameraData)
                .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showStartingLibrary,
            selection: $startingPhotoItem,
            matching: .images
        )
        .onChange(of: startingPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task { @MainActor in
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    persistStartingPhoto(data)
                }
            }
        }
        .onChange(of: startingCameraData) { _, newValue in
            guard let newValue else { return }
            persistStartingPhoto(newValue)
            startingCameraData = nil
        }
        .sheet(isPresented: $showScanSheet) {
            ScanView()
        }
        .sheet(isPresented: $showMealPhotoSheet) {
            MealPhotoView()
        }
        .sheet(isPresented: $showGrocerySheet) {
            GroceryListScreen()
        }
        .sheet(isPresented: $showMiraMealPlanSheet) {
            MiraChatView(
                autoSendMessage: "Help me generate my first meal plan."
            )
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                HapticManager.light()
                showMenu = true
            } label: {
                HStack(spacing: 8) {
                    OnboardingLogo(size: 32)
                    Text("Dashboard")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open menu")
            .accessibilityHint("Opens the navigation menu")
            .accessibilityAddTraits(.isButton)

            Spacer()

            Text(dayLabel)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Text.hint(for: scheme))
        }
    }

    private var dayLabel: String {
        guard let day = daysSinceJourneyStart() else { return "Day 1" }
        return "Day \(max(1, day + 1))"
    }

    // MARK: - Welcome header

    private var welcomeHeader: some View {
        HStack(spacing: 14) {
            Button {
                HapticManager.light()
                showStartingSourceChoice = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Theme.Surface.strong(section: .home, for: scheme))
                        .frame(width: 58, height: 58)
                        .overlay(
                            Circle()
                                .stroke(Theme.Border.strong(section: .home, for: scheme), lineWidth: Theme.glassBorderWidth)
                        )
                        .overlay(avatarContent)

                    Circle()
                        .fill(Color.violet)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: 0x0A0914))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: 0x0A0914), lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(latestPhotoData == nil ? "Add starting photo" : "Change starting photo")

            VStack(alignment: .leading, spacing: 1) {
                Text(welcomeTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Text.primary)
                Text(welcomeSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let data = latestPhotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
    }

    private var latestPhotoData: Data? {
        bodyCompRecords.first(where: { $0.photoData != nil })?.photoData
    }

    private var welcomeTitle: String {
        let name = profile?.name ?? ""
        return name.isEmpty ? "Welcome" : "Welcome, \(name)"
    }

    private var welcomeSubtitle: String {
        if let day = daysSinceJourneyStart(), day > 0 {
            return "Day \(day + 1) of your journey"
        }
        return "Your journey starts today"
    }

    // MARK: - Intro card

    private var intoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your personalized plan is ready")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.violet)
            Text("Based on your profile, we've calculated your daily targets. You can adjust them anytime from your profile.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Surface.strong(section: .home, for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.Border.strong(section: .home, for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    // MARK: - Progress row (Starting / Goal / Timeline)

    private var progressRow: some View {
        HStack(spacing: 8) {
            progressTile(label: "Starting", value: startingWeightText, unit: "lbs", accent: false)
            arrowDivider
            progressTile(label: "Goal", value: goalWeightText, unit: "lbs", accent: true)
            barDivider
            progressTile(label: "Timeline", value: timelineValueText, unit: timelineUnitText, accent: false)
        }
    }

    private func progressTile(label: String, value: String, unit: String, accent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(accent ? Color.violet : Theme.Text.tertiary(for: scheme))
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent ? Color.violet : Theme.Text.primary)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(accent ? Color.violet : Theme.Text.tertiary(for: scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private var arrowDivider: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 12))
            .foregroundStyle(Color.violet.opacity(0.25))
    }

    private var barDivider: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 10))
            .foregroundStyle(Color.violet.opacity(0.25))
    }

    private var startingWeightText: String {
        guard let w = profile?.weightLbs else { return "--" }
        return "\(Int(w))"
    }

    private var goalWeightText: String {
        guard let w = profile?.goalWeightLbs else { return "--" }
        return "\(Int(w))"
    }

    private var timelineValueText: String {
        guard let start = profile?.weightLbs, let goal = profile?.goalWeightLbs else { return "--" }
        let delta = abs(start - goal)
        guard delta > 0 else { return "0" }
        // 0.5 lb per week healthy rate → weeks = delta / 0.5 = delta * 2
        let weeks = delta * 2
        let months = Int((weeks / 4.33).rounded())
        return months >= 1 ? "~\(months)" : "<1"
    }

    private var timelineUnitText: String {
        guard let start = profile?.weightLbs, let goal = profile?.goalWeightLbs else { return "" }
        let delta = abs(start - goal)
        guard delta > 0 else { return "weeks" }
        let weeks = delta * 2
        let months = Int((weeks / 4.33).rounded())
        return months >= 1 ? "months" : "weeks"
    }

    // MARK: - Daily targets card (2x2)

    private var dailyTargetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROJECTED DAILY TARGETS")
                .font(.system(size: 11, weight: .regular))
                .tracking(0.8)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                targetTile(value: caloriesValue, label: "Calories", color: Color.violet, subtitle: caloriesSubtitle)
                targetTile(value: proteinValue, label: "Protein", color: Color(hex: 0x4ADE80), subtitle: proteinSubtitle)
                targetTile(value: carbsValue, label: "Carbs", color: Color(hex: 0xFBBF24), subtitle: nil)
                targetTile(value: waterValue, label: "Water", color: Color(hex: 0x60A5FA), subtitle: nil)
            }

            Text("You can adjust these anytime from your profile.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Text.hint(for: scheme))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func targetTile(value: String, label: String, color: Color, subtitle: String?) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.Text.hint(for: scheme))
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Border.glass(section: .home, for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private var caloriesValue: String {
        guard let cal = profile?.calorieTarget else { return "--" }
        return "\(cal)"
    }

    private var caloriesSubtitle: String? {
        guard let cal = profile?.calorieTarget, cal > 0 else { return nil }
        // Simple approximation: assume 2000 maintenance, show deficit from there
        let maintenance = 2000
        let delta = maintenance - cal
        guard delta > 0 else { return nil }
        return "\(delta) cal below baseline"
    }

    private var proteinValue: String {
        guard let p = profile?.proteinTargetGrams else { return "--" }
        return "\(p)g"
    }

    private var proteinSubtitle: String? {
        guard let p = profile?.proteinTargetGrams, let w = profile?.weightLbs, w > 0 else { return nil }
        let perLb = Double(p) / w
        return String(format: "%.2fg per lb body", perLb)
    }

    private var carbsValue: String {
        guard let cal = profile?.calorieTarget, let p = profile?.proteinTargetGrams else { return "--" }
        // Allocate 35% of calories to carbs
        let carbsCal = Double(cal) * 0.35
        let grams = Int(carbsCal / 4)
        _ = p
        return "\(grams)g"
    }

    private var waterValue: String {
        guard let w = profile?.waterTargetLiters else { return "--" }
        return String(format: "%.1fL", w)
    }

    // MARK: - Today's meals card

    private var todaysMealsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S MEALS")
                    .font(.system(size: 11, weight: .regular))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                Spacer()
                if !todaysLoggedMeals.isEmpty {
                    Text("\(todaysLoggedMeals.count) logged")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.violet)
                }
            }

            if todaysLoggedMeals.isEmpty {
                emptyMealsState
            } else {
                VStack(spacing: 5) {
                    ForEach(todaysLoggedMeals.reversed()) { log in
                        loggedMealRow(log)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.violet)
                Text("Protein first, then veggies, carbs last")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.violet)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.Surface.strong(section: .home, for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.Border.strong(section: .home, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private var emptyMealsState: some View {
        Button {
            HapticManager.light()
            showMealPhotoSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No meals logged yet today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Text.primary)
                    Text("Tap to snap your first meal")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Text.hint(for: scheme))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.Border.glass(section: .home, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log your first meal")
        .accessibilityHint("Opens the meal photo capture")
    }

    private func loggedMealRow(_ log: NutritionLog) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.violet)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.foodName ?? "Meal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                    .lineLimit(1)
                Text(mealTimeLabel(log.date))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            Spacer()
            Text("\(Int(log.proteinGrams))g P")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.violet)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Border.glass(section: .home, for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func mealTimeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    // MARK: - Mood card

    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW ARE YOU FEELING?")
                .font(.system(size: 11, weight: .regular))
                .tracking(0.8)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            HStack(spacing: 6) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    moodChip(mood)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func moodChip(_ mood: Mood) -> some View {
        let isPicked = pickedMood == mood
        return Button {
            HapticManager.selection()
            pickedMood = mood
            recordMood(mood)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: mood.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isPicked ? Color.violet : Theme.Text.tertiary(for: scheme))
                Text(mood.label)
                    .font(.system(size: 9))
                    .foregroundStyle(isPicked ? Color.violet : Theme.Text.tertiary(for: scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isPicked ? Color.violet.opacity(0.12) : Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isPicked ? Color.violet.opacity(0.3) : Theme.Border.glass(section: .home, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Get started card

    private var getStartedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GET STARTED")
                .font(.system(size: 11, weight: .regular))
                .tracking(0.8)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            VStack(spacing: 6) {
                getStartedRow(
                    title: "Log your first meal",
                    subtitle: "Snap a photo of your food",
                    icon: "camera.fill",
                    accent: Color(hex: 0x4ADE80),
                    highlighted: true
                ) {
                    showMealPhotoSheet = true
                }
                getStartedRow(
                    title: "Grocery list",
                    subtitle: "What to grab this week",
                    icon: "cart.fill",
                    accent: Color(hex: 0x4ADE80),
                    highlighted: false
                ) {
                    showGrocerySheet = true
                }
                getStartedRow(
                    title: "Scan something",
                    subtitle: "See how any food fits your plan",
                    icon: "barcode.viewfinder",
                    accent: Color.violet,
                    highlighted: false
                ) {
                    showScanSheet = true
                }
                getStartedRow(
                    title: "Generate your first meal plan",
                    subtitle: "Chat with Mira to build it together",
                    icon: "sparkles",
                    accent: Color.violet,
                    highlighted: false
                ) {
                    showMiraMealPlanSheet = true
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func getStartedRow(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        highlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.08))
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(accent.opacity(0.14), lineWidth: Theme.glassBorderWidth)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(highlighted ? accent : Theme.Text.primary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(highlighted ? accent.opacity(0.35) : Theme.Text.hint(for: scheme))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(highlighted ? accent.opacity(0.04) : Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(highlighted ? accent.opacity(0.12) : Theme.Border.glass(section: .home, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("First weigh-in scheduled for \(nextSundayLabel)")
            .font(.system(size: 10))
            .foregroundStyle(Theme.Text.hint(for: scheme))
            .padding(.top, 4)
    }

    private var nextSundayLabel: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today) // 1=Sun
        if weekday == 1 { return "today" }
        let daysUntil = 8 - weekday
        guard let next = cal.date(byAdding: .day, value: daysUntil, to: today) else { return "Sunday" }
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: next)
    }

    // MARK: - Helpers

    private func daysSinceJourneyStart() -> Int? {
        let start: Date?
        if let stored = UserDefaults.standard.object(forKey: "journeyStartDate") as? Date {
            start = stored
        } else if let earliest = bodyCompRecords.last?.date {
            start = earliest
        } else {
            start = profile?.createdAt
        }
        guard let start else { return nil }
        return Calendar.current.dateComponents([.day], from: start, to: .now).day
    }

    private func persistStartingPhoto(_ data: Data) {
        let weight = profile?.weightLbs ?? 0
        try? saveService.save(weight: weight, photoData: data, in: modelContext)
        HapticManager.success()
    }

    private func recordMood(_ mood: Mood) {
        let log = SymptomLog(
            date: .now,
            nauseaLevel: mood == .nausea ? 3 : 0,
            appetiteLevel: mood == .noAppetite ? 0 : 3,
            energyLevel: mood == .fatigue ? 1 : 3
        )
        modelContext.insert(log)
        HapticManager.success()
    }
}

// MARK: - Mood enum

private enum Mood: CaseIterable, Hashable {
    case good
    case nausea
    case noAppetite
    case fatigue

    var label: String {
        switch self {
        case .good: return "Good"
        case .nausea: return "Nausea"
        case .noAppetite: return "No appetite"
        case .fatigue: return "Fatigue"
        }
    }

    var icon: String {
        switch self {
        case .good: return "checkmark"
        case .nausea: return "exclamationmark.triangle"
        case .noAppetite: return "hourglass"
        case .fatigue: return "bolt.fill"
        }
    }
}
