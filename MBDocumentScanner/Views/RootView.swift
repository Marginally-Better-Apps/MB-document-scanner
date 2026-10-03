import SwiftUI
import VisionKit

private enum LibraryRoute: Hashable {
    case document(UUID)
}

struct RootView: View {
    @StateObject private var library = ScanLibrary()
    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var isScannerPresented = false
    @State private var isPDFImporterPresented = false
    @State private var scannerError: String?
    @State private var pendingDeletion: ScanSession?
    @State private var renamingDocument: ScanSession?
    @State private var isRenamePresented = false
    @State private var draftTitle = ""
    @State private var exportingDocument: ScanSession?

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
                newScanBar
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
        .sheet(item: $exportingDocument) { document in
            ExportOptionsView(session: document)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Rename Scan", isPresented: $isRenamePresented) {
            TextField("Name", text: $draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") { renamingDocument?.rename(to: draftTitle) }
        }
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

    private var filteredDocuments: [ScanSession] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return library.documents }
        return library.documents.filter { document in
            document.title.localizedStandardContains(query)
                || document.pages.contains { $0.recognizedText.localizedStandardContains(query) }
        }
    }

    private var scansList: some View {
        List {
            if filteredDocuments.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filteredDocuments) { document in
                        NavigationLink(value: LibraryRoute.document(document.id)) {
                            ScanLibraryRow(session: document)
                        }
                        .contextMenu { documentActions(for: document) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = document
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                exportingDocument = document
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .tint(.accentColor)
                        }
                    }
                } header: {
                    Text(searchText.isEmpty ? "On This iPhone" : "Results")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search titles and text"
        )
    }

    @ViewBuilder
    private func documentActions(for document: ScanSession) -> some View {
        Button {
            draftTitle = document.title
            renamingDocument = document
            isRenamePresented = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            exportingDocument = document
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(document.isEmpty)

        Divider()

        Button(role: .destructive) {
            pendingDeletion = document
        } label: {
            Label("Delete Scan", systemImage: "trash")
        }
    }

    private var newScanBar: some View {
        BottomActionBar {
            HStack(spacing: 12) {
                Button(action: beginScanning) {
                    Label("Scan Document", systemImage: "doc.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                ImportMenu(
                    onImportPDF: { isPDFImporterPresented = true },
                    onPaste: pasteDocument
                )
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
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
