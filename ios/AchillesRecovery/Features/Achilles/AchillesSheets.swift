import SwiftUI

struct MeasurementsSheet: View {
    @Environment(AchillesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]  // "metric|side" -> text

    var body: some View {
        NavigationStack {
            Form {
                Text("Fill in only what you measured today.").foregroundStyle(Aurora.textMuted)
                ForEach(AchillesStore.metrics) { m in
                    Section("\(m.title) (\(m.unit))") {
                        field(m, side: store.injured, label: "\(store.injured == "L" ? "Left" : "Right") (injured)")
                        field(m, side: store.healthy, label: store.healthy == "L" ? "Left" : "Right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Aurora.bg)
            .navigationTitle("Log measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(entries.isEmpty) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func key(_ m: RomMetric, _ side: String) -> String { "\(m.key)|\(side)" }

    private func field(_ m: RomMetric, side: String, label: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("--", text: Binding(get: { values[key(m, side)] ?? "" }, set: { values[key(m, side)] = $0 }))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                .accessibilityLabel("\(m.title), \(label)")
        }
    }

    private var entries: [(metric: String, side: String, value: Double)] {
        values.compactMap { k, v in
            let parts = k.split(separator: "|").map(String.init)
            guard parts.count == 2, let d = Double(v) else { return nil }
            return (parts[0], parts[1], d)
        }
    }

    private func save() {
        let e = entries
        Task { await store.logMeasurements(e); dismiss() }
    }
}

struct PTSheet: View {
    @Environment(AchillesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var minutes = 45
    @State private var notes = ""
    @State private var exercises = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                Stepper("Length: \(minutes) min", value: $minutes, in: 5...180, step: 5)
                Section("What you worked on") {
                    TextField("Balance, gait, calf raises", text: $exercises)
                }
                Section("Therapist notes") {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Aurora.bg)
            .navigationTitle("Log PT session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let tags = exercises.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await store.addPT(date: date, minutes: minutes, exercises: tags, notes: trimmed.isEmpty ? nil : trimmed)
            dismiss()
        }
    }
}

struct MilestoneSheet: View {
    @Environment(AchillesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var phase = 3
    @State private var week = 12

    var body: some View {
        NavigationStack {
            Form {
                TextField("Milestone, for example Single-leg heel raise x 10", text: $title)
                Picker("Phase", selection: $phase) {
                    ForEach(1...5, id: \.self) { Text("\($0) \(RehabPhases.all[$0 - 1].name)").tag($0) }
                }
                Stepper("Target: week \(week)", value: $week, in: 1...52)
            }
            .scrollContentBackground(.hidden)
            .background(Aurora.bg)
            .navigationTitle("Add milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await store.addMilestone(title: title.trimmingCharacters(in: .whitespaces), phase: phase, week: week); dismiss() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { phase = store.phase }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

struct SurgeryDateSheet: View {
    @Environment(AchillesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Surgery date", selection: $date, in: ...Date(), displayedComponents: .date).datePickerStyle(.graphical)
                Text("Used to work out your week post-op on Today and here.").font(.footnote).foregroundStyle(Aurora.textMuted)
            }
            .scrollContentBackground(.hidden)
            .background(Aurora.bg)
            .navigationTitle("Surgery date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await store.setSurgeryDate(date); dismiss() } } }
            }
            .onAppear { if let s = store.settings.surgeryDate, let d = Day.parse(s) { date = d } }
        }
        .preferredColorScheme(.dark)
    }
}
