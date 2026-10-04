import SwiftUI

struct ExportOptionsView: View {
    @ObservedObject var session: ScanSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var format: ExportFormat
    @State private var compression: CompressionPreset
    @State private var isExporting = false
    @State private var shareItems: [Any] = []
    @State private var isSharePresented = false
    @State private var pdfPreview: PDFPreviewItem?
    @State private var exportError: String?

    init(
        session: ScanSession,
        format: ExportFormat = .pdf,
        compression: CompressionPreset = .balanced
    ) {
        self.session = session
        _format = State(initialValue: format)
        _compression = State(initialValue: compression)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    exportSummary
                }

                Section("Format") {
                    ForEach(ExportFormat.allCases) { option in
                        formatRow(option)
                    }
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
                    Text(compression.detail)
                        .contentTransition(.opacity)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ScanTheme.background)
            .disabled(isExporting)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: export) {
                    HStack(spacing: 8) {
                        if isExporting {
                            ProgressView().tint(.white)
                        }
                        Text(exportButtonTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScanPrimaryButtonStyle())
                .disabled(isExporting)
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .tint(ScanTheme.accent)
        .sensoryFeedback(.selection, trigger: format)
        .sensoryFeedback(.selection, trigger: compression)
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

    private var exportSummary: some View {
        HStack(spacing: 16) {
            ZStack {
                if let thumbnail = session.thumbnail {
                    PaperImage(image: thumbnail, cornerRadius: 3)
                }
            }
            .frame(width: 52, height: 68)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.headline)
                    .foregroundStyle(ScanTheme.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Text("\(session.pages.count.pageCountText) · \(format == .pdf ? "One PDF" : "Separate JPEGs")")
                    .font(.subheadline)
                    .foregroundStyle(ScanTheme.secondaryInk)
                    .contentTransition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func formatRow(_ option: ExportFormat) -> some View {
        let isSelected = format == option
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                format = option
            }
        } label: {
            HStack(spacing: 12) {
                SettingsIcon(option.systemImage, color: option == .pdf ? .red : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .foregroundStyle(ScanTheme.ink)
                    Text(option == .pdf ? "One document, ready to sign or send" : "One image per page")
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ScanTheme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var exportButtonTitle: String {
        if isExporting { return "Preparing…" }
        return format == .pdf ? "Preview PDF" : "Share \(session.pages.count == 1 ? "Image" : "Images")"
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
