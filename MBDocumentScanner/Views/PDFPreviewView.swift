import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFPreviewView: View {
    let url: URL
    let pageCount: Int
    var onFinish: () -> Void = {}
    private let exportDocument: PDFExportDocument?

    @Environment(\.dismiss) private var dismiss
    @State private var isSavePresented = false
    @State private var didSave = false
    @State private var saveError: String?

    init(url: URL, pageCount: Int, onFinish: @escaping () -> Void = {}) {
        self.url = url
        self.pageCount = pageCount
        self.onFinish = onFinish
        exportDocument = try? PDFExportDocument(contentsOf: url)
    }

    var body: some View {
        NavigationStack {
            PDFDocumentView(url: url)
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { dismiss() }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    saveBar
                }
        }
        .fileExporter(
            isPresented: $isSavePresented,
            document: exportDocument,
            contentType: .pdf,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                Haptics.success()
                didSave = true
            case let .failure(error):
                saveError = error.localizedDescription
            }
        }
        .alert("PDF Saved", isPresented: $didSave) {
            Button("Done") {
                onFinish()
                dismiss()
            }
            Button("Keep Previewing", role: .cancel) {}
        } message: {
            Text("Your PDF was saved to the location you chose.")
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

    private var saveBar: some View {
        BottomActionBar {
            Text("\(pageCountText(pageCount)) · \(formattedFileSize)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    if exportDocument == nil {
                        saveError = "The prepared PDF could not be opened. Please return to Export and try again."
                    } else {
                        isSavePresented = true
                    }
                } label: {
                    Label("Save to Files", systemImage: "folder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ShareLink(
                    item: url,
                    preview: SharePreview(exportFilename, image: Image(systemName: "doc.richtext"))
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
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
        pdfView.pageBreakMargins = UIEdgeInsets(top: 22, left: 12, bottom: 22, right: 12)
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
