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

    /// Caps grouped forms at a readable width so rows don't stretch across a landscape iPad.
    /// No effect on iPhone, where the screen is narrower than the cap.
    func readableWidth(_ maxWidth: CGFloat = 700) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
    }
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
        // Decorative: the view that shows a ring describes it in words.
        .accessibilityHidden(true)
    }
}

/// Side by side normally, stacked at accessibility text sizes so nothing gets squeezed.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: spacing))
            : AnyLayout(HStackLayout(spacing: spacing))
        layout { content }
    }
}

/// Stat tiles two to a row, or one to a row at accessibility text sizes.
struct StatGrid<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let count = typeSize.isAccessibilitySize ? 1 : 2
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: count), spacing: 12) { content }
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
                    .foregroundStyle(Color.secondary)
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
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(target > 0
            ? "\(Int(consumed.rounded())) of \(Int(target.rounded())) grams, \(Int((consumed / target * 100).rounded())) percent"
            : "\(Int(consumed.rounded())) grams")
    }
}

// MARK: - Stat tile

struct StatTile: View {
    var title: String
    var value: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var tint: Color = .accentColor

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the tile has the full width, so let text wrap rather than truncate.
        let lines: Int? = typeSize.isAccessibilitySize ? nil : 1
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(lines)
                .minimumScaleFactor(0.7)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(lines)
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
            .accessibilityLabel("Previous day")
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
            .accessibilityLabel("Next day")
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
                .accessibilityHidden(true)
            Spacer()
            TextField("—", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .accessibilityLabel(title)
                .accessibilityHint(unit.isEmpty ? "" : "In \(unit)")
            if !unit.isEmpty {
                Text(unit).foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
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
                .accessibilityHidden(true)
            Spacer()
            TextField("—", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .accessibilityLabel(title)
                .accessibilityHint(unit.isEmpty ? "" : "In \(unit)")
            if !unit.isEmpty {
                Text(unit).foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// "Your trend needs a little more data": progress towards a trend insight, with an optional
/// button to log a weigh-in when that's what's missing.
struct TrendProgressView: View {
    var title: LocalizedStringKey
    var progress: TrendProgress
    var logWeighIn: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            ProgressView(value: progress.fraction)
                .tint(.indigo)
                .accessibilityLabel(Text(title))
                .accessibilityValue(progress.summary)
            Text(progress.summary)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
            if progress.needsWeighIns, let logWeighIn {
                Button("Log a weigh-in", action: logWeighIn)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// The background for controls floating over content (the undo toast, camera hints): Liquid
    /// Glass on iOS 26, a material with a soft shadow before. Glass adapts to Reduce Transparency
    /// and Increase Contrast by itself.
    @ViewBuilder
    func floatingBackground<S: Shape>(_ material: Material = .thickMaterial, in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(material, in: shape)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        }
        #else
        background(material, in: shape)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        #endif
    }
}
