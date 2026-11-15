import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum ServiceError: LocalizedError {
    case badResponse(Int)
    case noScreen
    case undecodableImage

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): "O servidor respondeu com status \(code)."
        case .noScreen: "Nenhuma tela disponível."
        case .undecodableImage: "Não foi possível processar a imagem."
        }
    }
}

struct FeedPage: Sendable {
    let items: [Wallpaper]
    let next: String?
}

struct WallcraftClient: Sendable {
    static let shared = WallcraftClient()
    static let resolution = "3840x2160"

    let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["User-Agent": "Pane/0.1 (macOS wallpaper app)"]
        configuration.timeoutIntervalForRequest = 30
        configuration.urlCache = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 1024 * 1024 * 1024)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()

    func page(category: WallCategory, continueToken: String?) async throws -> FeedPage {
        let number = continueToken.flatMap(Int.init) ?? 1
        let listing = try await listing(category: category, page: number)
        let hasMore = !listing.items.isEmpty && number < listing.lastPage
        return FeedPage(items: listing.items, next: hasMore ? String(number + 1) : nil)
    }

    func randomSlice(category: WallCategory) async throws -> [Wallpaper] {
        let first = try await listing(category: category, page: 1)
        let last = min(first.lastPage, 300)
        guard last > 1 else { return first.items }
        let slice = try await listing(category: category, page: .random(in: 2...last))
        return slice.items.isEmpty ? first.items : slice.items
    }

    func credit(for wallpaper: Wallpaper) async throws -> (author: String, license: String) {
        var request = URLRequest(url: wallpaper.pageURL)
        request.cachePolicy = .returnCacheDataElseLoad
        let html = try await text(for: request)
        let author = Self.firstMatch(#"author__row">\s*Author:\s*([^<]+)<"#, in: html) ?? ""
        let license = Self.firstMatch(#"author__row">\s*License:\s*([^<]*)<"#, in: html) ?? ""
        return (author, license)
    }

    func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ServiceError.badResponse(http.statusCode)
        }
        return data
    }

    private func listing(category: WallCategory, page: Int) async throws -> (items: [Wallpaper], lastPage: Int) {
        var path = "https://wallpaperscraft.com/\(category.wallcraftPath)/\(Self.resolution)"
        if page > 1 { path += "/page\(page)" }
        var request = URLRequest(url: URL(string: path)!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let html = try await text(for: request)
        let items = Self.wallpapers(in: html)
        let pages = Self.allMatches(#"/page(\d+)""#, in: html).compactMap(Int.init)
        return (items, max(pages.max() ?? page, page))
    }

    private func text(for request: URLRequest) async throws -> String {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ServiceError.badResponse(http.statusCode)
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func wallpapers(in html: String) -> [Wallpaper] {
        let pattern = #"href="/download/([a-z0-9_]+)/(\d+)x(\d+)".*?wallpapers__info">([^<]+)</span>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let slugRange = Range(match.range(at: 1), in: html),
                  let widthRange = Range(match.range(at: 2), in: html),
                  let heightRange = Range(match.range(at: 3), in: html),
                  let tagsRange = Range(match.range(at: 4), in: html),
                  let width = Int(html[widthRange]),
                  let height = Int(html[heightRange]) else { return nil }
            let slug = String(html[slugRange])
            let tags = plainText(String(html[tagsRange]))
            guard let original = URL(string: "https://images.wallpaperscraft.com/image/single/\(slug)_\(width)x\(height).jpg"),
                  let page = URL(string: "https://wallpaperscraft.com/wallpaper/\(slug)") else { return nil }
            return Wallpaper(
                id: slug,
                title: tags.prefix(1).uppercased() + tags.dropFirst(),
                author: "",
                license: "",
                width: width,
                height: height,
                originalURL: original,
                thumbnailBase: nil,
                pageURL: page
            )
        }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        allMatches(pattern, in: text).first.map(plainText).flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func allMatches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    private static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

actor ImagePipeline {
    static let shared = ImagePipeline()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<NSImage, Error>] = [:]

    init() {
        cache.countLimit = 300
    }

    func image(for url: URL) async throws -> NSImage {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let running = inFlight[url] { return try await running.value }
        let task = Task<NSImage, Error> {
            let data = try await WallcraftClient.shared.fetch(url)
            guard let image = NSImage(data: data) else { throw ServiceError.undecodableImage }
            return image
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let image = try await task.value
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

enum ImageProcessor {
    private static let context = CIContext()

    static func render(_ data: Data, filters: ImageFilters) throws -> Data {
        guard filters.isActive else { return data }
        guard var image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw ServiceError.undecodableImage
        }
        let extent = image.extent
        if filters.grayscale {
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = image
            image = mono.outputImage ?? image
        }
        if filters.blur > 0 {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = image.clampedToExtent()
            blur.radius = Float(filters.blur) * Float(extent.width) / 400
            image = (blur.outputImage ?? image).cropped(to: extent)
        }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let output = context.jpegRepresentation(
            of: image,
            colorSpace: space,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92]
        ) else { throw ServiceError.undecodableImage }
        return output
    }
}

@MainActor
enum DesktopService {
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pane", isDirectory: true)
    }

    static var appliedDirectory: URL {
        supportDirectory.appendingPathComponent("Applied", isDirectory: true)
    }

    static var downloadsDirectory: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        return pictures.appendingPathComponent("Pane", isDirectory: true)
    }

    static func pixelSize(of screen: NSScreen) -> (Int, Int) {
        let size = screen.frame.size
        let scale = screen.backingScaleFactor
        return (Int(size.width * scale), Int(size.height * scale))
    }

    static func apply(_ wallpaper: Wallpaper, filters: ImageFilters, allScreens: Bool) async throws {
        let screens = allScreens ? NSScreen.screens : [NSScreen.main].compactMap { $0 }
        guard !screens.isEmpty else { throw ServiceError.noScreen }
        let widest = screens.map { pixelSize(of: $0).0 }.max() ?? 1920
        let raw = try await WallcraftClient.shared.fetch(wallpaper.url(forWidth: widest))
        let data = try await Task.detached(priority: .userInitiated) {
            try ImageProcessor.render(raw, filters: filters)
        }.value
        try FileManager.default.createDirectory(at: appliedDirectory, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970)
        let file = appliedDirectory.appendingPathComponent("\(wallpaper.id)\(filters.fileTag)-\(stamp).jpg")
        try data.write(to: file, options: .atomic)
        for screen in screens {
            try NSWorkspace.shared.setDesktopImageURL(file, for: screen, options: [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                .allowClipping: true,
            ])
        }
        pruneApplied(keeping: file)
    }

    static func save(_ wallpaper: Wallpaper, size: ExportSize, filters: ImageFilters) async throws -> URL {
        let width = size.targetWidth(for: wallpaper)
        let raw = try await WallcraftClient.shared.fetch(wallpaper.url(forWidth: width))
        let data = try await Task.detached(priority: .userInitiated) {
            try ImageProcessor.render(raw, filters: filters)
        }.value
        try FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        let file = downloadsDirectory.appendingPathComponent("pane-\(wallpaper.id)-\(size.rawValue)\(filters.fileTag).jpg")
        try data.write(to: file, options: .atomic)
        return file
    }

    private static func pruneApplied(keeping current: URL, limit: Int = 12) {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: appliedDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let sorted = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        for file in sorted.dropFirst(limit) where file != current {
            try? manager.removeItem(at: file)
        }
    }
}
