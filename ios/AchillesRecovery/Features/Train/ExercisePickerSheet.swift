import SwiftUI

/// Pick one exercise (adds it to the session), or create a new one.
struct ExercisePickerSheet: View {
    @Environment(TrainStore.self) private var train
    @Environment(\.dismiss) private var dismiss
    var onPick: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            ExerciseList(selected: nil, onTap: { ex in onPick(ex); dismiss() })
                .navigationTitle("Add exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

/// Shared list with an inline "new exercise" form. `selected` is nil for single-pick mode.
struct ExerciseList: View {
    @Environment(TrainStore.self) private var train
    var selected: Set<String>?
    var onTap: (Exercise) -> Void

    @State private var name = ""
    @State private var category = "lower"
    @State private var unit = "lb"

    var body: some View {
        List {
            Section("Your exercises") {
                if train.exercises.isEmpty {
                    Text("No exercises yet. Add your first one below.").foregroundStyle(Aurora.textMuted)
                }
                ForEach(train.exercises) { ex in
                    Button { onTap(ex) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(ex.name).foregroundStyle(Aurora.text)
                                Text("\(ex.category.capitalized) · \(ex.unit)").font(.footnote).foregroundStyle(Aurora.textMuted)
                            }
                            Spacer()
                            if selected?.contains(ex.id) == true { Image(systemName: "checkmark.circle.fill").foregroundStyle(Aurora.recovery) }
                        }
                    }
                    .accessibilityAddTraits(selected?.contains(ex.id) == true ? .isSelected : [])
                }
            }
            Section("New exercise") {
                TextField("Name", text: $name)
                Picker("Type", selection: $category) {
                    ForEach(["lower", "upper", "rehab", "cardio"], id: \.self) { Text($0.capitalized).tag($0) }
                }
                Picker("Unit", selection: $unit) {
                    ForEach(["lb", "kg", "bodyweight", "sec", "min"], id: \.self) { Text($0).tag($0) }
                }
                Button("Add to library") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        if let ex = await train.createExercise(name: trimmed, category: category, unit: unit) {
                            name = ""
                            onTap(ex)
                        }
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let message = train.errorMessage {
                Text(message).font(.footnote).foregroundStyle(Aurora.alert)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Aurora.bg)
    }
}
