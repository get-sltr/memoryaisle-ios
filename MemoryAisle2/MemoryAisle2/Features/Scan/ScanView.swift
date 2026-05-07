import SwiftUI

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(BarcodeUsageTracker.self) private var barcodeUsage
    @State private var scanLineOffset: CGFloat = -100
    @State private var showGroceryList = false
    @State private var showPantry = false
    @State private var showMealPhoto = false
    @State private var showFoodSearch = false
    @State private var selectedMode: ScanMode
    @State private var isScanning = false
    @State private var scannedProduct: ScannedProduct?
    @State private var pendingManualEntry: PendingManualEntry?
    @State private var showPaywall = false
    @State private var showLimitAlert = false

    init(initialMode: ScanMode = .barcode) {
        _selectedMode = State(initialValue: initialMode)
    }

    private var isPro: Bool { subscriptionManager.tier == .pro }

    enum ScanMode: Hashable {
        case barcode, photo, search

        var promptLine: (top: String, bottom: String, italic: Bool) {
            switch self {
            case .barcode: return ("Scan a", "barcode.", true)
            case .photo:   return ("Snap your", "meal.", true)
            case .search:  return ("Search the", "label.", true)
            }
        }

        var helper: String {
            switch self {
            case .barcode: return "Mira reads protein, calories, and fiber off the package."
            case .photo:   return "Mira estimates the macros from a photo of your plate."
            case .search:  return "Look up a food by name and pick a serving size."
            }
        }

        var icon: String {
            switch self {
            case .barcode: return "barcode.viewfinder"
            case .photo:   return "camera"
            case .search:  return "magnifyingglass"
            }
        }
    }

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Theme.Editorial.Spacing.pad)
                    .padding(.top, Theme.Editorial.Spacing.topInset)

                Spacer(minLength: 6)
                prompt
                Spacer(minLength: 18)
                viewfinder
                Spacer(minLength: 24)
                modeSelector
                    .padding(.horizontal, Theme.Editorial.Spacing.pad)
                    .padding(.bottom, 18)
                captureButton
                Spacer(minLength: 32)
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea()
        .sheet(isPresented: $showGroceryList) { GroceryListView() }
        .sheet(isPresented: $showPantry) { PantryView() }
        .sheet(isPresented: $showMealPhoto) { MealPhotoView() }
        .sheet(isPresented: $showFoodSearch) { FoodSearchView() }
        .sheet(item: $scannedProduct) { product in
            ScanResultView(product: product)
        }
        .sheet(item: $pendingManualEntry) { entry in
            ManualNutritionEntrySheet(
                prefilledName: entry.name,
                prefilledBrand: entry.brand
            ) { nutrition in
                scannedProduct = BarcodeInterpreter.interpret(nutrition: nutrition)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Daily scan limit reached", isPresented: $showLimitAlert) {
            Button("See Pro") { showPaywall = true }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Free accounts get \(FreeTierLimits.barcodeScansPerDay) barcode scans per day. Unlock unlimited scans with Pro.")
        }
        .onAppear { barcodeUsage.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                closeButton

                Spacer()

                Text("SCAN")
                    .font(Theme.Editorial.Typography.wordmark())
                    .tracking(4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Editorial.onSurface)

                Spacer()

                HStack(spacing: 14) {
                    headerIcon("cart", label: "Grocery list") { showGroceryList = true }
                    headerIcon("refrigerator", label: "Pantry") { showPantry = true }
                }
            }
            HairlineDivider()
        }
    }

    private var closeButton: some View {
        Button {
            HapticManager.light()
            dismiss()
        } label: {
            Text("CLOSE")
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private func headerIcon(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Prompt

    private var prompt: some View {
        let lines = selectedMode.promptLine
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: -6) {
                Text(lines.top)
                    .font(Theme.Editorial.Typography.displaySmall())
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text(lines.bottom)
                    .font(lines.italic
                          ? Theme.Editorial.Typography.displaySmallItalic()
                          : Theme.Editorial.Typography.displaySmall())
                    .foregroundStyle(Theme.Editorial.onSurface)
            }
            .lineSpacing(-4)

            Text(selectedMode.helper)
                .font(Theme.Editorial.Typography.miraBody())
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Editorial.Spacing.pad)
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Editorial.onSurface.opacity(0.06))
                .frame(width: 260, height: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Editorial.hairlineSoft, lineWidth: 0.5)
                )

            if isScanning {
                BarcodeScannerView { barcode in
                    MainActor.assumeIsolated { handleBarcode(barcode) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(width: 260, height: 260)
            }

            ScannerCorners()
                .stroke(Theme.Editorial.onSurface.opacity(isScanning ? 0.85 : 0.55), lineWidth: 1.5)
                .frame(width: 220, height: 220)

            if isScanning && selectedMode == .barcode {
                scanLine
            }

            if !isScanning {
                VStack(spacing: 12) {
                    Image(systemName: selectedMode.icon)
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                    Text("TAP CAPTURE")
                        .font(Theme.Editorial.Typography.capsBold(9))
                        .tracking(2.2)
                        .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                }
            }
        }
    }

    private var scanLine: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    colors: [.clear, Theme.Editorial.onSurface.opacity(0.85), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 200, height: 1.5)
            .offset(y: scanLineOffset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    scanLineOffset = 100
                }
            }
    }

    // MARK: - Mode selector

    private var modeSelector: some View {
        HStack(spacing: 6) {
            modeChip(.barcode, "BARCODE")
            modeChip(.photo, "PHOTO")
            modeChip(.search, "SEARCH")
        }
    }

    private func modeChip(_ choice: ScanMode, _ label: String) -> some View {
        let selected = selectedMode == choice
        return Button {
            HapticManager.selection()
            withAnimation(.easeInOut(duration: 0.18)) {
                if isScanning && selectedMode == .barcode { isScanning = false }
                selectedMode = choice
            }
        } label: {
            Text(label)
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(selected ? 1.0 : 0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(Theme.Editorial.onSurface.opacity(selected ? 0.18 : 0.06))
                )
                .overlay(
                    Capsule().stroke(
                        Theme.Editorial.onSurface.opacity(selected ? 0.7 : 0.2),
                        lineWidth: selected ? 1.0 : 0.5
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) mode\(selected ? ", selected" : "")")
    }

    // MARK: - Capture button

    private var captureButton: some View {
        Button {
            HapticManager.heavy()
            switch selectedMode {
            case .barcode:
                if !isPro {
                    barcodeUsage.refresh()
                    if barcodeUsage.hasReachedLimit {
                        showLimitAlert = true
                        return
                    }
                }
                withAnimation(.easeOut(duration: 0.2)) { isScanning.toggle() }
            case .photo:
                showMealPhoto = true
            case .search:
                showFoodSearch = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.Editorial.onSurface)
                    .frame(width: 76, height: 76)
                Image(systemName: isScanning ? "stop.fill" : selectedMode.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.Editorial.nightTop)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isScanning ? "Stop scanning" : "Capture")
    }

    // MARK: - Barcode Handler

    private let nutritionClient = NutritionAPIClient()

    private func handleBarcode(_ barcode: String) {
        HapticManager.success()
        isScanning = false

        // Count this scan against the free-tier daily quota. Recorded
        // here (after a successful read, before the lookup network
        // request) so failed reads don't burn a slot.
        if !isPro {
            barcodeUsage.record()
        }

        Task {
            do {
                let result = try await nutritionClient.lookupBarcode(barcode)
                switch result {
                case .complete(let nutrition):
                    scannedProduct = BarcodeInterpreter.interpret(nutrition: nutrition)
                case .incomplete(let name, let brand):
                    // Open Food Facts knew the product but lacked serving
                    // info. Drop into manual entry with name and brand
                    // pre-filled so the user only types the label values.
                    pendingManualEntry = PendingManualEntry(name: name, brand: brand)
                case .notFound:
                    // No record at all. Open manual entry empty-handed.
                    pendingManualEntry = PendingManualEntry(name: "", brand: "")
                }
            } catch {
                scannedProduct = ScannedProduct(
                    barcode: barcode,
                    name: "Lookup Failed",
                    brand: "Check your connection",
                    servingSize: "",
                    protein: 0, calories: 0, fat: 0, carbs: 0, fiber: 0, sodium: 0,
                    verdict: .okay,
                    nauseaRisk: false,
                    reason: "Couldn't look up this barcode. Make sure you're connected to the internet."
                )
            }
        }
    }
}

/// Trigger payload for the ManualNutritionEntrySheet. When non-nil it
/// presents the sheet; the strings pre-fill the product name and brand.
struct PendingManualEntry: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
}

// MARK: - Scanner Corner Brackets

struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let l: CGFloat = 28
        let r: CGFloat = 8
        var p = Path()

        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))

        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))

        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))

        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))

        return p
    }
}
