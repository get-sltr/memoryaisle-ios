import PhotosUI
import SwiftUI

struct MealPhotoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isAnalyzing = false
    @State private var result: MealPhotoResult?

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

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.violet.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.violet.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.violet.opacity(0.25), radius: 20, y: 4)
            }
            .padding(.horizontal, 32)
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        photoData = data
                        analyzePhoto()
                    }
                }
            }

            Spacer()
                .frame(height: 56)
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

    private func resultView(_ r: MealPhotoResult) -> some View {
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

                Text(r.mealName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)

                // Macros
                HStack(spacing: 16) {
                    macroCell("Protein", "\(r.protein)g", Color.violet)
                    macroCell("Calories", "\(r.calories)", Theme.Text.secondary(for: scheme))
                    macroCell("Fat", "\(r.fat)g", Theme.Text.tertiary(for: scheme))
                    macroCell("Carbs", "\(r.carbs)g", Theme.Text.tertiary(for: scheme))
                }
                .padding(.horizontal, 20)

                // Mira's note
                HStack(alignment: .top, spacing: 10) {
                    MiraWaveform(state: .idle, size: .hero)
                        .scaleEffect(0.35, anchor: .leading)
                        .frame(width: 30, height: 14)
                    Text(r.miraNote)
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
                    HapticManager.success()
                    dismiss()
                }
                .padding(.horizontal, 32)

                Button {
                    result = nil
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

    // MARK: - Analysis (Bedrock Claude Vision)

    private func analyzePhoto() {
        isAnalyzing = true
        // AI analysis via Bedrock (simulated until Vision API is wired)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            result = MealPhotoResult(
                mealName: "Grilled Chicken with Rice & Vegetables",
                protein: 38,
                calories: 480,
                fat: 12,
                carbs: 45,
                fiber: 6,
                miraNote: "Solid meal. 38g protein puts you closer to your target. The vegetables add fiber and micronutrients. Consider adding a side of Greek yogurt for an extra protein boost."
            )
            isAnalyzing = false
            HapticManager.success()
        }
    }
}

struct MealPhotoResult {
    let mealName: String
    let protein: Int
    let calories: Int
    let fat: Int
    let carbs: Int
    let fiber: Int
    let miraNote: String
}
