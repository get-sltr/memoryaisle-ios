import Foundation
import SwiftData

@Observable
final class CloudSyncManager {
    private let baseURL = "https://9n2u3mkkma.execute-api.us-east-1.amazonaws.com/prod/sync"

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?
    private(set) var lastError: String?

    // MARK: - Push All Data

    func pushAll(userId: String, modelContext: ModelContext) async {
        isSyncing = true
        syncError = nil

        do {
            // Every fetch flows through `fetchSyncable`, whose generic
            // parameter is constrained to `CloudSyncable`. Anything that
            // isn't on the allowlist — including `SafeSpaceEntry` — can't
            // reach the network path without a compile error.

            let profiles = try fetchSyncable(UserProfile.self, from: modelContext)
            if let profile = profiles.first {
                try await push(userId: userId, dataType: "profile", data: encodeProfile(profile))
            }

            let logs = try fetchSyncable(NutritionLog.self, from: modelContext)
            let logsData = logs.map { log in
                [
                    "date": ISO8601DateFormatter().string(from: log.date),
                    "protein": log.proteinGrams,
                    "calories": log.caloriesConsumed,
                    "water": log.waterLiters,
                    "fiber": log.fiberGrams
                ] as [String: Any]
            }
            try await push(userId: userId, dataType: "nutritionLogs", data: logsData)

            let symptoms = try fetchSyncable(SymptomLog.self, from: modelContext)
            let symptomsData = symptoms.map { s in
                [
                    "date": ISO8601DateFormatter().string(from: s.date),
                    "nausea": s.nauseaLevel,
                    "appetite": s.appetiteLevel,
                    "energy": s.energyLevel,
                    "bloating": s.bloating,
                    "constipation": s.constipation,
                    "foodAversion": s.foodAversion
                ] as [String: Any]
            }
            try await push(userId: userId, dataType: "symptomLogs", data: symptomsData)

            let pantry = try fetchSyncable(PantryItem.self, from: modelContext)
            let pantryData = pantry.map { p in
                [
                    "name": p.name,
                    "brand": p.brand,
                    "category": p.category.rawValue,
                    "proteinPer100g": p.proteinPer100g
                ] as [String: Any]
            }
            try await push(userId: userId, dataType: "pantryItems", data: pantryData)

            lastSyncDate = .now
        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    /// Compile-time gated fetch. `T: CloudSyncable` is the privacy
    /// invariant — any model reaching the cloud push path must first be
    /// added to the `CloudSyncable` allowlist. `SafeSpaceEntry` is not a
    /// `@Model` and is not on the allowlist, so calls like
    /// `fetchSyncable(SafeSpaceEntry.self, ...)` will not compile.
    private func fetchSyncable<T: CloudSyncable>(
        _ type: T.Type,
        from modelContext: ModelContext
    ) throws -> [T] {
        try modelContext.fetch(FetchDescriptor<T>())
    }

    // MARK: - Pull Data

    func pullAll(userId: String) async -> [String: Any]? {
        isSyncing = true
        syncError = nil

        do {
            let data = try await pull(userId: userId, dataType: nil)
            isSyncing = false
            return data
        } catch {
            syncError = error.localizedDescription
            isSyncing = false
            return nil
        }
    }

    // MARK: - Delete All Cloud Data

    func deleteAllCloudData(userId: String) async -> Bool {
        do {
            guard let url = URL(string: "\(baseURL)/delete-account") else {
                lastError = "Invalid delete endpoint URL"
                return false
            }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["userId": userId])
            request.timeoutInterval = 15

            let (_, response) = try await URLSession.shared.data(for: request)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            if success {
                lastError = nil
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                lastError = "Delete request failed with status \(code)"
            }
            return success
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Network

    private func push(userId: String, dataType: String, data: Any) async throws {
        guard let url = URL(string: "\(baseURL)/push") else {
            throw SyncError.pushFailed(dataType)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "userId": userId,
            "dataType": dataType,
            "data": data,
            "timestamp": ISO8601DateFormatter().string(from: .now)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SyncError.pushFailed(dataType)
        }
    }

    private func pull(userId: String, dataType: String?) async throws -> [String: Any] {
        var urlString = "\(baseURL)/pull?userId=\(userId)"
        if let dt = dataType {
            urlString += "&dataType=\(dt)"
        }

        guard let url = URL(string: urlString) else { throw SyncError.pullFailed }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SyncError.pullFailed
        }

        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func encodeProfile(_ profile: UserProfile) -> [String: Any] {
        var dict: [String: Any] = [
            "proteinTarget": profile.proteinTargetGrams,
            "calorieTarget": profile.calorieTarget,
            "waterTarget": profile.waterTargetLiters,
            "fiberTarget": profile.fiberTargetGrams,
            "trainingLevel": profile.trainingLevel.rawValue,
            "productMode": profile.productMode.rawValue,
        ]
        if let med = profile.medication { dict["medication"] = med.rawValue }
        if let mod = profile.medicationModality { dict["modality"] = mod.rawValue }
        if let dose = profile.doseAmount { dict["dose"] = dose }
        if let age = profile.age { dict["age"] = age }
        if let sex = profile.sex { dict["sex"] = sex.rawValue }
        if let weight = profile.weightLbs { dict["weight"] = weight }
        if let goal = profile.goalWeightLbs { dict["goalWeight"] = goal }
        return dict
    }
}

enum SyncError: LocalizedError {
    case pushFailed(String)
    case pullFailed

    var errorDescription: String? {
        switch self {
        case .pushFailed(let type): "Failed to sync \(type)"
        case .pullFailed: "Failed to pull data"
        }
    }
}
