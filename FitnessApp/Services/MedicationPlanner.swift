import Foundation

/// Schedule, site rotation and progress for weight-loss medication. Pure, so it can be tested.
enum MedicationPlanner {
    struct Medication: Identifiable, Equatable {
        var name: String
        /// Days between doses: 7 for weekly injections, 1 for daily ones and tablets.
        var intervalDays: Int
        var isInjection: Bool
        /// Common strengths in milligrams, lowest first.
        var doses: [Double]

        var id: String { name }
    }

    /// Common GLP-1 medications. Doses are the usual titration steps; always follow the prescriber.
    static let medications: [Medication] = [
        .init(name: "Semaglutide (Wegovy)", intervalDays: 7, isInjection: true, doses: [0.25, 0.5, 1, 1.7, 2.4]),
        .init(name: "Semaglutide (Ozempic)", intervalDays: 7, isInjection: true, doses: [0.25, 0.5, 1, 2]),
        .init(name: "Tirzepatide (Zepbound)", intervalDays: 7, isInjection: true, doses: [2.5, 5, 7.5, 10, 12.5, 15]),
        .init(name: "Tirzepatide (Mounjaro)", intervalDays: 7, isInjection: true, doses: [2.5, 5, 7.5, 10, 12.5, 15]),
        .init(name: "Liraglutide (Saxenda)", intervalDays: 1, isInjection: true, doses: [0.6, 1.2, 1.8, 2.4, 3]),
        .init(name: "Oral semaglutide (Rybelsus)", intervalDays: 1, isInjection: false, doses: [3, 7, 14]),
    ]

    static func medication(named name: String) -> Medication? {
        medications.first { $0.name == name }
    }

    /// Generic names that mark a medication in Apple Health as one of these.
    static let genericNames = ["semaglutide", "tirzepatide", "liraglutide", "dulaglutide", "exenatide"]

    static func isGLP1(_ name: String) -> Bool {
        let lower = name.lowercased()
        let brands = ["wegovy", "ozempic", "zepbound", "mounjaro", "saxenda", "rybelsus", "trulicity", "victoza"]
        return (genericNames + brands).contains { lower.contains($0) }
    }

    static let sideEffects = [
        String(localized: "Nausea"), String(localized: "Vomiting"), String(localized: "Constipation"),
        String(localized: "Diarrhoea"), String(localized: "Heartburn"), String(localized: "Fatigue"),
        String(localized: "Headache"), String(localized: "Injection-site reaction"),
    ]

    /// When the next dose is due: one interval after the last, or today if there's none yet.
    static func nextDose(after last: Date?, intervalDays: Int, now: Date = .now, calendar: Calendar = .current) -> Date {
        guard let last else { return calendar.startOfDay(for: now) }
        return calendar.date(byAdding: .day, value: max(intervalDays, 1), to: calendar.startOfDay(for: last))
            ?? calendar.startOfDay(for: now)
    }

    /// Whole days until the due day: 0 today, negative when overdue.
    static func daysUntil(_ due: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
    }

    static func countdown(_ due: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = daysUntil(due, now: now, calendar: calendar)
        switch days {
        case ..<(-1): return String(localized: "Overdue by \(-days) days")
        case -1: return String(localized: "Due yesterday")
        case 0: return String(localized: "Due today")
        case 1: return String(localized: "Due tomorrow")
        default: return String(localized: "Due in \(days) days")
        }
    }

    /// The next site in the rotation after the last one used.
    static func nextSite(after last: InjectionSite?) -> InjectionSite {
        guard let last, let index = InjectionSite.allCases.firstIndex(of: last) else { return .abdomenLeft }
        return InjectionSite.allCases[(index + 1) % InjectionSite.allCases.count]
    }

    /// The most recent weigh-in on or before `start` (or the first after it) against the latest.
    /// Negative is a loss. Nil without weigh-ins on both sides.
    static func weightChange(since start: Date, weights: [(date: Date, kg: Double)]) -> Double? {
        let sorted = weights.sorted { $0.date < $1.date }
        guard let latest = sorted.last,
              let baseline = sorted.last(where: { $0.date <= start }) ?? sorted.first(where: { $0.date > start }),
              latest.date > baseline.date else { return nil }
        return latest.kg - baseline.kg
    }
}
