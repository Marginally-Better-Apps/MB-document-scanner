import ImageIO
import UIKit
import UniformTypeIdentifiers

enum PasteboardImageImportError: LocalizedError {
    case imageTooLarge
    case noSupportedImages

    var errorDescription: String? {
        switch self {
        case .imageTooLarge:
            "An image on the clipboard is larger than the 150 MB import limit."
        case .noSupportedImages:
            "The clipboard does not contain a supported image or image file."
        }
    }
}

@MainActor
enum PasteboardImageImporter {
    private static let maximumImageDataSize = 150 * 1_024 * 1_024

    static func supportedContentLabel(in pasteboard: UIPasteboard = .general) -> String? {
        supportedContentLabel(
            for: pasteboard.types,
            hasImages: pasteboard.hasImages,
            hasURLs: pasteboard.hasURLs
        )
    }

    static func importImages(from pasteboard: UIPasteboard = .general) throws -> [UIImage] {
        let images = try importImages(from: pasteboard.items)
        if !images.isEmpty {
            return images
        }

        if let pastedImages = pasteboard.images, !pastedImages.isEmpty {
            return pastedImages
        }

        if let urls = pasteboard.urls {
            let fileImages = try urls.compactMap { try image(at: $0) }
            if !fileImages.isEmpty {
                return fileImages
            }
        }

        throw PasteboardImageImportError.noSupportedImages
    }

    static func supportedContentLabel(
        for typeIdentifiers: [String],
        hasImages: Bool,
        hasURLs: Bool
    ) -> String? {
        if let identifier = preferredImageType(in: typeIdentifiers) {
            return displayLabel(for: identifier)
        }
        if hasImages {
            return "Image"
        }
        if hasURLs {
            return "File"
        }
        return nil
    }

    static func importImages(from items: [[String: Any]]) throws -> [UIImage] {
        try items.compactMap { try image(from: $0) }
    }

    private static func image(from item: [String: Any]) throws -> UIImage? {
        for identifier in preferredFileURLTypes(in: Array(item.keys)) {
            guard let value = item[identifier], let url = fileURL(from: value) else { continue }
            if let image = try image(at: url) {
                return image
            }
        }

        for identifier in preferredImageTypes(in: Array(item.keys)) {
            guard let value = item[identifier] else { continue }

            if let image = value as? UIImage {
                return image
            }
            if let data = value as? Data, let image = try image(from: data) {
                return image
            }
            if let url = value as? URL, let image = try image(at: url) {
                return image
            }
            if let url = value as? NSURL, let image = try image(at: url as URL) {
                return image
            }
        }

        return item.values.compactMap { $0 as? UIImage }.first
    }

    private static func image(at url: URL) throws -> UIImage? {
        guard url.isFileURL else { return nil }

        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return nil
        }
        return try image(from: data)
    }

    private static func image(from data: Data) throws -> UIImage? {
        guard data.count <= maximumImageDataSize else {
            throw PasteboardImageImportError.imageTooLarge
        }
        guard CGImageSourceCreateWithData(data as CFData, nil) != nil else {
            return nil
        }
        return UIImage(data: data)
    }

    private static func fileURL(from value: Any) -> URL? {
        if let url = value as? URL {
            return url
        }
        if let url = value as? NSURL {
            return url as URL
        }
        if let string = value as? String {
            if let url = URL(string: string), url.isFileURL {
                return url
            }
            if string.hasPrefix("/") {
                return URL(fileURLWithPath: string)
            }
            return nil
        }
        if let data = value as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }

    private static func preferredImageType(in identifiers: [String]) -> String? {
        preferredImageTypes(in: identifiers).first
    }

    private static func preferredImageTypes(in identifiers: [String]) -> [String] {
        identifiers
            .filter(isImageType)
            .sorted { imageTypePriority($0) < imageTypePriority($1) }
    }

    private static func preferredFileURLTypes(in identifiers: [String]) -> [String] {
        identifiers.filter { identifier in
            identifier == UTType.fileURL.identifier
                || UTType(identifier)?.conforms(to: .fileURL) == true
        }
    }

    private static func isImageType(_ identifier: String) -> Bool {
        identifier == "com.apple.uikit.image"
            || UTType(identifier)?.conforms(to: .image) == true
    }

    private static func imageTypePriority(_ identifier: String) -> Int {
        switch identifier.lowercased() {
        case "public.heic": 0
        case "public.heif": 1
        case "public.jpeg": 2
        case "public.png": 3
        case "org.webmproject.webp": 4
        case "public.tiff": 5
        case "com.microsoft.bmp": 6
        case "com.compuserve.gif": 7
        case "com.apple.uikit.image": 9
        default: 8
        }
    }

    private static func displayLabel(for identifier: String) -> String {
        switch identifier.lowercased() {
        case "public.heic": "HEIC"
        case "public.heif": "HEIF"
        case "public.jpeg": "JPEG"
        case "public.png": "PNG"
        case "org.webmproject.webp": "WebP"
        case "public.tiff": "TIFF"
        case "com.microsoft.bmp": "BMP"
        case "com.compuserve.gif": "GIF"
        case "com.apple.uikit.image", UTType.image.identifier: "Image"
        default:
            UTType(identifier)?.preferredFilenameExtension?.uppercased() ?? "Image"
        }
    }
}
