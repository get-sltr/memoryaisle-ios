import PhotosUI
import SwiftData
import SwiftUI

struct MealPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var cameraImageData: Data?
    @State private var showSourceChoice = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var isAnalyzing = false
    @State private var result: FoodAnalyzer.Analysis?
    @State private var analysisError: String?
    @Query private var profiles: [UserProfile]

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Theme.Editorial.Spacing.pad)
                    .padding(.top, Theme.Editorial.Spacing.topInset)

                if let result {
                    resultView(result)
                } else if isAnalyzing {
                    analyzingView
                } else if let analysisError {
                    errorView(analysisError)
                } else {
                    captureView
                }
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    Text("CLOSE")
                        .font(Theme.Editorial.Typography.capsBold(10))
                        .tracking(2.0)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()

                Text("MEAL")
                    .font(Theme.Editorial.Typography.wordmark())
                    .tracking(4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Editorial.onSurface)

                Spacer()

                // Symmetry spacer so the wordmark stays centered.
                Text("CLOSE")
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.0)
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
            }
            HairlineDivider()
        }
    }

    // MARK: - Capture

    private var captureView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: -8) {
                    Text("Snap your")
                        .font(Theme.Editorial.Typography.displayHero())
                        .foregroundStyle(Theme.Editorial.onSurface)
                    Text("meal.")
                        .font(Theme.Editorial.Typography.displayHeroItalic())
                        .foregroundStyle(Theme.Editorial.onSurface)
                }
                .lineSpacing(-6)

                Text("Mira will estimate the macros from your photo.")
                    .font(Theme.Editorial.Typography.miraBody())
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Editorial.Spacing.pad)

            Spacer()

            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 36)
                .opacity(0.65)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    HapticManager.light()
                    showSourceChoice = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13))
                        Text("TAKE OR CHOOSE PHOTO")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .tracking(2.2)
                    }
                    .foregroundStyle(Theme.Editorial.nightTop)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Theme.Editorial.onSurface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Take or choose meal photo")
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.bottom, 56)
        }
        .confirmationDialog(
            "Add Meal Photo",
            isPresented: $showSourceChoice,
            titleVisibility: .visible
        ) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(imageData: $cameraImageData)
                .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showLibraryPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    photoData = data
                    analyzePhoto()
                }
            }
        }
        .onChange(of: cameraImageData) { _, newValue in
            guard let newValue else { return }
            photoData = newValue
            cameraImageData = nil
            analyzePhoto()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 22) {
            Spacer()

            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(0.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.Editorial.hairlineSoft, lineWidth: 0.5)
                    )
            }

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26, weight: .ultraLight))
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)

            Text(message)
                .font(Theme.Editorial.Typography.miraBody())
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Editorial.Spacing.pad)

            VStack(spacing: 10) {
                Button {
                    analysisError = nil
                    analyzePhoto()
                } label: {
                    Text("TRY AGAIN")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2.2)
                        .foregroundStyle(Theme.Editorial.nightTop)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.Editorial.onSurface))
                }
                .buttonStyle(.plain)

                Button {
                    analysisError = nil
                    photoData = nil
                    selectedPhoto = nil
                } label: {
                    Text("Take a different photo")
                        .font(Theme.Editorial.Typography.miraBody())
                        .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)

            Spacer()
        }
    }

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.Editorial.hairlineSoft, lineWidth: 0.5)
                    )
            }

            MiraWaveform(state: .thinking, size: .hero)
                .frame(height: 36)

            Text("ANALYZING YOUR MEAL")
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)

            Spacer()
        }
    }

    // MARK: - Result

    private func resultView(_ r: FoodAnalyzer.Analysis) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.Editorial.hairlineSoft, lineWidth: 0.5)
                        )
                        .padding(.horizontal, Theme.Editorial.Spacing.pad)
                }

                Text(r.foodName)
                    .font(Theme.Editorial.Typography.mealName())
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Editorial.Spacing.pad)

                HStack(spacing: 10) {
                    macroCell("PROTEIN", "\(Int(r.estimatedProtein))g")
                    macroCell("CALORIES", "\(Int(r.estimatedCalories))")
                    macroCell("FAT", "\(Int(r.estimatedFat))g")
                    macroCell("CARBS", "\(Int(r.estimatedCarbs))g")
                }
                .padding(.horizontal, Theme.Editorial.Spacing.pad)

                HStack(alignment: .top, spacing: 10) {
                    MiraWaveform(state: .idle, size: .hero)
                        .scaleEffect(0.35, anchor: .leading)
                        .frame(width: 30, height: 14)
                    Text(r.explanation)
                        .font(Theme.Editorial.Typography.miraBody())
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.Editorial.onSurface.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.Editorial.hairlineSoft, lineWidth: 0.5)
                )
                .padding(.horizontal, Theme.Editorial.Spacing.pad)

                VStack(spacing: 10) {
                    Button {
                        saveMeal(r)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                            Text("LOG THIS MEAL")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .tracking(2.2)
                        }
                        .foregroundStyle(Theme.Editorial.nightTop)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.Editorial.onSurface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log this meal")

                    Button {
                        result = nil
                        analysisError = nil
                        photoData = nil
                        selectedPhoto = nil
                    } label: {
                        Text("Retake photo")
                            .font(Theme.Editorial.Typography.miraBody())
                            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Editorial.Spacing.pad)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }

    private func macroCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.Editorial.Typography.dataValue())
                .foregroundStyle(Theme.Editorial.onSurface)
            Text(label)
                .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.Editorial.onSurface.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Editorial.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Persistence

    private func saveMeal(_ analysis: FoodAnalyzer.Analysis) {
        // #region agent log (H4_insertionZerosAtWriteTime)
        AgentDebugLogger.log(
            runId: "pre-fix",
            hypothesisId: "H4_insertionZerosAtWriteTime",
            location: "MealPhotoView.swift:saveMeal",
            message: "MealPhotoView.saveMeal analysis-derived inputs",
            data: [
                "estimatedProtein": "\(analysis.estimatedProtein)",
                "estimatedCalories": "\(analysis.estimatedCalories)",
                // Fiber + water are intentionally set to 0 at this layer.
                "setFiberGramsTo": "0",
                "setWaterLitersTo": "0",
                "foodNamePresent": analysis.foodName.isEmpty ? "false" : "true"
            ]
        )
        // #endregion

        // Belt-and-suspenders: never persist a NutritionLog row that has no
        // macros and no food name. The analyzer should already have thrown
        // before reaching here, but if anything slips through, surface it
        // as an error rather than silently inflating today's meals counter.
        guard !analysis.foodName.isEmpty,
              analysis.foodName.lowercased() != "unknown meal",
              analysis.estimatedProtein > 0 || analysis.estimatedCalories > 0
        else {
            analysisError = "Mira couldn't read the macros from this photo. Try a closer shot, or describe what you ate in chat."
            HapticManager.error()
            result = nil
            return
        }

        let log = NutritionLog(
            date: .now,
            proteinGrams: analysis.estimatedProtein,
            caloriesConsumed: analysis.estimatedCalories,
            waterLiters: 0,
            fiberGrams: analysis.estimatedFiber,
            foodName: analysis.foodName,
            photoData: photoData
        )
        modelContext.insert(log)
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }

    // MARK: - Analysis (Bedrock Claude Vision)

    private func analyzePhoto() {
        guard let photoData else { return }
        guard let profile = profiles.first else { return }

        isAnalyzing = true
        analysisError = nil

        Task {
            do {
                let analyzer = FoodAnalyzer()
                let analysis = try await analyzer.analyzePhoto(
                    imageData: photoData,
                    profile: profile
                )
                result = analysis
                HapticManager.success()
            } catch {
                analysisError = error.localizedDescription
                HapticManager.error()
            }
            isAnalyzing = false
        }
    }
}
