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
    @State private var searchText = ""
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
                    EmptyScanView(
                        onScan: beginScanning,
                        onImportPhotos: { isPhotoImporterPresented = true },
                        onImportPDF: { isPDFImporterPresented = true },
                        onPaste: pasteDocument
                    )
                } else {
                    scansList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ScanTheme.background)
            .navigationTitle("Scans")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    optionsMenu
                }

                if !library.documents.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        importMenu
                        Spacer()
                        scanButton
                    }
                }
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
                    withAnimation { library.delete(documentID: document.id) }
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

    // MARK: - List

    private var scansList: some View {
        let sections = LibrarySection.group(filteredDocuments, by: settings.librarySortOrder)

        return List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.documents) { document in
                        NavigationLink(value: LibraryRoute.document(document.id)) {
                            ScanLibraryRow(session: document)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDeletion = document
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDeletion = document
                            } label: {
                                Label("Delete Scan", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search"
        )
        .overlay {
            if filteredDocuments.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .animation(.default, value: library.documents.map(\.id))
    }

    private var filteredDocuments: [ScanSession] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = settings.librarySortOrder.sorted(library.documents)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { document in
            document.title.localizedCaseInsensitiveContains(query)
                || document.pages.contains { $0.recognizedText.localizedCaseInsensitiveContains(query) }
        }
    }

    private var optionsMenu: some View {
        Menu {
            Picker(selection: $settings.librarySortOrder) {
                ForEach(LibrarySortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }
            .pickerStyle(.menu)

            Divider()

            Button {
                path.append(LibraryRoute.settings)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }

    // MARK: - Actions

    private var importMenu: some View {
        AddPagesMenu(
            includesScan: false,
            onScan: beginScanning,
            onImportPhotos: { isPhotoImporterPresented = true },
            onImportPDF: { isPDFImporterPresented = true },
            onPaste: pasteDocument
        ) {
            ActionLabel("Import", systemImage: "square.and.arrow.down")
        }
    }

    private var scanButton: some View {
        Button(action: beginScanning) {
            ActionLabel("Scan", systemImage: "doc.viewfinder")
        }
        .prominentActionStyle()
        .accessibilityLabel("Scan Document")
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

/// Date buckets in the style of Notes and Files: Today, Yesterday, then months.
private struct LibrarySection: Identifiable {
    let title: String?
    let documents: [ScanSession]

    var id: String { title ?? "all" }

    @MainActor
    static func group(_ documents: [ScanSession], by order: LibrarySortOrder) -> [LibrarySection] {
        guard order != .title else {
            return documents.isEmpty ? [] : [LibrarySection(title: nil, documents: documents)]
        }

        let calendar = Calendar.current
        let now = Date()
        var sections: [LibrarySection] = []

        for document in documents {
            let date = order == .recent ? document.modifiedAt : document.createdAt
            let title = bucketTitle(for: date, now: now, calendar: calendar)
            if let last = sections.last, last.title == title {
                sections[sections.count - 1] = LibrarySection(title: title, documents: last.documents + [document])
            } else {
                sections.append(LibrarySection(title: title, documents: [document]))
            }
        }
        return sections
    }

    private static func bucketTitle(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let startOfToday = calendar.startOfDay(for: now)
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: startOfToday).day {
            if days < 7 { return "Previous 7 Days" }
            if days < 30 { return "Previous 30 Days" }
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.wide))
        }
        return date.formatted(.dateTime.month(.wide).year())
    }
}
