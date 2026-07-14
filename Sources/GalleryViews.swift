import SwiftUI

struct RemoteImage: View {
    let url: URL
    var filters = ImageFilters()
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        Palette.well
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .grayscale(filters.grayscale ? 1 : 0)
                        .blur(radius: CGFloat(filters.blur) * 1.2, opaque: true)
                        .transition(.opacity)
                } else if failed {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .task(id: url) {
                failed = false
                do {
                    let loaded = try await ImagePipeline.shared.image(for: url)
                    withAnimation(.easeOut(duration: 0.3)) { image = loaded }
                } catch {
                    if !Task.isCancelled { failed = true }
                }
            }
    }
}

struct PageGrid<Footer: View>: View {
    @Environment(AppModel.self) private var model
    let items: [Wallpaper]
    var filters: ((Wallpaper) -> ImageFilters)?
    var caption: ((Wallpaper) -> String?)?
    var onReachEnd: (() -> Void)?
    @ViewBuilder var footer: () -> Footer

    private let columns = [GridItem(.adaptive(minimum: 230, maximum: 380), spacing: 26, alignment: .top)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 30) {
                ForEach(items) { wallpaper in
                    PageCard(
                        wallpaper: wallpaper,
                        filters: filters?(wallpaper) ?? ImageFilters(),
                        caption: caption?(wallpaper)
                    )
                    .onAppear {
                        if wallpaper.id == items.last?.id { onReachEnd?() }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            footer()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        }
        .scrollIndicators(.automatic)
    }
}

struct PageCard: View {
    @Environment(AppModel.self) private var model
    let wallpaper: Wallpaper
    let filters: ImageFilters
    var caption: String?
    @State private var hovering = false

    var body: some View {
        let busy = model.busyIDs.contains(wallpaper.id)
        let favorite = model.isFavorite(wallpaper)

        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(url: wallpaper.thumbnailURL, filters: filters)
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if hovering && !busy {
                        HStack(spacing: 0) {
                            ChipButton(icon: favorite ? "heart.fill" : "heart", help: favorite ? "Remover das salvas" : "Salvar") {
                                model.toggleFavorite(wallpaper)
                            }
                            Rectangle().fill(Palette.rule).frame(width: 1, height: 28)
                            ChipButton(icon: "menubar.dock.rectangle", help: "Usar como papel de parede") {
                                Task { await model.apply(wallpaper, filters: filters) }
                            }
                        }
                        .background(Palette.paper)
                        .padding(8)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                    }
                }
                .overlay {
                    if busy {
                        ZStack {
                            Palette.paper.opacity(0.55)
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .shadow(color: .black.opacity(hovering ? 0.22 : 0), radius: 16, x: 0, y: 10)
                .offset(y: hovering ? -4 : 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(wallpaper.title)
                    .font(.captionStrong)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if favorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.ink)
                }
            }
            Text(caption ?? wallpaper.author)
                .font(.caption1)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
                .padding(.top, -5)
        }
        .animation(.spring(duration: 0.3, bounce: 0.1), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.selection = wallpaper }
        .pointingHand()
        .contextMenu {
            Button("Usar como papel de parede") { Task { await model.apply(wallpaper, filters: filters) } }
            Button(favorite ? "Remover das salvas" : "Salvar") { model.toggleFavorite(wallpaper) }
            Menu("Baixar") {
                ForEach(ExportSize.allCases) { size in
                    Button(size.title) { Task { await model.download(wallpaper, size: size) } }
                }
            }
            Divider()
            Link("Ver no Wikimedia Commons", destination: wallpaper.pageURL)
        }
    }
}

struct ChipButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovering ? Palette.paper : Palette.ink)
                .frame(width: 30, height: 28)
                .background(hovering ? Palette.ink : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .help(help)
    }
}

struct SectionHeading: View {
    let title: String
    var count: Int?
    var trailing: AnyView?

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(title)
                .font(.display(52, weight: 850))
                .foregroundStyle(Palette.ink)
            if let count {
                Text("\(count)")
                    .font(.display(52, weight: 300))
                    .foregroundStyle(Palette.inkFaint)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }
}

struct BlankPage: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.display(36))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: 420, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(InkButtonStyle(prominent: false))
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 28)
        .padding(.top, 26)
    }
}

struct CatalogView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.inkFaint)
                    TextField("Título ou autor", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ink)
                    if !model.searchText.isEmpty {
                        Button {
                            model.searchText = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.inkSoft)
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                        .help("Limpar busca")
                    }
                }
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.ink).frame(height: 1)
                }
                .padding(.bottom, 18)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(WallCategory.allCases) { item in
                            CategoryIndexRow(item: item)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
            .frame(width: 196)
            .padding(.leading, 28)
            .padding(.trailing, 22)
            .padding(.top, 24)
            Rectangle().fill(Palette.rule).frame(width: 1)
            CatalogGrid()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct CategoryIndexRow: View {
    @Environment(AppModel.self) private var model
    let item: WallCategory
    @State private var hovering = false

    var body: some View {
        let selected = item == model.category
        Button {
            model.category = item
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.display(25, weight: selected ? 850 : 500))
                    .foregroundStyle(selected || hovering ? Palette.ink : Palette.inkSoft)
                Spacer()
                if selected, model.feed.items.count > 0 {
                    Text("\(model.feed.items.count)")
                        .font(.figures)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .padding(.vertical, 3)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Palette.ink)
                    .frame(width: 3)
                    .offset(x: -14)
                    .opacity(selected ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CatalogGrid: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let items = model.visibleItems
        let feed = model.feed
        Group {
            if items.isEmpty, let error = feed.error {
                BlankPage(
                    title: "O catálogo não carregou",
                    message: "O Wikimedia Commons não respondeu: \(error) Confira sua conexão e tente de novo.",
                    actionTitle: "Tentar de novo",
                    action: { Task { await model.reload() } }
                )
            } else if items.isEmpty && !model.searchText.isEmpty {
                BlankPage(
                    title: "Nada com “\(model.searchText)”",
                    message: "A busca olha só as fotos já carregadas em \(model.category.title). Role a categoria para carregar mais ou tente outro termo."
                )
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text("Carregando fotos de \(model.category.title.lowercased())")
                        .font(.caption1)
                        .foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PageGrid(items: items, onReachEnd: {
                    guard model.searchText.isEmpty else { return }
                    Task { await model.loadMore() }
                }) {
                    if model.isLoading {
                        ProgressView().controlSize(.small)
                    } else if feed.exhausted {
                        Text("Fim de \(model.category.title)")
                            .font(.display(22, weight: 500))
                            .foregroundStyle(Palette.inkFaint)
                    }
                }
                .id(model.category)
            }
        }
    }
}

struct SavedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Salvas", count: model.favorites.count)
            if model.favorites.isEmpty {
                BlankPage(
                    title: "Nenhuma foto salva",
                    message: "Passe o mouse numa foto do catálogo e clique no coração. As fotos salvas podem alimentar a troca automática."
                )
            } else {
                PageGrid(items: model.filtered(model.favorites)) { EmptyView() }
            }
        }
    }
}

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let entries = Dictionary(model.history.map { ($0.wallpaper.id, $0) }, uniquingKeysWith: { first, _ in first })
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                title: "Histórico",
                count: model.history.count,
                trailing: model.history.isEmpty ? nil : AnyView(
                    TextOption(title: "Limpar histórico", selected: false) { model.clearHistory() }
                )
            )
            if model.history.isEmpty {
                BlankPage(
                    title: "Nenhum papel de parede ainda",
                    message: "Cada papel de parede que você usar fica registrado aqui, com o dia e a hora."
                )
            } else {
                PageGrid(
                    items: model.filtered(model.history.map(\.wallpaper)),
                    filters: { entries[$0.id]?.filters ?? ImageFilters() },
                    caption: { wallpaper in
                        entries[wallpaper.id].map {
                            "\($0.date.formatted(.relative(presentation: .named))) · \(wallpaper.author)"
                        }
                    }
                ) { EmptyView() }
            }
        }
    }
}
