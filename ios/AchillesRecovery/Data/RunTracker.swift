import AVFoundation
import AudioToolbox
import CoreLocation
import Foundation
import Observation

/// Live run tracking from the phone's GPS. Keeps going with the screen locked (background location),
/// and speaks each run/walk change so the phone can stay in a pocket.
@MainActor
@Observable
final class RunTracker: NSObject {
    enum Phase { case idle, locating, running, paused, finished }

    private(set) var phase: Phase = .idle
    private(set) var engine = RunEngine(plan: RunPlan())
    /// Accuracy of the latest fix in metres. Nil until the first fix.
    private(set) var accuracy: Double?
    private(set) var denied = false
    /// The finished run, ready to save.
    private(set) var result: RunRecord?
    var voiceCues = true

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let synth = AVSpeechSynthesizer()
    @ObservationIgnored private var filter = GPSFilter()
    @ObservationIgnored private var route: [[Double]] = []
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var banked: TimeInterval = 0
    @ObservationIgnored private var resumedAt: Date?

    override init() {
        super.init()
        manager.delegate = self
        synth.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        refreshAuthorization()
    }

    /// Active seconds so far (pauses left out).
    func elapsed(at date: Date = Date()) -> TimeInterval {
        banked + (resumedAt.map { max(date.timeIntervalSince($0), 0) } ?? 0)
    }

    var gpsQuality: (label: String, good: Bool) {
        guard let accuracy, accuracy >= 0 else { return ("Finding GPS", false) }
        return accuracy <= 12 ? ("GPS strong", true) : (accuracy <= GPSFilter.maxAccuracy ? ("GPS ok", true) : ("GPS weak", false))
    }

    // MARK: Controls

    /// Asks for location access if needed, then waits for a good fix. The clock starts on that first fix.
    func begin(plan: RunPlan) {
        refreshAuthorization()
        guard phase == .idle, !denied else { return }
        engine = RunEngine(plan: plan)
        filter = GPSFilter()
        route = []
        result = nil
        accuracy = nil
        startedAt = nil
        banked = 0
        resumedAt = nil
        phase = .locating
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func pause() {
        guard phase == .running else { return }
        banked = elapsed()
        resumedAt = nil
        phase = .paused
        say("Paused")
    }

    func resume() {
        guard phase == .paused else { return }
        filter.reset()  // do not count ground covered while paused
        resumedAt = Date()
        phase = .running
        say("Resumed")
    }

    func finish() {
        guard phase == .running || phase == .paused, let startedAt else { return }
        let total = elapsed()
        banked = total
        resumedAt = nil
        stopLocation()
        result = RunRecord.make(plan: engine.plan, segments: engine.segments(elapsed: total), route: route, startedAt: startedAt, elapsed: total)
        phase = .finished
        say("Run finished. \(spoken(engine.totalMeters / RunPlan.metersPerMile)) miles.")
    }

    /// Back to idle, dropping anything not saved.
    func reset() {
        stopLocation()
        result = nil
        phase = .idle
    }

    private func stopLocation() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func refreshAuthorization() {
        let status = manager.authorizationStatus
        denied = status == .denied || status == .restricted
    }

    // MARK: Location

    private func handle(_ samples: [GPSFilter.Sample]) {
        for s in samples {
            accuracy = s.accuracy
            switch phase {
            case .locating:
                guard filter.accept(s) != nil else { continue }
                startedAt = Date()
                resumedAt = startedAt
                route.append(point(s))
                phase = .running
                announce(.run(round: 1))
            case .running:
                guard let meters = filter.accept(s) else { continue }
                route.append(point(s))
                for event in engine.advance(meters: meters, elapsed: elapsed()) { announce(event) }
            case .idle, .paused, .finished:
                break
            }
        }
    }

    private func point(_ s: GPSFilter.Sample) -> [Double] {
        [(s.lat * 100_000).rounded() / 100_000, (s.lon * 100_000).rounded() / 100_000]
    }

    // MARK: Cues

    private func announce(_ event: RunEngine.Event) {
        let plan = engine.plan
        switch event {
        case .run(let round):
            say("Run. \(spoken(plan.runMiles)) miles. Round \(round) of \(plan.rounds).")
        case .walk:
            say("Walk. \(spoken(plan.walkMiles)) miles.")
        case .planComplete:
            say("Plan complete. Walk to cool down, then finish your run.")
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func spoken(_ miles: Double) -> String { RunFormat.planMiles((miles * 100).rounded() / 100) }

    private func say(_ text: String) {
        guard voiceCues else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        synth.speak(AVSpeechUtterance(string: text))
    }
}

extension RunTracker: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map {
            GPSFilter.Sample(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude, accuracy: $0.horizontalAccuracy, time: $0.timestamp.timeIntervalSinceReferenceDate)
        }
        Task { @MainActor in self.handle(samples) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.refreshAuthorization()
            if self.denied && self.phase == .locating { self.reset() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient failures (no fix yet) are expected. Updates keep coming once a signal is found.
    }
}

extension RunTracker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Let music come back to full volume once the cue is done.
            if !self.synth.isSpeaking { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        }
    }
}
