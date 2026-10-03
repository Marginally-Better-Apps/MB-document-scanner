import Foundation
import UIKit
import Vision

final class DocumentAnalyzer: @unchecked Sendable {
    static let analysisVersion = 2
    private let workQueue = DispatchQueue(label: "com.marginallybetter.docscanner.analysis", qos: .userInitiated)

    func analyze(image: UIImage, usesLanguageCorrection: Bool = true) async -> PageAnalysis {
        await withCheckedContinuation { continuation in
            workQueue.async {
                continuation.resume(returning: self.performAnalysis(
                    image: image,
                    usesLanguageCorrection: usesLanguageCorrection
                ))
            }
        }
    }

    private func performAnalysis(image: UIImage, usesLanguageCorrection: Bool) -> PageAnalysis {
        guard let cgImage = image.cgImage else {
            return PageAnalysis(recognizedText: "", quality: .ready(checks: [
                QualityCheck(id: "image", title: "Image", detail: "The page image could not be read. Try importing it again.", status: .warning, systemImage: "photo")
            ]))
        }

        let text = recognizeText(in: cgImage, usesLanguageCorrection: usesLanguageCorrection)
        let regions = sampledLines(text.lines).compactMap { line in
            measureTextRegion(line.bounds, in: cgImage)
        }
        return PageAnalysis(recognizedText: text.lines.map(\.text).joined(separator: "\n"), quality: .ready(checks: [
            readabilityCheck(text),
            sharpnessCheck(regions),
            contrastCheck(regions),
            detailCheck(text.lines, image: cgImage)
        ]))
    }

    private func readabilityCheck(_ result: TextResult) -> QualityCheck {
        let status: QualityCheck.Status
        let detail: String
        if result.failed {
            status = .notEvaluated
            detail = "Text recognition was unavailable. Inspect the page at full size."
        } else if result.lines.isEmpty {
            status = .notEvaluated
            detail = "No text was recognized. This can be normal for photos, handwriting, or blank pages. Check any expected text visually."
        } else {
            // Weight by characters so a clear heading cannot outweigh several
            // uncertain body lines. Vision confidence is evidence, not a grade.
            let total = result.lines.reduce(0) { $0 + $1.text.count }
            let reliable = result.lines.filter { $0.confidence >= 0.5 }.reduce(0) { $0 + $1.text.count }
            let readable = Double(reliable) / Double(max(1, total)) >= 0.8
            status = readable ? .passed : .warning
            detail = readable
                ? "Most detected text was recognized confidently. Check names and numbers before sharing."
                : "Some detected text was difficult to recognize. Zoom in to check it; a clearer source may help."
        }
        return QualityCheck(id: "text", title: "Readable Text", detail: detail, status: status, systemImage: "text.viewfinder")
    }

    private func sharpnessCheck(_ regions: [TextRegionMetrics]) -> QualityCheck {
        // Low contrast has its own check; it is not evidence of defocus.
        let measurable = regions.filter { $0.contrast >= 0.12 && $0.edgeStrength > 0.01 }
        let status: QualityCheck.Status
        let detail: String
        if measurable.isEmpty {
            status = .notEvaluated
            detail = "Not enough distinct text edges to judge sharpness. Inspect small details at full size."
        } else {
            // At the normalized text scale, broad transitions have much less
            // curvature than crisp edges. This ratio does not depend on how
            // much of the page is blank or on the text/background polarity.
            let softFraction = Double(measurable.filter { $0.edgeDefinition < 0.6 }.count) / Double(measurable.count)
            status = softFraction >= 0.3 ? .warning : .passed
            detail = status == .warning
                ? "Some text edges look soft. Zoom in to check readability, or use a clearer source."
                : "Sampled text edges look well defined."
        }
        return QualityCheck(id: "sharpness", title: "Sharpness", detail: detail, status: status, systemImage: "viewfinder")
    }

    private func contrastCheck(_ regions: [TextRegionMetrics]) -> QualityCheck {
        let status: QualityCheck.Status
        let detail: String
        if regions.isEmpty {
            status = .notEvaluated
            detail = "No text regions were available to compare with their background."
        } else {
            let faintFraction = Double(regions.filter { $0.contrast < 0.12 }.count) / Double(regions.count)
            status = faintFraction >= 0.3 ? .warning : .passed
            detail = status == .warning
                ? "Some text is close in tone to its background. Check that faint text is readable."
                : "Sampled text stands out from its nearby background."
        }
        return QualityCheck(id: "contrast", title: "Text Contrast", detail: detail, status: status, systemImage: "circle.lefthalf.filled")
    }

    private func detailCheck(_ lines: [TextLine], image: CGImage) -> QualityCheck {
        let dimensions = "\(image.width) × \(image.height) pixels."
        let status: QualityCheck.Status
        let detail: String
        if lines.isEmpty {
            status = .notEvaluated
            detail = "\(dimensions) Check fine details at your intended viewing or print size."
        } else {
            // Actual text height matters more than a blanket page-size cutoff.
            // Warn only when tiny text also has weak recognition evidence.
            let tiny = lines.filter { $0.bounds.height * CGFloat(image.height) < 12 && $0.confidence < 0.5 }
            let tinyCharacters = tiny.reduce(0) { $0 + $1.text.count }
            let totalCharacters = lines.reduce(0) { $0 + $1.text.count }
            status = Double(tinyCharacters) / Double(max(1, totalCharacters)) >= 0.2 ? .warning : .passed
            detail = status == .warning
                ? "\(dimensions) Some text is very small and hard to recognize. A larger original may help."
                : "\(dimensions) Detected text has usable detail at this size. Enlarging it for print may soften it."
        }
        return QualityCheck(id: "resolution", title: "Image Detail", detail: detail, status: status, systemImage: "square.resize")
    }

    private func recognizeText(in image: CGImage, usesLanguageCorrection: Bool) -> TextResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = usesLanguageCorrection
        request.automaticallyDetectsLanguage = true
        // Retain small screenshot text instead of excluding lines below 1.2%.
        request.minimumTextHeight = 0
        do {
            try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
            let lines = (request.results ?? []).compactMap { observation -> TextLine? in
                guard let candidate = observation.topCandidates(1).first,
                      !candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return TextLine(text: candidate.string, confidence: candidate.confidence, bounds: observation.boundingBox)
            }
            return TextResult(lines: lines, failed: false)
        } catch {
            return TextResult(lines: [], failed: true)
        }
    }

    private func sampledLines(_ lines: [TextLine]) -> [TextLine] {
        // Bound work on dense documents while covering the full page, including
        // weak OCR results instead of cherry-picking the most confident lines.
        guard lines.count > 24 else { return lines }
        let sorted = lines.sorted { $0.bounds.midY < $1.bounds.midY }
        return (0..<24).map { sorted[$0 * (sorted.count - 1) / 23] }
    }

    private func measureTextRegion(_ bounds: CGRect, in image: CGImage) -> TextRegionMetrics? {
        let lineHeight = bounds.height * CGFloat(image.height)
        let rect = CGRect(
            x: bounds.minX * CGFloat(image.width),
            y: (1 - bounds.maxY) * CGFloat(image.height),
            width: bounds.width * CGFloat(image.width),
            height: lineHeight
        ).insetBy(dx: -lineHeight * 0.15, dy: -lineHeight * 0.2)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height)).integral
        guard !rect.isEmpty, let crop = image.cropping(to: rect) else { return nil }

        // Normalize only large text to a 32px line height, preserving aspect
        // ratio and never upscaling. Blank page margins do not dilute edges.
        let scale = min(1, 32 / max(1, lineHeight), 1_024 / CGFloat(crop.width))
        let width = max(1, Int(CGFloat(crop.width) * scale))
        let height = max(1, Int(CGFloat(crop.height) * scale))
        guard width >= 3, height >= 3 else { return nil }
        var pixels = [UInt8](repeating: 255, count: width * height)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .high
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }

        var histogram = [Int](repeating: 0, count: 256)
        for pixel in pixels { histogram[Int(pixel)] += 1 }
        func percentile(_ fraction: Double) -> Double {
            let target = max(1, Int(Double(pixels.count) * fraction))
            var cumulative = 0
            for (value, count) in histogram.enumerated() {
                cumulative += count
                if cumulative >= target { return Double(value) / 255 }
            }
            return 1
        }
        let contrast = percentile(0.95) - percentile(0.05)
        var gradient = 0.0
        var curvature = 0.0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                let center = Double(pixels[index]) / 255
                let left = Double(pixels[index - 1]) / 255
                let right = Double(pixels[index + 1]) / 255
                let top = Double(pixels[index - width]) / 255
                let bottom = Double(pixels[index + width]) / 255
                gradient += abs(right - center) + abs(bottom - center)
                curvature += abs(left - 2 * center + right) + abs(top - 2 * center + bottom)
            }
        }
        return TextRegionMetrics(
            contrast: contrast,
            edgeStrength: gradient / Double((width - 2) * (height - 2)),
            edgeDefinition: gradient > 0 ? curvature / gradient : 0
        )
    }
}

private struct TextResult {
    let lines: [TextLine]
    let failed: Bool
}

private struct TextLine {
    let text: String
    let confidence: Float
    let bounds: CGRect
}

private struct TextRegionMetrics {
    let contrast: Double
    let edgeStrength: Double
    let edgeDefinition: Double
}
