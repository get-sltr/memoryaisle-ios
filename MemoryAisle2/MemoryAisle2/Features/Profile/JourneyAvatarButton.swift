import PhotosUI
import SwiftUI

// Tappable profile avatar for JourneyProfileView.
// Persists the selected image to Documents/profile_avatar.jpg so it
// survives relaunches without requiring a SwiftData schema change.
struct JourneyAvatarButton: View {
    @Environment(\.colorScheme) private var scheme

    @State private var avatarData: Data?
    @State private var showSourceChoice = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var libraryPick: PhotosPickerItem?
    @State private var cameraImageData: Data?

    var body: some View {
        Button {
            HapticManager.light()
            showSourceChoice = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.violetDeep.opacity(0.6),
                                Theme.Semantic.info(for: scheme).opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(avatarContent)

                Circle()
                    .fill(Theme.Semantic.info(for: scheme))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white)
                    )
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(avatarData == nil ? "Add profile photo" : "Change profile photo")
        .onAppear { loadAvatar() }
        .confirmationDialog(
            "Profile photo",
            isPresented: $showSourceChoice,
            titleVisibility: .visible
        ) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showLibraryPicker = true }
            if avatarData != nil {
                Button("Remove photo", role: .destructive) { clearAvatar() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(imageData: $cameraImageData)
                .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showLibraryPicker,
            selection: $libraryPick,
            matching: .images
        )
        .onChange(of: libraryPick) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run { saveAvatar(data) }
                }
            }
        }
        .onChange(of: cameraImageData) { _, newValue in
            guard let newValue else { return }
            saveAvatar(newValue)
            cameraImageData = nil
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let avatarData, let image = UIImage(data: avatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 68, height: 68)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
    }

    // MARK: - Persistence

    private var avatarFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("profile_avatar.jpg")
    }

    private func loadAvatar() {
        avatarData = try? Data(contentsOf: avatarFileURL)
    }

    private func saveAvatar(_ data: Data) {
        guard let image = UIImage(data: data) else { return }
        let resized = resize(image, maxDimension: 512)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return }
        do {
            try jpeg.write(to: avatarFileURL, options: [.atomic])
            avatarData = jpeg
            HapticManager.success()
        } catch {
            HapticManager.warning()
        }
    }

    private func clearAvatar() {
        try? FileManager.default.removeItem(at: avatarFileURL)
        avatarData = nil
        HapticManager.light()
    }

    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
