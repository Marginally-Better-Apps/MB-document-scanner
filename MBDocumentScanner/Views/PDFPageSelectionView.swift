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
        return [GridItem(.adaptive(minimum: 132, maximum: 190), spacing: 16)]
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
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(source.suggestedTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(ScanTheme.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        Text("Keep the pages you need. Tap to select.")
                            .font(.subheadline)
                            .foregroundStyle(ScanTheme.secondaryInk)

                        if dynamicTypeSize.isAccessibilitySize {
                            Button(selectionButtonTitle, action: toggleAllPages)
                                .buttonStyle(ScanSecondaryButtonStyle())
                                .disabled(isImporting)
                                .padding(.top, 8)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(source.pages) { page in
                            pageButton(page)
                        }
                    }
                }
                .padding(24)
            }
            .background(ScanTheme.background)
            .navigationTitle("Choose PDF Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isImporting)
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(selectionButtonTitle, action: toggleAllPages)
                            .disabled(isImporting)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                importBar
            }
        }
        .tint(ScanTheme.accent)
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
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: page.thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                        .padding(10)

                    ZStack {
                        Circle()
                            .fill(isSelected ? ScanTheme.primaryFill : ScanTheme.surface)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Circle().strokeBorder(ScanTheme.border, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .padding(12)
                }
                .aspectRatio(0.74, contentMode: .fit)
                .background(isSelected ? ScanTheme.accentSoft : ScanTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isSelected ? ScanTheme.accent : ScanTheme.border, lineWidth: isSelected ? 2 : 1)
                }

                Text("Page \(page.index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? ScanTheme.accent : ScanTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
        .accessibilityLabel("Page \(page.index + 1)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var importBar: some View {
        VStack(spacing: 12) {
            Text(selectionSummary)
                .font(.footnote.weight(.medium))
                .foregroundStyle(ScanTheme.secondaryInk)
                .contentTransition(.numericText())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: importSelectedPages) {
                HStack {
                    if isImporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(importButtonTitle)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScanPrimaryButtonStyle())
            .disabled(selectedIndexes.isEmpty || isImporting)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(ScanTheme.background)
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

    private var importButtonTitle: String {
        if isImporting { return "Importing…" }
        if selectedIndexes.count == source.pages.count {
            return source.pages.count == 1 ? "Import Page" : "Import All Pages"
        }
        return selectedIndexes.count == 1 ? "Import 1 Page" : "Import \(selectedIndexes.count) Pages"
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
