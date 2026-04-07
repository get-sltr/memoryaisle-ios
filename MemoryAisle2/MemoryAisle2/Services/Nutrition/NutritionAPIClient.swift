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

actor NutritionAPIClient {
    // Using OpenFoodFacts (free, no API key required)
    private let baseURL = "https://world.openfoodfacts.org/api/v2"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "MemoryAisle/1.0 (iOS; contact: kevin@sltrdigital.com)"
        ]
        session = URLSession(configuration: config)
    }

    // MARK: - Barcode Lookup

    func lookupBarcode(_ barcode: String) async throws -> NutritionData? {
        let url = URL(string: "\(baseURL)/product/\(barcode).json")!

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

        return NutritionData(
            name: product.productName ?? "Unknown Product",
            brand: product.brands ?? "Unknown Brand",
            servingSize: product.servingSize ?? "1 serving",
            calories: Int(nutrients.energyKcal100g ?? 0),
            protein: nutrients.proteins100g ?? 0,
            fat: nutrients.fat100g ?? 0,
            carbs: nutrients.carbohydrates100g ?? 0,
            fiber: nutrients.fiber100g ?? 0,
            sodium: Int((nutrients.sodium100g ?? 0) * 1000),
            sugar: nutrients.sugars100g ?? 0
        )
    }

    // MARK: - Text Search

    func search(query: String, page: Int = 1) async throws -> [FoodSearchResult] {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments"),
            URLQueryItem(name: "json", value: "1")
        ]

        guard let url = components.url else { return [] }

        let (data, _) = try await session.data(from: url)
        let result = try JSONDecoder().decode(OpenFoodFactsSearch.self, from: data)

        return (result.products ?? []).compactMap { product in
            guard let name = product.productName, !name.isEmpty else { return nil }
            let nutrients = product.nutriments

            return FoodSearchResult(
                foodId: product.code ?? UUID().uuidString,
                name: name,
                brand: product.brands ?? "",
                calories: Int(nutrients.energyKcal100g ?? 0),
                protein: nutrients.proteins100g ?? 0
            )
        }
    }
}

// MARK: - OpenFoodFacts API Models

private struct OpenFoodFactsProduct: Codable {
    let status: Int
    let product: OFFProduct?
}

private struct OpenFoodFactsSearch: Codable {
    let products: [OFFProduct]?
}

private struct OFFProduct: Codable {
    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let nutriments: OFFNutriments

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case nutriments
    }
}

private struct OFFNutriments: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let fat100g: Double?
    let carbohydrates100g: Double?
    let fiber100g: Double?
    let sodium100g: Double?
    let sugars100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case fat100g = "fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fiber100g = "fiber_100g"
        case sodium100g = "sodium_100g"
        case sugars100g = "sugars_100g"
    }
}
