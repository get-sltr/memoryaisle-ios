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

    var color: Color {
        switch self {
        case .good: Color(hex: 0x34D399)
        case .okay: Color(hex: 0xFBBF24)
        case .skip: Color(hex: 0xF87171)
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

    var body: some View {
        VStack(spacing: 0) {
            // Close
            HStack {
                Spacer()
                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.Surface.strong(for: scheme)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Verdict
                    VStack(spacing: 12) {
                        Image(systemName: product.verdict.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(product.verdict.color)

                        Text(product.verdict.title)
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(Theme.Text.primary)
                            .tracking(0.3)
                    }
                    .padding(.top, 12)

                    // Product info
                    VStack(spacing: 4) {
                        Text(product.name)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.Text.primary)
                            .multilineTextAlignment(.center)

                        Text(product.brand)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))

                        Text(product.servingSize)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }

                    // Reason
                    Text(product.reason)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Nausea warning
                    if product.nauseaRisk {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: 0xFBBF24))

                            Text("May trigger nausea. High fat slows gastric emptying.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: 0xFBBF24).opacity(0.7))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(hex: 0xFBBF24).opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(hex: 0xFBBF24).opacity(0.12), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 20)
                    }

                    // Macros grid
                    VStack(spacing: 0) {
                        Text("NUTRITION")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1.2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 12)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            nutrientCell("Protein", "\(product.protein)g", Color.violet)
                            nutrientCell("Calories", "\(product.calories)", Theme.Text.secondary(for: scheme))
                            nutrientCell("Fat", "\(product.fat)g", Theme.Text.tertiary(for: scheme))
                            nutrientCell("Carbs", "\(product.carbs)g", Theme.Text.tertiary(for: scheme))
                            nutrientCell("Fiber", "\(product.fiber)g", Color(hex: 0xFBBF24))
                            nutrientCell("Sodium", "\(product.sodium)mg", Theme.Text.tertiary(for: scheme))
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

                    // Actions
                    GlowButton("Add to pantry") {
                        addToPantry()
                        HapticManager.success()
                        dismiss()
                    }
                    .padding(.horizontal, 32)

                    Button {
                        dismiss()
                    } label: {
                        Text("Scan another")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .themeBackground()
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
            category: category
        )
        modelContext.insert(item)
    }

    private func nutrientCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
