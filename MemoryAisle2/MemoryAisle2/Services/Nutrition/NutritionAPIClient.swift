import Foundation

struct NutritionData: Codable, Sendable {
    let name: String
    let brand: String
    let servingSize: String
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let fiber: Double
    let sodium: Int
    let sugar: Double
}

struct FoodSearchResult: Identifiable, Codable, Sendable {
    var id: String { foodId }
    let foodId: String
    let name: String
    let brand: String
    let calories: Int
    let protein: Double
}

/// What a barcode lookup can return. We never fall back to per-100g
/// numbers when the user expects per-serving — that's how Miss Vickie's
/// chips read 520 cal instead of the 210 on the bag. The bag is the
/// source of truth: either we can derive per-serving values from real
/// bag data (per-serving fields, or per-100g scaled by serving_quantity)
/// or we ask the user to type them in from the label.
enum BarcodeLookupResult: Sendable {
    /// Open Food Facts returned a product AND we have enough data to
    /// produce real per-serving values.
    case complete(NutritionData)

    /// Open Food Facts found the product but lacks the serving info we
    /// need to compute per-serving macros honestly. We pass back the
    /// product name and brand so the manual-entry sheet can pre-fill them.
    case incomplete(name: String, brand: String)

    /// No record for this barcode in Open Food Facts.
    case notFound
}

struct NutritionAPIClient: Sendable {
    // Using OpenFoodFacts (free, no API key required)
    private let baseURL = "https://world.openfoodfacts.org/api/v2"

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "MemoryAisle/1.0 (iOS; contact: support@memoryaisle.app)"
        ]
        return URLSession(configuration: config)
    }

    // MARK: - Barcode Lookup

    func lookupBarcode(_ barcode: String) async throws -> BarcodeLookupResult {
        guard let url = URL(string: "\(baseURL)/product/\(barcode).json") else {
            return .notFound
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return .notFound
        }

        let result = try JSONDecoder().decode(OpenFoodFactsProduct.self, from: data)

        guard result.status == 1, let product = result.product else {
            return .notFound
        }

        let nutrients = product.nutriments
        let grams = product.servingQuantity

        // Calories per serving is the floor: if we can't derive that
        // honestly, the rest of the row is unusable too. We don't show
        // per-100g masquerading as per-serving — the user tested that and
        // it reads as a broken app.
        guard let caloriesPerServing = strictPerServing(
            nutrients.energyKcalServing, nutrients.energyKcal100g, grams
        ) else {
            return .incomplete(
                name: product.productName ?? "Unknown product",
                brand: product.brands ?? ""
            )
        }

        return .complete(NutritionData(
            name: product.productName ?? "Unknown Product",
            brand: product.brands ?? "Unknown Brand",
            servingSize: product.servingSize ?? "1 serving",
            calories: Int(caloriesPerServing),
            protein: strictPerServing(nutrients.proteinsServing, nutrients.proteins100g, grams) ?? 0,
            fat: strictPerServing(nutrients.fatServing, nutrients.fat100g, grams) ?? 0,
            carbs: strictPerServing(nutrients.carbohydratesServing, nutrients.carbohydrates100g, grams) ?? 0,
            fiber: strictPerServing(nutrients.fiberServing, nutrients.fiber100g, grams) ?? 0,
            sodium: Int((strictPerServing(nutrients.sodiumServing, nutrients.sodium100g, grams) ?? 0) * 1000),
            sugar: strictPerServing(nutrients.sugarsServing, nutrients.sugars100g, grams) ?? 0
        ))
    }

    /// Returns a per-serving value derived from real bag data, or nil. The
    /// only honest sources are: a per-serving field that Open Food Facts
    /// already has, or a per-100g value scaled by a known serving_quantity
    /// in grams. We deliberately do NOT fall back to per-100g alone —
    /// that's a guess about what one serving looks like, and showing the
    /// user a guess as if it were the bag's value is the bug we're fixing.
    private func strictPerServing(
        _ perServing: Double?,
        _ per100g: Double?,
        _ servingGrams: Double?
    ) -> Double? {
        if let v = perServing { return v }
        if let per100 = per100g, let grams = servingGrams, grams > 0 {
            return per100 * grams / 100.0
        }
        return nil
    }

    // MARK: - Text Search

    func search(query: String, page: Int = 1) async throws -> [FoodSearchResult] {
        guard var components = URLComponents(string: "\(baseURL)/search") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,serving_quantity,nutriments"),
            URLQueryItem(name: "json", value: "1")
        ]

        guard let url = components.url else { return [] }

        let (data, _) = try await session.data(from: url)
        let result = try JSONDecoder().decode(OpenFoodFactsSearch.self, from: data)

        // Strict same as lookupBarcode: only surface results we can
        // display per-serving. Items missing serving info are dropped
        // from the list rather than shown with per-100g numbers that
        // misrepresent what's on the package.
        return (result.products ?? []).compactMap { product in
            guard let name = product.productName, !name.isEmpty else { return nil }
            let nutrients = product.nutriments
            let grams = product.servingQuantity

            guard let calories = strictPerServing(
                nutrients.energyKcalServing, nutrients.energyKcal100g, grams
            ) else {
                return nil
            }

            return FoodSearchResult(
                foodId: product.code ?? UUID().uuidString,
                name: name,
                brand: product.brands ?? "",
                calories: Int(calories),
                protein: strictPerServing(nutrients.proteinsServing, nutrients.proteins100g, grams) ?? 0
            )
        }
    }
}

// MARK: - OpenFoodFacts API Models

private struct OpenFoodFactsProduct: Decodable, Sendable {
    let status: Int
    let product: OFFProduct?
}

private struct OpenFoodFactsSearch: Decodable, Sendable {
    let products: [OFFProduct]?
}

private struct OFFProduct: Decodable, Sendable {
    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantity: Double?
    let nutriments: OFFNutriments

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutriments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try? c.decode(String.self, forKey: .code)
        self.productName = try? c.decode(String.self, forKey: .productName)
        self.brands = try? c.decode(String.self, forKey: .brands)
        self.servingSize = try? c.decode(String.self, forKey: .servingSize)
        self.servingQuantity = OFFDecoding.lenientDouble(c, forKey: .servingQuantity)
        self.nutriments = (try? c.decode(OFFNutriments.self, forKey: .nutriments)) ?? OFFNutriments.empty
    }
}

private struct OFFNutriments: Decodable, Sendable {
    let energyKcal100g: Double?
    let energyKcalServing: Double?
    let proteins100g: Double?
    let proteinsServing: Double?
    let fat100g: Double?
    let fatServing: Double?
    let carbohydrates100g: Double?
    let carbohydratesServing: Double?
    let fiber100g: Double?
    let fiberServing: Double?
    let sodium100g: Double?
    let sodiumServing: Double?
    let sugars100g: Double?
    let sugarsServing: Double?

    static let empty = OFFNutriments(
        energyKcal100g: nil, energyKcalServing: nil,
        proteins100g: nil, proteinsServing: nil,
        fat100g: nil, fatServing: nil,
        carbohydrates100g: nil, carbohydratesServing: nil,
        fiber100g: nil, fiberServing: nil,
        sodium100g: nil, sodiumServing: nil,
        sugars100g: nil, sugarsServing: nil
    )

    init(
        energyKcal100g: Double?, energyKcalServing: Double?,
        proteins100g: Double?, proteinsServing: Double?,
        fat100g: Double?, fatServing: Double?,
        carbohydrates100g: Double?, carbohydratesServing: Double?,
        fiber100g: Double?, fiberServing: Double?,
        sodium100g: Double?, sodiumServing: Double?,
        sugars100g: Double?, sugarsServing: Double?
    ) {
        self.energyKcal100g = energyKcal100g
        self.energyKcalServing = energyKcalServing
        self.proteins100g = proteins100g
        self.proteinsServing = proteinsServing
        self.fat100g = fat100g
        self.fatServing = fatServing
        self.carbohydrates100g = carbohydrates100g
        self.carbohydratesServing = carbohydratesServing
        self.fiber100g = fiber100g
        self.fiberServing = fiberServing
        self.sodium100g = sodium100g
        self.sodiumServing = sodiumServing
        self.sugars100g = sugars100g
        self.sugarsServing = sugarsServing
    }

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteins100g = "proteins_100g"
        case proteinsServing = "proteins_serving"
        case fat100g = "fat_100g"
        case fatServing = "fat_serving"
        case carbohydrates100g = "carbohydrates_100g"
        case carbohydratesServing = "carbohydrates_serving"
        case fiber100g = "fiber_100g"
        case fiberServing = "fiber_serving"
        case sodium100g = "sodium_100g"
        case sodiumServing = "sodium_serving"
        case sugars100g = "sugars_100g"
        case sugarsServing = "sugars_serving"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.energyKcal100g = OFFDecoding.lenientDouble(c, forKey: .energyKcal100g)
        self.energyKcalServing = OFFDecoding.lenientDouble(c, forKey: .energyKcalServing)
        self.proteins100g = OFFDecoding.lenientDouble(c, forKey: .proteins100g)
        self.proteinsServing = OFFDecoding.lenientDouble(c, forKey: .proteinsServing)
        self.fat100g = OFFDecoding.lenientDouble(c, forKey: .fat100g)
        self.fatServing = OFFDecoding.lenientDouble(c, forKey: .fatServing)
        self.carbohydrates100g = OFFDecoding.lenientDouble(c, forKey: .carbohydrates100g)
        self.carbohydratesServing = OFFDecoding.lenientDouble(c, forKey: .carbohydratesServing)
        self.fiber100g = OFFDecoding.lenientDouble(c, forKey: .fiber100g)
        self.fiberServing = OFFDecoding.lenientDouble(c, forKey: .fiberServing)
        self.sodium100g = OFFDecoding.lenientDouble(c, forKey: .sodium100g)
        self.sodiumServing = OFFDecoding.lenientDouble(c, forKey: .sodiumServing)
        self.sugars100g = OFFDecoding.lenientDouble(c, forKey: .sugars100g)
        self.sugarsServing = OFFDecoding.lenientDouble(c, forKey: .sugarsServing)
    }
}

/// Open Food Facts is community-edited and inconsistent: numeric fields
/// can come back as Double, Int, String (sometimes empty), or omitted
/// entirely. Strict Codable bails on the whole response when one field
/// is the wrong type, which is what was wiping out scans for products
/// like Miss Vickie's. This helper accepts any of those forms and
/// returns nil for unparseable values without throwing.
private enum OFFDecoding {
    static func lenientDouble<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Double? {
        if let d = try? container.decode(Double.self, forKey: key) { return d }
        if let i = try? container.decode(Int.self, forKey: key) { return Double(i) }
        if let s = try? container.decode(String.self, forKey: key) { return Double(s) }
        return nil
    }
}
