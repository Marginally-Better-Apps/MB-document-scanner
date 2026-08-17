import UIKit
import XCTest
@testable import MBDocumentScanner

final class DocumentCropperTests: XCTestCase {
    func testRectangularCropProducesExpectedPixelDimensions() throws {
        let image = makeImage(size: CGSize(width: 400, height: 300))
        let leftHalf = CropQuadrilateral(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 0.5, y: 0),
            bottomRight: CGPoint(x: 0.5, y: 1),
            bottomLeft: CGPoint(x: 0, y: 1)
        )

        let cropped = try DocumentCropper.crop(image, to: leftHalf)
        let cgImage = try XCTUnwrap(cropped.cgImage)

        XCTAssertEqual(cgImage.width, 200, accuracy: 2)
        XCTAssertEqual(cgImage.height, 300, accuracy: 2)
    }

    func testFullImageCropPreservesPixelDimensions() throws {
        let image = makeImage(size: CGSize(width: 320, height: 480))

        let cropped = try DocumentCropper.crop(image, to: .fullImage)
        let cgImage = try XCTUnwrap(cropped.cgImage)

        XCTAssertEqual(cgImage.width, 320, accuracy: 2)
        XCTAssertEqual(cgImage.height, 480, accuracy: 2)
    }

    func testUniformCropProducesExpectedPixelDimensions() throws {
        let image = makeImage(size: CGSize(width: 400, height: 300))
        let center = CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6)

        let cropped = try DocumentCropper.crop(image, to: center)
        let cgImage = try XCTUnwrap(cropped.cgImage)

        XCTAssertEqual(cgImage.width, 200, accuracy: 2)
        XCTAssertEqual(cgImage.height, 180, accuracy: 2)
    }

    func testUniformCropUsesTopLeftCoordinates() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 200, height: 200),
            format: format
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }

        let cropped = try DocumentCropper.crop(
            image,
            to: CGRect(x: 0, y: 0, width: 1, height: 0.5)
        )

        XCTAssertGreaterThan(darkPixelCoverage(in: cropped), 0.95)
    }

    private func makeImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40))
        }
    }

    private func darkPixelCoverage(in image: UIImage) -> Double {
        let width = 12
        let height = 12
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let cgImage = image.cgImage,
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return 0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let darkPixels = stride(from: 0, to: pixels.count, by: 4).filter { offset in
            pixels[offset] < 64 && pixels[offset + 1] < 64 && pixels[offset + 2] < 64
        }.count
        return Double(darkPixels) / Double(width * height)
    }
}
