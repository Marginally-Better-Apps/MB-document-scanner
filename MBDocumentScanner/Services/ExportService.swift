import Foundation
import PDFKit
import UIKit

enum ExportError: LocalizedError {
    case noPages
    case imageConversionFailed
    case pdfCreationFailed

    var errorDescription: String? {
        switch self {
        case .noPages: "There are no pages to export."
        case .imageConversionFailed: "A page could not be prepared for export."
        case .pdfCreationFailed: "The PDF could not be created."
        }
    }
}

enum ExportService {
    static func export(
        pages: [ScannedPage],
        title: String,
        format: ExportFormat,
        compression: CompressionPreset
    ) async throws -> [URL] {
        guard !pages.isEmpty else { throw ExportError.noPages }

        return try await Task.detached(priority: .userInitiated) {
            let folder = try makeExportFolder()
            switch format {
            case .pdf:
                return [try createPDF(pages: pages, title: title, compression: compression, in: folder)]
            case .images:
                return try createImages(pages: pages, title: title, compression: compression, in: folder)
            }
        }.value
    }

    private static func createPDF(
        pages: [ScannedPage],
        title: String,
        compression: CompressionPreset,
        in folder: URL
    ) throws -> URL {
        let document = PDFDocument()

        for (index, page) in pages.enumerated() {
            guard let data = preparedJPEGData(from: page.image, compression: compression),
                  let image = UIImage(data: data),
                  let pdfPage = PDFPage(image: image) else {
                throw ExportError.imageConversionFailed
            }
            pdfPage.setBounds(pdfPage.bounds(for: .mediaBox), for: .cropBox)
            document.insert(pdfPage, at: index)
        }

        let url = folder.appendingPathComponent("\(safeFilename(title)).pdf")
        guard document.write(to: url) else { throw ExportError.pdfCreationFailed }
        return url
    }

    private static func createImages(
        pages: [ScannedPage],
        title: String,
        compression: CompressionPreset,
        in folder: URL
    ) throws -> [URL] {
        let baseName = safeFilename(title)
        return try pages.enumerated().map { index, page in
            guard let data = preparedJPEGData(from: page.image, compression: compression) else {
                throw ExportError.imageConversionFailed
            }
            let pageNumber = String(format: "%02d", index + 1)
            let url = folder.appendingPathComponent("\(baseName)-Page-\(pageNumber).jpg")
            try data.write(to: url, options: .atomic)
            return url
        }
    }

    static func preparedImage(from image: UIImage, compression: CompressionPreset) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longestSide = max(pixelWidth, pixelHeight)
        guard longestSide > compression.maximumPixelDimension else { return image }

        let ratio = compression.maximumPixelDimension / longestSide
        let outputSize = CGSize(
            width: max(1, floor(pixelWidth * ratio)),
            height: max(1, floor(pixelHeight * ratio))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: outputSize))
            image.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }

    private static func preparedJPEGData(
        from image: UIImage,
        compression: CompressionPreset
    ) -> Data? {
        preparedImage(from: image, compression: compression)
            .jpegData(compressionQuality: compression.jpegQuality)
    }

    private static func makeExportFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MBDocumentScanner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func safeFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "MB Document Scanner" : cleaned
    }
}
