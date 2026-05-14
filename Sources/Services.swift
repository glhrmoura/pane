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

struct CommonsClient: Sendable {
    static let shared = CommonsClient()

    let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["User-Agent": "Pane/0.1 (macOS wallpaper app)"]
        configuration.timeoutIntervalForRequest = 30
        configuration.urlCache = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 1024 * 1024 * 1024)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()

    func page(category: WallCategory, continueToken: String?) async throws -> FeedPage {
        var extra: [URLQueryItem] = []
        if category.sortsByRecency {
            extra += [URLQueryItem(name: "gcmsort", value: "timestamp"), URLQueryItem(name: "gcmdir", value: "desc")]
        }
        if let continueToken {
            extra.append(URLQueryItem(name: "gcmcontinue", value: continueToken))
        }
        return try await query(category: category, extra: extra)
    }

    func randomSlice(category: WallCategory) async throws -> [Wallpaper] {
        let start = Date(timeIntervalSince1970: 1_230_768_000)
        let end = Date().addingTimeInterval(-30 * 86_400)
        let pick = Date(timeIntervalSince1970: .random(in: start.timeIntervalSince1970...end.timeIntervalSince1970))
        let stamp = ISO8601DateFormatter().string(from: pick)
        let slice = try await query(category: category, extra: [
            URLQueryItem(name: "gcmsort", value: "timestamp"),
            URLQueryItem(name: "gcmdir", value: "newer"),
            URLQueryItem(name: "gcmstart", value: stamp),
        ])
        if !slice.items.isEmpty { return slice.items }
        return try await page(category: category, continueToken: nil).items
    }

    func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ServiceError.badResponse(http.statusCode)
        }
        return data
    }

    private func query(category: WallCategory, extra: [URLQueryItem]) async throws -> FeedPage {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "generator", value: "categorymembers"),
            URLQueryItem(name: "gcmtitle", value: category.commonsCategory),
            URLQueryItem(name: "gcmtype", value: "file"),
            URLQueryItem(name: "gcmlimit", value: "50"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|size|mime|extmetadata"),
            URLQueryItem(name: "iiextmetadatafilter", value: "Artist|LicenseShortName|ObjectName"),
            URLQueryItem(name: "iiurlwidth", value: "960"),
        ] + extra
        var request = URLRequest(url: components.url!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ServiceError.badResponse(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(CommonsResponse.self, from: data)
        let items = (decoded.query?.pages ?? []).compactMap(Self.wallpaper(from:))
        return FeedPage(items: items, next: decoded.continuation?.gcmcontinue)
    }

    private static func wallpaper(from page: CommonsResponse.Page) -> Wallpaper? {
        guard let info = page.imageinfo?.first,
              ["image/jpeg", "image/png"].contains(info.mime ?? ""),
              info.width >= 1600,
              info.height > 0 else { return nil }
        let ratio = Double(info.width) / Double(info.height)
        guard (1.2...2.6).contains(ratio),
              let original = cleanURL(info.url),
              let pageURL = URL(string: info.descriptionurl) else { return nil }
        let title = info.extmetadata?["ObjectName"]?.value.map(plainText)
            ?? page.title.replacingOccurrences(of: "File:", with: "")
        let author = info.extmetadata?["Artist"]?.value.map(plainText) ?? "Autor desconhecido"
        return Wallpaper(
            id: String(page.pageid),
            title: title.isEmpty ? page.title : title,
            author: author.isEmpty ? "Autor desconhecido" : author,
            license: info.extmetadata?["LicenseShortName"]?.value.map(plainText) ?? "",
            width: info.width,
            height: info.height,
            originalURL: original,
            thumbnailBase: info.thumburl.flatMap(cleanURL),
            pageURL: pageURL
        )
    }

    private static func cleanURL(_ string: String) -> URL? {
        guard var components = URLComponents(string: string) else { return nil }
        components.query = nil
        return components.url
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

private struct CommonsResponse: Decodable {
    struct Continuation: Decodable {
        let gcmcontinue: String?
    }

    struct Meta: Decodable {
        let value: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try? container.decode(String.self, forKey: .value)
        }

        enum CodingKeys: String, CodingKey { case value }
    }

    struct Info: Decodable {
        let url: String
        let thumburl: String?
        let width: Int
        let height: Int
        let mime: String?
        let descriptionurl: String
        let extmetadata: [String: Meta]?
    }

    struct Page: Decodable {
        let pageid: Int
        let title: String
        let imageinfo: [Info]?
    }

    struct Query: Decodable {
        let pages: [Page]?
    }

    let query: Query?
    let continuation: Continuation?

    enum CodingKeys: String, CodingKey {
        case query
        case continuation = "continue"
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
            let data = try await CommonsClient.shared.fetch(url)
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
        let raw = try await CommonsClient.shared.fetch(wallpaper.url(forWidth: widest))
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
        let raw = try await CommonsClient.shared.fetch(wallpaper.url(forWidth: width))
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
