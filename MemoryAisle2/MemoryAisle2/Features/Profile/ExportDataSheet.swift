import SwiftData
import SwiftUI

struct ExportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var includePhotos = true
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            EditorialBackground(mode: .night)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("CANCEL")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                Text("EXPORT DATA")
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                Text("We’ll package your data into a single export you can save or share.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    .lineSpacing(3)

                HStack {
                    Text("Include photos")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                    Spacer()
                    Toggle("", isOn: $includePhotos)
                        .labelsHidden()
                        .tint(Color(red: 0.961, green: 0.851, blue: 0.478))
                }
                .padding(.top, 8)

                Button {
                    Task { await generate() }
                } label: {
                    Text(isGenerating ? "GENERATING..." : "GENERATE EXPORT")
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
                .disabled(isGenerating)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.75))
                        .padding(.top, 4)
                }

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.light)
        .presentationDetents([.medium])
    }

    private func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        HapticManager.light()

        do {
            let url = try DataExportService.exportPackage(
                modelContext: modelContext,
                options: .init(includePhotos: includePhotos)
            )
            await MainActor.run {
                ShareSheetPresenter.present(items: [url])
            }
            isGenerating = false
        } catch {
            await MainActor.run {
                errorMessage = "Export failed. Please try again."
                isGenerating = false
            }
        }
    }
}
