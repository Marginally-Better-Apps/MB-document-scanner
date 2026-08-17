import Foundation
import UIKit

enum ScanStorageError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: "A scanned page could not be saved."
        }
    }
}

struct ScanDocumentSnapshot {
    let id: UUID
    let title: String
    let createdAt: Date
    let modifiedAt: Date
    let pages: [ScannedPage]
}

final class ScanDocumentStore {
    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("MBDocumentScanner", isDirectory: true)
        .appendingPathComponent("Scans", isDirectory: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadAll() throws -> [ScanDocumentSnapshot] {
        guard fileManager.fileExists(atPath: rootURL.path) else { return [] }

        let folders = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return folders.compactMap { folder in
            try? loadDocument(from: folder)
        }
    }

    func save(_ snapshot: ScanDocumentSnapshot, forceImageIDs: Set<UUID> = []) throws {
        let documentFolder = folder(for: snapshot.id)
        let pagesFolder = documentFolder.appendingPathComponent("Pages", isDirectory: true)
        try fileManager.createDirectory(at: pagesFolder, withIntermediateDirectories: true)

        var storedPages: [StoredPage] = []
        var expectedImageNames = Set<String>()

        for page in snapshot.pages {
            let imageName = "\(page.id.uuidString).jpg"
            let imageURL = pagesFolder.appendingPathComponent(imageName)
            expectedImageNames.insert(imageName)

            if forceImageIDs.contains(page.id) || !fileManager.fileExists(atPath: imageURL.path) {
                guard let data = page.image.jpegData(compressionQuality: 0.96) else {
                    throw ScanStorageError.imageEncodingFailed
                }
                try data.write(to: imageURL, options: .atomic)
            }

            storedPages.append(StoredPage(
                id: page.id,
                imageName: imageName,
                recognizedText: page.recognizedText,
                quality: page.quality
            ))
        }

        if let existingImages = try? fileManager.contentsOfDirectory(
            at: pagesFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for imageURL in existingImages where !expectedImageNames.contains(imageURL.lastPathComponent) {
                try fileManager.removeItem(at: imageURL)
            }
        }

        let metadata = StoredDocument(
            id: snapshot.id,
            title: snapshot.title,
            createdAt: snapshot.createdAt,
            modifiedAt: snapshot.modifiedAt,
            pages: storedPages
        )
        let metadataURL = documentFolder.appendingPathComponent("metadata.json")
        try encoder.encode(metadata).write(to: metadataURL, options: .atomic)
    }

    func delete(documentID: UUID) throws {
        let documentFolder = folder(for: documentID)
        guard fileManager.fileExists(atPath: documentFolder.path) else { return }
        try fileManager.removeItem(at: documentFolder)
    }

    private func loadDocument(from folder: URL) throws -> ScanDocumentSnapshot {
        let metadataURL = folder.appendingPathComponent("metadata.json")
        let metadata = try decoder.decode(StoredDocument.self, from: Data(contentsOf: metadataURL))
        let pagesFolder = folder.appendingPathComponent("Pages", isDirectory: true)

        let pages = try metadata.pages.map { storedPage in
            let imageURL = pagesFolder.appendingPathComponent(storedPage.imageName)
            let data = try Data(contentsOf: imageURL)
            guard let image = UIImage(data: data) else {
                throw ScanStorageError.imageEncodingFailed
            }
            return ScannedPage(
                id: storedPage.id,
                image: image,
                recognizedText: storedPage.recognizedText,
                quality: storedPage.quality
            )
        }

        return ScanDocumentSnapshot(
            id: metadata.id,
            title: metadata.title,
            createdAt: metadata.createdAt,
            modifiedAt: metadata.modifiedAt,
            pages: pages
        )
    }

    private func folder(for documentID: UUID) -> URL {
        rootURL.appendingPathComponent(documentID.uuidString, isDirectory: true)
    }
}

private struct StoredDocument: Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let modifiedAt: Date
    let pages: [StoredPage]
}

private struct StoredPage: Codable {
    let id: UUID
    let imageName: String
    let recognizedText: String
    let quality: ScanQualityState
}
