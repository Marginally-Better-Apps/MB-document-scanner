import SwiftUI
import UIKit

struct PDFPageSelectionView: View {
    let source: PDFPageImportSource
    let onImport: ([UIImage]) -> Void
    let onCancel: () -> Void

    @State private var selectedIndexes: Set<Int>
    @State private var isImporting = false
    @State private var importError: String?

    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 190), spacing: 16)
    ]

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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tap a page to include or exclude it from this scan.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(source.pages) { page in
                            pageButton(page)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Choose PDF Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isImporting)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(selectionButtonTitle, action: toggleAllPages)
                        .disabled(isImporting)
                }
            }
            .safeAreaInset(edge: .bottom) {
                importBar
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
            if isSelected {
                selectedIndexes.remove(page.index)
            } else {
                selectedIndexes.insert(page.index)
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 8) {
                Color.white
                    .aspectRatio(0.74, contentMode: .fit)
                    .overlay {
                        Image(uiImage: page.thumbnail)
                            .resizable()
                            .scaledToFit()
                            .opacity(isSelected ? 1 : 0.55)
                    }
                    .pageSurface()
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: PageSurface.cornerRadius, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 3)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(isSelected ? Color.white : Color.secondary, isSelected ? Color.accentColor : Color.white)
                            .padding(8)
                    }

                Text("Page \(page.index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
        .accessibilityLabel("Page \(page.index + 1)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var importBar: some View {
        BottomActionBar {
            Text(selectionSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: importSelectedPages) {
                HStack {
                    if isImporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(importButtonTitle)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedIndexes.isEmpty || isImporting)
        }
    }

    private var selectionButtonTitle: String {
        selectedIndexes.count == source.pages.count ? "Deselect All" : "Select All"
    }

    private var selectionSummary: String {
        if selectedIndexes.isEmpty { return "No pages selected" }
        if selectedIndexes.count == source.pages.count {
            return source.pages.count == 1 ? "1 page selected" : "All \(source.pages.count) pages selected"
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
        if selectedIndexes.count == source.pages.count {
            selectedIndexes.removeAll()
        } else {
            selectedIndexes = Set(source.pages.map(\.index))
        }
        Haptics.selection()
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
