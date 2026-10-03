import PhotosUI
import SwiftUI
import UIKit

enum PhotoLibraryImageImportError: LocalizedError, Equatable {
    case unavailablePhoto(Int)
    case unsupportedPhoto(Int)
    case imageTooLarge(Int)

    var errorDescription: String? {
        switch self {
        case let .unavailablePhoto(number):
            "Photo \(number) could not be loaded. If it is stored in iCloud, check your connection and try again."
        case let .unsupportedPhoto(number):
            "Photo \(number) could not be opened as an image. Please choose another photo."
        case let .imageTooLarge(number):
            "Photo \(number) is larger than the 150 MB import limit."
        }
    }
}

enum PhotoLibraryImageImporter {
    private static let maximumImageDataSize = 150 * 1_024 * 1_024

    static func importImages(from items: [PhotosPickerItem]) async throws -> [UIImage] {
        try await importImages(from: items) { item in
            try await item.loadTransferable(type: Data.self)
        }
    }

    static func importImages<Item>(
        from items: [Item],
        loadData: (Item) async throws -> Data?
    ) async throws -> [UIImage] {
        var images: [UIImage] = []
        images.reserveCapacity(items.count)

        // Load one at a time to preserve selection order and avoid keeping all
        // of the original photo data in memory alongside the decoded images.
        for (index, item) in items.enumerated() {
            try Task.checkCancellation()
            let photoNumber = index + 1
            let data: Data?
            do {
                data = try await loadData(item)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
                throw PhotoLibraryImageImportError.unavailablePhoto(photoNumber)
            }

            try Task.checkCancellation()
            guard let data else {
                throw PhotoLibraryImageImportError.unavailablePhoto(photoNumber)
            }
            guard data.count <= maximumImageDataSize else {
                throw PhotoLibraryImageImportError.imageTooLarge(photoNumber)
            }
            guard let image = UIImage(data: data) else {
                throw PhotoLibraryImageImportError.unsupportedPhoto(photoNumber)
            }
            images.append(image)
        }

        try Task.checkCancellation()
        return images
    }
}
