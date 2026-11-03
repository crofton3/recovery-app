import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            Aurora.bg.ignoresSafeArea()
            LinearGradient(colors: [Aurora.recovery, Aurora.strain, Aurora.sleep], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.10)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .frame(height: 240)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    WhoopCard()
                    HStack(alignment: .top, spacing: 20) {
                        NutritionCard()
                        WaterCard()
                    }
                    DueTodayCard()
                    AchillesCheckCard()
                    if let message = store.errorMessage {
                        Text(message).font(.system(size: 13)).foregroundStyle(Aurora.alert)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable { await store.refresh() }
        }
        .foregroundStyle(Aurora.text)
        .task { await store.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            Text("Today").font(.system(size: 28, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var subtitle: String {
        let day = Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if let week = store.weekPostOp { return "\(day) · Week \(week) post-op" }
        return day
    }
}

private struct WhoopCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let w = store.whoop
        let recovery = (w?.recoveryScore ?? 0) / 100
        let strain = (w?.strain ?? 0) / 21
        let sleep = (w?.sleepPerformance ?? 0) / 100
        VStack(spacing: 16) {
            HStack {
                Text("WHOOP").caption()
                Spacer()
                if w == nil { Chip(text: "Not connected", tint: Aurora.nutrition) }
            }
            RingCluster(rings: [
                RingSpec(value: recovery, color: Aurora.recovery, label: "Recovery", display: w?.recoveryScore.map { "\(Int($0)) percent" } ?? "no data"),
                RingSpec(value: strain, color: Aurora.strain, label: "Strain", display: w?.strain.map { String(format: "%.1f of 21", $0) } ?? "no data"),
                RingSpec(value: sleep, color: Aurora.sleep, label: "Sleep", display: w?.sleepPerformance.map { "\(Int($0)) percent" } ?? "no data"),
            ], size: 248, stroke: 16, gap: 5) {
                VStack(spacing: 2) {
                    Text(w?.recoveryScore.map { "\(Int($0))" } ?? "--")
                        .font(.system(size: 56, weight: .bold)).monospacedDigit()
                        .foregroundStyle(Aurora.recovery)
                        .shadow(color: Aurora.recovery.opacity(0.35), radius: 10)
                    Text("Recovery").caption()
                }
            }
            HStack {
                stat("Recovery", w?.recoveryScore.map { "\(Int($0))%" }, sub: w?.hrv.map { "HRV \(Int($0)) ms" } ?? "", color: Aurora.recovery)
                stat("Strain", w?.strain.map { String(format: "%.1f", $0) }, sub: "of 21", color: Aurora.strain)
                stat("Sleep", w?.sleepPerformance.map { "\(Int($0))%" }, sub: w?.sleepHours.map { hoursText($0) } ?? "", color: Aurora.sleepInk)
            }
            if w == nil {
                Text("No WHOOP data yet. Connecting WHOOP comes in a later step.")
                    .font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
        }
        .auroraCard()
    }

    private func stat(_ label: String, _ value: String?, sub: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).caption()
            }
            Text(value ?? "--").font(.system(size: 28, weight: .semibold)).monospacedDigit()
            Text(sub).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func hoursText(_ h: Double) -> String {
        let total = Int((h * 60).rounded())
        return "\(total / 60)h \(String(format: "%02d", total % 60))m"
    }
}

private struct NutritionCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            Text("Nutrition").caption().frame(maxWidth: .infinity, alignment: .leading)
            RingCluster(rings: [
                RingSpec(value: Double(store.calories) / Double(max(store.calorieTarget, 1)), color: Aurora.nutrition, label: "Calories", display: "\(store.calories) of \(store.calorieTarget)"),
                RingSpec(value: Double(store.protein) / Double(max(store.proteinTarget, 1)), color: Aurora.nutrition, label: "Protein", display: "\(store.protein) of \(store.proteinTarget) grams"),
            ], size: 124, stroke: 16, gap: 5) { EmptyView() }
            VStack(spacing: 6) {
                row("Calories", "\(store.calories)")
                row("Protein", "\(store.protein) g")
            }
        }
        .auroraCard()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
        }
    }
}

private struct WaterCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            Text("Water").caption().frame(maxWidth: .infinity, alignment: .leading)
            RingCluster(rings: [
                RingSpec(value: Double(store.waterOz) / Double(max(store.waterTarget, 1)), color: Aurora.water, label: "Water", display: "\(store.waterOz) of \(store.waterTarget) ounces"),
            ], size: 124, stroke: 16, gap: 5) {
                VStack(spacing: 0) {
                    Text("\(store.waterOz)").font(.system(size: 28, weight: .semibold)).monospacedDigit()
                    Text("of \(store.waterTarget) oz").font(.system(size: 12)).foregroundStyle(Aurora.textMuted)
                }
            }
            Button("+ 8 oz") { Task { await store.addWater(8) } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .auroraCard()
    }
}

private struct DueTodayCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Due today").caption()
            if store.schedule.isEmpty {
                Text("Nothing scheduled").font(.system(size: 22, weight: .semibold))
                Text("Build your weekly schedule on the Train tab.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            } else {
                ForEach(store.schedule) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(size: 22, weight: .semibold))
                        if let t = item.reminderTime { Text("Reminder \(String(t.prefix(5)))").font(.system(size: 15)).foregroundStyle(Aurora.textMuted) }
                    }
                }
                Button("Start workout") {}.buttonStyle(PrimaryButtonStyle())
            }
        }
        .auroraCard()
    }
}

private struct AchillesCheckCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achilles check").caption()
                Spacer()
                Chip(text: store.achillesLogged ? "Logged today" : "Not logged today", tint: store.achillesLogged ? Aurora.recovery : Aurora.nutrition)
            }
            Text("Left Achilles").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            stepper("Pain", value: $store.pain, tint: Aurora.alert)
            stepper("Swelling", value: $store.swelling, tint: Aurora.water)
            Button(store.achillesLogged ? "Update today's check" : "Log today's check") { Task { await store.saveAchilles() } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .auroraCard()
    }

    private func stepper(_ label: String, value: Binding<Int>, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 17, weight: .semibold))
                Text("0 none, 10 worst").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
            Spacer()
            HStack(spacing: 12) {
                roundButton("minus", label: "Lower \(label.lowercased())") { value.wrappedValue = max(0, value.wrappedValue - 1) }
                Text("\(value.wrappedValue)").font(.system(size: 28, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(tint).frame(minWidth: 40)
                roundButton("plus", label: "Raise \(label.lowercased())") { value.wrappedValue = min(10, value.wrappedValue + 1) }
            }
        }
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Aurora.cardRaised, in: Circle())
                .overlay(Circle().stroke(Aurora.borderControl, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}
