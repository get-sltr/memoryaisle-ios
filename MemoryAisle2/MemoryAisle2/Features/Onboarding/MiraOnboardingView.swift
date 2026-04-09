import SwiftUI

struct MiraOnboardingView: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var profile: OnboardingProfile
    let onComplete: () -> Void

    @State private var voice = VoiceManager()
    @State private var step: MiraQuestion = .intro
    @State private var showChoices = false
    @State private var miraText = ""
    @State private var isListening = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Mira waveform
            MiraWaveform(
                state: voice.isSpeaking ? .speaking
                    : isListening ? .speaking
                    : .idle,
                size: .hero
            )
            .frame(height: 60)
            .padding(.bottom, 32)

            // Mira's question
            Text(miraText)
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 32)
                .animation(.easeOut(duration: 0.3), value: miraText)

            Spacer()

            // Choices or listening state
            if isListening {
                listeningView
            } else if showChoices {
                choicesForCurrentStep
            }

            // Mic button
            if !voice.isSpeaking && showChoices && !isListening {
                micButton
                    .padding(.bottom, 20)
            }

            Spacer()
                .frame(height: 40)
        }
        .themeBackground()
        .onAppear { startConversation() }
    }

    // MARK: - Listening State

    private var listeningView: some View {
        VStack(spacing: 12) {
            Text(voice.transcribedText.isEmpty ? "Listening..." : voice.transcribedText)
                .font(.system(size: 16))
                .foregroundStyle(voice.transcribedText.isEmpty
                    ? Theme.Text.tertiary(for: scheme)
                    : Theme.Text.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                stopAndProcess()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.violet)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button {
            HapticManager.medium()
            startListening()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                Text("Tap to speak")
                    .font(.system(size: 13))
            }
            .foregroundStyle(Color.violet.opacity(0.6))
        }
    }

    // MARK: - Choices Per Step

    @ViewBuilder
    private var choicesForCurrentStep: some View {
        VStack(spacing: 10) {
            switch step {
            case .intro:
                choiceButton("Let's go") { advanceTo(.goals) }

            case .goals:
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Worry.allCases, id: \.self) { worry in
                            let isSelected = profile.worries.contains(worry)
                            choiceButton(worry.rawValue, isSelected: isSelected) {
                                if isSelected {
                                    profile.worries.removeAll { $0 == worry }
                                } else {
                                    profile.worries.append(worry)
                                }
                            }
                        }
                        if !profile.worries.isEmpty {
                            choiceButton("Continue") { advanceTo(.training) }
                        }
                    }
                }
                .frame(maxHeight: 320)

            case .training:
                ForEach(TrainingLevel.allCases, id: \.self) { level in
                    choiceButton(level.rawValue) {
                        profile.trainingLevel = level
                        advanceTo(.dietary)
                    }
                }

            case .dietary:
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(DietaryRestriction.allCases, id: \.self) { r in
                            let isSelected = profile.dietaryRestrictions.contains(r)
                            choiceButton(r.rawValue, isSelected: isSelected) {
                                if isSelected {
                                    profile.dietaryRestrictions.removeAll { $0 == r }
                                } else {
                                    profile.dietaryRestrictions.append(r)
                                }
                            }
                        }
                        choiceButton("Continue") { advanceTo(.age) }
                    }
                }
                .frame(maxHeight: 300)

            case .age:
                HStack(spacing: 12) {
                    TextField("Age", text: Binding(
                        get: { profile.age.map { "\($0)" } ?? "" },
                        set: { profile.age = Int($0) }
                    ))
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundStyle(Theme.Text.primary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                    .padding(.vertical, 14)
                    .background(Theme.Surface.glass(for: scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    choiceButton("Next") { advanceTo(.sex) }
                }

            case .sex:
                ForEach(BiologicalSex.allCases, id: \.self) { sex in
                    choiceButton(sex.rawValue) {
                        profile.sex = sex
                        advanceTo(.heightWeight)
                    }
                }

            case .heightWeight:
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        numberField("Weight (lbs)", value: Binding(
                            get: { profile.weightLbs.map { "\(Int($0))" } ?? "" },
                            set: { profile.weightLbs = Double($0) }
                        ))
                        numberField("Goal (lbs)", value: Binding(
                            get: { profile.goalWeightLbs.map { "\(Int($0))" } ?? "" },
                            set: { profile.goalWeightLbs = Double($0) }
                        ))
                    }
                    choiceButton("Next") { advanceTo(.medication) }
                }

            case .medication:
                choiceButton("Yes") {
                    profile.isOnGLP1 = true
                    advanceTo(.whichMed)
                }
                choiceButton("No") {
                    profile.isOnGLP1 = false
                    profile.medication = nil
                    profile.modality = nil
                    advanceTo(.ready)
                }

            case .whichMed:
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Medication.allCases, id: \.self) { med in
                            choiceButton(med.rawValue) {
                                profile.medication = med
                                advanceTo(.ready)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)

            case .ready:
                choiceButton("Take me home") { onComplete() }
            }
        }
        .padding(.horizontal, 32)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Shared Components

    private func choiceButton(
        _ title: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.secondary(for: scheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected
                            ? Color.violet.opacity(0.15)
                            : Theme.Surface.glass(for: scheme))
                )
        }
        .buttonStyle(.plain)
    }

    private func numberField(_ placeholder: String, value: Binding<String>) -> some View {
        VStack(spacing: 4) {
            Text(placeholder)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            TextField("", text: value)
                .font(.system(size: 22, weight: .light, design: .monospaced))
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(.vertical, 10)
                .background(Theme.Surface.glass(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Conversation Flow

    private func startConversation() {
        Task {
            _ = await voice.requestPermissions()
            await miraSpeak(
                "Welcome to MemoryAisle. I'm Mira, and I'll help you get set up.",
                step: .intro
            )
        }
    }

    private func advanceTo(_ next: MiraQuestion) {
        withAnimation { showChoices = false }

        let text: String = switch next {
        case .intro: ""
        case .goals: "What matters most to you right now? Pick everything that applies."
        case .training: "Do you exercise or train regularly?"
        case .dietary: "Any dietary restrictions? Select what applies, or just hit continue."
        case .age: "How old are you?"
        case .sex: "What is your biological sex? This helps me calculate your protein targets."
        case .heightWeight: "What's your current weight and where do you want to be?"
        case .medication: "Are you on any medication that affects your appetite?"
        case .whichMed: "Which medication?"
        case .ready: buildReadySummary()
        }

        Task { await miraSpeak(text, step: next) }
    }

    private func buildReadySummary() -> String {
        var parts: [String] = ["I've got everything I need."]

        if !profile.worries.isEmpty {
            let focus = profile.worries.first?.rawValue.lowercased() ?? "your goals"
            parts.append("I'll focus on \(focus).")
        }

        if let weight = profile.weightLbs, let goal = profile.goalWeightLbs {
            let diff = Int(weight - goal)
            if diff > 0 {
                parts.append("We're working toward losing \(diff) pounds while keeping your muscle.")
            }
        }

        if profile.isOnGLP1, let med = profile.medication {
            parts.append("I'll adapt your meals to your \(med.rawValue) cycle.")
        }

        parts.append("Your plan is personalized and ready.")
        return parts.joined(separator: " ")
    }

    @MainActor
    private func miraSpeak(_ text: String, step: MiraQuestion) async {
        miraText = text
        self.step = step
        voice.speak(text)

        while voice.isSpeaking {
            try? await Task.sleep(for: .milliseconds(100))
        }

        withAnimation(.easeOut(duration: 0.4)) {
            showChoices = true
        }
    }

    private func startListening() {
        isListening = true
        voice.startListening()
    }

    private func stopAndProcess() {
        voice.stopListening()
        let response = voice.transcribedText
        isListening = false
        processVoiceResponse(response)
    }

    private func processVoiceResponse(_ text: String) {
        let lower = text.lowercased()

        switch step {
        case .medication:
            if lower.contains("yes") {
                profile.isOnGLP1 = true
                advanceTo(.whichMed)
            } else if lower.contains("no") {
                profile.isOnGLP1 = false
                profile.medication = nil
                advanceTo(.ready)
            }
        case .age:
            if let age = Int(text.filter(\.isNumber)) {
                profile.age = age
                advanceTo(.sex)
            }
        case .sex:
            if lower.contains("male") && !lower.contains("female") {
                profile.sex = .male
                advanceTo(.heightWeight)
            } else if lower.contains("female") {
                profile.sex = .female
                advanceTo(.heightWeight)
            }
        case .training:
            if lower.contains("lift") || lower.contains("weight") {
                profile.trainingLevel = .lifts
                advanceTo(.dietary)
            } else if lower.contains("cardio") || lower.contains("run") {
                profile.trainingLevel = .cardio
                advanceTo(.dietary)
            } else if lower.contains("sometimes") {
                profile.trainingLevel = .sometimes
                advanceTo(.dietary)
            } else if lower.contains("no") || lower.contains("not") {
                profile.trainingLevel = .none
                advanceTo(.dietary)
            }
        default:
            break
        }
    }
}

// MARK: - Question Steps (reordered: goals first, medication last)

enum MiraQuestion: Int, CaseIterable {
    case intro = 0
    case goals = 1        // What matters to you? (worries)
    case training = 2     // Do you exercise?
    case dietary = 3      // Restrictions?
    case age = 4          // How old?
    case sex = 5          // Biological sex
    case heightWeight = 6 // Weight + goal
    case medication = 7   // On any appetite medication?
    case whichMed = 8     // Which one?
    case ready = 9        // Personalized summary
}
