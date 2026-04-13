import PhotosUI
import SwiftUI

extension MiraOnboardingView {

    // MARK: - Starting Photo Step

    @ViewBuilder
    var startingPhotoChoices: some View {
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
    var startingPhotoPreview: some View {
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
}
