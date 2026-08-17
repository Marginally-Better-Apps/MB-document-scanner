import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension View {
    func pdfPageImporter(
        isPresented: Binding<Bool>,
        onImport: @escaping ([UIImage], String) -> Void,
        onError: @escaping (Error) -> Void
    ) -> some View {
        modifier(PDFPageImporterModifier(
            isPresented: isPresented,
            onImport: onImport,
            onError: onError
        ))
    }
}

private struct PDFPageImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImport: ([UIImage], String) -> Void
    let onError: (Error) -> Void

    @State private var preparedSource: PDFPageImportSource?
    @State private var isPreparing = false

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false,
                onCompletion: handleFileSelection
            )
            .fullScreenCover(item: $preparedSource) { source in
                PDFPageSelectionView(
                    source: source,
                    onImport: { images in
                        finishImport(images: images, source: source)
                    },
                    onCancel: {
                        PDFPageImporter.removeTemporaryCopy(of: source)
                        preparedSource = nil
                    }
                )
                .onDisappear {
                    PDFPageImporter.removeTemporaryCopy(of: source)
                }
            }
            .overlay {
                if isPreparing {
                    ZStack {
                        Color.black.opacity(0.16)
                            .ignoresSafeArea()

                        ProgressView("Opening PDF…")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            preparePDF(at: url)
        case let .failure(error):
            let nsError = error as NSError
            guard nsError.code != NSUserCancelledError else { return }
            onError(error)
        }
    }

    private func preparePDF(at url: URL) {
        isPreparing = true
        Task {
            do {
                preparedSource = try await PDFPageImporter.prepare(from: url)
            } catch {
                onError(error)
            }
            isPreparing = false
        }
    }

    private func finishImport(images: [UIImage], source: PDFPageImportSource) {
        PDFPageImporter.removeTemporaryCopy(of: source)
        preparedSource = nil
        onImport(images, source.suggestedTitle)
    }
}
