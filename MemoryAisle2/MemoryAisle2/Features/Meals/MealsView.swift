import SwiftData
import SwiftUI

struct MealsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealPlan.date, order: .reverse) private var plans: [MealPlan]
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var expandedMealId: String?

    private var profile: UserProfile? { profiles.first }

    private var todayPlan: MealPlan? {
        plans.first {
            Calendar.current.isDateInToday($0.date) && $0.isActive
        }
    }

    private var meals: [Meal] {
        todayPlan?.meals ?? []
    }

    private var totalProtein: Int {
        meals.reduce(0) { $0 + Int($1.proteinGrams) }
    }

    private var totalCal: Int {
        meals.reduce(0) { $0 + Int($1.caloriesTotal) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header
                modeBadge

                if isGenerating {
                    generatingState
                } else if meals.isEmpty {
                    emptyState
                } else {
                    ForEach(meals, id: \.id) { meal in
                        mealCard(meal)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Semantic.warning(for: scheme))
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 80)
            }
        }
        .section(.home)
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Meals")
                    .font(Typography.serifMedium)
                    .foregroundStyle(Theme.Text.primary)
                    .tracking(0.3)

                if !meals.isEmpty {
                    Text("\(totalProtein)g protein  ·  \(totalCal) cal")
                        .font(Typography.monoSmall)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }
            Spacer()

            Button {
                generatePlan()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Theme.Accent.primary(for: scheme).opacity(0.6))
            }
            .accessibilityLabel("Regenerate meal plan")
            .disabled(isGenerating)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var modeBadge: some View {
        Group {
            if let mode = profile?.productMode {
                HStack {
                    Text(mode.rawValue.uppercased())
                        .font(Typography.label)
                        .tracking(1)
                        .foregroundStyle(Theme.Accent.primary(for: scheme).opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.Accent.primary(for: scheme).opacity(0.08)))
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - States

    private var generatingState: some View {
        VStack(spacing: 16) {
            MiraWaveform(state: .thinking, size: .hero)
                .frame(height: 40)
            Text("Mira is building your meal plan...")
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 40)
            Text("No meal plan for today yet")
                .font(Typography.bodyLargeBold)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Text("Mira will generate a personalized plan based on your goals, medication phase, and dietary needs.")
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                generatePlan()
            } label: {
                Text("Generate Today's Plan")
                    .font(Typography.bodyMediumBold)
                    .foregroundStyle(Theme.Text.primary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Theme.Accent.primary(for: scheme).opacity(0.3))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.Accent.primary(for: scheme).opacity(0.4), lineWidth: 0.5))
            }
            .accessibilityLabel("Generate today's meal plan")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Meal Card

    private func mealCard(_ meal: Meal) -> some View {
        Button {
            HapticManager.light()
            withAnimation(Theme.Motion.spring) {
                expandedMealId = expandedMealId == meal.id ? nil : meal.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(meal.mealType.rawValue.uppercased())
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        .tracking(0.5)
                    Spacer()
                    if meal.isNauseaSafe {
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(Typography.label)
                            Text("Nausea-safe")
                                .font(Typography.label)
                        }
                        .foregroundStyle(Theme.Semantic.onTrack(for: scheme).opacity(0.7))
                    }
                }

                Text(meal.name)
                    .font(Typography.bodyLargeBold)
                    .foregroundStyle(Theme.Text.primary)

                HStack(spacing: 16) {
                    macroTag(Theme.Accent.primary(for: scheme), "\(Int(meal.proteinGrams))g protein")
                    macroTag(Theme.Text.tertiary(for: scheme), "\(Int(meal.caloriesTotal)) cal")
                    Spacer()
                    Text("\(meal.prepTimeMinutes) min")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }

                if expandedMealId == meal.id {
                    if !meal.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("INGREDIENTS")
                                .font(Typography.label)
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                .tracking(1)
                            ForEach(meal.ingredients, id: \.self) { ingredient in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Theme.Accent.primary(for: scheme).opacity(0.4))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 6)
                                    Text(ingredient)
                                        .font(Typography.bodySmall)
                                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                                }
                            }
                        }
                        .padding(.top, 8)
                    }

                    if let instructions = meal.cookingInstructions,
                       !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("INSTRUCTIONS")
                                .font(Typography.label)
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                .tracking(1)
                            let steps = instructions.components(separatedBy: ";")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                                Text(step)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                            }
                        }
                        .padding(.top, 8)
                    }
                } else {
                    if !meal.ingredients.isEmpty {
                        Text(meal.ingredients.joined(separator: ", "))
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private func macroTag(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(Typography.monoSmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
        }
    }

    // MARK: - Generate

    private func generatePlan() {
        guard let profile = profile else { return }
        isGenerating = true
        errorMessage = nil

        let cyclePhase: CyclePhase?
        if let day = profile.injectionDay {
            cyclePhase = InjectionCycleEngine.currentPhase(injectionDay: day)
        } else {
            cyclePhase = nil
        }

        Task {
            do {
                let generator = MealGenerator()
                let giTriggers = fetchGITriggers()
                let pantry = fetchPantryItems()

                _ = try await generator.generateDailyPlan(
                    profile: profile,
                    cyclePhase: cyclePhase,
                    giTriggers: giTriggers,
                    pantryItems: pantry,
                    isTrainingDay: false,
                    context: modelContext
                )
                isGenerating = false
            } catch {
                isGenerating = false
                errorMessage = "Could not generate plan: \(error.localizedDescription)"
            }
        }
    }

    private func fetchGITriggers() -> [String] {
        let descriptor = FetchDescriptor<GIToleranceRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map(\.foodName)
    }

    private func fetchPantryItems() -> [PantryItem] {
        let descriptor = FetchDescriptor<PantryItem>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
