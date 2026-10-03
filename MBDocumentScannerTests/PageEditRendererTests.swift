import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import MBDocumentScanner

@MainActor
final class PageEditRendererTests: XCTestCase {
    func testRenderPreservesSourcePixelResolutionAndPermanentlyRedactsPixels() throws {
        let source = makeImage(
            pointSize: CGSize(width: 120, height: 80),
            scale: 3,
            color: .systemRed
        )
        let sourceCGImage = try XCTUnwrap(source.cgImage)
        let redaction = PageRedactionEdit(
            frame: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        )

        let rendered = PageEditRenderer.render(
            image: source,
            drawing: PKDrawing(),
            drawingCanvasSize: source.size,
            textEdits: [],
            redactions: [redaction]
        )
        let renderedCGImage = try XCTUnwrap(rendered.cgImage)

        XCTAssertEqual(renderedCGImage.width, sourceCGImage.width)
        XCTAssertEqual(renderedCGImage.height, sourceCGImage.height)
        XCTAssertEqual(rendered.scale, 1)

        let pixels = try grayscalePixels(in: renderedCGImage)
        let interiorPoints = [
            CGPoint(x: 0.30, y: 0.30),
            CGPoint(x: 0.50, y: 0.50),
            CGPoint(x: 0.70, y: 0.70)
        ]

        for point in interiorPoints {
            XCTAssertEqual(
                pixels.value(atNormalized: point),
                0,
                "Every interior redaction pixel must be replaced by opaque black."
            )
        }

        XCTAssertGreaterThan(
            pixels.value(atNormalized: CGPoint(x: 0.10, y: 0.10)),
            32,
            "Pixels outside the redaction should retain source content."
        )
    }

    func testRedactionIsCompositedAboveTextMarkup() throws {
        let source = makeImage(
            pointSize: CGSize(width: 240, height: 160),
            scale: 1,
            color: .systemBlue
        )
        let sharedFrame = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let text = PageTextEdit(
            text: "Earlier markup",
            frame: sharedFrame,
            fontScale: 0.05,
            color: .white,
            hasBackground: true
        )

        let textOnly = PageEditRenderer.render(
            image: source,
            drawing: PKDrawing(),
            drawingCanvasSize: source.size,
            textEdits: [text],
            redactions: []
        )
        let redacted = PageEditRenderer.render(
            image: source,
            drawing: PKDrawing(),
            drawingCanvasSize: source.size,
            textEdits: [text],
            redactions: [PageRedactionEdit(frame: sharedFrame)]
        )

        let samplePoint = CGPoint(x: 0.5, y: 0.65)
        let textOnlyPixels = try grayscalePixels(in: XCTUnwrap(textOnly.cgImage))
        let redactedPixels = try grayscalePixels(in: XCTUnwrap(redacted.cgImage))

        XCTAssertGreaterThan(textOnlyPixels.value(atNormalized: samplePoint), 200)
        XCTAssertEqual(
            redactedPixels.value(atNormalized: samplePoint),
            0,
            "Redactions must be rendered last so earlier markup cannot remain visible."
        )
    }

    func testDrawingInputModesMapToExplicitPencilKitPolicies() {
        XCTAssertEqual(EditorDrawingInputMode.finger.pencilKitPolicy, .anyInput)
        XCTAssertEqual(EditorDrawingInputMode.pencil.pencilKitPolicy, .pencilOnly)
    }

    func testZoomedPageCoordinatesStayAlignedAfterPanning() throws {
        let controller = makeZoomController()
        let page = try XCTUnwrap(controller.viewForZooming(in: controller.scrollView))
        controller.scrollView.setZoomScale(3, animated: false)
        controller.scrollView.setContentOffset(CGPoint(x: 140, y: 210), animated: false)

        // A page-space location must map identically for the image, ink, and edit overlays.
        let pagePoint = CGPoint(x: 120, y: 160)
        let viewportPoint = page.convert(pagePoint, to: controller.view)
        XCTAssertEqual(viewportPoint.x, 220, accuracy: 0.001)
        XCTAssertEqual(viewportPoint.y, 270, accuracy: 0.001)
        let recoveredPoint = page.convert(viewportPoint, from: controller.view)
        XCTAssertEqual(recoveredPoint.x, pagePoint.x, accuracy: 0.001)
        XCTAssertEqual(recoveredPoint.y, pagePoint.y, accuracy: 0.001)

        let pageRect = page.convert(page.bounds, to: controller.view)
        XCTAssertEqual(pageRect.width, 900, accuracy: 0.001)
        XCTAssertEqual(pageRect.height, 1_200, accuracy: 0.001)
    }

    func testEditingContentDoesNotMoveOrResetTheZoomedPage() throws {
        let controller = makeZoomController()
        let page = try XCTUnwrap(controller.viewForZooming(in: controller.scrollView))
        controller.scrollView.setZoomScale(2.5, animated: false)
        controller.scrollView.setContentOffset(CGPoint(x: 130, y: 200), animated: false)
        let before = page.convert(CGPoint(x: 150, y: 200), to: controller.view)

        controller.update(content: .blue, pageSize: CGSize(width: 300, height: 400), resetID: 0)
        controller.view.layoutIfNeeded()

        let after = page.convert(CGPoint(x: 150, y: 200), to: controller.view)
        XCTAssertEqual(after.x, before.x, accuracy: 0.001)
        XCTAssertEqual(after.y, before.y, accuracy: 0.001)
        XCTAssertEqual(controller.scrollView.zoomScale, 2.5, accuracy: 0.001)
        XCTAssertEqual(controller.scrollView.contentOffset.x, 130, accuracy: 0.001)
        XCTAssertEqual(controller.scrollView.contentOffset.y, 200, accuracy: 0.001)
    }

    func testPinchKeepsThePageAnchorUnderTheMovingFingersAndLimitsZoom() throws {
        let controller = makeZoomController()
        let page = try XCTUnwrap(controller.viewForZooming(in: controller.scrollView))
        let anchor = CGPoint(x: 150, y: 180)
        let fingers = CGPoint(x: 190, y: 240)

        controller.zoom(to: 3, anchor: anchor, location: fingers)
        let visibleAnchor = page.convert(anchor, to: controller.view)
        XCTAssertEqual(visibleAnchor.x, fingers.x, accuracy: 0.001)
        XCTAssertEqual(visibleAnchor.y, fingers.y, accuracy: 0.001)

        controller.zoom(to: 20, anchor: anchor, location: fingers)
        XCTAssertEqual(controller.scrollView.zoomScale, 5, accuracy: 0.001)
        controller.zoom(to: 0.2, anchor: anchor, location: fingers)
        XCTAssertEqual(controller.scrollView.zoomScale, 1, accuracy: 0.001)
        XCTAssertTrue(controller.view.bounds.contains(page.convert(page.bounds, to: controller.view)))
    }

    func testResizingPreservesTheRelativePageLocationAtTheViewportCenter() throws {
        let controller = makeZoomController()
        let page = try XCTUnwrap(controller.viewForZooming(in: controller.scrollView))
        controller.scrollView.setZoomScale(3, animated: false)
        controller.scrollView.setContentOffset(CGPoint(x: 210, y: 420), animated: false)
        let before = relativePageCenter(page, in: controller.view)

        controller.view.frame.size = CGSize(width: 740, height: 880)
        controller.update(content: .blue, pageSize: CGSize(width: 600, height: 800), resetID: 0)
        controller.view.layoutIfNeeded()

        let after = relativePageCenter(page, in: controller.view)
        XCTAssertEqual(after.x, before.x, accuracy: 0.001)
        XCTAssertEqual(after.y, before.y, accuracy: 0.001)
        XCTAssertEqual(controller.scrollView.zoomScale, 3, accuracy: 0.001)
    }

    func testFitPageRestoresTheEntirePageCenteredInTheViewport() throws {
        let controller = makeZoomController()
        let page = try XCTUnwrap(controller.viewForZooming(in: controller.scrollView))
        controller.scrollView.setZoomScale(4, animated: false)
        controller.scrollView.setContentOffset(CGPoint(x: 250, y: 500), animated: false)

        controller.update(content: .blue, pageSize: CGSize(width: 300, height: 400), resetID: 1)
        controller.view.layoutIfNeeded()

        let visiblePage = page.convert(page.bounds, to: controller.view)
        XCTAssertEqual(visiblePage.minX, 30, accuracy: 0.001)
        XCTAssertEqual(visiblePage.minY, 60, accuracy: 0.001)
        XCTAssertEqual(visiblePage.width, 300, accuracy: 0.001)
        XCTAssertEqual(visiblePage.height, 400, accuracy: 0.001)
        XCTAssertTrue(controller.view.bounds.contains(visiblePage))
    }

    func testApplyEditClearsOCRAndForcesEditedImagePersistence() throws {
        let pageID = UUID()
        let original = makeImage(
            pointSize: CGSize(width: 20, height: 30),
            scale: 1,
            color: .white
        )
        let edited = makeImage(
            pointSize: CGSize(width: 20, height: 30),
            scale: 1,
            color: .black
        )
        let page = ScannedPage(
            id: pageID,
            image: original,
            recognizedText: "Sensitive OCR content",
            quality: .ready(checks: [])
        )
        let session = ScanSession(pages: [page])
        var persistenceRequests: [Set<UUID>] = []
        session.setChangeHandler { _, forceImageIDs in
            persistenceRequests.append(forceImageIDs)
        }

        session.applyEdit(pageID: pageID, image: edited)

        let updatedPage = try XCTUnwrap(session.page(withID: pageID))
        XCTAssertTrue(updatedPage.image === edited)
        XCTAssertEqual(updatedPage.recognizedText, "")
        XCTAssertEqual(updatedPage.quality, .analyzing)
        XCTAssertEqual(persistenceRequests, [Set([pageID])])
    }

    func testRedactedEditOverwritesStoredJPEGAndRemovesSensitiveOCRMetadata() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageEditPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let documentID = UUID()
        let pageID = UUID()
        let secret = "Secret account 9842-1138"
        let source = makeImage(
            pointSize: CGSize(width: 240, height: 180),
            scale: 1,
            color: .systemRed
        )
        let initialPage = ScannedPage(
            id: pageID,
            image: source,
            recognizedText: secret,
            quality: .ready(checks: [])
        )
        let store = ScanDocumentStore(rootURL: rootURL)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try store.save(ScanDocumentSnapshot(
            id: documentID,
            title: "Privacy Test",
            createdAt: date,
            modifiedAt: date,
            pages: [initialPage]
        ))

        let redactedImage = PageEditRenderer.render(
            image: source,
            drawing: PKDrawing(),
            drawingCanvasSize: source.size,
            textEdits: [],
            redactions: [PageRedactionEdit(
                frame: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
            )]
        )
        let session = ScanSession(
            id: documentID,
            title: "Privacy Test",
            createdAt: date,
            modifiedAt: date,
            pages: [initialPage]
        )
        var persistenceError: Error?
        session.setChangeHandler { changedSession, forceImageIDs in
            do {
                try store.save(
                    ScanDocumentSnapshot(
                        id: changedSession.id,
                        title: changedSession.title,
                        createdAt: changedSession.createdAt,
                        modifiedAt: changedSession.modifiedAt,
                        pages: changedSession.pages
                    ),
                    forceImageIDs: forceImageIDs
                )
            } catch {
                persistenceError = error
            }
        }

        session.applyEdit(pageID: pageID, image: redactedImage)
        session.setChangeHandler { _, _ in }

        XCTAssertNil(persistenceError)
        let restored = try XCTUnwrap(store.loadAll().first)
        let restoredPage = try XCTUnwrap(restored.pages.first)
        XCTAssertEqual(restoredPage.recognizedText, "")

        let metadataURL = rootURL
            .appendingPathComponent(documentID.uuidString, isDirectory: true)
            .appendingPathComponent("metadata.json")
        let metadata = try String(contentsOf: metadataURL, encoding: .utf8)
        XCTAssertFalse(metadata.contains(secret))

        let persistedPixels = try grayscalePixels(in: XCTUnwrap(restoredPage.image.cgImage))
        XCTAssertLessThan(
            persistedPixels.value(atNormalized: CGPoint(x: 0.5, y: 0.5)),
            12,
            "The stored JPEG must contain the flattened redaction, not the old source pixels."
        )
        XCTAssertGreaterThan(
            persistedPixels.value(atNormalized: CGPoint(x: 0.05, y: 0.05)),
            32
        )
    }

    private func makeZoomController() -> EditorZoomViewController<Color> {
        let controller = EditorZoomViewController(
            content: Color.white,
            pageSize: CGSize(width: 300, height: 400),
            resetID: 0
        )
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 360, height: 520)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return controller
    }

    private func relativePageCenter(_ page: UIView, in viewport: UIView) -> CGPoint {
        let center = CGPoint(x: viewport.bounds.midX, y: viewport.bounds.midY)
        let pagePoint = page.convert(center, from: viewport)
        return CGPoint(x: pagePoint.x / page.bounds.width, y: pagePoint.y / page.bounds.height)
    }

    private func makeImage(
        pointSize: CGSize,
        scale: CGFloat,
        color: UIColor
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: pointSize, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: pointSize))
        }
    }

    private func grayscalePixels(in image: CGImage) throws -> GrayscalePixels {
        let width = image.width
        let height = image.height
        var values = [UInt8](repeating: 0, count: width * height)
        let context = try XCTUnwrap(CGContext(
            data: &values,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return GrayscalePixels(width: width, height: height, values: values)
    }
}

private struct GrayscalePixels {
    let width: Int
    let height: Int
    let values: [UInt8]

    func value(atNormalized point: CGPoint) -> UInt8 {
        let x = min(max(Int(point.x * CGFloat(width)), 0), width - 1)
        let y = min(max(Int(point.y * CGFloat(height)), 0), height - 1)
        return values[y * width + x]
    }
}
