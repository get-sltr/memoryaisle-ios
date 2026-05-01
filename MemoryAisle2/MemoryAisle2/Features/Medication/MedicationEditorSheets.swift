import SwiftUI

/// Tiny modal for editing a single string field on the Medication page.
/// Editorial styling matches the parent page so the transition feels
/// continuous instead of dropping into a system-default form.
struct TextEditorSheet: View {
    let title: String
    let initial: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        onSave(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    } label: {
                        Text("SAVE")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                TextField(placeholder, text: $draft)
                    .focused($focused)
                    .keyboardType(keyboard)
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.Editorial.onSurface.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                    )

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.light)
        .onAppear {
            draft = initial
            focused = true
        }
        .presentationDetents([.medium])
    }
}

struct DatePickerSheet: View {
    let title: String
    let initial: Date
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var date: Date = .now

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        onSave(date)
                        dismiss()
                    } label: {
                        Text("SAVE")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .tint(Color(red: 0.961, green: 0.851, blue: 0.478))

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.light)
        .onAppear { date = initial }
        .presentationDetents([.large])
    }
}

struct TimePickerSheet: View {
    let title: String
    let initial: Date
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var time: Date = .now

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        onSave(time)
                        dismiss()
                    } label: {
                        Text("SAVE")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .tint(Color(red: 0.961, green: 0.851, blue: 0.478))

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.light)
        .onAppear { time = initial }
        .presentationDetents([.medium])
    }
}

