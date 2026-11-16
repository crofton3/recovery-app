import SwiftUI

@main
struct AchillesRecoveryApp: App {
    @State private var store = AppStore()
    @State private var train: TrainStore
    @State private var achilles = AchillesStore()
    @State private var fuel = FuelStore()
    @State private var trends = TrendsStore()
    @State private var runs = RunStore()
    @State private var runTracker: RunTracker

    init() {
        let train = TrainStore()
        let tracker = RunTracker()
        _train = State(initialValue: train)
        _runTracker = State(initialValue: tracker)
        Self.connectLiveActivities(train: train, tracker: tracker)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Aurora.card)
        appearance.shadowColor = UIColor(Aurora.hairline)
        let muted = UIColor(Aurora.textMuted)
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = muted
            item.normal.titleTextAttributes = [.foregroundColor: muted]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// Keeps the lock screen in step with the run and the workout, and lets its buttons reach back into the app.
    private static func connectLiveActivities(train: TrainStore, tracker: RunTracker) {
        let live = LiveActivityController.shared
        live.endLeftoverRuns()
        tracker.onLiveChange = { live.syncRun(plan: $0.engine.plan, state: $0.activityState) }
        train.onLiveChange = { live.syncWorkout(session: $0.session, blocks: $0.blocks) }
        LiveActivityBridge.resumeRun = { tracker.resume() }
        LiveActivityBridge.completeSet = { await train.completeSet(sessionId: $0, setId: $1) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(train)
                .environment(achilles)
                .environment(fuel)
                .environment(trends)
                .environment(runs)
                .environment(runTracker)
                .preferredColorScheme(.dark)
        }
    }
}

enum AppTab: Hashable {
    case today, train, achilles, fuel, trends

    var tint: Color {
        switch self {
        case .today: Aurora.recovery
        case .train: Aurora.strain
        case .achilles: Aurora.alert
        case .fuel: Aurora.nutrition
        case .trends: Aurora.sleepInk
        }
    }
}

struct RootView: View {
    @State private var tab: AppTab = .today
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "circle.circle") }
                .tag(AppTab.today)
            TrainView()
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }
                .tag(AppTab.train)
            AchillesView()
                .tabItem { Label("Achilles", systemImage: "waveform.path.ecg") }
                .tag(AppTab.achilles)
            FuelView()
                .tabItem { Label("Fuel", systemImage: "flame.fill") }
                .tag(AppTab.fuel)
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.trends)
        }
        .tint(tab.tint)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await NotificationPlanner.refresh() } }
        }
        .task { await NotificationPlanner.refresh() }
        .animation(Aurora.base, value: tab)
    }
}

struct PlaceholderTab: View {
    var title: String
    var note: String

    var body: some View {
        ZStack {
            Aurora.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 28, weight: .bold))
                Text(note).font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            .foregroundStyle(Aurora.text)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
