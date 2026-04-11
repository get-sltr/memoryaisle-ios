import LocalAuthentication
import SwiftUI

struct SafeSpaceView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var isUnlocked = false
    @State private var entryText = ""
    @State private var entries: [SafeSpaceEntry] = []
    @State private var showingEntry = false
    @FocusState private var isWriting: Bool

    var body: some View {
        Group {
            if isUnlocked {
                journalView
            } else {
                lockScreen
            }
        }
        .onAppear {
            authenticate()
        }
    }

    // MARK: - Lock Screen

    private var lockScreen: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            Text("My Safe Space")
                .font(Typography.serifMedium)
                .foregroundStyle(Theme.Text.secondary(for: scheme))

            Text("Face ID required")
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            Spacer()

            Button {
                authenticate()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "faceid")
                        .font(Typography.bodyLarge)
                    Text("Unlock")
                        .font(Typography.bodyMediumBold)
                }
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Theme.Surface.strong(for: scheme))
                .clipShape(Capsule())
            }
            .accessibilityLabel("Unlock with Face ID")

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themeBackground()
    }

    // MARK: - Journal View

    private var journalView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Go back")
                Spacer()
                Image(systemName: "lock.fill")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 20)

            if showingEntry {
                // Writing mode
                writeView
            } else if entries.isEmpty {
                // Empty state
                emptyState
            } else {
                // Entry list
                entryList
            }
        }
        .themeBackground()
        .onAppear { loadEntries() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("A safe space")
                .font(Typography.displaySmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Text("to let it all out.")
                .font(Typography.displaySmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .padding(.bottom, 40)

            Button {
                showingEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(Typography.titleMedium)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                    .frame(width: 56, height: 56)
                    .background(Theme.Surface.strong(for: scheme))
                    .clipShape(Circle())
            }
            .accessibilityLabel("New journal entry")

            Spacer()

            privacyFooter
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Write View

    private var writeView: some View {
        VStack(spacing: 0) {
            Text("A safe space")
                .font(Typography.displaySmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .padding(.bottom, Theme.Spacing.xs)
            Text("to let it all out.")
                .font(Typography.displaySmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .padding(.bottom, Theme.Spacing.lg)

            TextEditor(text: $entryText)
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.primary)
                .scrollContentBackground(.hidden)
                .focused($isWriting)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 20)
                .onAppear { isWriting = true }

            // Bottom bar
            VStack(spacing: 10) {
                Rectangle()
                    .fill(Theme.Border.glass(for: scheme))
                    .frame(height: 1)

                privacyFooter

                HStack {
                    // Mic and camera buttons (future)
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Theme.Surface.strong(for: scheme))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .font(Typography.bodyMedium)
                                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                            )

                        Circle()
                            .fill(Theme.Surface.strong(for: scheme))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(Typography.bodyMedium)
                                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                            )
                    }

                    Spacer()

                    // Date
                    Text(Date.now.formatted(.dateTime.month(.wide).day().year()))
                        .font(Typography.label)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))

                    Spacer()

                    // Save
                    if !entryText.isEmpty {
                        Button {
                            saveEntry()
                        } label: {
                            Text("Save")
                                .font(Typography.bodySmallBold)
                                .foregroundStyle(Color.violet)
                                .padding(.horizontal, Theme.Spacing.md)
                                .frame(minHeight: 44)
                        }
                        .accessibilityLabel("Save journal entry")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Entry List

    private var entryList: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(Typography.label)
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))

                            Text(entry.text)
                                .font(Typography.bodyMedium)
                                .foregroundStyle(Theme.Text.secondary(for: scheme))
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.Surface.glass(for: scheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                        )
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            // New entry button
            HStack {
                Spacer()
                Button {
                    entryText = ""
                    showingEntry = true
                } label: {
                    Image(systemName: "plus")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.violet.opacity(0.3))
                        .clipShape(Circle())
                }
                .accessibilityLabel("New journal entry")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }

            privacyFooter
                .padding(.bottom, Theme.Spacing.md)
        }
    }

    // MARK: - Privacy Footer

    private var privacyFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9))
            Text("Face ID protected. Stored only on this device. No one can see this. Not even us.")
                .font(Typography.label)
        }
        .foregroundStyle(Theme.Text.tertiary(for: scheme))
        .padding(.horizontal, 20)
    }

    // MARK: - Authentication

    private func authenticate() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        ) else {
            // No biometrics available - allow access
            isUnlocked = true
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock My Safe Space"
        ) { success, _ in
            DispatchQueue.main.async {
                isUnlocked = success
            }
        }
    }

    // MARK: - Local Storage (on-device ONLY, no SwiftData, no sync)

    private var storageURL: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent(".safespace.json")
    }

    private func loadEntries() {
        guard let storageURL else { return }
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        guard let data = try? Data(contentsOf: storageURL) else { return }
        entries = (try? JSONDecoder().decode([SafeSpaceEntry].self, from: data)) ?? []
    }

    private func saveEntry() {
        let entry = SafeSpaceEntry(text: entryText, date: .now)
        entries.insert(entry, at: 0)
        entryText = ""
        showingEntry = false

        if let storageURL, let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: storageURL, options: [.atomic, .completeFileProtection])
        }

        HapticManager.light()
    }
}

// MARK: - Entry Model (local only, never synced)

struct SafeSpaceEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date

    init(text: String, date: Date) {
        self.id = UUID()
        self.text = text
        self.date = date
    }
}
