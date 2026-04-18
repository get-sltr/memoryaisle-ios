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

    func lookupBarcode(_ barcode: String) async throws -> NutritionData? {
        guard let url = URL(string: "\(baseURL)/product/\(barcode).json") else {
            return nil
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let result = try JSONDecoder().decode(OpenFoodFactsProduct.self, from: data)

        guard result.status == 1, let product = result.product else {
            return nil
        }

        let nutrients = product.nutriments
        let grams = product.servingQuantity

        return NutritionData(
            name: product.productName ?? "Unknown Product",
            brand: product.brands ?? "Unknown Brand",
            servingSize: product.servingSize ?? "1 serving",
            calories: Int(perServing(nutrients.energyKcalServing, nutrients.energyKcal100g, grams) ?? 0),
            protein: perServing(nutrients.proteinsServing, nutrients.proteins100g, grams) ?? 0,
            fat: perServing(nutrients.fatServing, nutrients.fat100g, grams) ?? 0,
            carbs: perServing(nutrients.carbohydratesServing, nutrients.carbohydrates100g, grams) ?? 0,
            fiber: perServing(nutrients.fiberServing, nutrients.fiber100g, grams) ?? 0,
            sodium: Int((perServing(nutrients.sodiumServing, nutrients.sodium100g, grams) ?? 0) * 1000),
            sugar: perServing(nutrients.sugarsServing, nutrients.sugars100g, grams) ?? 0
        )
    }

    /// Picks the per-serving value when Open Food Facts provides one,
    /// otherwise scales the per-100g value by the product's serving size
    /// in grams. Falls back to the per-100g value as a last resort so a
    /// missing serving size doesn't render every macro as zero.
    private func perServing(
        _ perServing: Double?,
        _ per100g: Double?,
        _ servingGrams: Double?
    ) -> Double? {
        if let v = perServing { return v }
        if let per100 = per100g, let grams = servingGrams, grams > 0 {
            return per100 * grams / 100.0
        }
        return per100g
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

        return (result.products ?? []).compactMap { product in
            guard let name = product.productName, !name.isEmpty else { return nil }
            let nutrients = product.nutriments
            let grams = product.servingQuantity

            return FoodSearchResult(
                foodId: product.code ?? UUID().uuidString,
                name: name,
                brand: product.brands ?? "",
                calories: Int(perServing(nutrients.energyKcalServing, nutrients.energyKcal100g, grams) ?? 0),
                protein: perServing(nutrients.proteinsServing, nutrients.proteins100g, grams) ?? 0
            )
        }
    }
}

// MARK: - OpenFoodFacts API Models

private struct OpenFoodFactsProduct: Codable, Sendable {
    let status: Int
    let product: OFFProduct?
}

private struct OpenFoodFactsSearch: Codable, Sendable {
    let products: [OFFProduct]?
}

private struct OFFProduct: Codable, Sendable {
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
}

private struct OFFNutriments: Codable, Sendable {
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
}
