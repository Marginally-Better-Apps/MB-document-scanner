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

    func testAddingOrientedImagesPreservesPixelResolutionAcrossScales() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let original = UIGraphicsImageRenderer(
            size: CGSize(width: 24, height: 36),
            format: format
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 36))
        }
        let originalPixels = try XCTUnwrap(original.cgImage)
        let scales: [CGFloat] = [1, 2, 3]
        let orientations: [UIImage.Orientation] = [.right, .left, .down, .upMirrored]

        for scale in scales {
            for orientation in orientations {
                let input = UIImage(cgImage: originalPixels, scale: scale, orientation: orientation)
                let session = ScanSession()

                session.add([input])

                let normalized = try XCTUnwrap(session.pages.first?.image)
                let normalizedPixels = try XCTUnwrap(normalized.cgImage)
                XCTAssertEqual(normalized.imageOrientation, .up)
                XCTAssertEqual(normalized.scale, input.scale)
                XCTAssertEqual(normalized.size, input.size)
                XCTAssertEqual(normalizedPixels.width, Int(input.size.width * scale))
                XCTAssertEqual(normalizedPixels.height, Int(input.size.height * scale))
                XCTAssertEqual(
                    normalizedPixels.width * normalizedPixels.height,
                    originalPixels.width * originalPixels.height
                )
            }
        }
    }

    func testWarningsCanBeDismissedIndividuallyAndRestored() {
        let checks = ["sharpness", "contrast"].map {
            QualityCheck(id: $0, title: $0, detail: "Review this", status: .warning, systemImage: "eye")
        }
        let first = ScannedPage(image: makeImage(), quality: .ready(checks: checks))
        let second = ScannedPage(image: makeImage(), quality: .ready(checks: checks))
        let session = ScanSession(pages: [first, second])
        var changeCount = 0
        session.setChangeHandler { _, imageIDs in
            XCTAssertTrue(imageIDs.isEmpty)
            changeCount += 1
        }

        session.setWarningDismissed(true, checkID: "sharpness", pageID: first.id)
        XCTAssertEqual(session.pages[0].quality.activeWarnings.map(\.id), ["contrast"])
        XCTAssertEqual(session.pages[1].quality.activeWarnings.count, 2)
        XCTAssertEqual(session.pagesNeedingReview, 2)

        session.setWarningDismissed(true, checkID: "contrast", pageID: first.id)
        XCTAssertEqual(session.pages[0].quality.title, "Reviewed")
        XCTAssertEqual(session.pagesNeedingReview, 1)
        XCTAssertEqual(session.pages[0].quality.checks.map(\.status), [.warning, .warning])

        session.setWarningDismissed(false, checkID: "sharpness", pageID: first.id)
        XCTAssertEqual(session.pages[0].quality.title, "Needs Review")
        XCTAssertEqual(session.pagesNeedingReview, 2)
        XCTAssertEqual(changeCount, 3)

        session.setWarningDismissed(true, checkID: "missing", pageID: first.id)
        session.setWarningDismissed(true, checkID: "contrast", pageID: first.id)
        XCTAssertEqual(changeCount, 3)
    }

    func testEditingPageClearsDismissalsForTheChangedImage() {
        let warning = QualityCheck(
            id: "contrast", title: "Contrast", detail: "Faint text", status: .warning,
            systemImage: "eye", isDismissed: true
        )
        let page = ScannedPage(image: makeImage(), quality: .ready(checks: [warning]))
        let session = ScanSession(pages: [page])

        session.applyEdit(pageID: page.id, image: makeImage())

        XCTAssertEqual(session.pages[0].quality, .analyzing)
        XCTAssertTrue(session.pages[0].quality.dismissedWarnings.isEmpty)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
    }
}
