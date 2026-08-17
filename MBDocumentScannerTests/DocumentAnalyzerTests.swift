import CoreImage
import UIKit
import XCTest
@testable import MBDocumentScanner

final class DocumentAnalyzerTests: XCTestCase {
    func testClearDocumentPassesCoreImageChecks() async {
        let analysis = await DocumentAnalyzer().analyze(image: makeDocumentImage())

        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "lighting" })?.passed, true)
        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "contrast" })?.passed, true)
        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "sharpness" })?.passed, true)
        XCTAssertFalse(analysis.recognizedText.isEmpty)
    }

    func testBlurredDocumentIsFlaggedForReview() async throws {
        let original = makeDocumentImage()
        let input = CIImage(image: original)!
        let blurred = input
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 22])
            .cropped(to: input.extent)
        let context = CIContext()
        let output = try XCTUnwrap(context.createCGImage(blurred, from: input.extent))

        let analysis = await DocumentAnalyzer().analyze(image: UIImage(cgImage: output))

        XCTAssertEqual(analysis.quality.checks.first(where: { $0.id == "sharpness" })?.passed, false)
        XCTAssertTrue(analysis.quality.needsReview)
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
