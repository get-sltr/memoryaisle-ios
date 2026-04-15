import PhotosUI
import SwiftData
import SwiftUI

struct MealPhotoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
        VStack(spacing: 0) {
            // Header
            HStack {
                CloseButton(action: { dismiss() })
                    .section(.scanner)
                Spacer()
                Text("Meal Photo")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                Color.clear
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

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
        .themeBackground()
    }

    // MARK: - Capture

    private var captureView: some View {
        VStack(spacing: 24) {
            Spacer()

            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 50)

            Text("Snap your meal")
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("Mira will estimate the macros\nfrom your photo.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                HapticManager.light()
                showSourceChoice = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                    Text("Take or choose photo")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [
                            SectionPalette.primary(.scanner, for: scheme),
                            SectionPalette.mid(.scanner, for: scheme)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(
                    color: SectionPalette.primary(.scanner, for: scheme).opacity(0.35),
                    radius: 20,
                    y: 4
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Take or choose meal photo")
            .padding(.horizontal, 32)
            .confirmationDialog(
                "Add Meal Photo",
                isPresented: $showSourceChoice,
                titleVisibility: .visible
            ) {
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Choose from Library") {
                    showLibraryPicker = true
                }
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

            Spacer()
                .frame(height: 56)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(0.5)
            }

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            Text("Mira couldn't analyze this photo.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Text.secondary(for: scheme))

            Button {
                analysisError = nil
                analyzePhoto()
            } label: {
                Text("Try again")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.violet)
            }

            Button {
                analysisError = nil
                photoData = nil
                selectedPhoto = nil
            } label: {
                Text("Take a different photo")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }

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
                            .stroke(Color.violet.opacity(0.3), lineWidth: 0.5)
                    )
            }

            MiraWaveform(state: .thinking, size: .hero)
                .frame(height: 50)

            Text("Analyzing your meal...")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Text.secondary(for: scheme))

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
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                }

                Text(r.foodName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)

                HStack(spacing: 16) {
                    macroCell("Protein", "\(Int(r.estimatedProtein))g", Color.violet)
                    macroCell("Calories", "\(Int(r.estimatedCalories))", Theme.Text.secondary(for: scheme))
                    macroCell("Fat", "\(Int(r.estimatedFat))g", Theme.Text.tertiary(for: scheme))
                    macroCell("Carbs", "\(Int(r.estimatedCarbs))g", Theme.Text.tertiary(for: scheme))
                }
                .padding(.horizontal, 20)

                HStack(alignment: .top, spacing: 10) {
                    MiraWaveform(state: .idle, size: .hero)
                        .scaleEffect(0.35, anchor: .leading)
                        .frame(width: 30, height: 14)
                    Text(r.explanation)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.Surface.glass(for: scheme))
                )
                .padding(.horizontal, 20)

                GlowButton("Log this meal") {
                    saveMeal(r)
                }
                .padding(.horizontal, 32)

                Button {
                    result = nil
                    analysisError = nil
                    photoData = nil
                    selectedPhoto = nil
                } label: {
                    Text("Retake photo")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }

    private func macroCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Persistence

    private func saveMeal(_ analysis: FoodAnalyzer.Analysis) {
        let log = NutritionLog(
            date: .now,
            proteinGrams: analysis.estimatedProtein,
            caloriesConsumed: analysis.estimatedCalories,
            waterLiters: 0,
            fiberGrams: 0,
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
