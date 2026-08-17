import UIKit
import XCTest
@testable import MBDocumentScanner

@MainActor
final class ScanSessionTests: XCTestCase {
    func testMovingPagesUpdatesTheirOrderAndPersistsTheChange() {
        let first = ScannedPage(image: makeImage())
        let second = ScannedPage(image: makeImage())
        let third = ScannedPage(image: makeImage())
        let session = ScanSession(pages: [first, second, third])
        var changeCount = 0
        session.setChangeHandler { _, _ in changeCount += 1 }

        XCTAssertTrue(session.movePage(first.id, toPositionOf: third.id))

        XCTAssertEqual(session.pages.map(\.id), [second.id, third.id, first.id])
        XCTAssertEqual(changeCount, 1)
    }

    func testMovingPageUpPlacesItBeforeTheTarget() {
        let first = ScannedPage(image: makeImage())
        let second = ScannedPage(image: makeImage())
        let third = ScannedPage(image: makeImage())
        let session = ScanSession(pages: [first, second, third])

        XCTAssertTrue(session.movePage(third.id, toPositionOf: first.id))

        XCTAssertEqual(session.pages.map(\.id), [third.id, first.id, second.id])
    }

    func testMovingPageOntoItselfDoesNothing() {
        let page = ScannedPage(image: makeImage())
        let session = ScanSession(pages: [page])

        XCTAssertFalse(session.movePage(page.id, toPositionOf: page.id))
        XCTAssertEqual(session.pages.map(\.id), [page.id])
    }

    func testRemovingPageUpdatesTheSessionAndPersistsTheChange() {
        let first = ScannedPage(image: makeImage())
        let second = ScannedPage(image: makeImage())
        let session = ScanSession(pages: [first, second])
        var changeCount = 0
        session.setChangeHandler { _, _ in changeCount += 1 }

        session.remove(pageID: first.id)

        XCTAssertEqual(session.pages.map(\.id), [second.id])
        XCTAssertEqual(changeCount, 1)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
    }
}
