import SwiftUI

/// What was typed into the treadmill form, as text, so it can be checked without the view.
struct TreadmillEntry {
    var miles = ""
    var minutes = ""
    var seconds = ""
    var walkMiles = ""
    var walkMinutes = ""

    /// Longest run the form accepts. Also keeps typed numbers small enough to turn into whole seconds safely.
    static let maxSeconds = 24 * 3600

    var distanceM: Double? { Self.number(miles).map { $0 * RunPlan.metersPerMile } }
    var durationS: Int? {
        let m = Self.number(minutes) ?? 0, s = Self.number(seconds) ?? 0
        guard let total = Self.seconds(m * 60 + s), total > 0 else { return nil }
        return total
    }
    var walkM: Double { (Self.number(walkMiles) ?? 0) * RunPlan.metersPerMile }
    /// Nil when what was typed is too large to be a real walk time.
    var walkS: Int? { Self.seconds((Self.number(walkMinutes) ?? 0) * 60) }

    /// Why the entry can't be saved yet, or nil when it can.
    var problem: String? {
        guard let distanceM, distanceM > 0 else { return "Enter the distance from the treadmill." }
        guard let durationS else {
            let typed = (Self.number(minutes) ?? 0) > 0 || (Self.number(seconds) ?? 0) > 0
            return typed ? "That time is too long. Check minutes and seconds." : "Enter how long you were on the treadmill."
        }
        guard let walkS else { return "That walking time is too long." }
        if walkM > distanceM { return "Walking can't be more than the total distance." }
        if walkS > durationS { return "Walking time can't be more than the total time." }
        if walkM > 0, walkS == 0 { return "Add your walking time so run pace is right." }
        if walkS > 0, walkM == 0 { return "Add how far you walked." }
        if walkM > 0, walkM < distanceM, walkS >= durationS { return "Walking time has to leave some time for running." }
        return nil
    }

    func record(finishedAt: Date, pain: Int?, notes: String?) -> RunRecord? {
        guard problem == nil, let distanceM, let durationS, let walkS else { return nil }
        return .treadmill(finishedAt: finishedAt, distanceM: distanceM, durationS: durationS, walkM: walkM, walkS: walkS, pain: pain, notes: notes)
    }

    /// Whole seconds, or nil when the value is past `maxSeconds` (converting a huge Double to Int would crash).
    private static func seconds(_ value: Double) -> Int? {
        guard value.isFinite, value >= 0, value <= Double(maxSeconds) else { return nil }
        return Int(value.rounded())
    }

    /// Accepts "3.1" and "3,1".
    private static func number(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value.isFinite, value >= 0 else { return nil }
        return value
    }
}

/// Logs a run done on a treadmill by hand: no GPS, just what the treadmill's display says.
struct TreadmillLogSheet: View {
    @Environment(RunStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entry = TreadmillEntry()
    @State private var finishedAt = Date()
    @State private var includesWalking = false
    @State private var pain = 0
    @State private var notes = ""
    @State private var saving = false
    @State private var showProblem = false

    var body: some View {
        NavigationStack {
            ZStack {
                Aurora.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        totalsCard
                        walkingCard
                        painCard
                        if showProblem, let problem = entry.problem {
                            Text(problem).font(.system(size: 13)).foregroundStyle(Aurora.alert)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button(saving ? "Saving" : "Save run") { save() }
                            .buttonStyle(PrimaryButtonStyle(tint: Aurora.strain))
                            .disabled(saving)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .foregroundStyle(Aurora.text)
            .navigationTitle("Treadmill run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("From the treadmill").caption()
            HStack(spacing: 12) {
                numberField("Distance", text: $entry.miles, unit: "mi", keyboard: .decimalPad)
                numberField("Minutes", text: $entry.minutes, unit: "min", keyboard: .numberPad)
                numberField("Seconds", text: $entry.seconds, unit: "sec", keyboard: .numberPad)
            }
            if let d = entry.distanceM, let t = entry.durationS {
                let runM = d - min(entry.walkM, d), runS = max(t - (entry.walkS ?? 0), 0)
                Text("\(RunFormat.pace(meters: runM, seconds: Double(runS))) /mi run pace")
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Aurora.strain)
            }
            DatePicker("Finished", selection: $finishedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .font(.system(size: 17, weight: .semibold))
                .tint(Aurora.strain)
        }
        .auroraCard()
    }

    private var walkingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $includesWalking.animation(Aurora.fast)) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Included walking").font(.system(size: 17, weight: .semibold))
                    Text("Keeps walk breaks out of your run pace").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                }
            }
            .tint(Aurora.recovery)
            .frame(minHeight: 44)
            .onChange(of: includesWalking) { _, on in
                if !on { entry.walkMiles = ""; entry.walkMinutes = "" }
            }
            if includesWalking {
                HStack(spacing: 12) {
                    numberField("Walked", text: $entry.walkMiles, unit: "mi", keyboard: .decimalPad)
                    numberField("Walk time", text: $entry.walkMinutes, unit: "min", keyboard: .decimalPad)
                }
            }
        }
        .auroraCard()
    }

    private var painCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did the Achilles feel?").caption()
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pain").font(.system(size: 17, weight: .semibold))
                    Text("0 none, 10 worst").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                }
                Spacer()
                HStack(spacing: 12) {
                    RoundStepButton(symbol: "minus", label: "Lower pain") { pain = max(0, pain - 1) }
                    Text("\(pain)").font(.system(size: 28, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Aurora.alert).frame(minWidth: 40)
                    RoundStepButton(symbol: "plus", label: "Raise pain") { pain = min(10, pain + 1) }
                }
            }
            TextField("Notes, for example incline 1%, 5.5 mph", text: $notes, axis: .vertical)
                .lineLimit(2...5)
                .font(.system(size: 17))
                .padding(12)
                .background(Aurora.cardRaised, in: RoundedRectangle(cornerRadius: Aurora.radiusMd, style: .continuous))
        }
        .auroraCard()
    }

    private func numberField(_ label: String, text: Binding<String>, unit: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).caption().lineLimit(1).minimumScaleFactor(0.8)
            TextField("0", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .semibold)).monospacedDigit()
                .frame(height: 44)
                .background(Aurora.card, in: RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous).stroke(Aurora.borderControl, lineWidth: 1))
                .accessibilityLabel("\(label) in \(unit)")
            Text(unit).font(.system(size: 12)).foregroundStyle(Aurora.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let run = entry.record(finishedAt: finishedAt, pain: pain, notes: trimmed.isEmpty ? nil : trimmed) else {
            showProblem = true
            return
        }
        saving = true
        Task {
            await store.save(run)
            dismiss()
        }
    }
}
