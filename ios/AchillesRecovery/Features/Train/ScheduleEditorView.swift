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
                            Text("\(item.exerciseIds?.count ?? 0) exercises").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
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
    @State private var exerciseIds: [String] = []
    @State private var choosing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Title, for example Lower body", text: $title)
                    Toggle("Remind me", isOn: $remind)
                    if remind { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                }
                Section("Exercises, in order") {
                    ForEach(exerciseIds, id: \.self) { id in
                        Text(train.exercises.first(where: { $0.id == id })?.name ?? "Unknown exercise")
                    }
                    .onDelete { exerciseIds.remove(atOffsets: $0) }
                    .onMove { exerciseIds.move(fromOffsets: $0, toOffset: $1) }
                    Button("Choose exercises") { choosing = true }
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
                    ExerciseList(selected: Set(exerciseIds)) { ex in
                        if let i = exerciseIds.firstIndex(of: ex.id) { exerciseIds.remove(at: i) } else { exerciseIds.append(ex.id) }
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
            exerciseIds = item.exerciseIds ?? []
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
            await train.saveScheduleItem(id: item?.id, weekday: weekday, title: title.trimmingCharacters(in: .whitespaces), exerciseIds: exerciseIds, reminderTime: reminder)
            dismiss()
        }
    }
}
