import PhotosUI
import SwiftUI

struct PhotoCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var weight = ""
    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.05)))
                }
                Spacer()
                Text("Weekly Check-in")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if saved {
                savedView
            } else {
                checkInForm
            }
        }
        .themeBackground()
    }

    // MARK: - Form

    private var checkInForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 12)

                MiraWaveform(state: .idle, size: .hero)
                    .frame(height: 50)

                Text("How's this week?")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(0.3)

                // Photo
                VStack(spacing: 10) {
                    Text("PROGRESS PHOTO")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(1.2)

                    let currentPhotoData = photoData
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let currentPhotoData, let uiImage = UIImage(data: currentPhotoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color(hex: 0xA78BFA).opacity(0.3), lineWidth: 0.5)
                                )
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.4))
                                Text("Add photo")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.35))
                                Text("Optional")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.15))
                            }
                            .frame(width: 160, height: 220)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white.opacity(0.06), lineWidth: 0.5)
                            )
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        guard let newValue else { return }
                        Task { @MainActor in
                            photoData = try? await newValue.loadTransferable(type: Data.self)
                        }
                    }

                    // Privacy notice
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                        Text("Photos stay on your device only. Never uploaded.")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.white.opacity(0.2))
                }

                // Weight
                VStack(spacing: 8) {
                    Text("CURRENT WEIGHT")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(1.2)

                    HStack(spacing: 8) {
                        TextField("", text: $weight)
                            .font(.system(size: 28, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .frame(width: 120)

                        Text("lbs")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 60)
                }

                GlowButton("Save check-in") {
                    saveCheckIn()
                }
                .padding(.horizontal, 32)

                Button { dismiss() } label: {
                    Text("Skip this week")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Saved

    private var savedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: 0x34D399))

            Text("Check-in saved")
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundStyle(.white)
                .tracking(0.3)

            Text("Keep going. Every week of consistency\ngets you closer to your goal.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            Spacer()

            GlowButton("Done") {
                dismiss()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Save

    private func saveCheckIn() {
        // Save photo locally (never uploaded)
        if let photoData {
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let photosDir = documentsPath.appendingPathComponent("ProgressPhotos", isDirectory: true)

            try? fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let filename = "checkin-\(dateFormatter.string(from: .now)).jpg"

            let filePath = photosDir.appendingPathComponent(filename)
            try? photoData.write(to: filePath)
        }

        HapticManager.success()
        withAnimation(.easeOut(duration: 0.3)) {
            saved = true
        }
    }
}
