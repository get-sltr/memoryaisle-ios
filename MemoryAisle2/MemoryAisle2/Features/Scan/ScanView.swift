import SwiftUI

struct ScanView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var scanLineOffset: CGFloat = -100
    @State private var showGroceryList = false
    @State private var showPantry = false
    @State private var showMealPhoto = false
    @State private var showFoodSearch = false
    @State private var selectedMode = 0
    @State private var isScanning = false
    @State private var scannedProduct: ScannedProduct?

    var body: some View {
        ZStack {
            Color.indigoBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Scan")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                        .tracking(0.3)

                    Spacer()

                    HStack(spacing: 8) {
                        scanHeaderButton("cart", "List") { showGroceryList = true }
                        scanHeaderButton("refrigerator", "Pantry") { showPantry = true }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .sheet(isPresented: $showGroceryList) { GroceryListView() }
                .sheet(isPresented: $showPantry) { PantryView() }
                .sheet(isPresented: $showMealPhoto) { MealPhotoView() }
                .sheet(isPresented: $showFoodSearch) { FoodSearchView() }

                Spacer()

                // Viewfinder
                ZStack {
                    // Live camera feed when scanning
                    if isScanning {
                        BarcodeScannerView { barcode in
                            handleBarcode(barcode)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(width: 260, height: 260)
                    }

                    ScannerCorners()
                        .stroke(Color.violet.opacity(isScanning ? 0.8 : 0.5), lineWidth: 2)
                        .frame(width: 240, height: 240)

                    // Scan line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.violet.opacity(isScanning ? 0.7 : 0.5), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 200, height: 2)
                        .offset(y: scanLineOffset)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 2.2)
                                .repeatForever(autoreverses: true)
                            ) {
                                scanLineOffset = 100
                            }
                        }

                    if !isScanning {
                        VStack(spacing: 10) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundStyle(Color.violet.opacity(0.25))

                            Text("Tap capture to start")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }
                .sheet(item: $scannedProduct) { product in
                    ScanResultView(product: product)
                }

                Spacer()

                // Mode selector
                HStack(spacing: 0) {
                    modeTab("Barcode", icon: "barcode", index: 0)
                    modeTab("Photo", icon: "camera", index: 1)
                    modeTab("Search", icon: "magnifyingglass", index: 2)
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.04))
                )
                .padding(.horizontal, 40)

                // Capture button
                Button {
                    HapticManager.heavy()
                    switch selectedMode {
                    case 0:
                        withAnimation(.easeOut(duration: 0.2)) { isScanning.toggle() }
                    case 1:
                        showMealPhoto = true
                    case 2:
                        showFoodSearch = true
                    default:
                        break
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.violet.opacity(0.3), lineWidth: 2)
                            .frame(width: 68, height: 68)

                        Circle()
                            .fill(Color.violet.opacity(0.1))
                            .frame(width: 56, height: 56)

                        Image(systemName: "viewfinder")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.violet.opacity(0.8))
                    }
                    .shadow(color: Color.violet.opacity(0.15), radius: 16, y: 4)
                }
                .buttonStyle(GlassPressStyle())
                .padding(.top, 24)
                .padding(.bottom, 16)

                Spacer(minLength: 80)
            }
        }
    }

    // MARK: - Barcode Handler

    private let nutritionClient = NutritionAPIClient()

    private func handleBarcode(_ barcode: String) {
        HapticManager.success()
        isScanning = false

        Task {
            do {
                if let nutrition = try await nutritionClient.lookupBarcode(barcode) {
                    let product = BarcodeInterpreter.interpret(nutrition: nutrition)
                    scannedProduct = product
                } else {
                    // Product not found in database
                    scannedProduct = ScannedProduct(
                        barcode: barcode,
                        name: "Unknown Product",
                        brand: "Barcode: \(barcode)",
                        servingSize: "",
                        protein: 0, calories: 0, fat: 0, carbs: 0, fiber: 0, sodium: 0,
                        verdict: .okay,
                        nauseaRisk: false,
                        reason: "This product wasn't found in our database. Try searching by name instead."
                    )
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

    private func scanHeaderButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.violet.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.violet.opacity(0.08))
            .clipShape(Capsule())
        }
    }

    private func modeTab(_ title: String, icon: String, index: Int) -> some View {
        let isSelected = selectedMode == index

        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.15)) {
                selectedMode = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.violet.opacity(0.2))
                    : nil
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scanner Corner Brackets

struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let l: CGFloat = 28
        let r: CGFloat = 8
        var p = Path()

        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))

        // Top-right
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))

        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))

        return p
    }
}
