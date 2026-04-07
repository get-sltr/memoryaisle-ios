import SwiftData
import SwiftUI

struct MealItem: Identifiable {
    let id = UUID()
    let time: String
    let name: String
    let protein: Int
    let calories: Int
    let prepTime: String
    let description: String
    let nauseaSafe: Bool
}

struct MealsView: View {
    @Environment(\.colorScheme) private var scheme
    @Query private var profiles: [UserProfile]
    @State private var selectedMeal: MealItem?

    private var profile: UserProfile? { profiles.first }

    private var meals: [MealItem] {
        let mode = profile?.productMode ?? .everyday

        switch mode {
        case .sensitiveStomach:
            return [
                MealItem(time: "8:30 AM", name: "Banana Oat Smoothie", protein: 18, calories: 280, prepTime: "3 min", description: "Gentle on the stomach, easy to sip", nauseaSafe: true),
                MealItem(time: "12:00 PM", name: "Plain Rice with Soft-Boiled Egg", protein: 14, calories: 320, prepTime: "10 min", description: "Bland, easy to digest", nauseaSafe: true),
                MealItem(time: "3:00 PM", name: "Greek Yogurt + Honey", protein: 20, calories: 180, prepTime: "1 min", description: "Cool, smooth, probiotic boost", nauseaSafe: true),
                MealItem(time: "6:30 PM", name: "Chicken Broth with Toast", protein: 12, calories: 200, prepTime: "5 min", description: "Warm, hydrating, settles the stomach", nauseaSafe: true),
            ]
        case .musclePreservation, .trainingPerformance:
            return [
                MealItem(time: "7:30 AM", name: "Protein Overnight Oats", protein: 35, calories: 420, prepTime: "5 min prep", description: "Greek yogurt base, hemp seeds, berries", nauseaSafe: false),
                MealItem(time: "12:00 PM", name: "Grilled Chicken Power Bowl", protein: 45, calories: 580, prepTime: "15 min", description: "Rice, chicken breast, avocado, greens", nauseaSafe: false),
                MealItem(time: "3:30 PM", name: "Post-Workout Shake", protein: 30, calories: 280, prepTime: "2 min", description: "Whey protein, banana, almond milk", nauseaSafe: true),
                MealItem(time: "7:00 PM", name: "Salmon with Sweet Potato", protein: 38, calories: 520, prepTime: "25 min", description: "Omega-3 rich, complex carbs for recovery", nauseaSafe: false),
            ]
        default:
            return [
                MealItem(time: "8:30 AM", name: "Protein Overnight Oats", protein: 32, calories: 380, prepTime: "5 min prep", description: "Greek yogurt, chia seeds, berries", nauseaSafe: true),
                MealItem(time: "12:30 PM", name: "Grilled Chicken Bowl", protein: 42, calories: 520, prepTime: "15 min", description: "Quinoa, roasted vegetables, lemon tahini", nauseaSafe: false),
                MealItem(time: "6:00 PM", name: "Salmon with Vegetables", protein: 38, calories: 480, prepTime: "25 min", description: "Roasted broccoli, brown rice", nauseaSafe: false),
                MealItem(time: "Snack", name: "Greek Yogurt + Hemp Seeds", protein: 28, calories: 240, prepTime: "2 min", description: "Quick protein boost", nauseaSafe: true),
            ]
        }
    }

    private var totalProtein: Int { meals.reduce(0) { $0 + $1.protein } }
    private var totalCal: Int { meals.reduce(0) { $0 + $1.calories } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Meals")
                            .font(.system(size: 26, weight: .light, design: .serif))
                            .foregroundStyle(.white)
                            .tracking(0.3)

                        Text("\(totalProtein)g protein  ·  \(totalCal) cal")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()

                    MiraWaveform(state: .idle, size: .hero)
                        .frame(height: 28)
                        .scaleEffect(0.5, anchor: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Mode badge
                if let mode = profile?.productMode {
                    HStack {
                        Text(mode.rawValue.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(Color.violet.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color.violet.opacity(0.08))
                            )
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }

                // Meal cards
                ForEach(meals) { meal in
                    mealCard(meal)
                }

                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    private func mealCard(_ meal: MealItem) -> some View {
        Button {
            HapticManager.light()
            selectedMeal = meal
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Time + nausea badge
                HStack {
                    Text(meal.time)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(0.5)

                    Spacer()

                    if meal.nauseaSafe {
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 9))
                            Text("Nausea-safe")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                    }
                }

                // Name
                Text(meal.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)

                // Description
                Text(meal.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))

                // Macros + prep
                HStack(spacing: 16) {
                    macroTag(Color.violet, "\(meal.protein)g protein")
                    macroTag(.white.opacity(0.3), "\(meal.calories) cal")

                    Spacer()

                    Text(meal.prepTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
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
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func macroTag(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
