import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    let openCatalog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CurrentPage(openCatalog: openCatalog)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .top, spacing: 40) {
                NextChangeBlock()
                    .frame(width: 330, alignment: .leading)
                ScheduleGrid()
            }
            .padding(.horizontal, 28)
            .padding(.top, 30)
            .padding(.bottom, 26)
        }
    }
}

struct CurrentPage: View {
    @Environment(AppModel.self) private var model
    let openCatalog: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(Palette.well)
            if let entry = model.current {
                RemoteImage(url: entry.wallpaper.previewURL, filters: entry.filters)
                    .id(entry.id)
                    .transition(.pageTurn)
                    .onTapGesture { model.selection = entry.wallpaper }
                    .pointingHand()
                    .overlay(alignment: .bottom) {
                        CreditLine(entry: entry)
                            .allowsHitTesting(false)
                    }
            } else {
                VStack(spacing: 14) {
                    Text("Nenhum papel de parede ainda")
                        .font(.display(40))
                        .foregroundStyle(Palette.ink)
                    Text("Sorteie uma foto ou escolha uma no catálogo.")
                        .font(.ui(14))
                        .foregroundStyle(Palette.inkSoft)
                    Button("Abrir o catálogo", action: openCatalog)
                        .buttonStyle(InkButtonStyle(prominent: false))
                        .padding(.top, 6)
                }
            }
        }
        .clipped()
        .animation(.spring(duration: 0.75, bounce: 0.05), value: model.current?.id)
    }
}

struct CreditLine: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(entry.wallpaper.title)
                .font(.captionStrong)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(entry.wallpaper.credit)
                .font(.caption1)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Spacer(minLength: 16)
            Text("Aplicado às \(entry.date.formatted(date: .omitted, time: .shortened))")
                .font(.caption1)
                .foregroundStyle(.white.opacity(0.75))
        }
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
        .padding(.horizontal, 28)
        .padding(.top, 40)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct NextChangeBlock: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            let label = overline(now: context.date)
            VStack(alignment: .leading, spacing: 0) {
                if let label {
                    Text(label)
                        .font(.ui(14, .medium))
                        .foregroundStyle(Palette.inkSoft)
                }
                Text(headline(now: context.date))
                    .font(.display(132, weight: 850))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, label == nil ? -24 : -12)
                    .padding(.bottom, -14)
                    .contentTransition(.numericText())
                if label == nil {
                    Text("Troca automática desligada. Troque o papel de parede quando quiser.")
                        .font(.ui(14, .medium))
                        .foregroundStyle(Palette.inkSoft)
                }
                HStack(spacing: 10) {
                    let busy = model.current.map { model.busyIDs.contains($0.wallpaper.id) } ?? false
                    Button {
                        Task { await model.applyRandom() }
                    } label: {
                        HStack(spacing: 8) {
                            if model.isTurning {
                                ProgressView().controlSize(.small).tint(Palette.paper)
                            }
                            Text("Trocar papel de parede")
                        }
                    }
                    .buttonStyle(InkButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.isTurning || busy)
                    if let current = model.current {
                        let favorite = model.isFavorite(current.wallpaper)
                        Button {
                            model.toggleFavorite(current.wallpaper)
                        } label: {
                            Image(systemName: favorite ? "heart.fill" : "heart")
                        }
                        .buttonStyle(InkButtonStyle(prominent: false))
                        .help(favorite ? "Remover das salvas" : "Salvar esta foto")
                    }
                }
                .padding(.top, 18)
            }
        }
    }

    private func headline(now: Date) -> String {
        if model.rotationEnabled, let next = model.nextRotation {
            return next.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        }
        return now.formatted(.dateTime.day(.twoDigits))
    }

    private func overline(now: Date) -> String? {
        guard model.rotationEnabled, let next = model.nextRotation else { return nil }
        return Calendar.current.isDate(next, inSameDayAs: now) ? "Próxima troca às" : "Próxima troca amanhã às"
    }
}

struct ScheduleSlot: Identifiable {
    enum Kind { case past, next, future, blank }

    let id: Int
    let kind: Kind
    let date: Date?
    let entry: HistoryEntry?
}

struct ScheduleGrid: View {
    @Environment(AppModel.self) private var model
    private let columns = 6
    private let rows = 3

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text(dayHeading)
                    .font(.display(28))
                    .foregroundStyle(Palette.ink)
                Spacer()
                InkSwitch(isOn: $model.rotationEnabled, label: "Troca automática")
            }
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                let slots = makeSlots()
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            SlotCell(slot: slots[row * columns + column])
                        }
                    }
                }
            }
            .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 2))
            HStack(alignment: .firstTextBaseline, spacing: 28) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("A cada")
                        .font(.caption1)
                        .foregroundStyle(Palette.inkFaint)
                    RotationIntervalMenu()
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Sortear de")
                        .font(.caption1)
                        .foregroundStyle(Palette.inkFaint)
                    RotationSourceMenu()
                }
            }
        }
    }

    private var dayHeading: String {
        let text = Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func makeSlots() -> [ScheduleSlot] {
        let total = columns * rows
        var slots: [ScheduleSlot] = []
        let interval = TimeInterval(model.rotationMinutes * 60)
        let pastLimit = model.rotationEnabled ? min(model.history.count, columns) : min(model.history.count, total)
        for entry in model.history.prefix(pastLimit).reversed() {
            slots.append(ScheduleSlot(id: slots.count, kind: .past, date: entry.date, entry: entry))
        }
        if model.rotationEnabled, let next = model.nextRotation {
            slots.append(ScheduleSlot(id: slots.count, kind: .next, date: next, entry: nil))
            var step = 1
            while slots.count < total {
                slots.append(ScheduleSlot(id: slots.count, kind: .future, date: next.addingTimeInterval(interval * Double(step)), entry: nil))
                step += 1
            }
        }
        while slots.count < total {
            slots.append(ScheduleSlot(id: slots.count, kind: .blank, date: nil, entry: nil))
        }
        return slots
    }
}

struct SlotCell: View {
    @Environment(AppModel.self) private var model
    let slot: ScheduleSlot

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Palette.paper)
            if let entry = slot.entry {
                RemoteImage(url: entry.wallpaper.thumbnailURL, filters: entry.filters)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture { model.selection = entry.wallpaper }
                    .pointingHand()
            }
            if let date = slot.date {
                label(for: date)
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .overlay(Rectangle().strokeBorder(Palette.rule, lineWidth: 0.5))
        .clipped()
    }

    @ViewBuilder
    private func label(for date: Date) -> some View {
        let text = Text(timeLabel(date)).font(.figures)
        switch slot.kind {
        case .past:
            text
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Palette.paper)
        case .next:
            text
                .foregroundStyle(Palette.now)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .overlay(
                    Ellipse()
                        .stroke(Palette.now, lineWidth: 2)
                        .rotationEffect(.degrees(-6))
                )
        case .future:
            text.foregroundStyle(Palette.inkFaint)
        case .blank:
            EmptyView()
        }
    }

    private func timeLabel(_ date: Date) -> String {
        if model.rotationMinutes < 1440 || Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        }
        return date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }
}

struct DropdownField<Panel: View>: View {
    let title: String
    @ViewBuilder let panel: (_ close: @escaping () -> Void) -> Panel
    @State private var hovering = false
    @State private var open = false

    var body: some View {
        Button {
            open.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(title)
                    .font(.ui(12, .semibold))
                Image(systemName: "chevron.down")
                    .font(.ui(7, .heavy))
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Palette.ink)
                    .frame(height: 1.5)
                    .opacity(hovering || open ? 1 : 0.35)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .animation(.spring(duration: 0.25), value: open)
        .popover(isPresented: $open, arrowEdge: .top) {
            panel { open = false }
        }
    }
}

struct RotationIntervalMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        DropdownField(title: intervalShortLabel(model.rotationMinutes)) { close in
            VStack(alignment: .leading, spacing: 10) {
                Text("Trocar a cada")
                    .font(.caption1)
                    .foregroundStyle(Palette.inkFaint)
                LazyVGrid(columns: [GridItem(.fixed(150), spacing: 6), GridItem(.fixed(150), spacing: 6)], spacing: 4) {
                    ForEach(AppModel.rotationOptions, id: \.self) { minutes in
                        SourceRow(
                            title: intervalShortLabel(minutes),
                            icon: intervalIcon(minutes),
                            selected: model.rotationMinutes == minutes
                        ) {
                            model.rotationMinutes = minutes
                            close()
                        }
                    }
                }
            }
            .padding(14)
            .background(Palette.paper)
        }
    }
}

struct RotationSourceMenu: View {
    @Environment(AppModel.self) private var model

    private var currentTitle: String {
        switch model.rotationSource {
        case .favorites: "Salvas"
        case .everything: "Tudo"
        case .category: model.rotationCategory.title
        }
    }

    var body: some View {
        DropdownField(title: currentTitle) { close in
            RotationSourcePicker(done: close)
        }
    }
}

struct RotationSourcePicker: View {
    @Environment(AppModel.self) private var model
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sortear de")
                .font(.caption1)
                .foregroundStyle(Palette.inkFaint)
            LazyVGrid(columns: columns, spacing: 4) {
                SourceRow(title: "Tudo", icon: "square.grid.2x2", selected: model.rotationSource == .everything) {
                    choose(.everything)
                }
                SourceRow(title: "Salvas", icon: "heart", selected: model.rotationSource == .favorites) {
                    choose(.favorites)
                }
            }
            Rectangle().fill(Palette.rule).frame(height: 1)
                .padding(.vertical, 2)
            Text("Categorias")
                .font(.caption1)
                .foregroundStyle(Palette.inkFaint)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(WallCategory.allCases) { item in
                    SourceRow(
                        title: item.title,
                        icon: item.icon,
                        selected: model.rotationSource == .category && model.rotationCategory == item
                    ) {
                        model.rotationCategory = item
                        choose(.category)
                    }
                }
            }
        }
        .padding(14)
        .background(Palette.paper)
    }

    private var columns: [GridItem] {
        [GridItem(.fixed(150), spacing: 6), GridItem(.fixed(150), spacing: 6)]
    }

    private func choose(_ source: RotationSource) {
        model.rotationSource = source
        done()
    }
}

struct SourceRow: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .symbolVariant(selected ? .fill : .none)
                    .font(.ui(13, .regular))
                    .frame(width: 18, height: 18)
                Text(title)
                    .font(.ui(13, .medium))
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.ui(10, .bold))
                }
            }
            .foregroundStyle(selected || hovering ? Palette.ink : Palette.inkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected || hovering ? Palette.well : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}
