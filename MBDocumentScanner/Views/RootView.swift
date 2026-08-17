import SwiftUI
import VisionKit

private enum LibraryRoute: Hashable {
    case document(UUID)
}

struct RootView: View {
    @StateObject private var library = ScanLibrary()
    @State private var path = NavigationPath()
    @State private var isScannerPresented = false
    @State private var isPDFImporterPresented = false
    @State private var scannerError: String?
    @State private var pendingDeletion: ScanSession?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if library.documents.isEmpty {
                    EmptyScanView()
                } else {
                    scansList
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Scans")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                newScanButton
            }
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case let .document(documentID):
                    if let document = library.document(withID: documentID) {
                        DocumentContentsView(library: library, session: document)
                    } else {
                        ContentUnavailableView("Scan Not Found", systemImage: "doc.badge.minus")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isScannerPresented) {
            DocumentScannerView(
                onComplete: { images in
                    let document = library.createDocument(with: images)
                    isScannerPresented = false
                    path.append(LibraryRoute.document(document.id))
                },
                onCancel: { isScannerPresented = false },
                onError: { error in
                    isScannerPresented = false
                    scannerError = error.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .pdfPageImporter(
            isPresented: $isPDFImporterPresented,
            onImport: { images, title in
                let document = library.createDocument(with: images, title: title)
                path.append(LibraryRoute.document(document.id))
            },
            onError: { error in
                scannerError = error.localizedDescription
            }
        )
        .confirmationDialog(
            "Delete \(pendingDeletion?.title ?? "this scan")?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Scan", role: .destructive) {
                if let document = pendingDeletion {
                    library.delete(documentID: document.id)
                }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Its pages and recognized text will be removed from this device.")
        }
        .alert("Unable to Complete Action", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                scannerError = nil
                library.storageError = nil
            }
        } message: {
            Text(scannerError ?? library.storageError ?? "Please try again.")
        }
    }

    private var scansList: some View {
        List {
            Section {
                ForEach(library.documents) { document in
                    NavigationLink(value: LibraryRoute.document(document.id)) {
                        ScanLibraryRow(session: document)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeletion = document
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("On This iPhone")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var newScanButton: some View {
        AddPagesMenu(
            onScan: beginScanning,
            onImportPDF: { isPDFImporterPresented = true },
            onPaste: pasteDocument
        ) {
            Label("Add Document", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { scannerError != nil || library.storageError != nil },
            set: { isPresented in
                if !isPresented {
                    scannerError = nil
                    library.storageError = nil
                }
            }
        )
    }

    private func beginScanning() {
        guard VNDocumentCameraViewController.isSupported else {
            scannerError = "Document scanning requires a supported iPhone camera."
            return
        }
        isScannerPresented = true
    }

    private func pasteDocument() {
        do {
            let images = try PasteboardImageImporter.importImages()
            let document = library.createDocument(with: images)
            path.append(LibraryRoute.document(document.id))
        } catch {
            scannerError = error.localizedDescription
        }
    }
}
