import AppKit
import Foundation
import Observation

private struct StoredState: Codable {
    var favorites: [Wallpaper] = []
    var history: [HistoryEntry] = []
    var category: WallCategory = .nature
    var applyToAllScreens = true
    var rotationEnabled = false
    var rotationMinutes = 30
    var rotationSource: RotationSource = .favorites
    var rotationCategory: WallCategory?
}

extension StoredState {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        favorites = (try? container.decode([Wallpaper].self, forKey: .favorites)) ?? []
        history = (try? container.decode([HistoryEntry].self, forKey: .history)) ?? []
        category = (try? container.decode(WallCategory.self, forKey: .category)) ?? .nature
        applyToAllScreens = (try? container.decode(Bool.self, forKey: .applyToAllScreens)) ?? true
        rotationEnabled = (try? container.decode(Bool.self, forKey: .rotationEnabled)) ?? false
        rotationMinutes = (try? container.decode(Int.self, forKey: .rotationMinutes)) ?? 30
        rotationSource = (try? container.decode(RotationSource.self, forKey: .rotationSource)) ?? .favorites
        rotationCategory = try? container.decode(WallCategory.self, forKey: .rotationCategory)
    }
}

struct CategoryFeed {
    var items: [Wallpaper] = []
    var next: String?
    var started = false
    var exhausted = false
    var error: String?
}

@Observable
@MainActor
final class AppModel {
    static let rotationOptions = [5, 15, 30, 60, 120, 360, 720, 1440]

    var feeds: [WallCategory: CategoryFeed] = [:]
    var loadingCategories: Set<WallCategory> = []
    var searchText = ""
    var selection: Wallpaper?
    var busyIDs: Set<String> = []
    var toast: String?
    var nextRotation: Date?
    var isTurning = false
    var credits: [String: Wallpaper] = [:]

    var category: WallCategory = .nature {
        didSet {
            persist()
            Task { await loadMore() }
        }
    }
    var favorites: [Wallpaper] = [] { didSet { persist() } }
    var history: [HistoryEntry] = [] { didSet { persist() } }
    var applyToAllScreens = true { didSet { persist() } }
    var rotationEnabled = false { didSet { persist(); scheduleRotation() } }
    var rotationMinutes = 30 { didSet { persist(); scheduleRotation() } }
    var rotationSource: RotationSource = .favorites { didSet { persist() } }
    var rotationCategory: WallCategory = .nature { didSet { persist() } }

    @ObservationIgnored private var restoring = false
    @ObservationIgnored private var rotationTask: Task<Void, Never>?
    @ObservationIgnored private let client = WallcraftClient.shared

    private var stateFile: URL {
        DesktopService.supportDirectory.appendingPathComponent("library.json")
    }

    init() {
        restore()
        scheduleRotation()
        Task { await loadMore() }
    }

    var current: HistoryEntry? { history.first }

    var feed: CategoryFeed { feeds[category] ?? CategoryFeed() }

    var isLoading: Bool { loadingCategories.contains(category) }

    var visibleItems: [Wallpaper] {
        filtered(feed.items)
    }

    func filtered(_ list: [Wallpaper]) -> [Wallpaper] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return list }
        return list.filter {
            $0.author.localizedCaseInsensitiveContains(query) || $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    func loadMore() async {
        let target = category
        var state = feeds[target] ?? CategoryFeed()
        guard !loadingCategories.contains(target), !state.exhausted else { return }
        loadingCategories.insert(target)
        defer { loadingCategories.remove(target) }
        state.error = nil
        let before = state.items.count
        var known = Set(state.items.map(\.id))
        do {
            var attempts = 0
            repeat {
                let page = try await client.page(category: target, continueToken: state.started ? state.next : nil)
                state.started = true
                for item in page.items where !known.contains(item.id) {
                    known.insert(item.id)
                    state.items.append(item)
                }
                state.next = page.next
                state.exhausted = page.next == nil
                attempts += 1
                feeds[target] = state
            } while !state.exhausted && state.items.count - before < 12 && attempts < 5
        } catch {
            state.error = error.localizedDescription
            feeds[target] = state
        }
    }

    func reload() async {
        feeds[category] = CategoryFeed()
        await loadMore()
    }

    func isFavorite(_ wallpaper: Wallpaper) -> Bool {
        favorites.contains { $0.id == wallpaper.id }
    }

    func withCredit(_ wallpaper: Wallpaper) async -> Wallpaper {
        guard wallpaper.isWallcraft, wallpaper.author.isEmpty else { return wallpaper }
        if let known = credits[wallpaper.id] { return known }
        guard let found = try? await client.credit(for: wallpaper), !found.author.isEmpty else { return wallpaper }
        let credited = Wallpaper(
            id: wallpaper.id,
            title: wallpaper.title,
            author: found.author,
            license: found.license,
            width: wallpaper.width,
            height: wallpaper.height,
            originalURL: wallpaper.originalURL,
            thumbnailBase: wallpaper.thumbnailBase,
            pageURL: wallpaper.pageURL
        )
        credits[wallpaper.id] = credited
        return credited
    }

    func toggleFavorite(_ wallpaper: Wallpaper) {
        if let index = favorites.firstIndex(where: { $0.id == wallpaper.id }) {
            favorites.remove(at: index)
            flash("Removida das salvas")
        } else {
            favorites.insert(wallpaper, at: 0)
            flash("Adicionada às salvas")
        }
    }

    func apply(_ wallpaper: Wallpaper, filters override: ImageFilters? = nil) async {
        let used = override ?? ImageFilters()
        busyIDs.insert(wallpaper.id)
        defer { busyIDs.remove(wallpaper.id) }
        do {
            try await DesktopService.apply(wallpaper, filters: used, allScreens: applyToAllScreens)
            let credited = await withCredit(wallpaper)
            history.removeAll { $0.wallpaper.id == wallpaper.id }
            history.insert(HistoryEntry(wallpaper: credited, filters: used, date: Date()), at: 0)
            if history.count > 100 { history.removeLast(history.count - 100) }
            flash("Papel de parede aplicado")
        } catch {
            flash("Falha ao aplicar: \(error.localizedDescription)")
        }
    }

    func download(_ wallpaper: Wallpaper, size: ExportSize, filters override: ImageFilters? = nil) async {
        busyIDs.insert(wallpaper.id)
        defer { busyIDs.remove(wallpaper.id) }
        do {
            let file = try await DesktopService.save(wallpaper, size: size, filters: override ?? ImageFilters())
            NSWorkspace.shared.activateFileViewerSelecting([file])
            flash("Salvo em Imagens/Pane")
        } catch {
            flash("Falha ao baixar: \(error.localizedDescription)")
        }
    }

    func applyRandom() async {
        guard !isTurning else { return }
        isTurning = true
        defer { isTurning = false }
        guard let pick = await randomCandidate() else {
            flash("Nada para sortear ainda")
            return
        }
        await apply(pick)
    }

    func clearHistory() {
        history = []
    }

    private func randomCandidate() async -> Wallpaper? {
        let currentID = current?.wallpaper.id
        func pick(_ pool: [Wallpaper]) -> Wallpaper? {
            let others = pool.filter { $0.id != currentID }
            return (others.isEmpty ? pool : others).randomElement()
        }
        if rotationSource == .favorites, !favorites.isEmpty {
            return pick(favorites)
        }
        let source = rotationSource == .everything
            ? WallCategory.allCases.randomElement() ?? category
            : rotationCategory
        if let slice = try? await client.randomSlice(category: source), let choice = pick(slice) {
            return choice
        }
        return pick(feed.items)
    }

    private func scheduleRotation() {
        rotationTask?.cancel()
        rotationTask = nil
        nextRotation = nil
        guard rotationEnabled else { return }
        let interval = TimeInterval(max(rotationMinutes, 1) * 60)
        nextRotation = Date().addingTimeInterval(interval)
        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self else { return }
                await self.applyRandom()
                self.nextRotation = Date().addingTimeInterval(interval)
            }
        }
    }

    func flash(_ message: String) {
        toast = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, self.toast == message else { return }
            self.toast = nil
        }
    }

    private func restore() {
        guard let data = try? Data(contentsOf: stateFile),
              let state = try? JSONDecoder().decode(StoredState.self, from: data) else { return }
        restoring = true
        favorites = state.favorites
        history = state.history
        applyToAllScreens = state.applyToAllScreens
        rotationMinutes = Self.rotationOptions.min { abs($0 - state.rotationMinutes) < abs($1 - state.rotationMinutes) } ?? 30
        rotationSource = state.rotationSource
        rotationCategory = state.rotationCategory ?? state.category
        rotationEnabled = state.rotationEnabled
        restoring = false
        category = state.category
    }

    private func persist() {
        guard !restoring else { return }
        let state = StoredState(
            favorites: favorites,
            history: history,
            category: category,
            applyToAllScreens: applyToAllScreens,
            rotationEnabled: rotationEnabled,
            rotationMinutes: rotationMinutes,
            rotationSource: rotationSource,
            rotationCategory: rotationCategory
        )
        do {
            try FileManager.default.createDirectory(at: DesktopService.supportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            try encoder.encode(state).write(to: stateFile, options: .atomic)
        } catch {
            toast = "Falha ao salvar biblioteca"
        }
    }
}
