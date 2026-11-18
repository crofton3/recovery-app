import SwiftUI

/// A day picked on the calendar, as yyyy-MM-dd.
struct CalendarDay: Identifiable, Hashable {
    var id: String
}

/// A month of training. Days with a lifting session or a run get a dot, and tapping one opens that day.
struct WorkoutCalendarCard: View {
    @Environment(TrainStore.self) private var train
    @Environment(RunStore.self) private var runs
    @State private var month = Self.firstOfMonth(Date())
    var onOpen: (CalendarDay) -> Void

    var body: some View {
        let liftDays = Set(train.history.map(\.session.date))
        let runDays = Set(runs.all.map(\.date))
        let prefix = String(Day.string(month).prefix(7))
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("History").caption()
                    Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size: 22, weight: .semibold))
                }
                Spacer()
                RoundStepButton(symbol: "chevron.left", label: "Previous month") { shift(-1) }
                RoundStepButton(symbol: "chevron.right", label: "Next month") { shift(1) }
                    .disabled(isCurrentMonth).opacity(isCurrentMonth ? 0.35 : 1)
            }
            HStack(spacing: 8) {
                let lifts = train.history.filter { $0.session.date.hasPrefix(prefix) }.count
                let monthRuns = runs.all.filter { $0.date.hasPrefix(prefix) }.count
                Chip(text: lifts == 1 ? "1 workout" : "\(lifts) workouts", tint: Aurora.strain)
                Chip(text: monthRuns == 1 ? "1 run" : "\(monthRuns) runs", tint: Aurora.recovery)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter).caption().frame(maxWidth: .infinity)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        cell(date, lifted: liftDays.contains(Day.string(date)), ran: runDays.contains(Day.string(date)))
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
            HStack(spacing: 16) {
                legend("Lifting", Aurora.strain)
                legend("Run", Aurora.recovery)
            }
        }
        .auroraCard()
        .task(id: month) {
            let start = Day.string(month)
            await train.loadHistory(since: start)
            await runs.loadRuns(since: start)
        }
    }

    private func cell(_ date: Date, lifted: Bool, ran: Bool) -> some View {
        let active = lifted || ran
        let isToday = Calendar.current.isDateInToday(date)
        let number = Calendar.current.component(.day, from: date)
        return Button { onOpen(CalendarDay(id: Day.string(date))) } label: {
            VStack(spacing: 4) {
                Text("\(number)").font(.system(size: 15, weight: isToday || active ? .bold : .regular)).monospacedDigit()
                    .foregroundStyle(active ? Aurora.text : Aurora.textMuted)
                HStack(spacing: 3) {
                    if lifted { Circle().fill(Aurora.strain).frame(width: 6, height: 6) }
                    if ran { Circle().fill(Aurora.recovery).frame(width: 6, height: 6) }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(active ? Aurora.cardRaised : Color.clear, in: RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous))
            .overlay {
                if isToday { RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous).stroke(Aurora.strain, lineWidth: 1.5) }
            }
        }
        .disabled(!active)
        .accessibilityLabel(accessibility(date, lifted: lifted, ran: ran))
    }

    private func legend(_ label: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(label).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
        }
    }

    private func accessibility(_ date: Date, lifted: Bool, ran: Bool) -> String {
        let day = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        switch (lifted, ran) {
        case (true, true): return "\(day), workout and run"
        case (true, false): return "\(day), workout"
        case (false, true): return "\(day), run"
        default: return "\(day), nothing logged"
        }
    }

    private var isCurrentMonth: Bool { month >= Self.firstOfMonth(Date()) }

    private func shift(_ months: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: month) else { return }
        month = min(next, Self.firstOfMonth(Date()))
    }

    /// Single letters for each weekday, starting on the calendar's first weekday.
    private var weekdayLetters: [String] {
        let cal = Calendar.current
        let letters = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(letters[first...] + letters[..<first])
    }

    /// Blank cells before the 1st, then every day of the month.
    private var cells: [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    static func firstOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }
}

/// Everything logged on one day: lifting sessions with progress against last time, and runs.
struct WorkoutDaySheet: View {
    @Environment(TrainStore.self) private var train
    @Environment(RunStore.self) private var runs
    @Environment(\.dismiss) private var dismiss
    var day: String
    @State private var runDetail: RunRecord?

    var body: some View {
        let lifts = train.history.filter { $0.session.date == day }.sorted { ($0.session.startedAt ?? "") < ($1.session.startedAt ?? "") }
        let dayRuns = runs.all.filter { $0.date == day }.sorted { $0.startedAt < $1.startedAt }
        NavigationStack {
            ZStack {
                Aurora.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if lifts.isEmpty && dayRuns.isEmpty {
                            Text("Nothing logged this day.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading).auroraCard()
                        }
                        ForEach(lifts) { WorkoutDayCard(entry: $0) }
                        ForEach(dayRuns) { run in
                            Button { runDetail = run } label: { runRow(run) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .foregroundStyle(Aurora.text)
            .navigationTitle(Day.parse(day)?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? day)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $runDetail) { RunDetailSheet(run: $0) }
        }
        .preferredColorScheme(.dark)
    }

    private func runRow(_ run: RunRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Run").caption()
                Text("\(RunFormat.miles(run.distanceM)) mi").font(.system(size: 22, weight: .semibold)).monospacedDigit().foregroundStyle(Aurora.recovery)
                Text("\(RunFormat.duration(Double(run.durationS))) · \(RunFormat.pace(meters: run.runM, seconds: Double(run.runS))) /mi run")
                    .font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
            Spacer()
            if let pain = run.pain { Chip(text: "Pain \(pain)", tint: pain >= 4 ? Aurora.alert : Aurora.textMuted) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Aurora.textMuted)
        }
        .foregroundStyle(Aurora.text)
        .auroraCard()
        .contentShape(Rectangle())
    }
}

/// One finished lifting session, each exercise compared with the previous time it was done.
private struct WorkoutDayCard: View {
    @Environment(TrainStore.self) private var train
    var entry: TrainStore.HistoryEntry
    @State private var progress: [String: TrainStore.Progress] = [:]
    @State private var confirmDelete = false

    var body: some View {
        let prs = progress.values.filter(\.isPR).count
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.session.title).font(.system(size: 22, weight: .semibold))
                Text(WorkoutFormat.subtitle(entry)).font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                HStack(spacing: 8) {
                    Chip(text: entry.setCount == 1 ? "1 set" : "\(entry.setCount) sets", tint: Aurora.strain)
                    if prs > 0 { Chip(text: prs == 1 ? "1 PR" : "\(prs) PRs", tint: Aurora.nutrition) }
                }
            }
            if entry.exercises.isEmpty {
                Text("No sets were checked off in this workout.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            ForEach(entry.exercises) { logged in
                Divider().overlay(Aurora.hairline)
                exercise(logged)
            }
            Button("Delete workout") { confirmDelete = true }
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Aurora.alert)
                .frame(minHeight: 44)
        }
        .auroraCard()
        .task(id: entry.id) { progress = await train.progress(for: entry) }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) { Task { await train.deleteWorkout(entry.id) } }
            Button("Keep", role: .cancel) {}
        } message: { Text("Its sets are deleted too. This cannot be undone.") }
    }

    private func exercise(_ logged: TrainStore.LoggedExercise) -> some View {
        let ex = train.exercises.first { $0.id == logged.exerciseId }
        let unit = ex?.unit ?? "lb"
        let p = progress[logged.exerciseId]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ex?.name ?? "Exercise").font(.system(size: 17, weight: .semibold))
                Spacer()
                if p?.isPR == true { Chip(text: "PR", tint: Aurora.nutrition) }
            }
            if let p, let top = p.top {
                if let previous = p.previous {
                    let change = WorkoutFormat.change(top, vs: previous, unit: unit)
                    HStack(spacing: 8) {
                        Text("Last time \(WorkoutFormat.set(previous, unit: unit))").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                        Spacer()
                        Text(change.text).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(change.up == true ? Aurora.recovery : change.up == false ? Aurora.nutrition : Aurora.textMuted)
                    }
                } else {
                    Text("First time logging this").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                }
            }
            ForEach(Array(logged.sets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("\(index + 1)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Aurora.textMuted).frame(width: 22)
                    Text(WorkoutFormat.set(set, unit: unit)).font(.system(size: 17)).monospacedDigit()
                    Spacer()
                    if set.id == p?.top?.id && p?.previous != nil {
                        Text("Top set").font(.system(size: 12, weight: .semibold)).foregroundStyle(Aurora.strain)
                    }
                }
                .frame(minHeight: 32)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

enum WorkoutFormat {
    static func subtitle(_ entry: TrainStore.HistoryEntry) -> String {
        let count = entry.exercises.count == 1 ? "1 exercise" : "\(entry.exercises.count) exercises"
        guard let start = entry.started else { return count }
        let time = start.formatted(date: .omitted, time: .shortened)
        if let d = entry.duration { return "\(time) · \(duration(d)) · \(count)" }
        return "\(time) · \(count)"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// "135 lb × 10", or "× 12" when no weight was entered.
    static func set(_ set: WorkoutSet, unit: String) -> String {
        let weight = set.weight.flatMap { $0 > 0 ? TrainStore.format($0) : nil }
        switch (weight, set.reps) {
        case let (w?, r?): return "\(w) \(unit) × \(r)"
        case let (w?, nil): return "\(w) \(unit)"
        case let (nil, r?): return "× \(r)"
        default: return "–"
        }
    }

    /// The top set against last time's: weight first, then reps. `up` is nil when nothing changed.
    static func change(_ top: WorkoutSet, vs previous: WorkoutSet, unit: String) -> (text: String, up: Bool?) {
        let tw = top.weight ?? 0, pw = previous.weight ?? 0
        if tw != pw {
            let d = tw - pw
            return ("\(d > 0 ? "+" : "−")\(TrainStore.format(abs(d))) \(unit) vs last time", d > 0)
        }
        let tr = top.reps ?? 0, pr = previous.reps ?? 0
        if tr != pr {
            let d = tr - pr
            return ("\(d > 0 ? "+" : "−")\(abs(d)) \(abs(d) == 1 ? "rep" : "reps") vs last time", d > 0)
        }
        return ("Same as last time", nil)
    }
}
