import SwiftUI

struct TrainView: View {
    @Environment(TrainStore.self) private var train
    @State private var mode = 0
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Aurora.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        Picker("View", selection: $mode) {
                            Text("Session").tag(0)
                            Text("Schedule").tag(1)
                        }
                        .pickerStyle(.segmented)

                        if mode == 0 { sessionContent } else { ScheduleEditorView() }

                        if let message = train.errorMessage {
                            Text(message).font(.system(size: 13)).foregroundStyle(Aurora.alert)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .foregroundStyle(Aurora.text)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerSheet { ex in Task { await train.addExercise(ex) } }
            }
        }
        .task { await train.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            Text("Train").font(.system(size: 28, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    @ViewBuilder private var sessionContent: some View {
        if let session = train.session {
            SessionSummary(session: session)
            ForEach(train.blocks) { block in
                ExerciseCard(exerciseId: block.id)
            }
            Button("+ Add exercise") { showPicker = true }
                .buttonStyle(SecondaryButtonStyle())
            Button("Finish workout") { Task { await train.finish() } }
                .buttonStyle(PrimaryButtonStyle())
        } else {
            StartCard()
        }
    }
}

private struct StartCard: View {
    @Environment(TrainStore.self) private var train

    var body: some View {
        let today = train.weekSchedule.filter { $0.weekday == Day.weekday }
        VStack(alignment: .leading, spacing: 12) {
            Text("Due today").caption()
            if today.isEmpty {
                Text("Nothing scheduled").font(.system(size: 22, weight: .semibold))
                Text("Add sessions in Schedule, or start a quick one.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            ForEach(today) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title).font(.system(size: 22, weight: .semibold))
                    Text("\(item.exerciseIds?.count ?? 0) exercises").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                    Button("Start workout") { Task { await train.startSession(from: item) } }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            Button("Quick session") { Task { await train.startSession(from: nil) } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .auroraCard()
    }
}

private struct SessionSummary: View {
    @Environment(TrainStore.self) private var train
    var session: WorkoutSession

    var body: some View {
        let done = train.blocks.reduce(0) { $0 + $1.sets.filter(\.done).count }
        let prs = train.blocks.reduce(0) { $0 + $1.sets.filter(\.isPR).count }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title).font(.system(size: 22, weight: .semibold))
                    if let started = session.startedAt, let d = ISO8601DateFormatter().date(from: started) {
                        Text("Started \(d.formatted(date: .omitted, time: .shortened))").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                    }
                }
                Spacer()
                if let started = session.startedAt, let d = ISO8601DateFormatter().date(from: started) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(timerInterval: d...Date.distantFuture, countsDown: false)
                            .font(.system(size: 28, weight: .semibold)).monospacedDigit().foregroundStyle(Aurora.strain)
                        Text("elapsed").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                    }
                }
            }
            HStack(spacing: 8) {
                Chip(text: done == 1 ? "1 set done" : "\(done) sets done", tint: Aurora.recovery)
                if prs > 0 { Chip(text: "\(prs) PR", tint: Aurora.nutrition) }
            }
        }
        .auroraCard()
    }
}

private struct ExerciseCard: View {
    @Environment(TrainStore.self) private var train
    var exerciseId: String

    var body: some View {
        @Bindable var train = train
        if let bi = train.blocks.firstIndex(where: { $0.id == exerciseId }) {
            let block = train.blocks[bi]
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.exercise.name).font(.system(size: 17, weight: .semibold))
                        if block.priorBest > 0 {
                            Text("Beat your last sessions to earn a PR").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                        } else {
                            Text("First time logging this").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                        }
                    }
                    Spacer()
                    Chip(text: block.exercise.category.capitalized, tint: block.exercise.category == "rehab" ? Aurora.alert : Aurora.strain)
                }
                VStack(spacing: 8) {
                    ForEach(Array(block.sets.enumerated()), id: \.element.id) { si, set in
                        SetRowView(draft: $train.blocks[bi].sets[si], number: si + 1, unit: block.exercise.unit) {
                            Task { await train.toggleDone(exerciseId: exerciseId, setId: set.id) }
                        }
                    }
                }
                Button("+ Add set") { train.addSet(to: exerciseId) }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Aurora.strain)
                    .frame(minHeight: 44)
            }
            .auroraCard()
        }
    }
}

struct SetRowView: View {
    @Binding var draft: TrainStore.SetDraft
    var number: Int
    var unit: String
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)").font(.system(size: 17, weight: .semibold)).foregroundStyle(Aurora.textMuted).frame(width: 22)
            field($draft.weight, caption: draft.lastWeight.map { "was \(TrainStore.format($0)) \(unit)" } ?? unit, keyboard: .decimalPad, label: "Weight for set \(number)")
            field($draft.reps, caption: draft.lastReps.map { "was \($0)" } ?? "reps", keyboard: .numberPad, label: "Reps for set \(number)")
            if draft.isPR {
                Text("PR").font(.system(size: 12, weight: .bold)).tracking(0.7)
                    .foregroundStyle(Aurora.nutrition)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Aurora.nutrition.opacity(0.14), in: Capsule())
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            Button(action: onToggle) {
                Image(systemName: "checkmark").font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(draft.done ? Aurora.onAccent : Color.clear)
                    .frame(width: 44, height: 44)
                    .background(draft.done ? Aurora.recovery : Color.clear, in: Circle())
                    .overlay(Circle().stroke(draft.done ? Aurora.recovery : Aurora.borderControl, lineWidth: 1.5))
                    .shadow(color: draft.done ? Aurora.recovery.opacity(0.35) : .clear, radius: 8)
            }
            .accessibilityLabel(draft.done ? "Mark set \(number) not done" : "Mark set \(number) done")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(minHeight: 76)
        .background(draft.done ? Aurora.recovery.opacity(0.14) : Aurora.cardRaised, in: RoundedRectangle(cornerRadius: Aurora.radiusMd, style: .continuous))
        .animation(Aurora.fast, value: draft.done)
        .animation(Aurora.base, value: draft.isPR)
    }

    private func field(_ text: Binding<String>, caption: String, keyboard: UIKeyboardType, label: String) -> some View {
        VStack(spacing: 2) {
            TextField("", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .semibold)).monospacedDigit()
                .frame(height: 40)
                .background(Aurora.card, in: RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous).stroke(Aurora.borderControl, lineWidth: 1))
                .accessibilityLabel(label)
            Text(caption).font(.system(size: 12)).foregroundStyle(Aurora.textMuted).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}
