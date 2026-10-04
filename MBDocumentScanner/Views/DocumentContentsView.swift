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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isScannerPresented = false
    @State private var isPhotoImporterPresented = false
    @State private var isPDFImporterPresented = false
    @State private var isPreparingShare = false
    @State private var shareItems: ShareItems?
    @State private var openedPageID: UUID?
    @State private var isRenamePresented = false
    @State private var isDeletePresented = false
    @State private var draftTitle = ""
    @State private var alertMessage: String?
    @State private var draggedPageID: UUID?
    @State private var pendingPageDeletion: PendingPageDeletion?

    private var gridColumns: [GridItem] {
        let minimum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 200 : (horizontalSizeClass == .regular ? 160 : 100)
        return [GridItem(.adaptive(minimum: minimum, maximum: 240), spacing: 18, alignment: .bottom)]
    }

    var body: some View {
        Group {
            if session.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc.viewfinder",
                    description: Text("Tap Add Pages to scan or import pages.")
                )
            } else {
                pagesGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScanTheme.background)
        .navigationTitle(session.title)
        .navigationSubtitleIfAvailable(subtitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu { documentMenuItems }
        .toolbar { toolbarContent }
        .navigationDestination(item: $openedPageID) { pageID in
            PageDetailView(session: session, pageID: pageID)
        }
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
        .sheet(item: $shareItems) { items in
            ShareSheet(activityItems: items.urls)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
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
        .alert("Something Went Wrong", isPresented: Binding(
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
            VStack(alignment: .leading, spacing: 20) {
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
                        .accessibilityAction(named: "Move Earlier") {
                            if index > 0 {
                                _ = session.movePage(page.id, toPositionOf: session.pages[index - 1].id)
                            }
                        }
                        .accessibilityAction(named: "Move Later") {
                            if index < session.pages.count - 1 {
                                _ = session.movePage(page.id, toPositionOf: session.pages[index + 1].id)
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

    private var subtitle: String {
        "\(session.pages.count.pageCountText) · Edited \(session.modifiedAt.formatted(.relative(presentation: .named)))"
    }

    /// The subtitle on iOS 17 and 18, and the pages that need a second look on every version.
    @ViewBuilder
    private var header: some View {
        let showsSubtitle: Bool = {
            if #available(iOS 26.0, *) { return false }
            return true
        }()
        let flaggedPage = session.pages.first(where: { $0.quality.needsReview })

        if showsSubtitle || flaggedPage != nil {
            VStack(alignment: .leading, spacing: 10) {
                if showsSubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                }

                if let flaggedPage {
                    Button {
                        openedPageID = flaggedPage.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ScanTheme.warning)
                            Text("\(session.pagesNeedingReview.pageCountText) to check")
                                .foregroundStyle(ScanTheme.ink)
                            Spacer(minLength: 8)
                            Text("Show")
                                .foregroundStyle(ScanTheme.accent)
                        }
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 50)
                        .scanCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the first page to check")
                }
            }
        }
    }

    private var addPagesMenu: some View {
        AddPagesMenu(
            onScan: beginScanning,
            onImportPhotos: { isPhotoImporterPresented = true },
            onImportPDF: { isPDFImporterPresented = true },
            onPaste: pastePages
        ) {
            ActionLabel("Add Pages", systemImage: "plus")
        }
    }

    private var shareButton: some View {
        Button {
            share(as: settings.exportFormat)
        } label: {
            if isPreparingShare {
                ProgressView()
                    .accessibilityLabel("Preparing to share")
            } else {
                ActionLabel("Share", systemImage: "square.and.arrow.up")
            }
        }
        .prominentActionStyle()
        .disabled(session.isEmpty || isPreparingShare)
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
            share(as: otherFormat)
        } label: {
            Label(otherFormat == .pdf ? "Share as PDF" : "Share as Images", systemImage: otherFormat.systemImage)
        }
        .disabled(session.isEmpty || isPreparingShare)

        Divider()

        Button(role: .destructive) {
            isDeletePresented = true
        } label: {
            Label("Delete Scan", systemImage: "trash")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            addPagesMenu
            Spacer()
            shareButton
        }
    }

    private var otherFormat: ExportFormat {
        settings.exportFormat == .pdf ? .images : .pdf
    }

    private func share(as format: ExportFormat) {
        isPreparingShare = true
        Task {
            do {
                let urls = try await ExportService.export(
                    pages: session.pages,
                    title: session.title,
                    format: format,
                    compression: settings.compression
                )
                shareItems = ShareItems(urls: urls)
            } catch {
                alertMessage = error.localizedDescription
            }
            isPreparingShare = false
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
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ScanTheme.warning)
                }
                Text("\(pageNumber)")
                    .monospacedDigit()
                    .foregroundStyle(ScanTheme.secondaryInk)
            }
            .font(.subheadline.weight(.medium))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(pageNumber)")
        .accessibilityValue(page.quality.needsReview ? "Needs a check" : "")
    }
}

private struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
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
