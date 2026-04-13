import Foundation
import SwiftData

@MainActor
final class CheckInSaveService {

    func save(
        weight: Double,
        photoData: Data?,
        in context: ModelContext
    ) throws {
        let record = BodyComposition(
            date: .now,
            weightLbs: weight,
            source: .manual,
            photoData: photoData
        )
        context.insert(record)
        try context.save()
    }
}
