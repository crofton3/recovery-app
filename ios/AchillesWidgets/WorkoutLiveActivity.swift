import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(
                title: context.attributes.title, startedAt: context.attributes.startedAt, sessionId: context.attributes.sessionId, state: context.state
            )
                .padding(.horizontal, 18).padding(.vertical, 14)
                .activityBackgroundTint(Glass.card)
                .activitySystemActionForegroundColor(Aurora.text)
        } dynamicIsland: { context in
            let state = context.state
            let startedAt = context.attributes.startedAt
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        StatusBead(tint: Aurora.recovery)
                        Text(context.attributes.title).statusLabel(Aurora.recovery)
                    }
                    .lineLimit(1)
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutClock(startedAt: startedAt)
                        .font(.system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 84, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            WorkoutNow(state: state, nameSize: 22, showLast: false)
                            Spacer(minLength: 8)
                            CompleteSetButton(sessionId: context.attributes.sessionId, state: state, size: 48)
                        }
                        WorkoutProgress(state: state)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 5) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 13, weight: .semibold))
                    Text("\(state.doneSets)/\(state.totalSets)").font(.system(size: 15, weight: .semibold)).monospacedDigit()
                }
                .foregroundStyle(Aurora.recovery)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(state.doneSets) of \(state.totalSets) sets done")
            } compactTrailing: {
                WorkoutClock(startedAt: startedAt)
                    .font(.system(size: 15, weight: .semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52, alignment: .trailing)
            } minimal: {
                MiniRing(progress: state.progress, tint: Aurora.recovery)
                    .accessibilityHidden(false)
                    .accessibilityLabel("\(state.doneSets) of \(state.totalSets) sets done")
            }
            .keylineTint(Aurora.recovery)
        }
    }
}

/// Time since the workout started.
struct WorkoutClock: View {
    var startedAt: Date

    var body: some View {
        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Aurora.strain)
    }
}

/// The exercise and set you are on, with the target and what you did last time.
struct WorkoutNow: View {
    var state: WorkoutActivityAttributes.ContentState
    var nameSize: CGFloat = 24
    var showLast = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(headline).font(.system(size: nameSize, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
            if state.exerciseName.isEmpty {
                Text(state.allDone ? "Open the app to finish your workout." : "Add an exercise in the app.")
                    .font(.system(size: 15)).foregroundStyle(Glass.muted)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Set \(state.setNumber) of \(state.setCount)").font(.system(size: 15, weight: .semibold))
                    Text(state.target.isEmpty ? "Add weight or reps in the app" : state.target)
                        .font(.system(size: 15)).monospacedDigit()
                        .foregroundStyle(state.target.isEmpty ? Glass.muted : Aurora.text)
                }
                .lineLimit(1).minimumScaleFactor(0.8)
            }
            if showLast { detail }
        }
        .foregroundStyle(Aurora.text)
    }

    private var headline: String {
        if !state.exerciseName.isEmpty { return state.exerciseName }
        return state.allDone ? "All sets done" : "No exercises yet"
    }

    @ViewBuilder private var detail: some View {
        HStack(spacing: 8) {
            if let last = state.last, !state.exerciseName.isEmpty {
                Text("Last time \(last)").font(.system(size: 13)).monospacedDigit().foregroundStyle(Glass.muted)
            }
            if state.records > 0 {
                Text(state.records == 1 ? "1 PR today" : "\(state.records) PRs today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Aurora.nutrition)
                    .padding(.horizontal, 8).padding(.vertical, 1)
                    .background(Aurora.nutrition.opacity(0.14), in: Capsule())
            }
        }
        .lineLimit(1)
        .frame(minHeight: 18)
    }
}

/// Glossy check button. Marks the set shown as done without unlocking the phone.
struct CompleteSetButton: View {
    var sessionId: String?
    var state: WorkoutActivityAttributes.ContentState
    var size: CGFloat = 56

    var body: some View {
        if state.canComplete, let sessionId, let setId = state.setId {
            Button(intent: CompleteSetIntent(sessionId: sessionId, setId: setId)) {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .heavy))
                    .foregroundStyle(Aurora.onAccent)
                    .frame(width: size, height: size)
                    .background(Glossy(shape: Circle(), tint: Aurora.recovery))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark set \(state.setNumber) done")
        }
    }
}

/// One glass bead per set, grouped by exercise. Gold beads are PRs, the outlined bead is the set you are on.
struct WorkoutProgress: View {
    var state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            if state.totalSets > 45 {
                ZStack(alignment: .leading) {
                    Groove(shape: Capsule(), tint: Aurora.recovery)
                    GeometryReader { geo in
                        Glossy(shape: Capsule(), tint: Aurora.recovery).frame(width: max(geo.size.width * state.progress, 12))
                    }
                }
                .frame(height: 12)
            } else {
                beads
                Spacer(minLength: 0)
            }
            Text("\(state.doneSets) of \(state.totalSets) sets").font(.system(size: 13)).monospacedDigit().foregroundStyle(Glass.muted).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.doneSets) of \(state.totalSets) sets done")
    }

    private var beads: some View {
        let size: CGFloat = state.totalSets <= 18 ? 13 : (state.totalSets <= 30 ? 9 : 6)
        let current = Self.currentIndex(state.marks)
        return HStack(spacing: size * 0.75) {
            ForEach(Array(state.marks.enumerated()), id: \.offset) { row, sets in
                HStack(spacing: size * 0.3) {
                    ForEach(Array(sets.enumerated()), id: \.offset) { col, mark in
                        bead(mark, isCurrent: current.map { $0 == (row, col) } ?? false).frame(width: size, height: size)
                    }
                }
            }
        }
    }

    @ViewBuilder private func bead(_ mark: WorkoutActivityAttributes.Mark, isCurrent: Bool) -> some View {
        switch mark {
        case .done: Glossy(shape: Circle(), tint: Aurora.recovery)
        case .record: Glossy(shape: Circle(), tint: Aurora.nutrition)
        case .pending:
            if isCurrent {
                Circle().strokeBorder(Aurora.text, lineWidth: 2).background(Circle().fill(.black.opacity(0.3)))
            } else {
                Groove(shape: Circle(), tint: Aurora.recovery)
            }
        }
    }

    /// Row and column of the first set still to do.
    static func currentIndex(_ marks: [[WorkoutActivityAttributes.Mark]]) -> (Int, Int)? {
        for (row, sets) in marks.enumerated() {
            if let col = sets.firstIndex(of: .pending) { return (row, col) }
        }
        return nil
    }
}

struct WorkoutLockScreenView: View {
    var title: String
    var startedAt: Date
    var sessionId: String?
    var state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StatusBead(tint: Aurora.recovery)
                Text(title).statusLabel(Aurora.recovery).lineLimit(1)
                if state.exerciseCount > 0 && !state.exerciseName.isEmpty {
                    Text("Exercise \(state.exerciseNumber) of \(state.exerciseCount)").font(.system(size: 13)).lineLimit(1).fixedSize()
                }
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    WorkoutClock(startedAt: startedAt)
                        .font(.system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 84, alignment: .trailing)
                    Text("elapsed").font(.system(size: 13)).foregroundStyle(Glass.muted).fixedSize()
                }
            }
            HStack(alignment: .center, spacing: 12) {
                WorkoutNow(state: state)
                Spacer(minLength: 8)
                CompleteSetButton(sessionId: sessionId, state: state)
            }
            WorkoutProgress(state: state)
        }
        .foregroundStyle(Aurora.text)
    }
}
