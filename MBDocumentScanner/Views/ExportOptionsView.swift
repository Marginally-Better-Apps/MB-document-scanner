import SwiftUI

struct ExportOptionsView: View {
    @ObservedObject var session: ScanSession
    @Environment(\.dismiss) private var dismiss

    @State private var format: ExportFormat = .pdf
    @State private var compression: CompressionPreset = .balanced
    @State private var isExporting = false
    @State private var shareItems: [Any] = []
    @State private var isSharePresented = false
    @State private var pdfPreview: PDFPreviewItem?
    @State private var exportError: String?
    @State private var isFinished = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Format")
                } footer: {
                    Text(outputSummary)
                }

                Section {
                    Picker("Quality", selection: $compression) {
                        ForEach(CompressionPreset.allCases) { preset in
                            Text(preset.shortTitle).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Quality")
                } footer: {
                    Text("\(compression.title): \(compression.detail). Your original scan stays unchanged.")
                }

                if session.pagesNeedingReview > 0 {
                    Section {
                        Label(
                            "\(session.pagesNeedingReview) \(session.pagesNeedingReview == 1 ? "page needs" : "pages need") review. You can still export, or close this to fix them first.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isExporting)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BottomActionBar {
                    Button(action: export) {
                        HStack {
                            if isExporting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: format == .pdf ? "doc.richtext" : "square.and.arrow.up")
                            }
                            Text(exportButtonTitle)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isExporting || session.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(isExporting)
        .sheet(isPresented: $isSharePresented, onDismiss: dismissIfFinished) {
            ShareSheet(activityItems: shareItems) { completed in
                isFinished = completed
                isSharePresented = false
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $pdfPreview, onDismiss: dismissIfFinished) { preview in
            PDFPreviewView(
                url: preview.url,
                pageCount: session.pages.count,
                onFinish: { isFinished = true }
            )
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "Please try again.")
        }
    }

    private var outputSummary: String {
        let count = session.pages.count
        switch format {
        case .pdf:
            return "One PDF with \(pageCountText(count)). You can preview it before sharing or saving."
        case .images:
            return count == 1 ? "One JPEG image." : "\(count) separate JPEG images, one per page."
        }
    }

    private var exportButtonTitle: String {
        if isExporting { return "Preparing…" }
        switch format {
        case .pdf:
            return "Preview PDF"
        case .images:
            return session.pages.count == 1 ? "Share Image" : "Share \(session.pages.count) Images"
        }
    }

    private func dismissIfFinished() {
        if isFinished { dismiss() }
    }

    private func export() {
        isExporting = true
        isFinished = false
        Task {
            do {
                let urls = try await ExportService.export(
                    pages: session.pages,
                    title: session.title,
                    format: format,
                    compression: compression
                )
                if format == .pdf, let pdfURL = urls.first {
                    pdfPreview = PDFPreviewItem(url: pdfURL)
                } else {
                    shareItems = urls
                    isSharePresented = true
                }
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }
}

private struct PDFPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}
