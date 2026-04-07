import Foundation

enum HolidayCulture: String, CaseIterable {
    case us = "US"
    case jewish = "Jewish"
    case hindu = "Hindu"
    case muslim = "Muslim"
    case chinese = "Chinese"
    case vietnamese = "Vietnamese"
    case burmese = "Burmese"

    var color: UInt {
        switch self {
        case .us: 0x60A5FA       // blue
        case .jewish: 0xA78BFA   // violet
        case .hindu: 0xFBBF24    // amber
        case .muslim: 0x34D399   // green
        case .chinese: 0xF87171  // red
        case .vietnamese: 0xFCA5A5 // light red
        case .burmese: 0xFDE68A  // gold
        }
    }

    var emoji: String {
        switch self {
        case .us: "🇺🇸"
        case .jewish: "✡️"
        case .hindu: "🪔"
        case .muslim: "☪️"
        case .chinese: "🏮"
        case .vietnamese: "🎋"
        case .burmese: "🇲🇲"
        }
    }
}

struct Holiday: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
    let culture: HolidayCulture
    let mealNote: String?
    let fasting: Bool

    static func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}

struct HolidayCalendar {

    static func holidays(for year: Int = 2026) -> [Holiday] {
        var all: [Holiday] = []
        all.append(contentsOf: usHolidays(year))
        all.append(contentsOf: jewishHolidays(year))
        all.append(contentsOf: hinduHolidays(year))
        all.append(contentsOf: muslimHolidays(year))
        all.append(contentsOf: chineseHolidays(year))
        all.append(contentsOf: vietnameseHolidays(year))
        all.append(contentsOf: burmeseHolidays(year))
        return all.sorted { $0.date < $1.date }
    }

    static func upcoming(days: Int = 30) -> [Holiday] {
        let now = Date.now
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: now)!
        return holidays().filter { $0.date >= now && $0.date <= cutoff }
    }

    static func today() -> [Holiday] {
        holidays().filter { Calendar.current.isDateInToday($0.date) }
    }

    // MARK: - US Federal

    private static func usHolidays(_ y: Int) -> [Holiday] {
        [
            Holiday(name: "New Year's Day", date: .date(1, 1, year: y), culture: .us, mealNote: nil, fasting: false),
            Holiday(name: "MLK Day", date: .date(1, 19, year: y), culture: .us, mealNote: nil, fasting: false),
            Holiday(name: "Presidents' Day", date: .date(2, 16, year: y), culture: .us, mealNote: nil, fasting: false),
            Holiday(name: "Memorial Day", date: .date(5, 25, year: y), culture: .us, mealNote: "BBQ season. Grilled chicken and lean burgers are great protein sources.", fasting: false),
            Holiday(name: "Independence Day", date: .date(7, 4, year: y), culture: .us, mealNote: "Cookout day. Skip the hot dogs, go for grilled chicken or turkey burgers.", fasting: false),
            Holiday(name: "Labor Day", date: .date(9, 7, year: y), culture: .us, mealNote: nil, fasting: false),
            Holiday(name: "Thanksgiving", date: .date(11, 26, year: y), culture: .us, mealNote: "Turkey is 31g protein per 4oz. Load up on turkey, go easy on stuffing and pie. Eat slowly to manage nausea.", fasting: false),
            Holiday(name: "Christmas", date: .date(12, 25, year: y), culture: .us, mealNote: "Holiday meals can be heavy. Focus on protein first, then sides. Small portions if appetite is low.", fasting: false),
        ]
    }

    // MARK: - Jewish (2026 approximate dates)

    private static func jewishHolidays(_ y: Int) -> [Holiday] {
        [
            Holiday(name: "Passover (Pesach)", date: .date(4, 2, year: y), culture: .jewish, mealNote: "Matzo-based meals. Pair with eggs, fish, or chicken for protein. Avoid heavy matzo ball soup if nauseous.", fasting: false),
            Holiday(name: "Shavuot", date: .date(5, 22, year: y), culture: .jewish, mealNote: "Dairy holiday. Greek yogurt, cottage cheese, and cheese blintzes are protein-rich options.", fasting: false),
            Holiday(name: "Rosh Hashanah", date: .date(9, 12, year: y), culture: .jewish, mealNote: "Apples and honey. Light, sweet. Add protein with roasted chicken or fish for the main meal.", fasting: false),
            Holiday(name: "Yom Kippur", date: .date(9, 21, year: y), culture: .jewish, mealNote: "Fasting day. Break fast with light protein: eggs, yogurt, light soup. Avoid heavy foods.", fasting: true),
            Holiday(name: "Hanukkah", date: .date(12, 15, year: y), culture: .jewish, mealNote: "Latkes and sufganiyot are fried. If GI is sensitive, bake instead of fry. Add applesauce, not sour cream.", fasting: false),
        ]
    }

    // MARK: - Hindu (2026 approximate dates)

    private static func hinduHolidays(_ y: Int) -> [Holiday] {
        [
            Holiday(name: "Holi", date: .date(3, 10, year: y), culture: .hindu, mealNote: "Festival of colors. Thandai is traditional. Stay hydrated. Protein-rich snacks between celebrations.", fasting: false),
            Holiday(name: "Ram Navami", date: .date(3, 26, year: y), culture: .hindu, mealNote: nil, fasting: true),
            Holiday(name: "Navratri Begins", date: .date(10, 2, year: y), culture: .hindu, mealNote: "9-day festival. Many fast or eat vegetarian. Paneer, lentils, and chickpeas for protein.", fasting: true),
            Holiday(name: "Dussehra", date: .date(10, 12, year: y), culture: .hindu, mealNote: nil, fasting: false),
            Holiday(name: "Diwali", date: .date(10, 21, year: y), culture: .hindu, mealNote: "Festival of lights. Sweets are everywhere. Enjoy in moderation. Prioritize protein meals around celebrations.", fasting: false),
            Holiday(name: "Ganesh Chaturthi", date: .date(8, 27, year: y), culture: .hindu, mealNote: "Modak is traditional. Consider protein-rich versions with paneer filling.", fasting: false),
        ]
    }

    // MARK: - Muslim (2026 approximate dates - varies with lunar calendar)

    private static func muslimHolidays(_ y: Int) -> [Holiday] {
        [
            Holiday(name: "Ramadan Begins", date: .date(2, 18, year: y), culture: .muslim, mealNote: "Fasting sunrise to sunset. Suhoor: high-protein, slow-digesting foods. Iftar: start with dates and water, then protein.", fasting: true),
            Holiday(name: "Laylat al-Qadr", date: .date(3, 15, year: y), culture: .muslim, mealNote: "Night of Power. Light iftar to stay alert for prayer. Protein shake is efficient.", fasting: true),
            Holiday(name: "Eid al-Fitr", date: .date(3, 20, year: y), culture: .muslim, mealNote: "End of Ramadan. Ease back into regular eating. Start with light protein meals. Don't overeat after fasting.", fasting: false),
            Holiday(name: "Eid al-Adha", date: .date(5, 27, year: y), culture: .muslim, mealNote: "Feast of sacrifice. Lamb and goat are traditional and protein-rich. Watch portion sizes on GLP-1s.", fasting: false),
            Holiday(name: "Islamic New Year", date: .date(6, 17, year: y), culture: .muslim, mealNote: nil, fasting: false),
        ]
    }

    // MARK: - Chinese

    private static func chineseHolidays(_ y: Int) -> [Holiday] {
        [
            Holiday(name: "Chinese New Year", date: .date(2, 17, year: y), culture: .chinese, mealNote: "Dumplings, fish, noodles. Steamed dumplings are better for GI than fried. Fish is great protein.", fasting: false),
            Holiday(name: "Lantern Festival", date: .date(3, 3, year: y), culture: .chinese, mealNote: "Tangyuan (rice balls). Small portions. They're dense carbs, so pair with protein.", fasting: false),
            Holiday(name: "Dragon Boat Festival", date: .date(5, 31, year: y), culture: .chinese, mealNote: "Zongzi (rice dumplings). Heavy and sticky. Small piece + lean protein on the side.", fasting: false),
            Holiday(name: "Mid-Autumn Festival", date: .date(10, 6, year: y), culture: .chinese, mealNote: "Mooncakes are calorie-dense. One small piece max. Focus on the gathering, not the cake.", fasting: false),
            Holiday(name: "Qingming Festival", date: .date(4, 4, year: y), culture: .chinese, mealNote: nil, fasting: false),
        ]
    }

    // MARK: - Vietnamese

    private static func vietnameseHolidays(_ y: Int) -> [Holiday] {
        [
            Holiday(name: "Tet (Lunar New Year)", date: .date(2, 17, year: y), culture: .vietnamese, mealNote: "Banh chung/banh tet, pho, spring rolls. Pho broth is light and nausea-friendly. Go for lean cuts.", fasting: false),
            Holiday(name: "Hung Kings' Day", date: .date(4, 12, year: y), culture: .vietnamese, mealNote: "Banh giay and banh chung. Traditional sticky rice cakes. Small portions.", fasting: false),
            Holiday(name: "Tet Trung Thu", date: .date(10, 6, year: y), culture: .vietnamese, mealNote: "Mid-Autumn. Mooncakes and lanterns. Same as Chinese: one small piece max.", fasting: false),
            Holiday(name: "Vu Lan (Ghost Festival)", date: .date(8, 22, year: y), culture: .vietnamese, mealNote: "Many eat vegetarian. Tofu, tempeh, and edamame for protein.", fasting: false),
        ]
    }

    // MARK: - Burmese

    private static func burmeseHolidays(_ y: Int) -> [Holiday] {
        [
            Holiday(name: "Thingyan (Water Festival)", date: .date(4, 13, year: y), culture: .burmese, mealNote: "Burmese New Year water festival. Mont lone yee paw (rice balls in jaggery). Stay hydrated! Traditional snacks are sweet, so balance with protein.", fasting: false),
            Holiday(name: "Burmese New Year", date: .date(4, 17, year: y), culture: .burmese, mealNote: "Mohinga (fish noodle soup) is the national dish. Great protein source. Light on the stomach.", fasting: false),
            Holiday(name: "Full Moon of Kasone", date: .date(5, 12, year: y), culture: .burmese, mealNote: "Watering the banyan tree. Light vegetarian meals are traditional.", fasting: false),
            Holiday(name: "Full Moon of Waso", date: .date(7, 10, year: y), culture: .burmese, mealNote: "Start of Buddhist Lent. Many eat vegetarian or fast. Lentil soup, tofu, and tempeh for protein.", fasting: true),
            Holiday(name: "Thadingyut (Festival of Lights)", date: .date(10, 6, year: y), culture: .burmese, mealNote: "End of Buddhist Lent. Kanom jeen (rice noodles) and curries. Choose lean curries, skip the coconut-heavy ones if nauseous.", fasting: false),
            Holiday(name: "Tazaungdaing (Festival of Lights)", date: .date(11, 4, year: y), culture: .burmese, mealNote: "Weaving festival. Htamane (sticky rice) is traditional. Small portions, add nuts for protein.", fasting: false),
            Holiday(name: "National Day", date: .date(11, 28, year: y), culture: .burmese, mealNote: nil, fasting: false),
        ]
    }
}

private extension Date {
    static func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
