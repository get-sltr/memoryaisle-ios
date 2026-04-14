import PhotosUI
import SwiftData
import SwiftUI
@preconcurrency import Vision

struct ReceiptScannerView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cameraImageData: Data?
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var showSourceChoice = false
    @State private var isProcessing = false
    @State private var extractedItems: [ExtractedItem] = []
    @State private var totalSpend: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                    .section(.recipes)
                Spacer()
                Text("Receipt Scanner")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                Color.clear
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if extractedItems.isEmpty {
                captureView
            } else {
                resultsView
            }
        }
        .section(.recipes)
        .themeBackground()
    }

    // MARK: - Capture

    private var captureView: some View {
        VStack(spacing: 24) {
            Spacer()

            if isProcessing {
                MiraWaveform(state: .thinking, size: .hero)
                    .frame(height: 60)
                Text("Reading your receipt...")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
            } else {
                MiraWaveform(state: .idle, size: .hero)
                    .frame(height: 60)
                    .padding(.bottom, 12)

                Text("Scan a receipt")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundStyle(Theme.Text.primary)
                    .tracking(0.3)

                Text("I'll extract the items and add\nthem to your pantry.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .multilineTextAlignment(.center)

                Spacer()
                    .frame(height: 20)

                Button {
                    showSourceChoice = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 18))
                        Text("Take photo or choose")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(Color.violet)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .confirmationDialog(
                    "Add Receipt",
                    isPresented: $showSourceChoice,
                    titleVisibility: .visible
                ) {
                    Button("Take Photo") {
                        showCamera = true
                    }
                    Button("Choose from Library") {
                        showLibraryPicker = true
                    }
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
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self) {
                            processReceipt(data)
                        }
                    }
                }
                .onChange(of: cameraImageData) { _, newValue in
                    guard let newValue else { return }
                    processReceipt(newValue)
                    cameraImageData = nil
                }
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(extractedItems.count) items found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Text.primary)
                    if let total = totalSpend {
                        Text("Total: \(total)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.violet.opacity(0.7))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Item list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(Array(extractedItems.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text(item.name)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.Text.primary)

                            Spacer()

                            if let price = item.price {
                                Text(price)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            }

                            Button {
                                extractedItems.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.Surface.glass(for: scheme))
                        )
                    }
                }
                .padding(.horizontal, 20)
            }

            // Actions
            VStack(spacing: 12) {
                GlowButton("Add all to pantry") {
                    addToPantry()
                    HapticManager.success()
                    dismiss()
                }

                Button {
                    exportItemList()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                        Text("Export item list")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
    }

    // MARK: - OCR Processing

    private func processReceipt(_ imageData: Data) {
        isProcessing = true

        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            isProcessing = false
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async { isProcessing = false }
                return
            }

            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let items = extractItems(from: lines)

            DispatchQueue.main.async {
                extractedItems = items
                totalSpend = extractTotal(from: lines)
                isProcessing = false
                HapticManager.success()
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    // Extract item names only -- no measurements, quantities, or codes
    private func extractItems(from lines: [String]) -> [ExtractedItem] {
        let skipPatterns = [
            "subtotal", "total", "tax", "change", "cash", "credit",
            "debit", "visa", "mastercard", "amex", "thank", "welcome",
            "store", "address", "phone", "receipt", "transaction",
            "barcode", "upc", "sku", "qty", "date", "time",
            "savings", "discount", "coupon", "member", "rewards"
        ]

        return lines.compactMap { line in
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Skip short lines, numbers-only, skip patterns
            guard lower.count > 2 else { return nil }
            guard !skipPatterns.contains(where: { lower.contains($0) }) else { return nil }

            // Extract price if present (e.g., "CHICKEN BREAST  $5.99")
            var name = line
            var price: String?

            if let range = line.range(of: #"\$?\d+\.\d{2}"#, options: .regularExpression) {
                price = String(line[range])
                name = String(line[line.startIndex..<range.lowerBound])
            }

            // Clean up the name
            name = name.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"\d+[xX]\s*"#, with: "", options: .regularExpression) // remove "2x"
                .replacingOccurrences(of: #"\d+\s*(oz|lb|kg|g|ml|ct|pk|ea)\b"#, with: "", options: [.regularExpression, .caseInsensitive]) // remove measurements
                .trimmingCharacters(in: .whitespaces)

            // Must have at least 2 alpha chars remaining
            let alphaCount = name.filter(\.isLetter).count
            guard alphaCount >= 2, name.count >= 2 else { return nil }

            // Title case
            let titleCased = name.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")

            return ExtractedItem(name: titleCased, price: price)
        }
    }

    private func extractTotal(from lines: [String]) -> String? {
        for line in lines.reversed() {
            let lower = line.lowercased()
            if lower.contains("total") && !lower.contains("sub"),
               let range = line.range(of: #"\$?\d+\.\d{2}"#, options: .regularExpression) {
                return String(line[range])
            }
        }
        return nil
    }

    // MARK: - Actions

    private func addToPantry() {
        for item in extractedItems {
            let pantryItem = PantryItem(name: item.name, isInPantry: true)
            modelContext.insert(pantryItem)
        }
    }

    private func exportItemList() {
        let text = extractedItems.map { item in
            if let price = item.price {
                return "\(item.name) - \(price)"
            }
            return item.name
        }.joined(separator: "\n")

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct ExtractedItem {
    let name: String
    let price: String?
}
