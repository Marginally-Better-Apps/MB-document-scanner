# MB Document Scanner

Marginally Better Document Scanner—MB Document Scanner for short—is a free and open-source, privacy-first document scanner for iPhone and iPad. It uses Apple frameworks for the complete capture and export pipeline and does not require an account or network connection.

The project is released under the MIT License. Its bundle identifier is `com.marginallybetter.docscanner`.

## MVP features

- Multi-page document capture and automatic edge correction with VisionKit
- Import selected photos as a new document or add them as pages to an existing scan
- Persistent on-device scan library with thumbnails, dates, page counts, and review status
- On-device OCR with Vision
- Text-aware checks for readability, sharpness, local contrast, and image detail, with individually dismissible warnings
- Page review, 90-degree rotation, deletion, and selectable OCR text
- Full-page editing with text, permanent pixel-level redaction, and freehand markup
- Pinch to zoom up to 5× while editing, pan with two fingers, and use Fit Page to reset
- Finger drawing on iPhone and switchable Finger/Apple Pencil input on iPad
- Export as a multi-page PDF or as individual JPEG pages
- Small, balanced, and best-quality compression presets
- Settings for appearance, library sorting, export defaults, and OCR language correction
- In-app privacy information, version details, GitHub links, and the MIT License
- Native SwiftUI interface using system colors, typography, materials, and accessibility behavior

## Apple-first architecture

| Capability | Framework |
| --- | --- |
| Capture and perspective correction | VisionKit |
| Photo library selection | PhotosUI |
| OCR | Vision |
| Image-quality measurements | Core Graphics |
| PDF generation and inspection | PDFKit |
| JPEG scaling and compression | UIKit/Core Graphics |
| Pencil and touch markup | PencilKit |
| Interface and sharing | SwiftUI/UIKit |
| Private scan storage | Foundation/Application Support |

All processing and storage are local to the device. Each scan is saved in the app's private Application Support directory with its page images, OCR text, and quality results. Explicit exports create shareable files in a temporary export folder.

## Scan quality review

Quality review reports individual findings instead of an uncalibrated percentage. Recognition uses [Apple Vision](https://developer.apple.com/documentation/vision/vnrecognizetextrequest) on the device. Each check can pass, warn, or explain why it could not be assessed.

- **Readable text:** at least 80% of recognized characters must come from lines with Vision confidence of at least 0.5. This confidence is evidence for review, not a probability that the page is correct. Small text is included in recognition.
- **Sharpness:** measures edge definition in up to 24 text regions distributed across the page. Large text is reduced to a 32-pixel line height, with a 1,024-pixel region-width limit, while small text is never enlarged. A ratio of absolute second to first pixel differences below 0.6 in at least 30% of measurable regions produces a warning. Regions with insufficient contrast or edge signal are not used to diagnose blur.
- **Text contrast:** compares the 5th and 95th brightness percentiles inside those text regions. A range below 0.12 in at least 30% of regions produces a warning. Blank margins and dark backgrounds do not independently lower a grade.
- **Image detail:** shows the original pixel dimensions. A warning requires both text under 12 pixels tall and weak recognition confidence, affecting at least 20% of recognized characters. There is no blanket minimum page dimension or assumed PDF print size.

Pages without recognized text receive neutral visual-review guidance; an empty page or photo is not automatically considered defective. Average brightness is no longer used to claim uneven lighting or overexposure. These are heuristic checks of detected text, not a guarantee that all content was found or is legible; photos, handwriting, unusual fonts, and missing text still need visual review.

Every warning has a **Dismiss warning** button. Dismissed warnings stop contributing to page and library review counts, remain saved with that page, and can be restored individually under **Dismissed warnings**. Clearing every warning changes the page status to **Reviewed** without rewriting the measured findings as passes. Editing, cropping, or rotating a page starts fresh analysis and clears its prior dismissals. Existing documents are automatically reanalyzed when loaded with the new analysis version.

## Build

1. Run `xcodegen generate` from the repository root.
2. Open `MBDocumentScanner.xcodeproj` in Xcode.
3. Select an iPhone or iPad device and run the `MBDocumentScanner` scheme.

The VisionKit document camera requires a supported physical device, and Apple Pencil behavior requires a physical iPad. The remaining interface, export pipeline, and unit tests can run in the iOS Simulator.

## MVP boundaries

This first version intentionally excludes cloud sync, cross-device sync, password-protected PDFs, searchable PDF text layers, and handwritten-text tuning. Those are natural follow-on features once the capture/review/export workflow is validated.
