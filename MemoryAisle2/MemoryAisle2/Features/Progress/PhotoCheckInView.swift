import PhotosUI
import SwiftData
import SwiftUI

struct PhotoCheckInView: View {
    var mode: MAMode = .auto

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
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
        ZStack {
            EditorialBackground(mode: mode)

            if saved {
                savedView
            } else {
                checkInForm
            }

            VStack {
                HStack {
                    Spacer()
                    doneButton
                }
                .padding(.top, 16)
                .padding(.trailing, 24)
                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea()
    }

    // MARK: - Form

    private var checkInForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header
                HairlineDivider().padding(.vertical, 8)

                // Photo
                VStack(spacing: 10) {
                    Text("PROGRESS PHOTO")
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(2.8)
                        .foregroundStyle(Theme.Editorial.onSurfaceMuted)

                    let currentPhotoData = photoData
                    let textTertiary = Theme.Editorial.onSurface.opacity(0.6)
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
                                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.45))
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
                                    .fill(Theme.Editorial.onSurface.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
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
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.6))
                }

                // Weight
                VStack(spacing: 8) {
                    Text("CURRENT WEIGHT")
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(2.8)
                        .foregroundStyle(Theme.Editorial.onSurfaceMuted)

                    HStack(spacing: 8) {
                        TextField("", text: $weight)
                            .font(.system(size: 28, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Editorial.onSurface)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .frame(width: 120)

                        Text(WeightFormat.unit(system: appState.unitSystem))
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.6))
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.Editorial.onSurface.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 60)
                }

                let weightValue = Double(weight)
                Button {
                    HapticManager.light()
                    saveCheckIn()
                } label: {
                    Text("SAVE CHECK-IN")
                        .font(Theme.Editorial.Typography.capsBold(11))
                        .tracking(2.0)
                        .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.Editorial.onSurface.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .disabled(weightValue == nil)
                .opacity(weightValue == nil ? 0.5 : 1.0)

                Button { dismiss() } label: {
                    Text("Skip this week")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.6))
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Saved

    private var savedView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header
                HairlineDivider().padding(.vertical, 8)

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478).opacity(0.85))
                    .padding(.top, 14)

                Text("Check-in saved")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .tracking(0.3)

                Text("Keep going. Every week of consistency gets you closer to your goal.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(Theme.Editorial.Typography.capsBold(11))
                        .tracking(2.0)
                        .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.Editorial.onSurface.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)
            Image(systemName: "camera")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)
            Text("Weekly Weigh-In")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .tracking(0.6)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("PHOTO · WEIGHT · LEAN MASS")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.top, 8)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
    }

    private var doneButton: some View {
        Button {
            HapticManager.light()
            dismiss()
        } label: {
            Text("DONE")
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func saveCheckIn() {
        guard let entered = Double(weight) else { return }
        let weightLbs = WeightFormat.toCanonical(entered, from: appState.unitSystem)
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
