import SwiftUI

private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

struct ScheduleEditorView: View {
    @Environment(TrainStore.self) private var train
    @State private var target: EditTarget?

    struct EditTarget: Identifiable {
        let id = UUID()
        var weekday: Int
        var item: ScheduleItem?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly schedule").font(.system(size: 22, weight: .semibold))
                Text("Reminders arrive at the time you set.").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
            ForEach([1, 2, 3, 4, 5, 6, 0], id: \.self) { weekday in
                dayCard(weekday)
            }
        }
        .sheet(item: $target) { t in
            ScheduleItemSheet(weekday: t.weekday, item: t.item)
        }
    }

    private func summary(_ item: ScheduleItem) -> String {
        let parts = item.entries.map { e -> String in
            let name = train.exercises.first(where: { $0.id == e.exerciseId })?.name ?? "Exercise"
            return e.plan.map { "\(name) \($0.sets)×\($0.reps)" } ?? name
        }
        return parts.isEmpty ? "No exercises yet" : parts.joined(separator: " · ")
    }

    private func dayCard(_ weekday: Int) -> some View {
        let items = train.weekSchedule.filter { $0.weekday == weekday }
        let isToday = weekday == Day.weekday
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayNames[weekday]).caption().foregroundStyle(isToday ? Aurora.recovery : Aurora.textMuted)
                Spacer()
                Button { target = EditTarget(weekday: weekday, item: nil) } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .bold)).foregroundStyle(Aurora.strain)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Add session on \(dayNames[weekday])")
            }
            .frame(minHeight: 28)
            if items.isEmpty {
                Text("Rest").font(.system(size: 17)).foregroundStyle(Aurora.textMuted)
            }
            ForEach(items) { item in
                Button { target = EditTarget(weekday: weekday, item: item) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Aurora.text)
                            Text(summary(item)).font(.system(size: 13)).foregroundStyle(Aurora.textMuted).lineLimit(2).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Text(item.reminderTime.map { timeLabel($0) } ?? "No reminder")
                            .font(.system(size: 15)).foregroundStyle(item.reminderTime == nil ? Aurora.textMuted : Aurora.text)
                            .padding(.horizontal, 10).frame(minHeight: 36)
                            .background(Aurora.cardRaised, in: RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous))
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .auroraCard()
        .overlay(RoundedRectangle(cornerRadius: Aurora.radiusLg, style: .continuous).stroke(isToday ? Aurora.recovery.opacity(0.5) : .clear, lineWidth: 1))
    }
}

func timeLabel(_ hhmmss: String) -> String {
    let parts = hhmmss.split(separator: ":")
    guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return hhmmss }
    var comps = DateComponents(); comps.hour = h; comps.minute = m
    guard let d = Calendar.current.date(from: comps) else { return hhmmss }
    return d.formatted(date: .omitted, time: .shortened)
}

struct ScheduleItemSheet: View {
    @Environment(TrainStore.self) private var train
    @Environment(\.dismiss) private var dismiss

    var weekday: Int
    var item: ScheduleItem?

    @State private var title = ""
    @State private var remind = true
    @State private var time = Calendar.current.date(from: DateComponents(hour: 18, minute: 30)) ?? Date()
    @State private var plan: [PlanEntry] = []
    @State private var choosing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Title, for example Lower body", text: $title)
                    Toggle("Remind me", isOn: $remind)
                    if remind { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                }
                Section {
                    ForEach($plan, id: \.exerciseId) { $entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(train.exercises.first(where: { $0.id == entry.exerciseId })?.name ?? "Unknown exercise")
                                .font(.headline)
                            Stepper("Sets: \(entry.sets)", value: $entry.sets, in: 1...10)
                            Stepper("Reps: \(entry.reps)", value: $entry.reps, in: 1...60)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { plan.remove(atOffsets: $0) }
                    .onMove { plan.move(fromOffsets: $0, toOffset: $1) }
                    Button("Choose exercises") { choosing = true }
                } header: {
                    Text("Exercises, in order")
                } footer: {
                    Text("Swipe left to remove, or tap Edit to reorder. Sets and reps are your targets. Weights come from your last session.")
                }
                if let item {
                    Section {
                        Button("Delete session", role: .destructive) {
                            Task { await train.deleteScheduleItem(item.id); dismiss() }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Aurora.bg)
            .navigationTitle(dayNames[weekday])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .bottomBar) { EditButton() }
            }
            .sheet(isPresented: $choosing) {
                NavigationStack {
                    ExerciseList(selected: Set(plan.map(\.exerciseId))) { ex in
                        if let i = plan.firstIndex(where: { $0.exerciseId == ex.id }) { plan.remove(at: i) }
                        else { plan.append(PlanEntry(exerciseId: ex.id, sets: 3, reps: 10)) }
                    }
                    .navigationTitle("Choose exercises")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { choosing = false } } }
                }
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard let item else { return }
            title = item.title
            plan = item.entries.map { $0.plan ?? PlanEntry(exerciseId: $0.exerciseId, sets: 3, reps: 10) }
            if let t = item.reminderTime {
                let p = t.split(separator: ":")
                if p.count >= 2, let h = Int(p[0]), let m = Int(p[1]) {
                    time = Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? time
                }
            } else { remind = false }
        }
    }

    private func save() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        let reminder = remind ? String(format: "%02d:%02d:00", c.hour ?? 18, c.minute ?? 30) : nil
        Task {
            await train.saveScheduleItem(id: item?.id, weekday: weekday, title: title.trimmingCharacters(in: .whitespaces), plan: plan, reminderTime: reminder)
            dismiss()
        }
    }
}
