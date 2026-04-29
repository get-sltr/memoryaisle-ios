import SwiftUI

/// Reusable expandable row used for Daily Targets, Meals, and Feeling on the
/// dashboard. Closed: shows summary text on the right. Open: reveals content.
struct DashboardExpandableSection<Content: View>: View {
    let label: String
    let summary: String
    /// When true the summary text renders italic (Caslon italic).
    var summaryItalic: Bool = false
    @Binding var isOpen: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                row
            }
            .buttonStyle(.plain)

            if isOpen {
                content()
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.Editorial.hairline)
                .frame(height: 0.5)
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Theme.Editorial.Typography.capsBold(9))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurface)

            Spacer(minLength: 12)

            Group {
                if summaryItalic {
                    Text(summary)
                        .font(Theme.Editorial.Typography.miraBody())
                } else {
                    Text(summary)
                        .font(Theme.Editorial.Typography.body())
                }
            }
            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func toggle() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isOpen.toggle()
        }
    }
}

// MARK: - Daily Targets content

struct DailyTargetsContent: View {
    let calories: Int
    let calorieDelta: Int  // negative = below baseline
    let proteinG: Int
    let fiberG: Int
    let waterL: Double

    var body: some View {
        VStack(spacing: 0) {
            row(name: "Calories", value: "\(calories) · \(abs(calorieDelta)) BELOW")
            row(name: "Protein",  value: "\(proteinG) g")
            row(name: "Fiber",    value: "\(fiberG) g")
            row(name: "Water",    value: String(format: "%.1f L", waterL))
        }
    }

    private func row(name: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurface)
            Spacer()
            Text(value)
                .font(Theme.Editorial.Typography.dataValue())
                .tracking(0.5)
                .foregroundStyle(Theme.Editorial.onSurface)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Meals empty state content

struct MealsEmptyContent: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "camera")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(Theme.Editorial.onSurfaceMuted, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tap to snap your first meal.")
                            .font(Theme.Editorial.Typography.body())
                            .foregroundStyle(Theme.Editorial.onSurface)
                        Text("PHOTO + AI RECOGNITION")
                            .font(Theme.Editorial.Typography.caps(8))
                            .tracking(1.8)
                            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    }
                    Spacer()
                }
                .padding(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.Editorial.hairlineSoft, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack {
                Text("Protein first, then veggies, carbs last.")
                    .font(Theme.Editorial.Typography.miraBody())
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.Editorial.hairlineSoft)
                            .frame(width: 0.5)
                    }
                Spacer()
            }
        }
    }
}

// MARK: - Feeling content

struct FeelingContent: View {
    @Binding var selected: Feeling?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Feeling.allCases) { feeling in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected = (selected == feeling) ? nil : feeling
                    }
                } label: {
                    Text(feeling.label)
                        .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(selected == feeling
                                      ? Theme.Editorial.onSurface.opacity(0.18)
                                      : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(
                                Theme.Editorial.hairline,
                                lineWidth: selected == feeling ? 1.2 : 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}
