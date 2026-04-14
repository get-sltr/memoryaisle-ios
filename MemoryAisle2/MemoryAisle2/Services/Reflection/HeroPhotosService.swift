import Foundation

/// The bundle of data the Reflection hero card needs: earliest and latest
/// BodyComposition records that have a photo, plus their dates and
/// weights for the overlay labels. nil all the way through if the user
/// hasn't taken any photos yet (the view shows the invite card instead).
struct HeroPhotos: Equatable {
    let day1: Data?
    let today: Data?
    let day1Date: Date?
    let todayDate: Date?
    let day1Weight: Double?
    let todayWeight: Double?
}

@MainActor
struct HeroPhotosService {

    func photos(from records: ReflectionSourceRecords) -> HeroPhotos {
        let withPhotos = records.bodyCompositions
            .filter { $0.photoData != nil }
            .sorted { $0.date < $1.date }

        guard let first = withPhotos.first, let last = withPhotos.last else {
            return HeroPhotos(
                day1: nil, today: nil,
                day1Date: nil, todayDate: nil,
                day1Weight: nil, todayWeight: nil
            )
        }

        return HeroPhotos(
            day1: first.photoData,
            today: last.photoData,
            day1Date: first.date,
            todayDate: last.date,
            day1Weight: first.weightLbs,
            todayWeight: last.weightLbs
        )
    }
}
