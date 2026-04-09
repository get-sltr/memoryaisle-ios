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
    @State private var userResponse = ""

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

            // Mic button at bottom
            if !voice.isSpeaking && showChoices {
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
                choiceButton("Let's go") { advanceTo(.glp1) }

            case .glp1:
                choiceButton("Yes, I'm on a GLP-1") {
                    profile.isOnGLP1 = true
                    advanceTo(.medication)
                }
                choiceButton("No, just smarter nutrition") {
                    profile.isOnGLP1 = false
                    profile.medication = nil
                    profile.modality = nil
                    advanceTo(.age)
                }

            case .medication:
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Medication.allCases, id: \.self) { med in
                            choiceButton(med.rawValue) {
                                profile.medication = med
                                advanceTo(.age)
                            }
                        }
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
                    choiceButton("Next") { advanceTo(.worries) }
                }

            case .worries:
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Worry.allCases, id: \.self) { worry in
                            let isSelected = profile.worries.contains(worry)
                            choiceButton(
                                worry.rawValue,
                                isSelected: isSelected
                            ) {
                                if isSelected {
                                    profile.worries.removeAll { $0 == worry }
                                } else {
                                    profile.worries.append(worry)
                                }
                            }
                        }
                        choiceButton("Continue") { advanceTo(.training) }
                    }
                }
                .frame(maxHeight: 300)

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
                            choiceButton(
                                r.rawValue,
                                isSelected: isSelected
                            ) {
                                if isSelected {
                                    profile.dietaryRestrictions.removeAll { $0 == r }
                                } else {
                                    profile.dietaryRestrictions.append(r)
                                }
                            }
                        }
                        choiceButton("Continue") { advanceTo(.ready) }
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
                "Welcome to MemoryAisle. I'm Mira, and I'll walk you through the setup.",
                step: .intro
            )
        }
    }

    private func advanceTo(_ next: MiraQuestion) {
        withAnimation { showChoices = false }

        let text: String = switch next {
        case .intro: ""
        case .glp1: "Are you currently on a GLP-1 medication?"
        case .medication: "Which medication are you on?"
        case .age: "How old are you?"
        case .sex: "What is your biological sex? This helps me calculate your protein targets."
        case .heightWeight: "What's your current weight and goal weight?"
        case .worries: "What worries you most right now? Select all that apply."
        case .training: "Do you exercise or train regularly?"
        case .dietary: "Any dietary restrictions? Select all that apply, or just hit continue."
        case .ready: "I've got everything I need. Your plan is personalized and ready to go."
        }

        Task {
            await miraSpeak(text, step: next)
        }
    }

    @MainActor
    private func miraSpeak(_ text: String, step: MiraQuestion) async {
        miraText = text
        self.step = step
        voice.speak(text)

        // Wait for speech to finish
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
        case .glp1:
            if lower.contains("yes") {
                profile.isOnGLP1 = true
                advanceTo(.medication)
            } else if lower.contains("no") {
                profile.isOnGLP1 = false
                profile.medication = nil
                advanceTo(.age)
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

// MARK: - Question Steps

enum MiraQuestion: Int, CaseIterable {
    case intro = 0
    case glp1 = 1
    case medication = 2
    case age = 3
    case sex = 4
    case heightWeight = 5
    case worries = 6
    case training = 7
    case dietary = 8
    case ready = 9
}
