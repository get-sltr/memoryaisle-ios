import SwiftUI

struct ScanView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
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
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 20)
            viewfinder
            Spacer(minLength: 20)
            modeSelector
                .padding(.horizontal, 40)
            captureButton
            Spacer(minLength: 60)
        }
        .section(.scanner)
        .themeBackground()
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
        HStack(spacing: 10) {
            CloseButton(action: { dismiss() })

            Text("Scan")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)
                .padding(.leading, 4)

            Spacer()

            IconButton(systemName: "cart", accessibilityLabel: "Grocery list") {
                showGroceryList = true
            }
            IconButton(systemName: "refrigerator", accessibilityLabel: "Pantry") {
                showPantry = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        ZStack {
            if isScanning {
                BarcodeScannerView { barcode in
                    // BarcodeScanner already dispatches to main; assume
                    // isolation so we can call the MainActor handler
                    // from this @Sendable callback without an extra hop.
                    MainActor.assumeIsolated {
                        handleBarcode(barcode)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(width: 300, height: 300)
            }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    SectionPalette.primary(.scanner, for: scheme)
                        .opacity(isScanning ? 0.10 : 0.05)
                )
                .frame(width: 280, height: 280)
                .blur(radius: isScanning ? 30 : 20)

            ScannerCorners()
                .stroke(
                    SectionPalette.primary(.scanner, for: scheme)
                        .opacity(isScanning ? 0.9 : 0.55),
                    lineWidth: 2.5
                )
                .frame(width: 240, height: 240)

            scanLine

            if !isScanning {
                VStack(spacing: 10) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(
                            SectionPalette.primary(.scanner, for: scheme).opacity(0.35)
                        )
                    Text("Tap capture to start")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }
        }
    }

    private var scanLine: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        SectionPalette.primary(.scanner, for: scheme)
                            .opacity(isScanning ? 0.85 : 0.55),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 210, height: 2)
            .shadow(
                color: SectionPalette.primary(.scanner, for: scheme).opacity(0.5),
                radius: 4
            )
            .offset(y: scanLineOffset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                ) {
                    scanLineOffset = 100
                }
            }
    }

    // MARK: - Mode selector

    private var modeSelector: some View {
        SegmentedPill(
            options: [
                (ScanMode.barcode, "Barcode"),
                (ScanMode.photo, "Photo"),
                (ScanMode.search, "Search")
            ],
            selection: $selectedMode
        )
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
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SectionPalette.primary(.scanner, for: scheme).opacity(0.35),
                            SectionPalette.primary(.scanner, for: scheme).opacity(0.12)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 36
                    )
                )
                .frame(width: 72, height: 72)
                .overlay(
                    Circle().stroke(
                        SectionPalette.primary(.scanner, for: scheme).opacity(0.55),
                        lineWidth: 1
                    )
                )
                .overlay(
                    Image(systemName: isScanning ? "stop.fill" : "viewfinder")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(SectionPalette.primary(.scanner, for: scheme))
                )
                .shadow(
                    color: SectionPalette.primary(.scanner, for: scheme).opacity(0.45),
                    radius: 18,
                    y: 0
                )
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel("Capture")
        .padding(.top, 20)
        .padding(.bottom, 12)
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
