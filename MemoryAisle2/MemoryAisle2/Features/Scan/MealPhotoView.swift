import PhotosUI
import SwiftUI

struct MealPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isAnalyzing = false
    @State private var result: MealPhotoResult?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.05)))
                }
                Spacer()
                Text("Meal Photo")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 32, height: 32)
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
                .foregroundStyle(.white)
                .tracking(0.3)

            Text("Mira will estimate the macros\nfrom your photo.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.35))
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
                        .fill(Color(hex: 0xA78BFA).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: 0xA78BFA).opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color(hex: 0xA78BFA).opacity(0.25), radius: 20, y: 4)
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
                            .stroke(Color(hex: 0xA78BFA).opacity(0.3), lineWidth: 0.5)
                    )
            }

            MiraWaveform(state: .thinking, size: .hero)
                .frame(height: 50)

            Text("Analyzing your meal...")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.5))

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
                    .foregroundStyle(.white)

                // Macros
                HStack(spacing: 16) {
                    macroCell("Protein", "\(r.protein)g", Color(hex: 0xA78BFA))
                    macroCell("Calories", "\(r.calories)", .white.opacity(0.4))
                    macroCell("Fat", "\(r.fat)g", .white.opacity(0.3))
                    macroCell("Carbs", "\(r.carbs)g", .white.opacity(0.3))
                }
                .padding(.horizontal, 20)

                // Mira's note
                HStack(alignment: .top, spacing: 10) {
                    MiraWaveform(state: .idle, size: .hero)
                        .scaleEffect(0.35, anchor: .leading)
                        .frame(width: 30, height: 14)
                    Text(r.miraNote)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.03))
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
                        .foregroundStyle(.white.opacity(0.35))
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
                .foregroundStyle(.white.opacity(0.25))
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
