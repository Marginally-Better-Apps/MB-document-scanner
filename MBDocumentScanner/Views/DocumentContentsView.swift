import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct DocumentContentsView: View {
    @ObservedObject var library: ScanLibrary
    @ObservedObject var session: ScanSession
    @EnvironmentObject private var settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isScannerPresented = false
    @State private var isPhotoImporterPresented = false
    @State private var isPDFImporterPresented = false
    @State private var isExportPresented = false
    @State private var isRenamePresented = false
    @State private var isDeletePresented = false
    @State private var draftTitle = ""
    @State private var alertMessage: String?
    @State private var draggedPageID: UUID?
    @State private var pendingPageDeletion: PendingPageDeletion?

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 200 : 100, maximum: 220), spacing: 18, alignment: .bottom)]
    }

    var body: some View {
        Group {
            if session.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc.viewfinder",
                    description: Text("Add pages below, or delete this scan from the title menu.")
                )
            } else {
                pagesGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScanTheme.background)
        .tint(ScanTheme.accent)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu { documentMenuItems }
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { actionBar }
        .fullScreenCover(isPresented: $isScannerPresented) {
            DocumentScannerView(
                onComplete: { images in
                    session.add(images)
                    isScannerPresented = false
                },
                onCancel: { isScannerPresented = false },
                onError: { error in
                    isScannerPresented = false
                    alertMessage = error.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isExportPresented) {
            ExportOptionsView(
                session: session,
                format: settings.exportFormat,
                compression: settings.compression
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .photoLibraryImporter(
            isPresented: $isPhotoImporterPresented,
            onImport: { images in
                session.add(images)
            },
            onError: { error in
                alertMessage = error.localizedDescription
            }
        )
        .pdfPageImporter(
            isPresented: $isPDFImporterPresented,
            onImport: { images, _ in
                session.add(images)
            },
            onError: { error in
                alertMessage = error.localizedDescription
            }
        )
        .alert("Rename Scan", isPresented: $isRenamePresented) {
            TextField("Name", text: $draftTitle)
                .submitLabel(.done)
            Button("Cancel", role: .cancel) {}
            Button("Save") { session.rename(to: draftTitle) }
        }
        .alert("Unable to Add Pages", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "Please try again.")
        }
        .alert(
            "Delete Page \(pendingPageDeletion?.pageNumber ?? 1)?",
            isPresented: Binding(
                get: { pendingPageDeletion != nil },
                set: { if !$0 { pendingPageDeletion = nil } }
            )
        ) {
            Button("Delete Page", role: .destructive) {
                if let pendingPageDeletion {
                    session.remove(pageID: pendingPageDeletion.pageID)
                }
                pendingPageDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPageDeletion = nil
            }
        } message: {
            Text("This page and its recognized text will be removed from the scan.")
        }
        .alert(
            "Delete \(session.title)?",
            isPresented: $isDeletePresented
        ) {
            Button("Delete Scan", role: .destructive) {
                library.delete(documentID: session.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its pages and recognized text will be removed from this device.")
        }
    }

    private var pagesGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                LazyVGrid(columns: gridColumns, spacing: 26) {
                    ForEach(Array(session.pages.enumerated()), id: \.element.id) { index, page in
                        NavigationLink {
                            PageDetailView(session: session, pageID: page.id)
                        } label: {
                            PageTile(page: page, pageNumber: index + 1)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                session.rotate(pageID: page.id)
                            } label: {
                                Label("Rotate Right", systemImage: "rotate.right")
                            }

                            Button(role: .destructive) {
                                pendingPageDeletion = PendingPageDeletion(
                                    pageID: page.id,
                                    pageNumber: index + 1
                                )
                            } label: {
                                Label("Delete Page", systemImage: "trash")
                            }
                        }
                        .onDrag {
                            draggedPageID = page.id
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            return NSItemProvider(object: page.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: PageReorderDropDelegate(
                                targetPageID: page.id,
                                session: session,
                                draggedPageID: $draggedPageID
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            draggedPageID = nil
            return false
        }
    }

    /// One large, light numeral, the way Compass and Level lead with a reading.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(session.pages.count)")
                    .font(.system(size: 64, weight: .thin))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(ScanTheme.ink)
                Text(session.pages.count == 1 ? "page" : "pages")
                    .font(.title3.weight(.light))
                    .foregroundStyle(ScanTheme.secondaryInk)
            }

            HStack(spacing: 6) {
                Text("Edited \(session.modifiedAt.formatted(.relative(presentation: .named)))")
                    .foregroundStyle(ScanTheme.secondaryInk)
                if session.pagesNeedingReview > 0 {
                    Text("·").foregroundStyle(ScanTheme.tertiaryInk)
                    Label("\(session.pagesNeedingReview) to review", systemImage: "exclamationmark.circle.fill")
                        .labelStyle(CompactLabelStyle())
                        .foregroundStyle(ScanTheme.warning)
                } else if session.pages.contains(where: { $0.quality == .analyzing }) {
                    Text("·").foregroundStyle(ScanTheme.tertiaryInk)
                    Text("Reading text…")
                        .foregroundStyle(ScanTheme.secondaryInk)
                }
            }
            .font(.subheadline)
        }
        .animation(.snappy, value: session.pages.count)
        .accessibilityElement(children: .combine)
    }

    private var actionBar: some View {
        FloatingActionBar {
            AddPagesMenu(
                onScan: beginScanning,
                onImportPhotos: { isPhotoImporterPresented = true },
                onImportPDF: { isPDFImporterPresented = true },
                onPaste: pastePages
            ) {
                FloatingActionLabel(title: "Add Pages", systemImage: "plus")
            }

            Button {
                isExportPresented = true
            } label: {
                FloatingActionLabel(title: "Export", systemImage: "square.and.arrow.up", isProminent: !session.isEmpty)
            }
            .buttonStyle(.plain)
            .disabled(session.isEmpty)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var documentMenuItems: some View {
        Button {
            draftTitle = session.title
            isRenamePresented = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            isExportPresented = true
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(session.isEmpty)

        Divider()

        Button(role: .destructive) {
            isDeletePresented = true
        } label: {
            Label("Delete Scan", systemImage: "trash")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                documentMenuItems
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("Scan options")
        }
    }

    private func beginScanning() {
        guard VNDocumentCameraViewController.isSupported else {
            alertMessage = "Document scanning requires a supported device camera."
            return
        }
        isScannerPresented = true
    }

    private func pastePages() {
        do {
            session.add(try PasteboardImageImporter.importImages())
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

/// A page as paper on the canvas with its number beneath, like Files and Pages.
private struct PageTile: View {
    let page: ScannedPage
    let pageNumber: Int

    var body: some View {
        VStack(spacing: 10) {
            Color.clear
                .aspectRatio(0.75, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    PaperImage(image: page.image)
                }

            HStack(spacing: 4) {
                if page.quality == .analyzing {
                    ProgressView()
                        .controlSize(.mini)
                } else if page.quality.needsReview {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(ScanTheme.warning)
                }
                Text("\(pageNumber)")
                    .monospacedDigit()
                    .foregroundStyle(ScanTheme.secondaryInk)
            }
            .font(.footnote.weight(.medium))
            .frame(height: 18)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(pageNumber)")
        .accessibilityValue(page.quality.title)
        .accessibilityHint("Opens the page")
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

private struct PendingPageDeletion {
    let pageID: UUID
    let pageNumber: Int
}

private struct PageReorderDropDelegate: DropDelegate {
    let targetPageID: UUID
    let session: ScanSession
    @Binding var draggedPageID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggedPageID else { return }

        var didMove = false
        withAnimation(.snappy(duration: 0.18)) {
            didMove = session.movePage(draggedPageID, toPositionOf: targetPageID)
        }

        if didMove {
            let feedback = UISelectionFeedbackGenerator()
            feedback.prepare()
            feedback.selectionChanged()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPageID = nil
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()
        feedback.impactOccurred()
        return true
    }
}
