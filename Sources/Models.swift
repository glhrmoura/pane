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

    static let wallcraftSizes = [(1280, 720), (1920, 1080), (2560, 1440), (3840, 2160)]

    var resolutionLabel: String { "\(width) × \(height)" }

    var isWallcraft: Bool { originalURL.host == "images.wallpaperscraft.com" }

    var sourceName: String { isWallcraft ? "Wallcraft" : "Wikimedia Commons" }

    var credit: String {
        if author.isEmpty { return "via \(sourceName)" }
        return license.isEmpty ? "foto de \(author)" : "foto de \(author) · \(license)"
    }

    func url(forWidth requested: Int) -> URL {
        if isWallcraft {
            let size = Self.wallcraftSizes.first { $0.0 >= requested && $0.0 <= width } ?? (width, height)
            let path = originalURL.absoluteString.replacingOccurrences(
                of: #"_\d+x\d+\.jpg$"#,
                with: "_\(size.0)x\(size.1).jpg",
                options: .regularExpression
            )
            return URL(string: path) ?? originalURL
        }
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
    case popular
    case nature
    case city
    case space
    case abstract
    case minimalism
    case dark
    case blackAndWhite
    case macro
    case flowers
    case animals
    case cars
    case art
    case fantasy
    case threeD
    case textures
    case vector
    case sport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "Novidades"
        case .popular: "Destaques"
        case .nature: "Natureza"
        case .city: "Cidades"
        case .space: "Espaço"
        case .abstract: "Abstrato"
        case .minimalism: "Minimalismo"
        case .dark: "Escuro"
        case .blackAndWhite: "Preto e branco"
        case .macro: "Macro"
        case .flowers: "Flores"
        case .animals: "Animais"
        case .cars: "Carros"
        case .art: "Arte"
        case .fantasy: "Fantasia"
        case .threeD: "3D"
        case .textures: "Texturas"
        case .vector: "Vetor"
        case .sport: "Esporte"
        }
    }

    var icon: String {
        switch self {
        case .recent: "sparkle"
        case .popular: "star"
        case .nature: "leaf"
        case .city: "building.2"
        case .space: "moon.stars"
        case .abstract: "scribble.variable"
        case .minimalism: "circle.and.line.horizontal"
        case .dark: "moon"
        case .blackAndWhite: "circle.lefthalf.filled"
        case .macro: "camera.macro"
        case .flowers: "camera.filters"
        case .animals: "pawprint"
        case .cars: "car"
        case .art: "paintpalette"
        case .fantasy: "wand.and.stars"
        case .threeD: "cube"
        case .textures: "square.grid.3x3"
        case .vector: "scribble"
        case .sport: "figure.run"
        }
    }

    var wallcraftPath: String {
        switch self {
        case .recent: "all/date"
        case .popular: "all"
        case .nature: "catalog/nature"
        case .city: "catalog/city"
        case .space: "catalog/space"
        case .abstract: "catalog/abstract"
        case .minimalism: "catalog/minimalism"
        case .dark: "catalog/dark"
        case .blackAndWhite: "catalog/black_and_white"
        case .macro: "catalog/macro"
        case .flowers: "catalog/flowers"
        case .animals: "catalog/animals"
        case .cars: "catalog/cars"
        case .art: "catalog/art"
        case .fantasy: "catalog/fantasy"
        case .threeD: "catalog/3d"
        case .textures: "catalog/textures"
        case .vector: "catalog/vector"
        case .sport: "catalog/sport"
        }
    }
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
