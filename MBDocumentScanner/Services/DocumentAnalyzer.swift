import Foundation
import ImageIO
import UIKit
import Vision

final class DocumentAnalyzer: @unchecked Sendable {
    private let workQueue = DispatchQueue(label: "com.marginallybetter.docscanner.analysis", qos: .userInitiated)

    func analyze(image: UIImage) async -> PageAnalysis {
        await withCheckedContinuation { continuation in
            workQueue.async {
                continuation.resume(returning: self.performAnalysis(image: image))
            }
        }
    }

    private func performAnalysis(image: UIImage) -> PageAnalysis {
        guard let cgImage = image.cgImage else {
            return PageAnalysis(
                recognizedText: "",
                quality: .ready(score: 0, checks: [
                    QualityCheck(
                        id: "image",
                        title: "Image",
                        detail: "The page image could not be read.",
                        passed: false,
                        isImportant: true,
                        systemImage: "photo"
                    )
                ])
            )
        }

        let textResult = recognizeText(in: cgImage)
        let metrics = pixelMetrics(for: cgImage)
        let shortestSide = min(cgImage.width, cgImage.height)

        let lightingPassed = (0.20...0.98).contains(metrics.meanBrightness)
        let contrastPassed = metrics.contrast >= 0.12
        let sharpnessPassed = metrics.sharpness >= 0.075
        let resolutionPassed = shortestSide >= 1_200
        let textPassed = !textResult.text.isEmpty && textResult.averageConfidence >= 0.45

        let lightingDetail: String
        if metrics.meanBrightness < 0.20 {
            lightingDetail = "The page is dark. Try brighter, even light."
        } else if metrics.meanBrightness > 0.98 {
            lightingDetail = "The page may be overexposed. Avoid glare."
        } else {
            lightingDetail = "Lighting is even enough to read."
        }

        let checks = [
            QualityCheck(
                id: "lighting",
                title: "Lighting",
                detail: lightingDetail,
                passed: lightingPassed,
                isImportant: true,
                systemImage: "sun.max"
            ),
            QualityCheck(
                id: "sharpness",
                title: "Sharpness",
                detail: sharpnessPassed ? "Text edges appear clear." : "The page may be blurry. Hold the phone steady and rescan.",
                passed: sharpnessPassed,
                isImportant: true,
                systemImage: "viewfinder"
            ),
            QualityCheck(
                id: "contrast",
                title: "Contrast",
                detail: contrastPassed ? "The page has readable tonal range." : "Text and paper may be too similar in tone.",
                passed: contrastPassed,
                isImportant: false,
                systemImage: "circle.lefthalf.filled"
            ),
            QualityCheck(
                id: "resolution",
                title: "Resolution",
                detail: resolutionPassed ? "There is enough detail for export." : "This page is low resolution and may look soft in a PDF.",
                passed: resolutionPassed,
                isImportant: false,
                systemImage: "square.resize"
            ),
            QualityCheck(
                id: "text",
                title: "Readable Text",
                detail: textPassed ? "OCR found clear text on this page." : "Little reliable text was found. Check the page or rescan it.",
                passed: textPassed,
                isImportant: false,
                systemImage: "text.viewfinder"
            )
        ]

        var score = 0
        score += lightingPassed ? 25 : 7
        score += sharpnessPassed ? 25 : 5
        score += contrastPassed ? 15 : 5
        score += resolutionPassed ? 15 : 6
        if textPassed {
            score += 20
        } else if !textResult.text.isEmpty {
            score += 11
        } else {
            score += 3
        }

        return PageAnalysis(
            recognizedText: textResult.text,
            quality: .ready(score: min(score, 100), checks: checks)
        )
    }

    private func recognizeText(in image: CGImage) -> (text: String, averageConfidence: Float) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = 0.012

        do {
            try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
            let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
            let text = candidates.map(\.string).joined(separator: "\n")
            let confidence = candidates.isEmpty
                ? 0
                : candidates.map(\.confidence).reduce(0, +) / Float(candidates.count)
            return (text, confidence)
        } catch {
            return ("", 0)
        }
    }

    private func pixelMetrics(for image: CGImage) -> PixelMetrics {
        let sampleWidth = 160
        let sourceRatio = CGFloat(image.height) / CGFloat(image.width)
        let sampleHeight = max(80, min(240, Int(CGFloat(sampleWidth) * sourceRatio)))
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight)

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return PixelMetrics(meanBrightness: 0, contrast: 0, sharpness: 0)
        }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        let values = pixels.map { Double($0) / 255.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(values.count)

        var laplacianSum = 0.0
        var laplacianCount = 0
        for y in 1..<(sampleHeight - 1) {
            for x in 1..<(sampleWidth - 1) {
                let center = Double(pixels[y * sampleWidth + x])
                let neighbors = Double(pixels[(y - 1) * sampleWidth + x])
                    + Double(pixels[(y + 1) * sampleWidth + x])
                    + Double(pixels[y * sampleWidth + x - 1])
                    + Double(pixels[y * sampleWidth + x + 1])
                laplacianSum += abs((4 * center) - neighbors) / 255.0
                laplacianCount += 1
            }
        }

        return PixelMetrics(
            meanBrightness: mean,
            contrast: sqrt(variance),
            sharpness: laplacianCount == 0 ? 0 : laplacianSum / Double(laplacianCount)
        )
    }
}

private struct PixelMetrics {
    let meanBrightness: Double
    let contrast: Double
    let sharpness: Double
}
