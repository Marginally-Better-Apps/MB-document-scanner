import PencilKit
import UIKit

enum PageMarkupColor: String, CaseIterable, Identifiable {
    case black
    case blue
    case red
    case green
    case yellow
    case white

    var id: Self { self }

    var uiColor: UIColor {
        switch self {
        case .black: .black
        case .blue: UIColor(red: 0.05, green: 0.39, blue: 0.96, alpha: 1)
        case .red: UIColor(red: 0.91, green: 0.16, blue: 0.20, alpha: 1)
        case .green: UIColor(red: 0.08, green: 0.62, blue: 0.35, alpha: 1)
        case .yellow: UIColor(red: 1, green: 0.78, blue: 0.04, alpha: 1)
        case .white: .white
        }
    }
}

struct PageTextEdit: Identifiable, Equatable {
    let id: UUID
    var text: String
    var frame: CGRect
    var fontScale: CGFloat
    var color: PageMarkupColor
    var isBold: Bool
    var hasBackground: Bool

    init(
        id: UUID = UUID(),
        text: String,
        frame: CGRect,
        fontScale: CGFloat = 0.045,
        color: PageMarkupColor = .black,
        isBold: Bool = false,
        hasBackground: Bool = false
    ) {
        self.id = id
        self.text = text
        self.frame = frame
        self.fontScale = fontScale
        self.color = color
        self.isBold = isBold
        self.hasBackground = hasBackground
    }
}

struct PageRedactionEdit: Identifiable, Equatable {
    let id: UUID
    var frame: CGRect

    init(id: UUID = UUID(), frame: CGRect) {
        self.id = id
        self.frame = frame
    }
}

enum PageEditRenderer {
    /// Flattens every edit into a new opaque bitmap. Redactions are drawn last so
    /// neither the source pixels nor earlier markup survive inside their bounds.
    static func render(
        image: UIImage,
        drawing: PKDrawing,
        drawingCanvasSize: CGSize,
        textEdits: [PageTextEdit],
        redactions: [PageRedactionEdit]
    ) -> UIImage {
        let outputSize = pixelSize(for: image)
        guard outputSize.width > 0, outputSize.height > 0 else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            let outputRect = CGRect(origin: .zero, size: outputSize)

            UIColor.white.setFill()
            context.fill(outputRect)
            image.draw(in: outputRect)

            drawPencilMarkup(
                drawing,
                canvasSize: drawingCanvasSize,
                outputRect: outputRect
            )
            drawTextEdits(textEdits, outputRect: outputRect)
            drawPermanentRedactions(redactions, outputRect: outputRect)
        }
    }

    private static func drawPencilMarkup(
        _ drawing: PKDrawing,
        canvasSize: CGSize,
        outputRect: CGRect
    ) {
        guard canvasSize.width > 0, canvasSize.height > 0, !drawing.strokes.isEmpty else {
            return
        }

        let scale = max(
            outputRect.width / canvasSize.width,
            outputRect.height / canvasSize.height
        )
        let drawingImage = drawing.image(
            from: CGRect(origin: .zero, size: canvasSize),
            scale: scale
        )
        drawingImage.draw(in: outputRect)
    }

    private static func drawTextEdits(
        _ textEdits: [PageTextEdit],
        outputRect: CGRect
    ) {
        for edit in textEdits where !edit.text.isEmpty {
            let rect = denormalized(edit.frame, in: outputRect)

            if edit.hasBackground {
                let background = UIBezierPath(
                    roundedRect: rect.insetBy(dx: -4, dy: -3),
                    cornerRadius: max(4, edit.fontScale * outputRect.width * 0.24)
                )
                UIColor.white.withAlphaComponent(0.92).setFill()
                background.fill()
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byWordWrapping
            let fontSize = max(8, edit.fontScale * outputRect.width)
            let font = UIFont.systemFont(
                ofSize: fontSize,
                weight: edit.isBold ? .bold : .regular
            )
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: edit.color.uiColor,
                .paragraphStyle: paragraph
            ]
            (edit.text as NSString).draw(
                with: rect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        }
    }

    private static func drawPermanentRedactions(
        _ redactions: [PageRedactionEdit],
        outputRect: CGRect
    ) {
        UIColor.black.setFill()

        for redaction in redactions {
            let mapped = denormalized(redaction.frame, in: outputRect)
            // Round outward and add one pixel so antialiased source edges cannot leak.
            let secureRect = CGRect(
                x: floor(mapped.minX) - 1,
                y: floor(mapped.minY) - 1,
                width: ceil(mapped.maxX) - floor(mapped.minX) + 2,
                height: ceil(mapped.maxY) - floor(mapped.minY) + 2
            ).intersection(outputRect)
            UIRectFill(secureRect)
        }
    }

    private static func denormalized(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX + rect.minX * bounds.width,
            y: bounds.minY + rect.minY * bounds.height,
            width: rect.width * bounds.width,
            height: rect.height * bounds.height
        )
    }

    private static func pixelSize(for image: UIImage) -> CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return CGSize(
            width: max(1, image.size.width * image.scale),
            height: max(1, image.size.height * image.scale)
        )
    }
}
