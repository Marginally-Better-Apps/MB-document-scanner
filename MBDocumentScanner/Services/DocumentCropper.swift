import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct CropQuadrilateral: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let fullImage = CropQuadrilateral(
        topLeft: CGPoint(x: 0, y: 0),
        topRight: CGPoint(x: 1, y: 0),
        bottomRight: CGPoint(x: 1, y: 1),
        bottomLeft: CGPoint(x: 0, y: 1)
    )
}

enum DocumentCropError: LocalizedError {
    case invalidImage
    case invalidCrop

    var errorDescription: String? {
        switch self {
        case .invalidImage: "This page could not be prepared for cropping."
        case .invalidCrop: "The selected crop area could not be applied."
        }
    }
}

enum DocumentCropper {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func crop(_ image: UIImage, to normalizedRect: CGRect) throws -> UIImage {
        guard let inputImage = CIImage(
            image: image,
            options: [.applyOrientationProperty: true]
        ) else {
            throw DocumentCropError.invalidImage
        }

        let extent = inputImage.extent
        let standardizedRect = normalizedRect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard standardizedRect.width > 0, standardizedRect.height > 0 else {
            throw DocumentCropError.invalidCrop
        }

        let cropRect = CGRect(
            x: extent.minX + standardizedRect.minX * extent.width,
            y: extent.minY + (1 - standardizedRect.maxY) * extent.height,
            width: standardizedRect.width * extent.width,
            height: standardizedRect.height * extent.height
        ).integral.intersection(extent)
        guard !cropRect.isEmpty else { throw DocumentCropError.invalidCrop }

        let outputImage = inputImage.cropped(to: cropRect)
        guard let cgImage = context.createCGImage(outputImage, from: cropRect) else {
            throw DocumentCropError.invalidCrop
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    static func crop(_ image: UIImage, to quadrilateral: CropQuadrilateral) throws -> UIImage {
        guard let inputImage = CIImage(
            image: image,
            options: [.applyOrientationProperty: true]
        ) else {
            throw DocumentCropError.invalidImage
        }

        let extent = inputImage.extent
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = inputImage
        filter.topLeft = imagePoint(for: quadrilateral.topLeft, in: extent)
        filter.topRight = imagePoint(for: quadrilateral.topRight, in: extent)
        filter.bottomRight = imagePoint(for: quadrilateral.bottomRight, in: extent)
        filter.bottomLeft = imagePoint(for: quadrilateral.bottomLeft, in: extent)

        guard let outputImage = filter.outputImage,
              !outputImage.extent.isEmpty,
              !outputImage.extent.isInfinite,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw DocumentCropError.invalidCrop
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func imagePoint(for normalizedPoint: CGPoint, in extent: CGRect) -> CGPoint {
        CGPoint(
            x: extent.minX + normalizedPoint.x * extent.width,
            y: extent.maxY - normalizedPoint.y * extent.height
        )
    }
}
