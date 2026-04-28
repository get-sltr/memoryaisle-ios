import Foundation

enum MAMode: Sendable {
    case day, night

    static var auto: MAMode {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 6 && hour < 20) ? .day : .night
    }
}
