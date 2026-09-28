import SwiftUI
import Charts

/// Renders the shareable weekly summary image and the doctor-friendly PDF to temporary files.
@MainActor
enum ReportRenderer {
    static func weeklySummaryImage(review: WeeklyReview, streak: Int, units: Units) -> URL? {
        let renderer = ImageRenderer(content: WeeklySummaryImage(review: review, streak: streak, units: units))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("weekly-summary.png")
        return (try? data.write(to: url)).map { url }
    }

    static func doctorReportPDF(report: HealthReport, profile: UserProfile) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("health-report.pdf")
        let renderer = ImageRenderer(content: DoctorReportPage(report: report, profile: profile))
        var box = CGRect(origin: .zero, size: DoctorReportPage.pageSize)
        var ok = false
        renderer.render { _, draw in
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}

/// A square card for sharing the last seven days.
struct WeeklySummaryImage: View {
    var review: WeeklyReview
    var streak: Int
    var units: Units

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("My last 7 days")
                .font(.title.bold())
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    tile("Days logged", "\(review.daysLogged)/7", "calendar")
                    tile("Average intake", review.averageIntake.map { "\(Energy.string($0))" } ?? "—", "fork.knife")
                }
                GridRow {
                    tile("Weight change", review.weightChangeKg.map { units.weightString(kg: $0, signed: true) } ?? "—", "scalemass")
                    tile("Logging streak", "\(streak) days", "flame")
                }
            }
            Text(review.headline)
                .font(.headline)
            if review.completedFasts > 0 {
                Label("\(review.completedFasts) fasts completed", systemImage: "timer")
                    .font(.subheadline)
            }
            Spacer(minLength: 0)
            Text("Tracked with Stride")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 360, height: 360, alignment: .topLeading)
        .background(LinearGradient(colors: [Color.indigo.opacity(0.18), Color.teal.opacity(0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func tile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// One US Letter page: who, the period, weight and vitals with averages, and recent readings.
struct DoctorReportPage: View {
    static let pageSize = CGSize(width: 612, height: 792)
    static let maxRows = 14

    var report: HealthReport
    var profile: UserProfile

    private var units: Units { profile.units }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            summary
            if report.weights.count >= 2 { weightChart }
            readingsTable
            Spacer(minLength: 0)
            Text("Self-recorded at home with the Stride app. Not a medical record; readings are as entered by the patient.")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .padding(36)
        .frame(width: Self.pageSize.width, height: Self.pageSize.height, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Weight and vitals summary").font(.system(size: 18, weight: .bold))
            Text([profile.name.isEmpty ? nil : profile.name,
                  "\(profile.age) y", profile.sex.rawValue.capitalized,
                  "height \(units.heightString(cm: profile.heightCm))"].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 11))
            Text("\(report.start.formatted(date: .abbreviated, time: .omitted)) – \(report.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted)) · generated \(Date.now.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 24) {
            fact("Weight", report.weights.last.map { units.weightString(kg: $0.kg) } ?? "—",
                 report.weightChangeKg.map { "\(units.weightString(kg: $0, signed: true)) over period" })
            fact("Avg blood pressure", report.averageBloodPressure.map { "\($0.systolic)/\($0.diastolic) mmHg" } ?? "—",
                 report.averageBloodPressure.map {
                     NutritionCalculator.bloodPressureCategory(systolic: $0.systolic, diastolic: $0.diastolic).rawValue
                 })
            fact("Avg resting HR", report.averageHeartRate.map { "\($0) bpm" } ?? "—", nil)
            fact("Avg glucose", report.averageGlucose.map { "\(Int($0.rounded())) mg/dL" } ?? "—", nil)
        }
    }

    private func fact(_ title: String, _ value: String, _ note: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .semibold))
            if let note { Text(note).font(.system(size: 9)).foregroundStyle(.secondary) }
        }
    }

    private var weightChart: some View {
        Chart(report.weights, id: \.date) { point in
            LineMark(x: .value("Date", point.date), y: .value(units.weightUnit, units.weightValue(kg: point.kg)))
                .foregroundStyle(.indigo)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel(units.weightUnit)
        .frame(height: 150)
    }

    private var readingsTable: some View {
        let rows = Array(report.readings.suffix(Self.maxRows).reversed())
        return VStack(alignment: .leading, spacing: 4) {
            Text(rows.isEmpty ? "No vitals recorded in this period." : "Most recent readings")
                .font(.system(size: 11, weight: .semibold))
            if !rows.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 3) {
                    GridRow {
                        ForEach(["Date", "BP (mmHg)", "HR (bpm)", "Glucose", "Waist"], id: \.self) {
                            Text($0).font(.system(size: 9, weight: .semibold))
                        }
                    }
                    ForEach(rows, id: \.date) { r in
                        GridRow {
                            Text(r.date.formatted(date: .abbreviated, time: .shortened))
                            Text(r.systolic.flatMap { s in r.diastolic.map { "\(s)/\($0)" } } ?? "—")
                            Text(r.heartRate.map(String.init) ?? "—")
                            Text(r.glucose.map { "\(Int($0.rounded()))" } ?? "—")
                            Text(r.waistCm.map { units.lengthString(cm: $0) } ?? "—")
                        }
                        .font(.system(size: 9).monospacedDigit())
                    }
                }
            }
        }
    }
}
