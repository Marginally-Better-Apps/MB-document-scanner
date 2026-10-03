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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    exportSummary

                    VStack(alignment: .leading, spacing: 12) {
                        ScanSectionHeading(title: "File format")
                        formatLayout {
                            ForEach(ExportFormat.allCases) { option in
                                formatButton(option)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ScanSectionHeading(title: "Quality")
                        VStack(alignment: .leading, spacing: 18) {
                            qualityLayout {
                                ForEach(CompressionPreset.allCases) { preset in
                                    qualityButton(preset)
                                }
                            }
                            .padding(5)
                            .background(ScanTheme.background, in: RoundedRectangle(cornerRadius: 16))

                            VStack(alignment: .leading, spacing: 5) {
                                Text(compression.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ScanTheme.ink)
                                Text(compression.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(ScanTheme.secondaryInk)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                        .scanCard()
                    }
                }
                .padding(24)
            }
            .background(ScanTheme.background)
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
                .buttonStyle(ScanPrimaryButtonStyle())
                .disabled(isExporting)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(ScanTheme.background)
            }
        }
        .tint(ScanTheme.accent)
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

    private var formatLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private var qualityLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
    }

    private var exportSummary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 16))

        return layout {
            Image(systemName: "doc.text")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(ScanTheme.accent)
                .frame(width: 64, height: 72)
                .background(ScanTheme.accentSoft, in: RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to share")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ScanTheme.ink)
                Text(session.title)
                    .font(.subheadline)
                    .foregroundStyle(ScanTheme.secondaryInk)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Text("\(session.pages.count) \(session.pages.count == 1 ? "page" : "pages") · \(format == .pdf ? "One PDF" : "Individual JPEGs")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ScanTheme.accent)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatButton(_ option: ExportFormat) -> some View {
        let isSelected = format == option
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                format = option
            }
        } label: {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 25, weight: .regular))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? ScanTheme.accent : ScanTheme.border)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.headline)
                    Text(option == .pdf ? "One document" : "Separate images")
                        .font(.caption)
                        .foregroundStyle(ScanTheme.secondaryInk)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? ScanTheme.accent : ScanTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(isSelected ? ScanTheme.accentSoft : ScanTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(isSelected ? ScanTheme.accent : ScanTheme.border, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func qualityButton(_ preset: CompressionPreset) -> some View {
        let isSelected = compression == preset
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                compression = preset
            }
        } label: {
            Text(preset.shortTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? ScanTheme.accent : ScanTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? ScanTheme.surface : .clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .accessibilityLabel(preset.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
