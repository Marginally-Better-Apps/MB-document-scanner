import CoreImage
import UIKit
import XCTest
@testable import MBDocumentScanner

final class DocumentAnalyzerTests: XCTestCase {
    func testClearDocumentPassesTextRegionChecks() async {
        let analysis = await DocumentAnalyzer().analyze(image: makeDocumentImage())

        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "contrast" })?.status, .passed)
        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "sharpness" })?.status, .passed)
        XCTAssertFalse(analysis.recognizedText.isEmpty)
    }

    func testClearDocumentCanBeRecognizedWithoutLanguageCorrection() async {
        let analysis = await DocumentAnalyzer().analyze(
            image: makeDocumentImage(),
            usesLanguageCorrection: false
        )

        XCTAssertTrue(analysis.recognizedText.contains("OPENSCAN DOCUMENT"))
        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "text" })?.status, .passed)
    }

    func testBlurredDocumentIsFlaggedForReview() async throws {
        let original = makeDocumentImage()
        let input = CIImage(image: original)!
        let blurred = input
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 4])
            .cropped(to: input.extent)
        let context = CIContext()
        let output = try XCTUnwrap(context.createCGImage(blurred, from: input.extent))

        let analysis = await DocumentAnalyzer().analyze(image: UIImage(cgImage: output))

        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "sharpness" })?.status, .warning)
        XCTAssertTrue(analysis.quality.needsReview)
    }

    func testSmallClearScreenshotsDoNotTriggerWarningsInLightOrDarkMode() async {
        for dark in [false, true] {
            let analysis = await DocumentAnalyzer().analyze(image: makeScreenshot(dark: dark))

            XCTAssertTrue(analysis.recognizedText.contains("Quarterly report"))
            XCTAssertEqual(analysis.quality.title, "Looks Good", "Checks: \(analysis.quality.checks)")
            XCTAssertFalse(analysis.quality.needsReview)
        }
    }

    func testSparseTextIsNotPenalizedForBlankMargins() async {
        let analysis = await DocumentAnalyzer().analyze(image: makeScreenshot(sparse: true))

        XCTAssertFalse(analysis.recognizedText.isEmpty)
        XCTAssertEqual(analysis.quality.title, "Looks Good", "Checks: \(analysis.quality.checks)")
    }

    func testFaintTextHasAContrastWarningWhenDetected() async {
        let analysis = await DocumentAnalyzer().analyze(image: makeScreenshot(faint: true))

        XCTAssertFalse(analysis.recognizedText.isEmpty)
        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "contrast" })?.status, .warning)
        XCTAssertTrue(analysis.quality.needsReview)
    }

    func testBlankPageIsNotGradedAsBadOrReportedAsPassing() async {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }

        let analysis = await DocumentAnalyzer().analyze(image: image)

        XCTAssertTrue(analysis.recognizedText.isEmpty)
        XCTAssertTrue(analysis.quality.checks.allSatisfy { $0.status == .notEvaluated })
        XCTAssertFalse(analysis.quality.needsReview)
        XCTAssertEqual(analysis.quality.title, "Check Visually")
    }

    func testSeverelyBlurredPageIsNotReportedAsLookingGood() async throws {
        let input = try XCTUnwrap(CIImage(image: makeDocumentImage()))
        let blurred = input.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 22])
            .cropped(to: input.extent)
        let output = try XCTUnwrap(CIContext().createCGImage(blurred, from: input.extent))

        let analysis = await DocumentAnalyzer().analyze(image: UIImage(cgImage: output))

        XCTAssertNotEqual(analysis.quality.title, "Looks Good")
    }

    private func makeScreenshot(dark: Bool = false, sparse: Bool = false, faint: Bool = false) -> UIImage {
        let size = CGSize(width: 900, height: 650)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            (dark ? UIColor(white: 0.06, alpha: 1) : UIColor.white).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let color = faint ? UIColor(white: 0.92, alpha: 1) : (dark ? .white : UIColor.black)
            "Quarterly report".draw(at: CGPoint(x: 40, y: 35), withAttributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                .foregroundColor: color
            ])
            if !sparse {
                for row in 0..<14 {
                    "Revenue and expenses for this quarter are ready to review.".draw(
                        at: CGPoint(x: 40, y: 110 + row * 28),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: color]
                    )
                }
            }
        }
    }

    private func makeDocumentImage() -> UIImage {
        let size = CGSize(width: 1_600, height: 2_200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let heading = "OPENSCAN DOCUMENT"
            heading.draw(
                at: CGPoint(x: 130, y: 140),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 72, weight: .bold),
                    .foregroundColor: UIColor.black
                ]
            )

            let paragraph = "This is a clear test page for private on-device optical character recognition."
            for row in 0..<14 {
                paragraph.draw(
                    at: CGPoint(x: 130, y: 310 + CGFloat(row * 105)),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 42),
                        .foregroundColor: UIColor.black
                    ]
                )
            }
        }
    }
}
