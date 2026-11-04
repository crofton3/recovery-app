import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(TrendsStore.self) private var trends

    var body: some View {
        ZStack {
            Aurora.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    RecoveryChart()
                    SleepChart()
                    StrainChart()
                    OverlayChart()
                    BodyCard()
                    if let message = trends.errorMessage {
                        Text(message).font(.system(size: 13)).foregroundStyle(Aurora.alert)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable { await trends.load() }
        }
        .foregroundStyle(Aurora.text)
        .task { await trends.load() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WHOOP and body check-ins").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                Text("Trends").font(.system(size: 28, weight: .bold))
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach([7, 30, 90], id: \.self) { d in
                    Button { Task { await trends.setRange(d) } } label: {
                        Text("\(d)D").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(trends.rangeDays == d ? Aurora.strain : Aurora.text)
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .background(trends.rangeDays == d ? Aurora.strain.opacity(0.14) : Color.clear, in: Capsule())
                            .overlay(Capsule().stroke(trends.rangeDays == d ? Aurora.strain : Aurora.borderControl, lineWidth: 1))
                    }
                    .accessibilityLabel("Last \(d) days")
                    .accessibilityAddTraits(trends.rangeDays == d ? .isSelected : [])
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: Shared pieces

private func day(_ s: String) -> Date { Day.parse(s) ?? Date() }

private struct ChartCard<Content: View>: View {
    var title: String
    var subtitle: String
    var average: String?
    var tint: Color
    var isEmpty: Bool
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).caption()
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                }
                Spacer()
                if let average {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(average).font(.system(size: 28, weight: .semibold)).foregroundStyle(tint).monospacedDigit()
                        Text("average").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                    }
                }
            }
            if isEmpty {
                Text("No data for this range yet.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted).padding(.vertical, 24)
            } else {
                content().frame(height: 170)
                if let footer { Text(footer).font(.system(size: 13)).foregroundStyle(Aurora.textMuted) }
            }
        }
        .auroraCard()
    }
}

private extension View {
    func auroraAxes(yValues: [Double]? = nil) -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Aurora.textMuted)
                }
            }
            .chartYAxis {
                if let yValues {
                    AxisMarks(values: yValues) { _ in
                        AxisGridLine().foregroundStyle(Aurora.hairline)
                        AxisValueLabel().foregroundStyle(Aurora.textMuted)
                    }
                } else {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Aurora.hairline)
                        AxisValueLabel().foregroundStyle(Aurora.textMuted)
                    }
                }
            }
    }
}

// MARK: Charts

private struct RecoveryChart: View {
    @Environment(TrendsStore.self) private var trends

    var body: some View {
        let rows = trends.whoop.filter { $0.recoveryScore != nil }
        let avg = TrendsStore.average(rows.compactMap(\.recoveryScore))
        let footer = rows.contains(where: { ($0.recoveryScore ?? 0) < 34 }) ? "Coral bars are low days, under 34%." : nil
        ChartCard(title: "Recovery", subtitle: "Daily score", average: avg.map { "\(Int($0.rounded()))%" }, tint: Aurora.recovery, isEmpty: rows.isEmpty, footer: footer) {
            Chart(rows, id: \.date) { r in
                BarMark(x: .value("Day", day(r.date), unit: .day), y: .value("Recovery", r.recoveryScore ?? 0))
                    .foregroundStyle((r.recoveryScore ?? 0) < 34 ? Aurora.alert : Aurora.recovery)
                    .cornerRadius(3)
            }
            .chartYScale(domain: 0...100)
            .auroraAxes(yValues: [0, 50, 100])
            .accessibilityLabel("Recovery scores, average \(avg.map { "\(Int($0.rounded())) percent" } ?? "none")")
        }
    }
}

private struct SleepChart: View {
    @Environment(TrendsStore.self) private var trends

    var body: some View {
        let rows = trends.whoop.filter { $0.sleepHours != nil }
        let avg = TrendsStore.average(rows.compactMap(\.sleepHours))
        ChartCard(title: "Sleep", subtitle: "Hours asleep, goal 8 h", average: avg.map(hm), tint: Aurora.sleepInk, isEmpty: rows.isEmpty) {
            Chart {
                RuleMark(y: .value("Goal", 8)).foregroundStyle(Aurora.textMuted.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                ForEach(rows, id: \.date) { r in
                    AreaMark(x: .value("Day", day(r.date), unit: .day), yStart: .value("Base", 0), yEnd: .value("Hours", r.sleepHours ?? 0))
                        .foregroundStyle(Aurora.sleep.opacity(0.22))
                    LineMark(x: .value("Day", day(r.date), unit: .day), y: .value("Hours", r.sleepHours ?? 0))
                        .foregroundStyle(Aurora.sleep).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            }
            .chartYScale(domain: 0...10)
            .auroraAxes(yValues: [0, 4, 8])
            .accessibilityLabel("Hours of sleep, average \(avg.map(hm) ?? "none")")
        }
    }

    private func hm(_ h: Double) -> String {
        let total = Int((h * 60).rounded())
        return "\(total / 60)h \(String(format: "%02d", total % 60))m"
    }
}

private struct StrainChart: View {
    @Environment(TrendsStore.self) private var trends

    var body: some View {
        let rows = trends.whoop.filter { $0.strain != nil }
        let avg = TrendsStore.average(rows.compactMap(\.strain))
        ChartCard(title: "Strain", subtitle: "Day strain, scale 0 to 21", average: avg.map { String(format: "%.1f", $0) }, tint: Aurora.strain, isEmpty: rows.isEmpty) {
            Chart(rows, id: \.date) { r in
                BarMark(x: .value("Day", day(r.date), unit: .day), y: .value("Strain", r.strain ?? 0))
                    .foregroundStyle(Aurora.strain).cornerRadius(3)
            }
            .chartYScale(domain: 0...21)
            .auroraAxes(yValues: [0, 10, 21])
            .accessibilityLabel("Day strain, average \(avg.map { String(format: "%.1f", $0) } ?? "none") of 21")
        }
    }
}

private struct OverlayChart: View {
    @Environment(TrendsStore.self) private var trends

    var body: some View {
        let rows = trends.whoop.filter { $0.recoveryScore != nil || $0.strain != nil }
        ChartCard(title: "Recovery vs training", subtitle: "Does a hard session cost you the next morning?", average: nil, tint: Aurora.recovery, isEmpty: rows.isEmpty) {
            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(rows, id: \.date) { r in
                        if let s = r.strain {
                            BarMark(x: .value("Day", day(r.date), unit: .day), y: .value("Strain", s / 21 * 100))
                                .foregroundStyle(Aurora.strain.opacity(0.38)).cornerRadius(3)
                        }
                        if let rec = r.recoveryScore {
                            LineMark(x: .value("Day", day(r.date), unit: .day), y: .value("Recovery", rec))
                                .foregroundStyle(Aurora.recovery).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        }
                        if trends.trainingDays.contains(r.date) {
                            PointMark(x: .value("Day", day(r.date), unit: .day), y: .value("Trained", 4))
                                .foregroundStyle(Aurora.text).symbolSize(36)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .auroraAxes(yValues: [0, 50, 100])
                HStack(spacing: 14) {
                    key(Aurora.recovery, "Recovery")
                    key(Aurora.strain.opacity(0.6), "Strain")
                    key(Aurora.text, "Training day")
                }
            }
        }
    }

    private func key(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
        }
    }
}

private struct BodyCard: View {
    @Environment(TrendsStore.self) private var trends

    var body: some View {
        let weights = trends.checkins.filter { $0.bodyWeight != nil }
        let waists = trends.checkins.filter { $0.waist != nil }
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Body").caption()
                Text("Check-ins every two weeks").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
            if weights.isEmpty {
                Text("No check-ins yet.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted).padding(.vertical, 24)
            } else {
                let latest = weights.last?.bodyWeight ?? 0
                HStack(alignment: .firstTextBaseline) {
                    Text(TrainStore.format((latest * 10).rounded() / 10)).font(.system(size: 40, weight: .bold)).monospacedDigit()
                    Text("lb").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                    Spacer()
                    if let first = weights.first?.bodyWeight, weights.count > 1 {
                        let d = latest - first
                        Text("\(d <= 0 ? "down" : "up") \(String(format: "%.1f", abs(d))) lb since \(day(weights.first!.date).formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                    }
                }
                Chart(weights) { c in
                    LineMark(x: .value("Day", day(c.date), unit: .day), y: .value("Weight", c.bodyWeight ?? 0))
                        .foregroundStyle(Aurora.text).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("Day", day(c.date), unit: .day), y: .value("Weight", c.bodyWeight ?? 0))
                        .foregroundStyle(Aurora.text).symbolSize(40)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .auroraAxes()
                .frame(height: 170)
                .accessibilityLabel("Body weight at each check-in")
            }
            if let w = waists.last?.waist {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Waist").font(.system(size: 17, weight: .semibold))
                        if let first = waists.first?.waist, waists.count > 1 {
                            Text("\(TrainStore.format((first * 10).rounded() / 10)) in at first check-in").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                        }
                    }
                    Spacer()
                    Text(TrainStore.format((w * 10).rounded() / 10)).font(.system(size: 28, weight: .semibold)).monospacedDigit()
                    Text("in").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                }
                .padding(.top, 8)
                .overlay(alignment: .top) { Divider().overlay(Aurora.hairline) }
            }
        }
        .auroraCard()
    }
}
