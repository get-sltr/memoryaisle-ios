import PhotosUI
import SwiftUI

/// The empty-hero state when the user has no photos yet. A single
/// elevated card with Mira's gentle invitation to set the Day 1 photo.
/// Tap "Set Day 1 photo" → opens the same camera/library picker as
/// PhotoCheckInView. Tap "Not now" → fires a dismiss callback so the
/// parent view can store a 30-day cooldown.
struct ReflectionHeroInviteCard: View {
    let onPhotoChosen: (Data) -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    @State private var showSourceChoice = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var cameraImageData: Data?
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                MiraWaveform(state: .idle, size: .compact)
                    .frame(width: 32, height: 32)
                Spacer()
            }

            Text("Day 1 hasn't started yet.")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Text.primary)

            Text("When you're ready, set your starting photo. It is how the story begins. You can always change it later.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .lineSpacing(4)

            HStack(spacing: 10) {
                Button {
                    HapticManager.light()
                    showSourceChoice = true
                } label: {
                    Text("Set Day 1 photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.violet)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.violet.opacity(0.12)))
                        .overlay(
                            Capsule().stroke(Color.violet.opacity(0.3),
                                             lineWidth: Theme.glassBorderWidth)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.light()
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.Surface.strong(section: .home, for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.Border.strong(section: .home, for: scheme),
                        lineWidth: Theme.glassBorderWidth)
        )
        .padding(.horizontal, 28)
        .confirmationDialog(
            "Starting photo",
            isPresented: $showSourceChoice,
            titleVisibility: .visible
        ) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(imageData: $cameraImageData)
                .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showLibrary,
            selection: $libraryItem,
            matching: .images
        )
        .onChange(of: cameraImageData) { _, newValue in
            guard let newValue else { return }
            onPhotoChosen(newValue)
            cameraImageData = nil
        }
        .onChange(of: libraryItem) { _, newValue in
            guard let newValue else { return }
            Task { @MainActor in
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    onPhotoChosen(data)
                }
            }
        }
    }
}
