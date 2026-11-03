import SwiftUI

struct FuelView: View {
    @Environment(FuelStore.self) private var fuel

    var body: some View {
        NavigationStack {
            ZStack {
                Aurora.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        TotalsCard()
                        QuickAddCard()
                        AddFoodCard()
                        EndOfDayCard()
                        LoggedCard()
                        TargetsCard()
                        if let message = fuel.errorMessage {
                            Text(message).font(.system(size: 13)).foregroundStyle(Aurora.alert)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await fuel.load() }
            }
            .foregroundStyle(Aurora.text)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
        }
        .task { await fuel.load() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Manual entry, no barcode needed").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                Text("Fuel").font(.system(size: 28, weight: .bold))
            }
            Spacer()
            HStack(spacing: 4) {
                dayButton("chevron.left", label: "Previous day", enabled: true) { Task { await fuel.shift(days: -1) } }
                Text(fuel.isToday ? "Today" : fuel.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 17, weight: .semibold)).frame(minWidth: 64)
                dayButton("chevron.right", label: "Next day", enabled: !fuel.isToday) { Task { await fuel.shift(days: 1) } }
            }
        }
        .padding(.top, 8)
    }

    private func dayButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Aurora.card, in: Circle())
                .overlay(Circle().stroke(Aurora.hairline, lineWidth: 1))
        }
        .disabled(!enabled).opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}

// MARK: Field

struct AuroraField: View {
    var title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var unit: String?
    var placeholder = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Aurora.textMuted)
            HStack {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .font(.system(size: 17))
                    .accessibilityLabel(title)
                if let unit { Text(unit).font(.system(size: 15)).foregroundStyle(Aurora.textMuted) }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(Aurora.cardRaised, in: RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Aurora.radiusSm, style: .continuous).stroke(Aurora.borderControl, lineWidth: 1))
        }
    }
}

private func intValue(_ s: String) -> Int? { Int(s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)) }

// MARK: Cards

private struct TotalsCard: View {
    @Environment(FuelStore.self) private var fuel

    var body: some View {
        let t = fuel.totals
        let leftCal = max(fuel.calorieTarget - t.calories, 0), leftPro = max(fuel.proteinTarget - t.protein, 0)
        VStack(spacing: 12) {
            RingCluster(rings: [
                RingSpec(value: Double(t.calories) / Double(max(fuel.calorieTarget, 1)), color: Aurora.nutrition, label: "Calories", display: "\(t.calories) of \(fuel.calorieTarget)"),
                RingSpec(value: Double(t.protein) / Double(max(fuel.proteinTarget, 1)), color: Aurora.nutrition, label: "Protein", display: "\(t.protein) of \(fuel.proteinTarget) grams"),
            ], size: 150, stroke: 16, gap: 5) { EmptyView() }
            .frame(maxWidth: .infinity)
            HStack(spacing: 24) {
                legend("Calories", "\(t.calories)", of: "\(fuel.calorieTarget) kcal", opacity: 1)
                legend("Protein", "\(t.protein) g", of: "\(fuel.proteinTarget) g", opacity: 0.55)
            }
            if t.usesEndOfDay {
                Chip(text: "Using your end-of-day total", tint: Aurora.nutrition)
            }
            HStack {
                Text("Left").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
                Spacer()
                Text("\(leftCal) kcal · \(leftPro) g protein").font(.system(size: 15, weight: .semibold)).foregroundStyle(Aurora.nutrition)
            }
            .padding(.top, 8)
            .overlay(alignment: .top) { Divider().overlay(Aurora.hairline) }
        }
        .auroraCard()
    }

    private func legend(_ label: String, _ value: String, of target: String, opacity: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(Aurora.nutrition.opacity(opacity)).frame(width: 8, height: 8)
                Text(label).font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
            }
            Text(value).font(.system(size: 22, weight: .semibold)).monospacedDigit()
            Text("of \(target)").font(.system(size: 12)).foregroundStyle(Aurora.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QuickAddCard: View {
    @Environment(FuelStore.self) private var fuel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick add").caption()
            if fuel.recents.isEmpty {
                Text("Foods you log show up here so you can add them again with one tap.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(fuel.recents) { r in
                        Button { Task { await fuel.add(name: r.itemName, calories: r.calories ?? 0, protein: r.protein ?? 0) } } label: {
                            Text("\(r.itemName) · \(r.calories ?? 0)")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Aurora.nutrition)
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .background(Aurora.nutrition.opacity(0.14), in: Capsule())
                        }
                        .accessibilityLabel("Add \(r.itemName), \(r.calories ?? 0) calories")
                    }
                }
            }
        }
        .auroraCard()
    }
}

private struct AddFoodCard: View {
    @Environment(FuelStore.self) private var fuel
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a food").font(.system(size: 22, weight: .semibold))
            AuroraField(title: "Food", text: $name, placeholder: "Salmon, rice and broccoli")
            HStack(spacing: 12) {
                AuroraField(title: "Calories", text: $calories, keyboard: .numberPad, unit: "kcal")
                AuroraField(title: "Protein", text: $protein, keyboard: .numberPad, unit: "g")
            }
            Button("Add food") {
                let n = name.trimmingCharacters(in: .whitespaces)
                let c = intValue(calories) ?? 0, p = intValue(protein) ?? 0
                Task { await fuel.add(name: n, calories: c, protein: p); name = ""; calories = ""; protein = "" }
            }
            .buttonStyle(PrimaryButtonStyle(tint: Aurora.nutrition))
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .auroraCard()
    }
}

private struct EndOfDayCard: View {
    @Environment(FuelStore.self) private var fuel
    @State private var calories = ""
    @State private var protein = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("End-of-day total").font(.system(size: 22, weight: .semibold))
                Text("Short on time? Enter the whole day's numbers. They replace the foods below in today's totals, and your foods stay saved.")
                    .font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            HStack(spacing: 12) {
                AuroraField(title: "Total calories", text: $calories, keyboard: .numberPad, unit: "kcal", placeholder: fuel.endOfDay?.calories.map(String.init) ?? "2,060")
                AuroraField(title: "Total protein", text: $protein, keyboard: .numberPad, unit: "g", placeholder: fuel.endOfDay?.protein.map(String.init) ?? "138")
            }
            Button("Save day total") {
                guard let c = intValue(calories), let p = intValue(protein) else { return }
                Task { await fuel.setEndOfDay(calories: c, protein: p); calories = ""; protein = "" }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(intValue(calories) == nil || intValue(protein) == nil)
            .opacity(intValue(calories) == nil || intValue(protein) == nil ? 0.5 : 1)
            if let eod = fuel.endOfDay {
                Button("Remove day total (\(eod.calories ?? 0) kcal)", role: .destructive) { Task { await fuel.delete(eod) } }
                    .font(.system(size: 15)).frame(minHeight: 44)
            }
        }
        .auroraCard()
    }
}

private struct LoggedCard: View {
    @Environment(FuelStore.self) private var fuel

    var body: some View {
        let foods = fuel.foods
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Logged").font(.system(size: 22, weight: .semibold))
                Spacer()
                Text("\(foods.count) food\(foods.count == 1 ? "" : "s")").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            if foods.isEmpty {
                Text("Nothing logged for this day.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted).padding(.vertical, 8)
            }
            ForEach(foods) { f in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.itemName).font(.system(size: 17))
                        Text("\(f.protein ?? 0) g protein").font(.system(size: 13)).foregroundStyle(Aurora.textMuted)
                    }
                    Spacer()
                    Text("\(f.calories ?? 0)").font(.system(size: 17, weight: .semibold)).monospacedDigit()
                    Menu {
                        Button("Delete", role: .destructive) { Task { await fuel.delete(f) } }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44).foregroundStyle(Aurora.textMuted)
                    }
                    .accessibilityLabel("Actions for \(f.itemName)")
                }
                .frame(minHeight: 56)
                Divider().overlay(Aurora.hairline)
            }
            HStack {
                Text("Foods total").font(.system(size: 17, weight: .semibold))
                Spacer()
                let c = foods.reduce(0) { $0 + ($1.calories ?? 0) }, p = foods.reduce(0) { $0 + ($1.protein ?? 0) }
                Text("\(c) kcal · \(p) g").font(.system(size: 17, weight: .semibold)).foregroundStyle(Aurora.nutrition).monospacedDigit()
            }
            .padding(.top, 8)
        }
        .auroraCard()
    }
}

private struct TargetsCard: View {
    @Environment(FuelStore.self) private var fuel
    @State private var calories = ""
    @State private var protein = ""
    @State private var water = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily targets").font(.system(size: 22, weight: .semibold))
                Text("Used by the rings on Today and Fuel.").font(.system(size: 15)).foregroundStyle(Aurora.textMuted)
            }
            HStack(spacing: 12) {
                AuroraField(title: "Calories", text: $calories, keyboard: .numberPad, unit: "kcal")
                AuroraField(title: "Protein", text: $protein, keyboard: .numberPad, unit: "g")
            }
            AuroraField(title: "Water", text: $water, keyboard: .numberPad, unit: "oz")
            Button("Save targets") {
                guard let c = intValue(calories), let p = intValue(protein), let w = intValue(water) else { return }
                Task { await fuel.saveTargets(calories: c, protein: p, water: w) }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .auroraCard()
        .onAppear(perform: fill)
        .onChange(of: fuel.settings.calorieTarget) { _, _ in fill() }
    }

    private func fill() {
        calories = String(fuel.calorieTarget); protein = String(fuel.proteinTarget); water = String(fuel.waterTarget)
    }
}

/// Wraps children onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
    }
}
