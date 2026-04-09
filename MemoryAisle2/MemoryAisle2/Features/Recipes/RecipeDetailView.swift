import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let recipe: RecipeItem

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                        .frame(width: 44, height: 44)
                }
                Spacer()
                if recipe.nauseaSafe {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 10))
                        Text("Nausea-safe")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Title
                    VStack(spacing: 8) {
                        Text(recipe.name)
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(Theme.Text.primary)
                            .tracking(0.3)
                            .multilineTextAlignment(.center)

                        Text(recipe.description)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 4)

                    // Stats
                    HStack(spacing: 0) {
                        statCell("\(recipe.protein)g", label: "Protein", color: Color(hex: 0xA78BFA))
                        statCell("\(recipe.calories)", label: "Calories", color: Theme.Text.secondary(for: scheme))
                        statCell(recipe.prepTime, label: "Prep", color: Theme.Text.tertiary(for: scheme))
                        statCell(recipe.cookTime, label: "Cook", color: Theme.Text.tertiary(for: scheme))
                        statCell("\(recipe.servings)", label: "Serves", color: Theme.Text.tertiary(for: scheme))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.Surface.glass(for: scheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                    )
                    .padding(.horizontal, 20)

                    // Ingredients
                    VStack(alignment: .leading, spacing: 10) {
                        Text("INGREDIENTS")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1.2)

                        ForEach(recipe.ingredients) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color(hex: 0xA78BFA).opacity(0.3))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(item.name)
                                            .font(.system(size: 15))
                                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                                        Spacer()
                                        Text(item.amount)
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                    }
                                    if let prep = item.prep {
                                        Text(prep)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.4))
                                    }
                                }
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

                    // Steps
                    VStack(alignment: .leading, spacing: 14) {
                        Text("HOW TO MAKE IT")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1.2)

                        ForEach(recipe.steps) { step in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(step.number)")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: 0xA78BFA))
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.instruction)
                                            .font(.system(size: 15))
                                            .foregroundStyle(Theme.Text.primary)

                                        if let duration = step.duration {
                                            HStack(spacing: 4) {
                                                Image(systemName: "clock")
                                                    .font(.system(size: 10))
                                                Text(duration)
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                        }

                                        if let tip = step.tip {
                                            HStack(alignment: .top, spacing: 6) {
                                                Image(systemName: "lightbulb.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color(hex: 0xFBBF24).opacity(0.5))
                                                Text(tip)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(Color(hex: 0xFBBF24).opacity(0.5))
                                            }
                                            .padding(.top, 2)
                                        }
                                    }
                                }

                                if step.number < recipe.steps.count {
                                    Rectangle()
                                        .fill(Theme.Border.glass(for: scheme))
                                        .frame(height: 0.5)
                                        .padding(.leading, 30)
                                }
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

                    // Mira tip
                    HStack(alignment: .top, spacing: 10) {
                        MiraWaveform(state: .idle, size: .hero)
                            .scaleEffect(0.35, anchor: .leading)
                            .frame(width: 30, height: 14)
                            .padding(.top, 2)

                        Text(recipe.miraTip)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.Surface.glass(for: scheme))
                    )
                    .padding(.horizontal, 20)

                    GlowButton("Add to today's plan") {
                        HapticManager.success()
                        dismiss()
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 40)
                }
            }
        }
        .themeBackground()
    }

    private func statCell(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .frame(maxWidth: .infinity)
    }
}
