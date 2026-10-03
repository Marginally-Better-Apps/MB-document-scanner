import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFPreviewView: View {
    let url: URL
    let pageCount: Int
    private let exportDocument: PDFExportDocument?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isSharePresented = false
    @State private var isSavePresented = false
    @State private var didSave = false
    @State private var saveError: String?

    init(url: URL, pageCount: Int) {
        self.url = url
        self.pageCount = pageCount
        exportDocument = try? PDFExportDocument(contentsOf: url)
    }

    var body: some View {
        NavigationStack {
            PDFDocumentView(url: url)
                .background(ScanTheme.background)
                .navigationTitle("PDF Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { dismiss() }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    actionBar
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    documentSummary
                }
        }
        .tint(ScanTheme.accent)
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: [url])
        }
        .fileExporter(
            isPresented: $isSavePresented,
            document: exportDocument,
            contentType: .pdf,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                didSave = true
            case let .failure(error):
                saveError = error.localizedDescription
            }
        }
        .alert("PDF Saved", isPresented: $didSave) {
            Button("Done") { dismiss() }
            Button("Save Another Copy") { isSavePresented = true }
        } message: {
            Text("A copy of the reviewed PDF was saved successfully.")
        }
        .alert("Unable to Save PDF", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please choose another location and try again.")
        }
    }

    private var documentSummary: some View {
        HStack(spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(ScanTheme.accent)
                    .frame(width: 46, height: 46)
                    .background(ScanTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exportFilename)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ScanTheme.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Text("\(pageCount) \(pageCount == 1 ? "page" : "pages") · \(formattedFileSize)")
                    .font(.caption)
                    .foregroundStyle(ScanTheme.secondaryInk)
            }
            Spacer(minLength: 0)
            if !dynamicTypeSize.isAccessibilitySize {
                Text("PDF")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(ScanTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ScanTheme.accentSoft, in: Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(ScanTheme.background)
    }

    private var actionBar: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        return layout {
            Button {
                isSharePresented = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScanSecondaryButtonStyle())

            Button {
                if exportDocument == nil {
                    saveError = "The prepared PDF could not be opened. Please return to Export and try again."
                } else {
                    isSavePresented = true
                }
            } label: {
                Label("Save PDF", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScanPrimaryButtonStyle())
        }
        .font(.headline)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(ScanTheme.background)
    }

    private var formattedFileSize: String {
        guard let byteCount = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return "Size unavailable"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    private var exportFilename: String {
        let filename = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return filename.isEmpty ? "MB Document Scanner" : filename
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        pdfView.backgroundColor = UIColor(ScanTheme.background)
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil {
            pdfView.document = PDFDocument(url: url)
        }
    }
}

private struct PDFExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    let data: Data

    init(contentsOf url: URL) throws {
        data = try Data(contentsOf: url)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
