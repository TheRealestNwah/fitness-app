import SwiftUI

// MARK: - Card container

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var color: Color = .accentColor
    var overColor: Color = .orange

    private var clamped: Double { min(max(progress, 0), 1) }
    private var isOver: Bool { progress > 1 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(isOver ? overColor : color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
    }
}

// MARK: - Macro bar

struct MacroBar: View {
    var name: String
    var consumed: Double
    var target: Double
    var color: Color

    private var fraction: Double { target > 0 ? min(consumed / target, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(consumed.rounded())) / \(Int(target.rounded())) g")
                    .font(.caption.monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    var title: String
    var value: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    var title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Macro summary line

struct MacroSummary: View {
    var protein: Double
    var carbs: Double
    var fat: Double

    var body: some View {
        HStack(spacing: 10) {
            Label("\(Int(protein.rounded()))g", systemImage: "p.circle.fill").foregroundStyle(.blue)
            Label("\(Int(carbs.rounded()))g", systemImage: "c.circle.fill").foregroundStyle(.orange)
            Label("\(Int(fat.rounded()))g", systemImage: "f.circle.fill").foregroundStyle(.pink)
        }
        .font(.caption.monospacedDigit())
        .labelStyle(.titleAndIcon)
    }
}

// MARK: - Day stepper

struct DayStepper: View {
    @Binding var date: Date

    var body: some View {
        HStack {
            Button { date = date.adding(days: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(date.relativeDayLabel)
                    .font(.headline)
                if !date.isToday {
                    Button("Back to today") { date = .now }
                        .font(.caption)
                }
            }
            Spacer()
            Button { date = date.adding(days: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .disabled(date.isToday || date > .now)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)
    }
}

// MARK: - Number field helpers

struct DecimalField: View {
    var title: String
    @Binding var value: Double?
    var unit: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
            if !unit.isEmpty {
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}

struct IntField: View {
    var title: String
    @Binding var value: Int?
    var unit: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
            if !unit.isEmpty {
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}
