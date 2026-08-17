# MB Document Scanner

Marginally Better Document Scanner—MB Document Scanner for short—is a free and open-source, privacy-first document scanner MVP for iPhone. It uses Apple frameworks for the complete capture and export pipeline and does not require an account or network connection.

The project is released under the MIT License. Its bundle identifier is `com.marginallybetter.docscanner`.

## MVP features

- Multi-page document capture and automatic edge correction with VisionKit
- Persistent on-device scan library with thumbnails, dates, page counts, and review status
- On-device OCR with Vision
- Explainable scan checks for lighting, sharpness, contrast, resolution, and readable text
- Page review, 90-degree rotation, deletion, and selectable OCR text
- Export as a multi-page PDF or as individual JPEG pages
- Small, balanced, and best-quality compression presets
- Native SwiftUI interface using system colors, typography, materials, and accessibility behavior

## Apple-first architecture

| Capability | Framework |
| --- | --- |
| Capture and perspective correction | VisionKit |
| OCR | Vision |
| Image-quality measurements | Core Graphics |
| PDF generation and inspection | PDFKit |
| JPEG scaling and compression | UIKit/Core Graphics |
| Interface and sharing | SwiftUI/UIKit |
| Private scan storage | Foundation/Application Support |

All processing and storage are local to the device. Each scan is saved in the app's private Application Support directory with its page images, OCR text, and quality results. Explicit exports create shareable files in a temporary export folder.

## Build

1. Run `xcodegen generate` from the repository root.
2. Open `MBDocumentScanner.xcodeproj` in Xcode.
3. Select an iPhone device and run the `MBDocumentScanner` scheme.

The VisionKit document camera requires a physical supported iPhone. The remaining interface, export pipeline, and unit tests can run in the iOS Simulator.

## MVP boundaries

This first version intentionally excludes cloud sync, cross-device sync, password-protected PDFs, searchable PDF text layers, handwritten-text tuning, and manual crop editing. Those are natural follow-on features once the capture/review/export workflow is validated.
