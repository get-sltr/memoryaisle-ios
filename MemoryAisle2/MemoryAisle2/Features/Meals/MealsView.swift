import SwiftData
import SwiftUI

struct MealsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealPlan.date, order: .reverse) private var plans: [MealPlan]
    @State private var isGenerating = false
    @State private var errorMessage: String?

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
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: 0xF87171))
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Meals")
                    .font(.system(size: 26, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(0.3)

                if !meals.isEmpty {
                    Text("\(totalProtein)g protein  ·  \(totalCal) cal")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            Spacer()

            Button {
                generatePlan()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.violet.opacity(0.6))
            }
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
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(Color.violet.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.violet.opacity(0.08)))
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
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 40)
            Text("No meal plan for today yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Text("Mira will generate a personalized plan based on your goals, medication phase, and dietary needs.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                generatePlan()
            } label: {
                Text("Generate Today's Plan")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.violet.opacity(0.3))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.violet.opacity(0.4), lineWidth: 0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Meal Card

    private func mealCard(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(meal.mealType.rawValue.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .tracking(0.5)
                Spacer()
                if meal.isNauseaSafe {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 9))
                        Text("Nausea-safe")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                }
            }

            Text(meal.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)

            if let instructions = meal.cookingInstructions,
               !instructions.isEmpty {
                Text(instructions)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                macroTag(Color.violet, "\(Int(meal.proteinGrams))g protein")
                macroTag(.white.opacity(0.3), "\(Int(meal.caloriesTotal)) cal")
                Spacer()
                Text("\(meal.prepTimeMinutes) min")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
            }

            if !meal.ingredients.isEmpty {
                Text(meal.ingredients.joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    private func macroTag(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
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
