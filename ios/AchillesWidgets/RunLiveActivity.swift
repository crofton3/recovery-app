import ActivityKit
import SwiftUI
import WidgetKit

struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            RunLockScreenView(plan: context.attributes.plan, state: context.state)
                .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 18)
                .activityBackgroundTint(Glass.card)
                .activitySystemActionForegroundColor(Aurora.text)
        } dynamicIsland: { context in
            let plan = context.attributes.plan
            let state = context.state
            let tint = state.phase == .locating ? Aurora.nutrition : state.kind.activityTint
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RunStatus(plan: plan, state: state).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RunClock(state: state)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Aurora.text)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 84, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            RunHero(state: state, size: 44)
                            Spacer(minLength: 8)
                            Text(state.phase == .locating ? state.nextUp(plan: plan) : "\(state.totalMiles) mi total")
                                .font(.system(size: 13)).monospacedDigit().foregroundStyle(Glass.muted)
                        }
                        PlanRailView(segments: state.rail(plan: plan), height: 10)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 5) {
                    MiniRing(progress: state.phase == .locating ? 0 : state.progress, tint: tint)
                    if state.phase != .locating {
                        Text(state.intervalMiles).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(tint)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.phase == .locating ? "Finding GPS" : "\(state.kind.activityTitle), \(state.intervalMiles) miles")
            } compactTrailing: {
                RunClock(state: state)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Aurora.text)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52, alignment: .trailing)
            } minimal: {
                MiniRing(progress: state.phase == .locating ? 0 : state.progress, tint: tint)
                    .accessibilityHidden(false)
                    .accessibilityLabel("\(state.kind.activityTitle) interval")
            }
            .keylineTint(tint)
        }
    }
}

/// Active time: a live clock while running, frozen while paused.
struct RunClock: View {
    var state: RunActivityAttributes.ContentState

    var body: some View {
        Group {
            if let start = state.timerStart {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
            } else {
                Text(RunFormat.duration(Double(state.pausedSeconds ?? 0)))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// "RUN  Round 2 of 4" with the glowing bead in front.
struct RunStatus: View {
    var plan: RunPlan
    var state: RunActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            switch state.phase {
            case .locating:
                StatusBead(tint: Aurora.nutrition)
                Text("Finding GPS").statusLabel(Aurora.nutrition)
            case .paused:
                Image(systemName: "pause.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Aurora.text)
                Text("Paused").statusLabel(Aurora.text)
                Text(state.planComplete ? "Cool down" : "\(state.kind.activityTitle), round \(state.round) of \(plan.rounds)")
                    .font(.system(size: 13)).foregroundStyle(Glass.muted)
            case .running:
                StatusBead(tint: state.kind.activityTint)
                Text(state.kind.activityTitle).statusLabel(state.kind.activityTint)
                Text(state.roundLabel(plan: plan)).font(.system(size: 13)).foregroundStyle(Aurora.text)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// The big number: miles left in this interval, or miles of cool down.
struct RunHero: View {
    var state: RunActivityAttributes.ContentState
    var size: CGFloat = 58

    var body: some View {
        let tint = state.phase == .paused ? Aurora.text : state.kind.activityTint
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(state.intervalMiles)
                .font(.system(size: size, weight: .bold)).monospacedDigit().tracking(-1)
                .foregroundStyle(tint)
                .shadow(color: state.phase == .paused ? .clear : tint.opacity(0.45), radius: 9)
                .contentTransition(.numericText())
            Text(state.planComplete ? "mi extra" : "mi left").font(.system(size: 15)).foregroundStyle(Glass.muted)
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

struct RunLockScreenView: View {
    var plan: RunPlan
    var state: RunActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RunStatus(plan: plan, state: state)
                Spacer(minLength: 8)
                Text(state.phase == .paused ? "\(RunFormat.duration(Double(state.pausedSeconds ?? 0))) · \(state.totalMiles) mi" : state.nextUp(plan: plan))
                    .font(.system(size: 13)).monospacedDigit().foregroundStyle(Glass.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            middle
            PlanRailView(segments: state.rail(plan: plan))
        }
        .foregroundStyle(Aurora.text)
    }

    @ViewBuilder private var middle: some View {
        switch state.phase {
        case .locating:
            Text("Stand outside with a clear view of the sky. The clock starts on its own.")
                .font(.system(size: 17))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        case .paused:
            HStack(alignment: .center, spacing: 12) {
                RunHero(state: state)
                Spacer(minLength: 8)
                Button(intent: ResumeRunIntent()) {
                    Text("Resume")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Aurora.onAccent)
                        .padding(.horizontal, 22)
                        .frame(height: 48)
                        .background(Glossy(shape: Capsule(), tint: Aurora.strain))
                }
                .buttonStyle(.plain)
            }
        case .running:
            HStack(alignment: .bottom, spacing: 12) {
                RunHero(state: state)
                Spacer(minLength: 8)
                HStack(alignment: .top, spacing: 18) {
                    stat("Time") {
                        RunClock(state: state).frame(maxWidth: 78, alignment: .leading)
                    }
                    stat("Distance") {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(state.totalMiles).monospacedDigit()
                            Text("mi").font(.system(size: 13, weight: .regular)).foregroundStyle(Glass.muted)
                        }
                        .fixedSize()
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func stat<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).statusLabel(Glass.muted)
            value().font(.system(size: 24, weight: .semibold))
        }
        .accessibilityElement(children: .combine)
    }
}
