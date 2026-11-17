import MapKit
import SwiftUI

/// Distance, time and pace for one run.
struct RunStatsCard: View {
    var run: RunRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Distance").caption()
                Spacer()
                if run.isTreadmill { Chip(text: "Treadmill", tint: Aurora.textMuted) }
                if let rounds = run.planRounds {
                    Chip(text: "\(run.roundsDone) of \(rounds) rounds", tint: run.roundsDone >= rounds ? Aurora.recovery : Aurora.nutrition)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(RunFormat.miles(run.distanceM)).font(.system(size: 48, weight: .bold)).monospacedDigit()
                    .foregroundStyle(Aurora.strain).shadow(color: Aurora.strain.opacity(0.45), radius: 12)
                Text("mi").font(.system(size: 17, weight: .semibold)).foregroundStyle(Aurora.textMuted)
            }
            HStack(spacing: 0) {
                stat("Time", RunFormat.duration(Double(run.durationS)), unit: "active")
                stat("Run pace", RunFormat.pace(meters: run.runM, seconds: Double(run.runS)), unit: "/mi")
                stat("Running", RunFormat.miles(run.runM), unit: "mi")
                stat("Walking", RunFormat.miles(run.walkM), unit: "mi")
            }
        }
        .auroraCard()
    }

    private func stat(_ label: String, _ value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).caption().lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 22, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(unit).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Each run and walk interval with its pace.
struct SegmentsCard: View {
    var segments: [RunSegment]

    var body: some View {
        if !segments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Intervals").font(.system(size: 22, weight: .semibold))
                ForEach(Array(segments.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 12) {
                        Circle().fill(s.kind.tint).frame(width: 8, height: 8)
                        Text(s.kind.title).font(.system(size: 17)).frame(width: 96, alignment: .leading)
                        Text("\(RunFormat.miles(s.meters)) mi").font(.system(size: 15, weight: .semibold)).monospacedDigit()
                        Spacer()
                        Text("\(RunFormat.duration(s.seconds)) · \(RunFormat.pace(meters: s.meters, seconds: s.seconds)) /mi")
                            .font(.system(size: 13)).monospacedDigit().foregroundStyle(Aurora.textMuted)
                    }
                    .frame(minHeight: 36)
                    .accessibilityElement(children: .combine)
                }
            }
            .auroraCard()
        }
    }
}

struct RouteMap: View {
    var route: [[Double]]

    var body: some View {
        let coords = route.compactMap { $0.count == 2 ? CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) : nil }
        Map(initialPosition: .automatic, interactionModes: []) {
            MapPolyline(coordinates: coords)
                .stroke(Aurora.strain, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            if let start = coords.first {
                Annotation("Start", coordinate: start) {
                    Circle().fill(Aurora.recovery).frame(width: 12, height: 12).overlay(Circle().stroke(Aurora.bg, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Aurora.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Aurora.radiusLg, style: .continuous).stroke(Aurora.hairline, lineWidth: 1))
        .accessibilityLabel("Map of your route")
    }
}

/// A saved run opened from the history list.
struct RunDetailSheet: View {
    @Environment(RunStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var run: RunRecord
    @State private var route: [[Double]] = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Aurora.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        RunStatsCard(run: run)
                        if route.count > 1 { RouteMap(route: route) }
                        SegmentsCard(segments: run.segments ?? [])
                        if run.pain != nil || run.notes != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Achilles").caption()
                                if let pain = run.pain {
                                    Text("Pain \(pain) of 10").font(.system(size: 17, weight: .semibold)).foregroundStyle(pain >= 4 ? Aurora.alert : Aurora.text)
                                }
                                if let notes = run.notes { Text(notes).font(.system(size: 15)).foregroundStyle(Aurora.textMuted) }
                            }
                            .auroraCard()
                        }
                        Button("Delete run") { confirmDelete = true }
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(Aurora.alert)
                            .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .foregroundStyle(Aurora.text)
            .navigationTitle(run.started?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()) ?? run.date)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Delete this run?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete run", role: .destructive) { Task { await store.delete(run); dismiss() } }
                Button("Keep", role: .cancel) {}
            } message: { Text("This cannot be undone.") }
        }
        .preferredColorScheme(.dark)
        .task { route = await store.route(for: run) }
    }
}
