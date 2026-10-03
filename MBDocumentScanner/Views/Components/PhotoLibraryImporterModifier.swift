import PhotosUI
import SwiftUI
import UIKit

extension View {
    func photoLibraryImporter(
        isPresented: Binding<Bool>,
        onImport: @escaping ([UIImage]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> some View {
        modifier(PhotoLibraryImporterModifier(
            isPresented: isPresented,
            onImport: onImport,
            onError: onError
        ))
    }
}

private struct PhotoLibraryImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImport: ([UIImage]) -> Void
    let onError: (Error) -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isImporting = false

    func body(content: Content) -> some View {
        content
            .disabled(isImporting)
            .photosPicker(
                isPresented: $isPresented,
                selection: $selectedItems,
                maxSelectionCount: nil,
                selectionBehavior: .ordered,
                matching: .images,
                preferredItemEncoding: .automatic
            )
            .overlay {
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.16)
                            .ignoresSafeArea()

                        ProgressView("Importing Photos…")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .task(id: selectedItems) {
                await importSelection()
            }
    }

    @MainActor
    private func importSelection() async {
        let selection = selectedItems
        guard !selection.isEmpty else { return }
        isImporting = true
        defer {
            if selectedItems == selection {
                // A fresh selection also lets the same photos be imported again.
                selectedItems = []
                isImporting = false
            }
        }

        do {
            let images = try await PhotoLibraryImageImporter.importImages(from: selection)
            try Task.checkCancellation()
            onImport(images)
        } catch is CancellationError {
            // Leaving the view cancels the import without adding partial pages.
        } catch {
            guard !Task.isCancelled else { return }
            onError(error)
        }
    }
}
