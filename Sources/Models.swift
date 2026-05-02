import AppKit
import Foundation

struct Wallpaper: Codable, Hashable, Identifiable, Sendable {
    static let standardWidths = [500, 960, 1280, 1920, 3840]

    let id: String
    let title: String
    let author: String
    let license: String
    let width: Int
    let height: Int
    let originalURL: URL
    let thumbnailBase: URL?
    let pageURL: URL

    var resolutionLabel: String { "\(width) × \(height)" }

    func url(forWidth requested: Int) -> URL {
        guard requested < width,
              let base = thumbnailBase,
              let step = Self.standardWidths.first(where: { $0 >= requested }),
              step < width else { return originalURL }
        let path = base.absoluteString.replacingOccurrences(
            of: #"/\d+px-"#,
            with: "/\(step)px-",
            options: .regularExpression
        )
        return URL(string: path) ?? originalURL
    }

    var thumbnailURL: URL { url(forWidth: 960) }
    var previewURL: URL { url(forWidth: 1920) }
}

struct ImageFilters: Codable, Hashable, Sendable {
    var grayscale = false
    var blur = 0

    var isActive: Bool { grayscale || blur > 0 }

    var fileTag: String {
        var tag = ""
        if grayscale { tag += "-mono" }
        if blur > 0 { tag += "-blur\(blur)" }
        return tag
    }
}

struct HistoryEntry: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    let wallpaper: Wallpaper
    let filters: ImageFilters
    let date: Date
}

enum WallCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case recent
    case landscapes
    case mountains
    case cityscapes
    case sunsets
    case lakes
    case forests
    case waterfalls
    case clouds
    case flowers
    case architecture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "Destaques"
        case .landscapes: "Paisagens"
        case .mountains: "Montanhas"
        case .cityscapes: "Cidades"
        case .sunsets: "Pôr do sol"
        case .lakes: "Lagos"
        case .forests: "Florestas"
        case .waterfalls: "Cachoeiras"
        case .clouds: "Céus"
        case .flowers: "Flores"
        case .architecture: "Arquitetura"
        }
    }

    var icon: String {
        switch self {
        case .recent: "star"
        case .landscapes: "photo"
        case .mountains: "mountain.2"
        case .cityscapes: "building.2"
        case .sunsets: "sunset"
        case .lakes: "water.waves"
        case .forests: "tree"
        case .waterfalls: "drop"
        case .clouds: "cloud"
        case .flowers: "camera.macro"
        case .architecture: "building.columns"
        }
    }

    var commonsCategory: String {
        switch self {
        case .recent: "Category:Featured pictures on Wikimedia Commons"
        case .landscapes: "Category:Featured pictures of landscapes"
        case .mountains: "Category:Featured pictures of mountains"
        case .cityscapes: "Category:Featured pictures of cityscapes"
        case .sunsets: "Category:Featured pictures of sunsets"
        case .lakes: "Category:Featured pictures of lakes"
        case .forests: "Category:Featured pictures of forests"
        case .waterfalls: "Category:Featured pictures of waterfalls"
        case .clouds: "Category:Featured pictures of clouds"
        case .flowers: "Category:Featured pictures of flowers"
        case .architecture: "Category:Featured pictures of architecture"
        }
    }

    var sortsByRecency: Bool { self == .recent }
}

enum RotationSource: String, Codable, CaseIterable, Identifiable {
    case everything
    case favorites
    case category

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites: "Salvas"
        case .category: "Uma categoria"
        case .everything: "Tudo"
        }
    }
}

enum ExportSize: String, CaseIterable, Identifiable {
    case screen
    case uhd4k
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screen: "Tela atual"
        case .uhd4k: "4K"
        case .original: "Original"
        }
    }

    @MainActor
    func targetWidth(for wallpaper: Wallpaper) -> Int {
        switch self {
        case .screen:
            guard let screen = NSScreen.main else { return wallpaper.width }
            return DesktopService.pixelSize(of: screen).0
        case .uhd4k: return 3840
        case .original: return wallpaper.width
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case today
    case catalog
    case saved
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Hoje"
        case .catalog: "Catálogo"
        case .saved: "Salvas"
        case .history: "Histórico"
        }
    }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
