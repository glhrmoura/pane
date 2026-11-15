import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var section: SidebarItem = .today
    @State private var forward = true

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            TopBar(section: section) { target in
                forward = target.order >= section.order
                withAnimation(.spring(duration: 0.45, bounce: 0.08)) { section = target }
            }
            ZStack {
                switch section {
                case .today: TodayView(openCatalog: { open(.catalog) })
                        .transition(.push(from: forward ? .trailing : .leading))
                case .catalog: CatalogView()
                        .transition(.push(from: forward ? .trailing : .leading))
                case .saved: SavedView()
                        .transition(.push(from: forward ? .trailing : .leading))
                case .history: HistoryView()
                        .transition(.push(from: forward ? .trailing : .leading))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background(Palette.paper)
        .ignoresSafeArea(edges: .top)
        .tint(Palette.ink)
        .sheet(item: $model.selection) { wallpaper in
            DetailView(
                wallpaper: wallpaper,
                filters: model.current?.wallpaper.id == wallpaper.id ? model.current?.filters ?? ImageFilters() : ImageFilters()
            )
            .environment(model)
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                PaperSlip(text: toast)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: model.toast)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            AppDelegate.openMainWindow = { [openWindow] in openWindow(id: "main") }
        }
    }

    private func open(_ target: SidebarItem) {
        forward = target.order >= section.order
        withAnimation(.spring(duration: 0.45, bounce: 0.08)) { section = target }
    }
}

struct TopBar: View {
    let section: SidebarItem
    let select: (SidebarItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 31)
            HStack(alignment: .center, spacing: 26) {
                HStack(alignment: .lastTextBaseline, spacing: 26) {
                    Text("Pane")
                        .font(.display(34, weight: 900))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    ForEach(SidebarItem.allCases) { item in
                        NavTab(title: item.title, selected: item == section) {
                            select(item)
                        }
                        .keyboardShortcut(KeyEquivalent(Character(String(item.order + 1))), modifiers: .command)
                    }
                }
                SettingsButton()
                .padding(.top, 6)
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
    }
}

struct NavTab: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.display(21, weight: 600))
                .foregroundStyle(selected || hovering ? Palette.ink : Palette.inkSoft)
                .padding(.bottom, 3)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(height: selected ? 2 : 0)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SettingsButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: "settings")
        } label: {
            TopIcon(icon: "gearshape", active: false, badge: false)
        }
        .buttonStyle(.plain)
        .pointingHand()
        .help("Configurações")
    }
}

struct TopIcon: View {
    let icon: String
    let active: Bool
    let badge: Bool
    @State private var hovering = false

    var body: some View {
        let lit = active || hovering
        Image(systemName: icon)
            .font(.ui(13, .medium))
            .foregroundStyle(lit ? Palette.paper : Palette.ink)
            .frame(width: 32, height: 32)
            .background(lit ? Palette.ink : Color.clear)
            .overlay(Rectangle().strokeBorder(lit ? Palette.ink : Palette.rule, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if badge {
                    Circle()
                        .fill(Palette.now)
                        .frame(width: 7, height: 7)
                        .offset(x: 3, y: -3)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: lit)
    }
}

struct ClearFiltersButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.ui(11, .semibold))
                .foregroundStyle(hovering ? Palette.paper : Palette.ink)
                .frame(width: 22, height: 22)
                .background(hovering ? Palette.ink : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .help("Limpar filtros")
    }
}
