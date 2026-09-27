import Foundation

enum FastingCalculator {
    struct Preset: Identifiable, Hashable {
        var name: String
        var hours: Double
        var id: String { name }
    }

    /// Fasting hours : eating hours.
    static let presets = [Preset(name: "16:8", hours: 16), Preset(name: "18:6", hours: 18), Preset(name: "20:4", hours: 20)]
    static let customRange: ClosedRange<Double> = 12...36

    struct Fast {
        var start: Date
        var end: Date?
        var targetHours: Double
    }

    static func elapsedHours(_ fast: Fast, now: Date = .now) -> Double {
        max((fast.end ?? now).timeIntervalSince(fast.start) / 3600, 0)
    }

    /// 0...1 towards the target (can exceed 1 once past it).
    static func progress(_ fast: Fast, now: Date = .now) -> Double {
        guard fast.targetHours > 0 else { return 0 }
        return elapsedHours(fast, now: now) / fast.targetHours
    }

    static func targetEnd(_ fast: Fast) -> Date {
        fast.start.addingTimeInterval(fast.targetHours * 3600)
    }

    static func isComplete(_ fast: Fast) -> Bool {
        guard let end = fast.end else { return false }
        return end >= targetEnd(fast)
    }

    /// Fasts that reached their target and ended inside [start, end).
    static func completed(_ fasts: [Fast], from start: Date, to end: Date) -> Int {
        fasts.filter { fast in
            guard let finished = fast.end else { return false }
            return finished >= start && finished < end && isComplete(fast)
        }.count
    }
}
