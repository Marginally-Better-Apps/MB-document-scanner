import SwiftUI
import UIKit

@MainActor
final class ScanSession: ObservableObject, Identifiable {
    let id: UUID
    let createdAt: Date

    @Published private(set) var pages: [ScannedPage]
    @Published private(set) var title: String
    @Published private(set) var modifiedAt: Date

    private let analyzer = DocumentAnalyzer()
    private var changeHandler: ((ScanSession, Set<UUID>) -> Void)?

    init(
        id: UUID = UUID(),
        title: String = "New Scan",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        pages: [ScannedPage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.pages = pages
    }

    var isEmpty: Bool { pages.isEmpty }

    var pagesNeedingReview: Int {
        pages.filter(\.quality.needsReview).count
    }

    var thumbnail: UIImage? {
        pages.first?.image
    }

    func setChangeHandler(_ handler: @escaping (ScanSession, Set<UUID>) -> Void) {
        changeHandler = handler
    }

    func resumePendingAnalysis() {
        for page in pages where page.quality == .analyzing {
            analyze(pageID: page.id, image: page.image)
        }
    }

    func rename(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != title else { return }
        title = trimmed
        documentChanged()
    }

    func add(_ images: [UIImage]) {
        let newPages = images.map { ScannedPage(image: $0.normalizedOrientation()) }
        guard !newPages.isEmpty else { return }
        pages.append(contentsOf: newPages)
        documentChanged()

        for page in newPages {
            analyze(pageID: page.id, image: page.image)
        }
    }

    func remove(pageID: UUID) {
        let oldCount = pages.count
        pages.removeAll { $0.id == pageID }
        if pages.count != oldCount { documentChanged() }
    }

    @discardableResult
    func movePage(_ pageID: UUID, toPositionOf targetPageID: UUID) -> Bool {
        guard let sourceIndex = pages.firstIndex(where: { $0.id == pageID }),
              let targetIndex = pages.firstIndex(where: { $0.id == targetPageID }),
              sourceIndex != targetIndex else { return false }

        pages.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        )
        documentChanged()
        return true
    }

    func rotate(pageID: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        let rotated = pages[index].image.rotatedClockwise()
        pages[index].image = rotated
        pages[index].recognizedText = ""
        pages[index].quality = .analyzing
        documentChanged(forceImageIDs: [pageID])
        analyze(pageID: pageID, image: rotated)
    }

    func applyCrop(pageID: UUID, image: UIImage) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        pages[index].image = image
        pages[index].recognizedText = ""
        pages[index].quality = .analyzing
        documentChanged(forceImageIDs: [pageID])
        analyze(pageID: pageID, image: image)
    }

    func page(withID id: UUID) -> ScannedPage? {
        pages.first { $0.id == id }
    }

    func pageNumber(for id: UUID) -> Int? {
        pages.firstIndex(where: { $0.id == id }).map { $0 + 1 }
    }

    private func analyze(pageID: UUID, image: UIImage) {
        Task {
            let analysis = await analyzer.analyze(image: image)
            guard let index = pages.firstIndex(where: { $0.id == pageID }),
                  pages[index].image === image else { return }
            pages[index].recognizedText = analysis.recognizedText
            pages[index].quality = analysis.quality
            changeHandler?(self, [])
        }
    }

    private func documentChanged(forceImageIDs: Set<UUID> = []) {
        modifiedAt = Date()
        changeHandler?(self, forceImageIDs)
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func rotatedClockwise() -> UIImage {
        let outputSize = CGSize(width: size.height, height: size.width)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            cgContext.rotate(by: .pi / 2)
            draw(in: CGRect(
                x: -size.width / 2,
                y: -size.height / 2,
                width: size.width,
                height: size.height
            ))
        }
    }
}
