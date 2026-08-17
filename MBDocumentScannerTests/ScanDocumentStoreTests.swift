import UIKit
import XCTest
@testable import MBDocumentScanner

final class ScanDocumentStoreTests: XCTestCase {
    private var temporaryFolder: URL!

    override func setUpWithError() throws {
        temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MBDocumentScannerTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: temporaryFolder.path) {
            try FileManager.default.removeItem(at: temporaryFolder)
        }
    }

    func testDocumentRoundTripsWithPagesOCRAndQuality() throws {
        let store = ScanDocumentStore(rootURL: temporaryFolder)
        let documentID = UUID()
        let pageID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let quality = ScanQualityState.ready(score: 92, checks: [
            QualityCheck(
                id: "sharpness",
                title: "Sharpness",
                detail: "Text edges appear clear.",
                passed: true,
                isImportant: true,
                systemImage: "viewfinder"
            )
        ])
        let snapshot = ScanDocumentSnapshot(
            id: documentID,
            title: "Tax Receipt",
            createdAt: date,
            modifiedAt: date,
            pages: [
                ScannedPage(
                    id: pageID,
                    image: makeImage(),
                    recognizedText: "Receipt total $42.00",
                    quality: quality
                )
            ]
        )

        try store.save(snapshot)
        let restored = try XCTUnwrap(store.loadAll().first)

        XCTAssertEqual(restored.id, documentID)
        XCTAssertEqual(restored.title, "Tax Receipt")
        XCTAssertEqual(restored.pages.count, 1)
        XCTAssertEqual(restored.pages[0].id, pageID)
        XCTAssertEqual(restored.pages[0].recognizedText, "Receipt total $42.00")
        XCTAssertEqual(restored.pages[0].quality, quality)
    }

    func testDeletingDocumentRemovesItFromLibrary() throws {
        let store = ScanDocumentStore(rootURL: temporaryFolder)
        let snapshot = ScanDocumentSnapshot(
            id: UUID(),
            title: "Temporary Scan",
            createdAt: Date(),
            modifiedAt: Date(),
            pages: [ScannedPage(image: makeImage())]
        )

        try store.save(snapshot)
        try store.delete(documentID: snapshot.id)

        XCTAssertTrue(try store.loadAll().isEmpty)
    }

    private func makeImage() -> UIImage {
        let size = CGSize(width: 300, height: 420)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 30, y: 40, width: 240, height: 12))
        }
    }
}

