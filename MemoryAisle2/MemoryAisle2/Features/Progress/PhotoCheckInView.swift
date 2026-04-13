import PhotosUI
import SwiftData
import SwiftUI

struct PhotoCheckInView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    private let saveService = CheckInSaveService()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var cameraImageData: Data?
    @State private var showSourceChoice = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var weight = ""
    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                    .section(.progress)
                Spacer()
                Text("Weekly Check-in")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                Color.clear
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if saved {
                savedView
            } else {
                checkInForm
            }
        }
        .section(.progress)
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
                    .foregroundStyle(Theme.Text.primary)
                    .tracking(0.3)

                // Photo
                VStack(spacing: 10) {
                    Text("PROGRESS PHOTO")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        .tracking(1.2)

                    let currentPhotoData = photoData
                    let textTertiary = Theme.Text.tertiary(for: scheme)
                    Button {
                        HapticManager.light()
                        showSourceChoice = true
                    } label: {
                        if let currentPhotoData, let uiImage = UIImage(data: currentPhotoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.violet.opacity(0.4))
                                Text("Add photo")
                                    .font(.system(size: 14))
                                    .foregroundStyle(textTertiary)
                                Text("Optional")
                                    .font(.system(size: 11))
                                    .foregroundStyle(textTertiary)
                            }
                            .frame(width: 160, height: 220)
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
                    .buttonStyle(.plain)
                    .accessibilityLabel(currentPhotoData == nil ? "Add progress photo" : "Change progress photo")
                    .confirmationDialog(
                        "Progress Photo",
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
                        Task { @MainActor in
                            photoData = try? await newValue.loadTransferable(type: Data.self)
                        }
                    }
                    .onChange(of: cameraImageData) { _, newValue in
                        guard let newValue else { return }
                        photoData = newValue
                        cameraImageData = nil
                    }

                    // Privacy notice
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                        Text("Photos stay on your device only. Never uploaded.")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }

                // Weight
                VStack(spacing: 8) {
                    Text("CURRENT WEIGHT")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        .tracking(1.2)

                    HStack(spacing: 8) {
                        TextField("", text: $weight)
                            .font(.system(size: 28, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Text.primary)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .frame(width: 120)

                        Text("lbs")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.Surface.glass(for: scheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
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
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
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
                .foregroundStyle(Theme.Semantic.onTrack(for: scheme))

            Text("Check-in saved")
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("Keep going. Every week of consistency\ngets you closer to your goal.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
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
        guard let weightLbs = Double(weight) else { return }
        do {
            try saveService.save(
                weight: weightLbs,
                photoData: photoData,
                in: modelContext
            )
            HapticManager.success()
            withAnimation(.easeOut(duration: 0.3)) {
                saved = true
            }
        } catch {
            // Save failed; stay on the form so the user can retry.
        }
    }
}
