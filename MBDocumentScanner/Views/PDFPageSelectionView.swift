import SwiftUI
import UIKit

struct PDFPageSelectionView: View {
    let source: PDFPageImportSource
    let onImport: ([UIImage]) -> Void
    let onCancel: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedIndexes: Set<Int>
    @State private var isImporting = false
    @State private var importError: String?

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(minimum: 132, maximum: 400))]
        }
        return [GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 18, alignment: .bottom)]
    }

    init(
        source: PDFPageImportSource,
        onImport: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.source = source
        self.onImport = onImport
        self.onCancel = onCancel
        _selectedIndexes = State(initialValue: Set(source.pages.map(\.index)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.suggestedTitle)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(ScanTheme.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        Text("Tap a page to leave it out.")
                            .font(.subheadline)
                            .foregroundStyle(ScanTheme.secondaryInk)
                    }

                    LazyVGrid(columns: columns, alignment: .center, spacing: 22) {
                        ForEach(source.pages) { page in
                            pageButton(page)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(ScanTheme.background)
            .navigationTitle("Import PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isImporting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isImporting {
                        ProgressView()
                    } else {
                        Button("Import", action: importSelectedPages)
                            .fontWeight(.semibold)
                            .disabled(selectedIndexes.isEmpty)
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button(selectionButtonTitle, action: toggleAllPages)
                        .disabled(isImporting)
                }

                ToolbarItem(placement: .status) {
                    Text(selectionSummary)
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                        .contentTransition(.numericText())
                }
            }
        }
        .interactiveDismissDisabled(isImporting)
        .alert("Unable to Import PDF", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Please try again.")
        }
    }

    private func pageButton(_ page: PDFPageImportPreview) -> some View {
        let isSelected = selectedIndexes.contains(page.index)

        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                if isSelected {
                    selectedIndexes.remove(page.index)
                } else {
                    selectedIndexes.insert(page.index)
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 8) {
                PaperImage(image: page.thumbnail)
                    .opacity(isSelected ? 1 : 0.45)
                    .overlay(alignment: .bottomTrailing) {
                        selectionMark(isSelected)
                            .padding(6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .aspectRatio(0.75, contentMode: .fit)

                Text("\(page.index + 1)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? ScanTheme.ink : ScanTheme.tertiaryInk)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
        .accessibilityLabel("Page \(page.index + 1)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectionMark(_ isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(ScanTheme.tertiaryInk)
            }
        }
        .font(.system(size: 24))
        .background(Circle().fill(.white).padding(2))
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private var selectionButtonTitle: String {
        selectedIndexes.count == source.pages.count ? "Deselect All" : "Select All"
    }

    private var selectionSummary: String {
        if selectedIndexes.isEmpty { return "No pages selected" }
        if selectedIndexes.count == source.pages.count {
            return "All \(source.pages.count) \(source.pages.count == 1 ? "page" : "pages") selected"
        }
        return "\(selectedIndexes.count) of \(source.pages.count) pages selected"
    }

    private func toggleAllPages() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            if selectedIndexes.count == source.pages.count {
                selectedIndexes.removeAll()
            } else {
                selectedIndexes = Set(source.pages.map(\.index))
            }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func importSelectedPages() {
        let indexes = selectedIndexes.sorted()
        guard !indexes.isEmpty else { return }

        isImporting = true
        Task {
            do {
                let images = try await PDFPageImporter.importPages(at: indexes, from: source)
                onImport(images)
            } catch {
                importError = error.localizedDescription
                isImporting = false
            }
        }
    }
}
