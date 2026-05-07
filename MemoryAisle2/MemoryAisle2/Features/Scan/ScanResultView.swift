import SwiftData
import SwiftUI

enum ScanVerdict {
    case good
    case okay
    case skip

    var title: String {
        switch self {
        case .good: "Good choice"
        case .okay: "It's okay"
        case .skip: "Skip this one"
        }
    }

    var icon: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .okay: "minus.circle.fill"
        case .skip: "xmark.circle.fill"
        }
    }

    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .good: Theme.Semantic.onTrack(for: scheme)
        case .okay: Theme.Semantic.fiber(for: scheme)
        case .skip: Theme.Semantic.warning(for: scheme)
        }
    }

    // Maps verdict to a SectionID so HeroHeader can use its mesh gradient.
    var heroSection: SectionID {
        switch self {
        case .good: .pantry    // emerald
        case .okay: .recipes   // amber
        case .skip: .calendar  // rose
        }
    }
}

struct ScannedProduct: Identifiable {
    let id = UUID()
    let barcode: String
    let name: String
    let brand: String
    let servingSize: String
    let protein: Int
    let calories: Int
    let fat: Int
    let carbs: Int
    let fiber: Int
    let sodium: Int
    let verdict: ScanVerdict
    let nauseaRisk: Bool
    let reason: String
}

struct ScanResultView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let product: ScannedProduct

    private var subtitle: String {
        product.brand.isEmpty ? product.name : "\(product.name) · \(product.brand)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroHeader(
                title: product.verdict.title,
                subtitle: subtitle
            ) {
                CloseButton(action: { dismiss() })
            }
            .section(product.verdict.heroSection)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text(product.servingSize)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        .padding(.top, 14)

                    Text(product.reason)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    if product.nauseaRisk {
                        nauseaWarning
                    }

                    HStack(spacing: 10) {
                        StatTile(label: "Protein", value: "\(product.protein)g")
                        StatTile(label: "Calories", value: "\(product.calories)")
                        StatTile(label: "Fiber", value: "\(product.fiber)g")
                    }
                    .padding(.horizontal, 20)

                    SectionCard {
                        VStack(spacing: 0) {
                            Text("DETAILS")
                                .font(Typography.label)
                                .foregroundStyle(SectionPalette.soft(.scanner))
                                .tracking(1.2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 8)

                            HStack(spacing: 0) {
                                detailCell("Fat", "\(product.fat)g")
                                Divider().frame(height: 28).opacity(0.15)
                                detailCell("Carbs", "\(product.carbs)g")
                                Divider().frame(height: 28).opacity(0.15)
                                detailCell("Sodium", "\(product.sodium)mg")
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        GlowButton("Log this meal", icon: "checkmark.circle.fill") {
                            logAsMeal()
                        }

                        GhostButton("Add to pantry", icon: "plus") {
                            addToPantry()
                            HapticManager.success()
                            dismiss()
                        }
                        .section(.scanner)

                        Button {
                            dismiss()
                        } label: {
                            Text("Scan another")
                                .font(Typography.bodyMediumBold)
                                .tracking(0.4)
                                .foregroundStyle(Theme.Text.secondary(for: scheme))
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                    Spacer(minLength: 40)
                }
            }
        }
        .section(.scanner)
        .themeBackground()
    }

    /// Persists the scanned product as a meal entry. Mirrors MealLogger paths
    /// from the dashboard log card / recipe detail / meal-plan rows so the
    /// scanner shares the same "log without a photo" affordance the rest of
    /// the app does.
    private func logAsMeal() {
        let label = product.brand.isEmpty
            ? product.name
            : "\(product.name) (\(product.brand))"
        MealLogger.log(
            name: label,
            proteinGrams: Double(product.protein),
            caloriesConsumed: Double(product.calories),
            fiberGrams: Double(product.fiber),
            in: modelContext
        )
        HapticManager.success()
        dismiss()
    }

    private var nauseaWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Semantic.fiber(for: scheme))

            Text("May trigger nausea. High fat slows gastric emptying.")
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Semantic.fiber(for: scheme).opacity(0.85))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Semantic.fiber(for: scheme).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Semantic.fiber(for: scheme).opacity(0.25), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    private func detailCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Typography.bodyMediumBold)
                .foregroundStyle(Theme.Text.primary)
            Text(label)
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .frame(maxWidth: .infinity)
    }

    private func addToPantry() {
        let category: PantryCategory = product.protein >= 15
            ? .protein : .other
        let item = PantryItem(
            name: product.name,
            brand: product.brand,
            barcode: product.barcode,
            proteinPer100g: Double(product.protein),
            caloriesPer100g: product.calories,
            category: category,
            isInPantry: true
        )
        modelContext.insert(item)
    }
}
