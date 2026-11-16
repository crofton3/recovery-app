import SwiftUI

extension RunSegment.Kind {
    var tint: Color {
        switch self {
        case .run: Aurora.strain
        case .walk: Aurora.recovery
        case .cooldown: Aurora.sleepInk
        }
    }

    var title: String {
        switch self {
        case .run: "Run"
        case .walk: "Walk"
        case .cooldown: "Cool down"
        }
    }
}

/// The Run section of the Train tab: the interval plan, the start button and past runs.
struct RunSection: View {
    @Environment(RunStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @State private var detail: RunRecord?

    var body: some View {
        VStack(spacing: 20) {
            PlanCard()
            HistoryCard(onOpen: { detail = $0 })
            if let message = store.errorMessage {
                Text(message).font(.system(size: 13)).foregroundStyle(Aurora.alert)
            }
        }
        .task { await store.load() }
        .fullScreenCover(isPresented: Binding(get: { tracker.phase != .idle }, set: { _ in })) {
            RunLiveView()
        }
        .sheet(item: $detail) { RunDetailSheet(run: $0) }
    }
}

private struct PlanCard: View {
    @Environment(RunStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var store = store
        let plan = store.plan
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Return to run").caption()
                Spacer()
                Chip(text: "\(RunFormat.planMiles(plan.totalMiles)) mi total", tint: Aurora.strain)
            }
            Text(plan.walkMiles > 0 ? "Run \(RunFormat.planMiles(plan.runMiles)), walk \(RunFormat.planMiles(plan.walkMiles))" : "Run \(RunFormat.planMiles(plan.runMiles))")
                .font(.system(size: 22, weight: .semibold))
            Text(plan.rounds == 1 ? "1 round, distances in miles" : "\(plan.rounds) rounds, distances in miles")
                .font(.system(size: 15)).foregroundStyle(Aurora.textMuted)

            stepper("Run", detail: "miles each round", value: RunFormat.planMiles(plan.runMiles), tint: Aurora.strain,
                    down: { store.plan.runMiles = Self.step(plan.runMiles, by: -0.05, in: 0.05...10) },
                    up: { store.plan.runMiles = Self.step(plan.runMiles, by: 0.05, in: 0.05...10) })
            stepper("Walk", detail: "miles, 0 for no breaks", value: RunFormat.planMiles(plan.walkMiles), tint: Aurora.recovery,
                    down: { store.plan.walkMiles = Self.step(plan.walkMiles, by: -0.05, in: 0...5) },
                    up: { store.plan.walkMiles = Self.step(plan.walkMiles, by: 0.05, in: 0...5) })
            stepper("Rounds", detail: "run then walk", value: "\(plan.rounds)", tint: Aurora.text,
                    down: { store.plan.rounds = max(1, plan.rounds - 1) },
                    up: { store.plan.rounds = min(30, plan.rounds + 1) })

            Toggle(isOn: $store.voiceCues) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Voice cues").font(.system(size: 17, weight: .semibold))
                    Text("Says when to run and walk").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                }
            }
            .tint(Aurora.strain)
            .frame(minHeight: 44)

            if tracker.denied {
                Text("Location is off for this app, so distance cannot be tracked. Allow it in Settings.")
                    .font(.system(size: 13)).foregroundStyle(Aurora.alert)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("Start run") {
                    tracker.voiceCues = store.voiceCues
                    tracker.begin(plan: store.plan)
                }
                .buttonStyle(PrimaryButtonStyle(tint: Aurora.strain))
            }
            Text("Distance comes from your phone's GPS, so run outside and keep the phone on you. It keeps tracking with the screen locked.")
                .font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
        }
        .auroraCard()
    }

    /// Steps in clean 0.05 mile increments (no floating point drift).
    static func step(_ value: Double, by delta: Double, in range: ClosedRange<Double>) -> Double {
        let next = ((value + delta) * 20).rounded() / 20
        return min(max(next, range.lowerBound), range.upperBound)
    }

    private func stepper(_ label: String, detail: String, value: String, tint: Color, down: @escaping () -> Void, up: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 17, weight: .semibold))
                Text(detail).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
            Spacer()
            HStack(spacing: 12) {
                RoundStepButton(symbol: "minus", label: "Less \(label.lowercased())", action: down)
                Text(value).font(.system(size: 28, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(tint).frame(minWidth: 68)
                RoundStepButton(symbol: "plus", label: "More \(label.lowercased())", action: up)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct RoundStepButton: View {
    var symbol: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Aurora.cardRaised, in: Circle())
                .overlay(Circle().stroke(Aurora.borderControl, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}

private struct HistoryCard: View {
    @Environment(RunStore.self) private var store
    var onOpen: (RunRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent runs").font(.system(size: 22, weight: .semibold))
                Spacer()
                Text("\(RunFormat.miles(store.weekMeters)) mi in 7 days").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            if store.all.isEmpty {
                Text(store.loaded ? "No runs yet. Your first one shows up here." : "Loading runs")
                    .font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            ForEach(store.all) { run in
                Button { onOpen(run) } label: { row(run) }
                Divider().overlay(Aurora.hairline)
            }
        }
        .auroraCard()
    }

    private func row(_ run: RunRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(RunFormat.miles(run.distanceM)) mi").font(.system(size: 17, weight: .semibold)).monospacedDigit().foregroundStyle(Aurora.text)
                Text(subtitle(run)).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
            Spacer()
            if store.isPending(run) { Chip(text: "Not synced", tint: Aurora.nutrition) }
            else if let pain = run.pain { Chip(text: "Pain \(pain)", tint: pain >= 4 ? Aurora.alert : Aurora.textMuted) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Aurora.textMuted)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func subtitle(_ run: RunRecord) -> String {
        let day = run.started?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) ?? run.date
        return "\(day) · \(RunFormat.duration(Double(run.durationS))) · \(RunFormat.pace(meters: run.runM, seconds: Double(run.runS))) /mi run"
    }
}
