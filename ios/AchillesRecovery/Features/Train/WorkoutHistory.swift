import SwiftUI

/// Finished lifting sessions, newest first. Shown on the Session view when no workout is running.
struct WorkoutHistoryCard: View {
    @Environment(TrainStore.self) private var train
    var onOpen: (TrainStore.HistoryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent workouts").font(.system(size: 22, weight: .semibold))
                Spacer()
                Text("\(weekCount) in 7 days").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            if train.history.isEmpty {
                Text(train.historyLoaded ? "No finished workouts yet. They show up here when you tap Finish." : "Loading workouts")
                    .font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            ForEach(train.history) { entry in
                Button { onOpen(entry) } label: { row(entry) }
                Divider().overlay(Aurora.hairline)
            }
        }
        .auroraCard()
    }

    private var weekCount: Int {
        let from = Day.string(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        return train.history.filter { $0.session.date >= from }.count
    }

    private func row(_ entry: TrainStore.HistoryEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.session.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Aurora.text)
                Text(WorkoutFormat.subtitle(entry)).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
            Spacer()
            Chip(text: entry.setCount == 1 ? "1 set" : "\(entry.setCount) sets", tint: entry.setCount > 0 ? Aurora.recovery : Aurora.textMuted)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Aurora.textMuted)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// One finished workout: every exercise and the sets logged for it.
struct WorkoutDetailSheet: View {
    @Environment(TrainStore.self) private var train
    @Environment(\.dismiss) private var dismiss
    var entry: TrainStore.HistoryEntry
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Aurora.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        summary
                        if entry.exercises.isEmpty {
                            Text("No sets were checked off in this workout.")
                                .font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .auroraCard()
                        }
                        ForEach(entry.exercises) { logged in
                            exerciseCard(logged)
                        }
                        Button("Delete workout") { confirmDelete = true }
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(Aurora.alert)
                            .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .foregroundStyle(Aurora.text)
            .navigationTitle(entry.started?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) ?? entry.session.date)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete workout", role: .destructive) { Task { await train.deleteWorkout(entry.id); dismiss() } }
                Button("Keep", role: .cancel) {}
            } message: { Text("Its sets are deleted too. This cannot be undone.") }
        }
        .preferredColorScheme(.dark)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.session.title).font(.system(size: 22, weight: .semibold))
            HStack(spacing: 0) {
                stat("Time", entry.duration.map(WorkoutFormat.duration) ?? "–")
                stat("Exercises", "\(entry.exercises.count)")
                stat("Sets", "\(entry.setCount)")
            }
            if let start = entry.started {
                Text("Started \(start.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
        }
        .auroraCard()
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).caption().lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 22, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func exerciseCard(_ logged: TrainStore.LoggedExercise) -> some View {
        let exercise = train.exercises.first { $0.id == logged.exerciseId }
        let unit = exercise?.unit ?? "lb"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise?.name ?? "Exercise").font(.system(size: 17, weight: .semibold))
                Spacer()
                if let category = exercise?.category {
                    Chip(text: category.capitalized, tint: category == "rehab" ? Aurora.alert : Aurora.strain)
                }
            }
            ForEach(Array(logged.sets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("\(index + 1)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Aurora.textMuted).frame(width: 22)
                    Text(WorkoutFormat.set(set, unit: unit)).font(.system(size: 17)).monospacedDigit()
                    Spacer()
                }
                .frame(minHeight: 32)
                .accessibilityElement(children: .combine)
            }
        }
        .auroraCard()
    }
}

enum WorkoutFormat {
    static func subtitle(_ entry: TrainStore.HistoryEntry) -> String {
        let day = entry.started?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) ?? entry.session.date
        let count = entry.exercises.count == 1 ? "1 exercise" : "\(entry.exercises.count) exercises"
        if let d = entry.duration { return "\(day) · \(duration(d)) · \(count)" }
        return "\(day) · \(count)"
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
}
