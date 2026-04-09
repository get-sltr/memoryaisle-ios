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

    // Ultra dark - darker than the rest of the app
    private let bgColor = Color(hex: 0x09090F)

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
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: 0x3A3A50))

            Text("My Safe Space")
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundStyle(Color(hex: 0x6B6B88))

            Text("Face ID required")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0x3A3A50))

            Spacer()

            Button {
                authenticate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                        .font(.system(size: 16))
                    Text("Unlock")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color(hex: 0x6B6B88))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color(hex: 0x12121E))
                .clipShape(Capsule())
            }

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bgColor.ignoresSafeArea())
    }

    // MARK: - Journal View

    private var journalView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: 0x3A3A50))
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0x3A3A50))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
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
        .background(bgColor.ignoresSafeArea())
        .onAppear { loadEntries() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("A safe space")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color(hex: 0x6B6B88))
            Text("to let it all out.")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color(hex: 0x6B6B88))
                .padding(.bottom, 40)

            Button {
                showingEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: 0x6B6B88))
                    .frame(width: 56, height: 56)
                    .background(Color(hex: 0x12121E))
                    .clipShape(Circle())
            }

            Spacer()

            privacyFooter
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Write View

    private var writeView: some View {
        VStack(spacing: 0) {
            Text("A safe space")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color(hex: 0x6B6B88))
                .padding(.bottom, 4)
            Text("to let it all out.")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color(hex: 0x6B6B88))
                .padding(.bottom, 24)

            TextEditor(text: $entryText)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: 0xE8E8F0))
                .scrollContentBackground(.hidden)
                .focused($isWriting)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 20)
                .onAppear { isWriting = true }

            // Bottom bar
            VStack(spacing: 10) {
                Rectangle()
                    .fill(Color(hex: 0x151520))
                    .frame(height: 1)

                privacyFooter

                HStack {
                    // Mic and camera buttons (future)
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: 0x12121E))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: 0x6B6B88))
                            )

                        Circle()
                            .fill(Color(hex: 0x12121E))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: 0x6B6B88))
                            )
                    }

                    Spacer()

                    // Date
                    Text(Date.now.formatted(.dateTime.month(.wide).day().year()))
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: 0x2A2A3A))

                    Spacer()

                    // Save
                    if !entryText.isEmpty {
                        Button {
                            saveEntry()
                        } label: {
                            Text("Save")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.violet)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
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
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: 0x3A3A50))

                            Text(entry.text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: 0x6B6B88))
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(hex: 0x0E0E18))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.violet.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }

            privacyFooter
                .padding(.bottom, 16)
        }
    }

    // MARK: - Privacy Footer

    private var privacyFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9))
            Text("Face ID protected. Stored only on this device. No one can see this. Not even us.")
                .font(.system(size: 10))
        }
        .foregroundStyle(Color(hex: 0x2A2A3A))
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

    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(".safespace.json")
    }

    private func loadEntries() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        guard let data = try? Data(contentsOf: storageURL) else { return }
        entries = (try? JSONDecoder().decode([SafeSpaceEntry].self, from: data)) ?? []
    }

    private func saveEntry() {
        let entry = SafeSpaceEntry(text: entryText, date: .now)
        entries.insert(entry, at: 0)
        entryText = ""
        showingEntry = false

        if let data = try? JSONEncoder().encode(entries) {
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
