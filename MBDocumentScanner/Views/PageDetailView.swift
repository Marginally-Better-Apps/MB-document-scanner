import SwiftUI

struct PageDetailView: View {
    @ObservedObject var session: ScanSession
    let pageID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleteConfirmationPresented = false
    @State private var cropRequest: CropRequest?
    @State private var editRequest: EditRequest?
    @State private var isZoomPresented = false
    @State private var rotationCount = 0

    private var pageNumber: Int { session.pageNumber(for: pageID) ?? 1 }

    var body: some View {
        Group {
            if let page = session.page(withID: pageID) {
                List {
                    Section {
                        pagePreview(page)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))

                    Section {
                        recognizedTextRow(page)
                    }

                    QualitySections(quality: page.quality) { checkID, dismissed in
                        withAnimation {
                            session.setWarningDismissed(dismissed, checkID: checkID, pageID: pageID)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(ScanTheme.background)
                .navigationTitle("Page \(pageNumber) of \(session.pages.count)")
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    actionBar(page)
                }
                .fullScreenCover(isPresented: $isZoomPresented) {
                    PageZoomView(image: page.image, title: "Page \(pageNumber)")
                }
            } else {
                ContentUnavailableView("Page Removed", systemImage: "doc.badge.minus")
            }
        }
        .sensoryFeedback(.selection, trigger: rotationCount)
        .alert(
            "Delete Page \(pageNumber)?",
            isPresented: $isDeleteConfirmationPresented
        ) {
            Button("Delete Page", role: .destructive) {
                session.remove(pageID: pageID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This page and its recognized text will be removed from the scan.")
        }
        .fullScreenCover(item: $cropRequest) { request in
            CropPageView(
                image: request.image,
                onCancel: { cropRequest = nil },
                onComplete: { croppedImage in
                    session.applyCrop(pageID: pageID, image: croppedImage)
                    cropRequest = nil
                }
            )
        }
        .fullScreenCover(item: $editRequest) { request in
            PageEditorView(
                image: request.image,
                pageNumber: request.pageNumber,
                onCancel: { editRequest = nil },
                onComplete: { editedImage in
                    session.applyEdit(pageID: pageID, image: editedImage)
                    editRequest = nil
                }
            )
        }
    }

    private func pagePreview(_ page: ScannedPage) -> some View {
        Button {
            isZoomPresented = true
        } label: {
            PaperImage(image: page.image, cornerRadius: 6)
                .frame(maxWidth: .infinity, maxHeight: 460)
                .padding(.horizontal, 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scanned page \(pageNumber)")
        .accessibilityHint("Opens the page full screen for zooming")
    }

    private func recognizedTextRow(_ page: ScannedPage) -> some View {
        NavigationLink {
            RecognizedTextView(session: session, pageID: pageID)
        } label: {
            HStack(spacing: 12) {
                SettingsIcon("text.viewfinder", color: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recognized Text")
                        .foregroundStyle(ScanTheme.ink)
                    Text(textSummary(for: page))
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                        .lineLimit(1)
                }
            }
        }
        .disabled(page.quality == .analyzing)
    }

    private func actionBar(_ page: ScannedPage) -> some View {
        FloatingActionBar {
            Button {
                editRequest = EditRequest(image: page.image, pageNumber: pageNumber)
            } label: {
                FloatingActionLabel(title: "Markup", systemImage: "pencil.tip.crop.circle")
            }

            Button {
                cropRequest = CropRequest(image: page.image)
            } label: {
                FloatingActionLabel(title: "Crop", systemImage: "crop")
            }

            Button {
                rotationCount += 1
                session.rotate(pageID: pageID)
            } label: {
                FloatingActionLabel(title: "Rotate", systemImage: "rotate.right")
            }

            Button {
                isDeleteConfirmationPresented = true
            } label: {
                FloatingActionLabel(title: "Delete", systemImage: "trash", role: .destructive)
            }
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
    }

    private func textSummary(for page: ScannedPage) -> String {
        if page.quality == .analyzing { return "Reading on device…" }
        if page.recognizedText.isEmpty { return "No text found" }
        let words = page.recognizedText.split(whereSeparator: \.isWhitespace).count
        return "\(words) \(words == 1 ? "word" : "words")"
    }
}

private struct CropRequest: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct EditRequest: Identifiable {
    let id = UUID()
    let image: UIImage
    let pageNumber: Int
}
