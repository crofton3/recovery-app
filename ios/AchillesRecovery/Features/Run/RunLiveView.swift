import SwiftUI

/// Full-screen run: finding GPS, the live interval ring, then the summary to save.
struct RunLiveView: View {
    @Environment(RunTracker.self) private var tracker
    @State private var confirmFinish = false

    var body: some View {
        ZStack {
            Aurora.bg.ignoresSafeArea()
            if tracker.phase == .finished, let result = tracker.result {
                RunSummaryView(draft: result)
            } else {
                live
            }
        }
        .foregroundStyle(Aurora.text)
        .preferredColorScheme(.dark)
        .animation(Aurora.base, value: tracker.phase)
    }

    private var live: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = tracker.elapsed(at: context.date)
            let engine = tracker.engine
            VStack(spacing: 24) {
                topBar(engine)
                Spacer(minLength: 0)
                IntervalRing(progress: tracker.phase == .locating ? 0 : engine.progress, tint: engine.kind.tint) {
                    ringCenter(engine)
                }
                Text(nextUp(engine)).font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    stat("Distance", RunFormat.miles(engine.totalMeters), unit: "mi")
                    stat("Time", RunFormat.duration(elapsed), unit: tracker.phase == .paused ? "paused" : "active")
                    stat("Pace", RunFormat.pace(meters: engine.segmentMeters, seconds: engine.segmentSeconds(elapsed: elapsed)), unit: "/mi now")
                }
                .auroraCard()
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .confirmationDialog("Finish this run?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish run") { tracker.finish() }
            Button("Keep going", role: .cancel) {}
        }
    }

    private func topBar(_ engine: RunEngine) -> some View {
        let gps = tracker.gpsQuality
        return HStack {
            HStack(spacing: 6) {
                Image(systemName: gps.good ? "location.fill" : "location.slash.fill").font(.system(size: 12, weight: .semibold))
                Text(gps.label)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(gps.good ? Aurora.recovery : Aurora.nutrition)
            .padding(.horizontal, 12).frame(minHeight: 32)
            .background((gps.good ? Aurora.recovery : Aurora.nutrition).opacity(0.14), in: Capsule())
            Spacer()
            if tracker.phase != .locating {
                Text(engine.planComplete ? "Plan complete" : "Round \(engine.round) of \(engine.plan.rounds)")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Aurora.textMuted)
            }
        }
    }

    @ViewBuilder private func ringCenter(_ engine: RunEngine) -> some View {
        if tracker.phase == .locating {
            VStack(spacing: 8) {
                ProgressView().tint(Aurora.strain)
                Text("Finding GPS").font(.system(size: 22, weight: .semibold))
                Text("Stand outside with a clear view of the sky.\nThe clock starts on its own.")
                    .font(.system(size: 13)).foregroundStyle(Aurora.textMuted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
        } else {
            VStack(spacing: 2) {
                Text(tracker.phase == .paused ? "Paused" : engine.kind.title)
                    .font(.system(size: 13, weight: .bold)).tracking(1.2).textCase(.uppercase).foregroundStyle(engine.kind.tint)
                Text(RunFormat.miles(engine.remaining ?? engine.segmentMeters))
                    .font(.system(size: 64, weight: .bold)).monospacedDigit()
                    .foregroundStyle(engine.kind.tint)
                    .shadow(color: engine.kind.tint.opacity(0.45), radius: 12)
                    .contentTransition(.numericText())
                Text(engine.remaining == nil ? "miles of cool down" : "miles left").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func nextUp(_ engine: RunEngine) -> String {
        let plan = engine.plan
        switch (tracker.phase, engine.kind) {
        case (.locating, _): return "First up: run \(RunFormat.planMiles(plan.runMiles)) mi"
        case (_, .cooldown): return "Walk it off, then tap Finish"
        case (_, .run) where plan.walkMiles > 0: return "Next: walk \(RunFormat.planMiles(plan.walkMiles)) mi"
        case (_, _) where engine.round >= plan.rounds: return "Last one, then cool down"
        default: return "Next: run \(RunFormat.planMiles(plan.runMiles)) mi"
        }
    }

    private func stat(_ label: String, _ value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label).caption()
            Text(value).font(.system(size: 28, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(unit).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var controls: some View {
        switch tracker.phase {
        case .locating:
            Button("Cancel") { tracker.reset() }.buttonStyle(SecondaryButtonStyle())
        case .paused:
            HStack(spacing: 12) {
                Button("Finish") { confirmFinish = true }.buttonStyle(SecondaryButtonStyle())
                Button("Resume") { tracker.resume() }.buttonStyle(PrimaryButtonStyle(tint: Aurora.strain))
            }
        default:
            HStack(spacing: 12) {
                Button("Pause") { tracker.pause() }.buttonStyle(SecondaryButtonStyle())
                Button("Finish") { confirmFinish = true }.buttonStyle(PrimaryButtonStyle(tint: Aurora.strain))
            }
        }
    }
}

/// One activity ring showing how far through the current interval you are.
struct IntervalRing<Center: View>: View {
    var progress: Double
    var tint: Color
    var size: CGFloat = 280
    var stroke: CGFloat = 18
    @ViewBuilder var center: () -> Center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.16), lineWidth: stroke)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.55), radius: 6)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: progress)
            center()
        }
        .padding(stroke / 2)
        .frame(width: size, height: size)
        .animation(Aurora.base, value: tint)
    }
}

// MARK: Summary

struct RunSummaryView: View {
    @Environment(RunStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @State var draft: RunRecord
    @State private var pain = 0
    @State private var notes = ""
    @State private var saving = false
    @State private var confirmDiscard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.started?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? draft.date)
                        .font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                    Text("Run complete").font(.system(size: 28, weight: .bold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                RunStatsCard(run: draft)
                if let route = draft.route, route.count > 1 { RouteMap(route: route) }
                SegmentsCard(segments: draft.segments ?? [])

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
                    TextField("Notes, for example tight for the first round", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .font(.system(size: 17))
                        .padding(12)
                        .background(Aurora.cardRaised, in: RoundedRectangle(cornerRadius: Aurora.radiusMd, style: .continuous))
                }
                .auroraCard()

                Button(saving ? "Saving" : "Save run") { save() }
                    .buttonStyle(PrimaryButtonStyle(tint: Aurora.strain))
                    .disabled(saving)
                Button("Discard") { confirmDiscard = true }
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Aurora.alert)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("Discard this run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard run", role: .destructive) { tracker.reset() }
            Button("Keep", role: .cancel) {}
        } message: { Text("It will not be saved.") }
    }

    private func save() {
        saving = true
        var run = draft
        run.pain = pain
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        run.notes = trimmed.isEmpty ? nil : trimmed
        Task {
            await store.save(run)
            tracker.reset()
        }
    }
}
