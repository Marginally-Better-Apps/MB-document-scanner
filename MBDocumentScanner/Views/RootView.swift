import SwiftUI
import VisionKit

private enum LibraryRoute: Hashable {
    case document(UUID)
    case settings
}

struct RootView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var library: ScanLibrary
    @State private var path = NavigationPath()
    @State private var isScannerPresented = false
    @State private var isPhotoImporterPresented = false
    @State private var isPDFImporterPresented = false
    @State private var scannerError: String?
    @State private var pendingDeletion: ScanSession?

    init(settings: AppSettings) {
        self.settings = settings
        _library = StateObject(wrappedValue: ScanLibrary(settings: settings))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if library.documents.isEmpty {
                    EmptyScanView()
                } else {
                    scansList
                }
            }
            .background(ScanTheme.background)
            .navigationTitle("Scans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ScanTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: LibraryRoute.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 9) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(ScanTheme.accent)
                            .accessibilityHidden(true)
                        Text("Scans")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(ScanTheme.ink)
                    }
                    .accessibilityAddTraits(.isHeader)
                }
            }
            .safeAreaInset(edge: .bottom) {
                newScanButton
            }
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .settings:
                    SettingsView()
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
        .photoLibraryImporter(
            isPresented: $isPhotoImporterPresented,
            onImport: { images in
                let document = library.createDocument(with: images)
                path.append(LibraryRoute.document(document.id))
            },
            onError: { error in
                scannerError = error.localizedDescription
            }
        )
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
        .alert(
            "Delete \(pendingDeletion?.title ?? "this scan")?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
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
                ForEach(settings.librarySortOrder.sorted(library.documents)) { document in
                    NavigationLink(value: LibraryRoute.document(document.id)) {
                        ScanLibraryRow(session: document)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .alignmentGuide(.listRowSeparatorLeading) { _ in -16 }
                    .listRowBackground(ScanTheme.surface)
                    .listRowSeparatorTint(ScanTheme.border)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeletion = document
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Your documents (\(library.documents.count))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ScanTheme.secondaryInk)
                    .textCase(nil)
                    .padding(.bottom, 6)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
    }

    private var newScanButton: some View {
        VStack(spacing: 10) {
            AddPagesMenu(
                onScan: beginScanning,
                onImportPhotos: { isPhotoImporterPresented = true },
                onImportPDF: { isPDFImporterPresented = true },
                onPaste: pasteDocument
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                    Text("Add document")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScanPrimaryButtonStyle())
        }
        .frame(maxWidth: 552)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(ScanTheme.background)
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
