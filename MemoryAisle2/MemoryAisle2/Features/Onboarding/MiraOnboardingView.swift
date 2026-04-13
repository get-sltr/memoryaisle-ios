import PhotosUI
import SwiftUI

struct MiraOnboardingView: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var profile: OnboardingProfile
    let onComplete: () -> Void

    @State private var step: MiraQuestion = .intro
    @State private var showChoices = false
    @State private var miraText = ""
    @State private var voice = VoiceManager()
    @State private var startingPhotoItem: PhotosPickerItem?
    @State private var startingCameraData: Data?
    @State private var showStartingSourceChoice = false
    @State private var showStartingCamera = false
    @State private var showStartingLibrary = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Mira waveform
            MiraWaveform(state: .idle, size: .hero)
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

            // Choices
            if showChoices {
                choicesForCurrentStep
            }

            Spacer()
                .frame(height: 40)
        }
        .section(.home)
        .themeBackground()
        .onAppear { startConversation() }
        .onDisappear { voice.stopSpeaking() }
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
                    .font(Typography.monoLarge)
                    .fontWeight(.light)
                    .foregroundStyle(Theme.Text.primary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                    .accessibilityLabel("Age")
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
                    choiceButton("Next") { advanceTo(.startingPhoto) }
                }

            case .startingPhoto:
                startingPhotoChoices

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

    // MARK: - Starting Photo Step

    @ViewBuilder
    private var startingPhotoChoices: some View {
        VStack(spacing: 12) {
            startingPhotoPreview
                .onTapGesture {
                    HapticManager.light()
                    showStartingSourceChoice = true
                }
                .accessibilityLabel(profile.startingPhotoData == nil
                    ? "Add starting photo"
                    : "Change starting photo")
                .confirmationDialog(
                    "Starting photo",
                    isPresented: $showStartingSourceChoice,
                    titleVisibility: .visible
                ) {
                    Button("Take Photo") { showStartingCamera = true }
                    Button("Choose from Library") { showStartingLibrary = true }
                    Button("Cancel", role: .cancel) {}
                }
                .fullScreenCover(isPresented: $showStartingCamera) {
                    CameraPicker(imageData: $startingCameraData)
                        .ignoresSafeArea()
                }
                .photosPicker(
                    isPresented: $showStartingLibrary,
                    selection: $startingPhotoItem,
                    matching: .images
                )
                .onChange(of: startingPhotoItem) { _, newValue in
                    guard let newValue else { return }
                    Task { @MainActor in
                        profile.startingPhotoData = try? await newValue.loadTransferable(type: Data.self)
                    }
                }
                .onChange(of: startingCameraData) { _, newValue in
                    guard let newValue else { return }
                    profile.startingPhotoData = newValue
                    startingCameraData = nil
                }

            choiceButton("Continue") { advanceTo(.medication) }
            choiceButton("Skip for now") {
                profile.startingPhotoData = nil
                advanceTo(.medication)
            }
        }
    }

    @ViewBuilder
    private var startingPhotoPreview: some View {
        if let data = profile.startingPhotoData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 140, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.violet.opacity(0.4))
                Text("Add a photo")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .frame(width: 140, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
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
                .font(isSelected ? Typography.bodyMediumBold : Typography.bodyMedium)
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
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func numberField(_ placeholder: String, value: Binding<String>) -> some View {
        VStack(spacing: 4) {
            Text(placeholder)
                .font(Typography.label)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            TextField("", text: value)
                .font(Typography.displaySmallMono)
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(.vertical, 10)
                .background(Theme.Surface.glass(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(placeholder)
        }
    }

    // MARK: - Conversation Flow

    private func startConversation() {
        miraText = "Hello, my name is Mira. Welcome to MemoryAisle. I will be assisting you with your onboarding process today."
        step = .intro
        voice.speak(miraText)
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            showChoices = true
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
        case .startingPhoto: "Want to set a starting photo? It is optional, and you can always change your mind later."
        case .medication: "Are you on any medication that affects your appetite?"
        case .whichMed: "Which medication?"
        case .ready: buildReadySummary()
        }

        miraText = text
        step = next
        if !text.isEmpty {
            voice.speak(text)
        }
        withAnimation(.easeOut(duration: 0.4)) {
            showChoices = true
        }
    }

    private func buildReadySummary() -> String {
        "All set. Your plan is personalized based on everything you've told me. Let's get started."
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
    case startingPhoto = 7 // Optional starting photo (NEW)
    case medication = 8   // On any appetite medication?
    case whichMed = 9     // Which one?
    case ready = 10       // Personalized summary
}
