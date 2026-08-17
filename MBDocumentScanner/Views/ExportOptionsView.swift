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

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases) { option in
                            Label(option.title, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Picker("Compression", selection: $compression) {
                        ForEach(CompressionPreset.allCases) { preset in
                            Text(preset.shortTitle).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(compression.title)
                            .font(.subheadline.weight(.medium))
                        Text(compression.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Compression")
                } footer: {
                    Text("Compression is applied locally. Your original scan stays unchanged.")
                }

                Section("Summary") {
                    LabeledContent("Pages", value: "\(session.pages.count)")
                    LabeledContent("Output", value: format == .pdf ? "One PDF" : "\(session.pages.count) JPEG files")
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: export) {
                    HStack {
                        if isExporting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: format == .pdf ? "doc.text.magnifyingglass" : "square.and.arrow.up")
                        }
                        Text(exportButtonTitle)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isExporting)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: shareItems)
        }
        .fullScreenCover(item: $pdfPreview) { preview in
            PDFPreviewView(url: preview.url, pageCount: session.pages.count)
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

    private var exportButtonTitle: String {
        if isExporting { return "Preparing…" }
        return format == .pdf ? "Preview PDF" : "Export Images"
    }

    private func export() {
        isExporting = true
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
