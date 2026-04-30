import PhotosUI
import SwiftUI

/// Screen 16 — Optional starting photo via PhotosPicker.
/// Camera capture lives in the legacy `MiraOnboardingView+StartingPhoto.swift`
/// extension; this editorial version ships with library-pick only for now.
/// Camera is a follow-up if Kev wants single-tap snap.
struct PhotoScreenEditorial: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var thumbnail: Image?

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "A starting"),
                    QuestionLine(text: "photo?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Optional, private, only you see it. Useful later when you want to look back.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                photoPicker

                OnboardingPrimaryButton(title: "CONTINUE", action: onContinue)
                    .padding(.top, 14)

                OnboardingSecondaryButton(title: "SKIP FOR NOW", action: {
                    profile.startingPhotoData = nil
                    onContinue()
                })
                .padding(.top, 8)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    profile.startingPhotoData = data
                    if let uiImage = UIImage(data: data) {
                        thumbnail = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }

    /// Local-captured thumbnail keeps PhotosPicker's @Sendable label closure
    /// from crossing the main-actor isolation boundary that direct
    /// `self.thumbnail` access would trigger under Swift 6 strict concurrency.
    @ViewBuilder
    private var photoPicker: some View {
        let thumb: Image? = thumbnail
        PhotosPicker(selection: $pickerItem, matching: .images) {
            PhotoCard(thumbnail: thumb)
        }
    }

}

/// Extracted card view so the PhotosPicker label closure (which Swift 6
/// treats as @Sendable) can reference it without crossing main-actor
/// isolation boundaries.
private struct PhotoCard: View {
    let thumbnail: Image?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    Theme.Editorial.onSurface.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.Editorial.onSurface.opacity(0.06))
                )

            if let thumbnail {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                    Text("ADD A PHOTO")
                        .font(Theme.Editorial.Typography.capsBold(10))
                        .tracking(1.8)
                        .foregroundStyle(Theme.Editorial.onSurface)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }
}
