import SwiftUI
import Charts

struct AchillesView: View {
    @Environment(AchillesStore.self) private var store
    @State private var sheet: AchillesSheet?

    enum AchillesSheet: String, Identifiable {
        case measurements, pt, milestone, surgery
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Aurora.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    PhaseCard()
                    MilestonesCard(onAdd: { sheet = .milestone })
                    TrendCard()
                    MotionCard(onLog: { sheet = .measurements })
                    PTCard(onAdd: { sheet = .pt })
                    if let message = store.errorMessage {
                        Text(message).font(.system(size: 13)).foregroundStyle(Aurora.alert)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .opacity(store.loaded ? 1 : 0)
                .animation(Aurora.base, value: store.loaded)
            }
            .refreshable { await store.load() }
        }
        .foregroundStyle(Aurora.text)
        .task { await store.load() }
        .sheet(item: $sheet) { s in
            switch s {
            case .measurements: MeasurementsSheet()
            case .pt: PTSheet()
            case .milestone: MilestoneSheet()
            case .surgery: SurgeryDateSheet()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.injured == "L" ? "Left" : "Right") Achilles" + (store.weekPostOp.map { " · Week \($0) post-op" } ?? ""))
                    .font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                Text("Achilles").font(.system(size: 28, weight: .bold))
            }
            Spacer()
            Button { sheet = .surgery } label: {
                Image(systemName: "calendar").font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .background(Aurora.card, in: Circle())
                    .overlay(Circle().stroke(Aurora.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Set surgery date")
        }
        .padding(.top, 8)
    }
}

// MARK: Phase

private struct PhaseCard: View {
    @Environment(AchillesStore.self) private var store

    var body: some View {
        let phases = RehabPhases.all
        let current = phases[store.phase - 1]
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rehab phase").caption()
                Spacer()
                Chip(text: "Phase \(store.phase) of 5", tint: Aurora.strain)
            }
            Text(current.name).font(.system(size: 22, weight: .semibold))
            Text(weeksText(current)).font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            HStack(spacing: 6) {
                ForEach(Array(phases.enumerated()), id: \.offset) { i, p in
                    Button { Task { await store.setPhase(i + 1) } } label: {
                        VStack(spacing: 6) {
                            Capsule()
                                .fill(i + 1 < store.phase ? Aurora.recovery : (i + 1 == store.phase ? Aurora.strain : Aurora.cardRaised))
                                .frame(height: 8)
                                .shadow(color: i + 1 == store.phase ? Aurora.strain.opacity(0.5) : .clear, radius: 5)
                            Text("\(i + 1) \(p.name)").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(i + 1 == store.phase ? Aurora.strain : Aurora.textMuted)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Phase \(i + 1), \(p.name)")
                    .accessibilityAddTraits(i + 1 == store.phase ? .isSelected : [])
                }
            }
            Text("Tap a phase to set where you are.").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
        }
        .auroraCard()
    }

    private func weeksText(_ p: RehabPhases.Phase) -> String {
        let range = p.endWeek.map { "Weeks \(p.startWeek) to \($0)" } ?? "Week \(p.startWeek) onward"
        if let w = store.weekPostOp { return "\(range) · you are in week \(w)" }
        return range + " · set your surgery date to see your week"
    }
}

// MARK: Milestones

private struct MilestonesCard: View {
    @Environment(AchillesStore.self) private var store
    var onAdd: () -> Void

    var body: some View {
        let done = store.milestones.filter { $0.doneAt != nil }.count
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Milestones").font(.system(size: 22, weight: .semibold))
                Spacer()
                Text("\(done) of \(store.milestones.count) done").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            if store.milestones.isEmpty {
                Text("No milestones yet. Add the goals your PT gives you.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            ForEach(store.milestones) { m in
                Button { Task { await store.toggle(m) } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(m.doneAt == nil ? Color.clear : Aurora.onAccent)
                            .frame(width: 28, height: 28)
                            .background(m.doneAt == nil ? Color.clear : Aurora.recovery, in: Circle())
                            .overlay(Circle().stroke(m.doneAt == nil ? Aurora.borderControl : Aurora.recovery, lineWidth: 1.5))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title).font(.system(size: 17)).foregroundStyle(Aurora.text).multilineTextAlignment(.leading)
                            Text(m.doneAt.map { "Done \($0)" } ?? (m.targetWeek.map { "Target week \($0)" } ?? "No target"))
                                .font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                        }
                        Spacer()
                        Text("Phase \(m.phase)").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                    }
                    .frame(minHeight: 52)
                }
                .accessibilityAddTraits(m.doneAt == nil ? [] : .isSelected)
                Divider().overlay(Aurora.hairline)
            }
            Button("+ Add milestone", action: onAdd).buttonStyle(SecondaryButtonStyle())
        }
        .auroraCard()
    }
}

// MARK: Pain and swelling

private struct TrendCard: View {
    @Environment(AchillesStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pain and swelling").font(.system(size: 22, weight: .semibold))
                Spacer()
                Text("14 days").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            if store.daily.isEmpty {
                Text("Log your daily check on Today and the trend appears here.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            } else {
                Chart {
                    ForEach(store.daily, id: \.date) { d in
                        if let day = Day.parse(d.date) {
                            LineMark(x: .value("Day", day, unit: .day), y: .value("Score", d.pain), series: .value("Metric", "Pain"))
                                .foregroundStyle(by: .value("Metric", "Pain"))
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            LineMark(x: .value("Day", day, unit: .day), y: .value("Score", d.swelling), series: .value("Metric", "Swelling"))
                                .foregroundStyle(by: .value("Metric", "Swelling"))
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            if d.date == store.daily.last?.date {
                                PointMark(x: .value("Day", day, unit: .day), y: .value("Score", d.pain)).foregroundStyle(Aurora.alert)
                                PointMark(x: .value("Day", day, unit: .day), y: .value("Score", d.swelling)).foregroundStyle(Aurora.water)
                            }
                        }
                    }
                }
                .chartForegroundStyleScale(["Pain": Aurora.alert, "Swelling": Aurora.water])
                .chartYScale(domain: 0...10)
                .chartYAxis {
                    AxisMarks(values: [0, 5, 10]) { _ in
                        AxisGridLine().foregroundStyle(Aurora.hairline)
                        AxisValueLabel().foregroundStyle(Aurora.textMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Aurora.textMuted)
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 190)
            }
        }
        .auroraCard()
    }
}

// MARK: Motion and strength

private struct MotionCard: View {
    @Environment(AchillesStore.self) private var store
    var onLog: () -> Void

    var body: some View {
        let injured = store.injured, healthy = store.healthy
        VStack(alignment: .leading, spacing: 12) {
            Text("Motion and strength").font(.system(size: 22, weight: .semibold))
            HStack(spacing: 16) {
                legendDot(Aurora.recovery, "\(injured) \(injured == "L" ? "left" : "right") (injured)")
                legendDot(Aurora.strain, "\(healthy) \(healthy == "L" ? "left" : "right")")
            }
            ForEach(AchillesStore.metrics) { metric in
                let a = store.latest(metric.key, side: injured)?.value
                let b = store.latest(metric.key, side: healthy)?.value
                let top = max(a ?? 0, b ?? 0, 0.0001)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(metric.title).font(.system(size: 17, weight: .semibold))
                        Spacer()
                        symmetryChip(store.symmetry(metric.key))
                    }
                    bar(side: injured, value: a, top: top, unit: metric.unit, color: Aurora.recovery)
                    bar(side: healthy, value: b, top: top, unit: metric.unit, color: Aurora.strain)
                }
                .padding(.top, 8)
                Divider().overlay(Aurora.hairline)
            }
            Button("+ Log measurements", action: onLog).buttonStyle(SecondaryButtonStyle())
        }
        .auroraCard()
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
        }
    }

    @ViewBuilder private func symmetryChip(_ pct: Int?) -> some View {
        if let pct {
            let (tint, word) = pct >= 90 ? (Aurora.recovery, "") : (pct >= 60 ? (Aurora.nutrition, "") : (Aurora.alert, ": low"))
            Chip(text: "\(pct)% of other side\(word)", tint: tint)
        } else {
            Chip(text: "No data", tint: Aurora.textMuted)
        }
    }

    private func bar(side: String, value: Double?, top: Double, unit: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(side).caption().foregroundStyle(color).frame(width: 20)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Aurora.cardRaised)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat((value ?? 0) / top))
                }
            }
            .frame(height: 10)
            Text(value.map { "\(TrainStore.format($0)) \(unit)" } ?? "--")
                .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                .frame(minWidth: 76, alignment: .trailing)
        }
    }
}

// MARK: PT log

private struct PTCard: View {
    @Environment(AchillesStore.self) private var store
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PT sessions").font(.system(size: 22, weight: .semibold))
            if store.pt.isEmpty {
                Text("No sessions logged yet.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            ForEach(store.pt) { s in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(label(s.date)).font(.system(size: 17, weight: .semibold))
                        Spacer()
                        if let m = s.durationMin { Text("\(m) min").font(.system(size: 13)).foregroundStyle(Aurora.textMuted) }
                    }
                    if let n = s.therapistNotes, !n.isEmpty {
                        Text(n).font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                    }
                    if let ex = s.exercises, !ex.isEmpty {
                        HStack { ForEach(ex, id: \.self) { Chip(text: $0, tint: Aurora.strain) } }
                    }
                }
                .padding(.vertical, 8)
                Divider().overlay(Aurora.hairline)
            }
            Button("+ Log PT session", action: onAdd).buttonStyle(SecondaryButtonStyle())
        }
        .auroraCard()
    }

    private func label(_ date: String) -> String {
        Day.parse(date)?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) ?? date
    }
}
