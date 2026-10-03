import SwiftUI

struct PageDetailView: View {
    @ObservedObject var session: ScanSession
    let pageID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleteConfirmationPresented = false
    @State private var cropRequest: CropRequest?
    @State private var editRequest: EditRequest?

    var body: some View {
        Group {
            if let page = session.page(withID: pageID) {
                ScrollView {
                    VStack(spacing: 18) {
                        pagePreview(page)

                        QualitySummaryCard(quality: page.quality) { checkID, dismissed in
                            session.setWarningDismissed(dismissed, checkID: checkID, pageID: pageID)
                        }

                        recognizedTextCard(page)
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
                .background(ScanTheme.background)
                .tint(ScanTheme.accent)
                .navigationTitle("Page \(session.pageNumber(for: pageID) ?? 1)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editRequest = EditRequest(
                                image: page.image,
                                pageNumber: session.pageNumber(for: pageID) ?? 1
                            )
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                        }
                        .fontWeight(.semibold)
                        .accessibilityLabel("Edit page")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                cropRequest = CropRequest(image: page.image)
                            } label: {
                                Label("Crop Page", systemImage: "crop")
                            }

                            Button {
                                session.rotate(pageID: pageID)
                            } label: {
                                Label("Rotate Right", systemImage: "rotate.right")
                            }

                            Divider()

                            Button(role: .destructive) {
                                isDeleteConfirmationPresented = true
                            } label: {
                                Label("Delete Page", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Page options")
                    }
                }
            } else {
                ContentUnavailableView("Page Removed", systemImage: "doc.badge.minus")
            }
        }
        .alert(
            "Delete this page?",
            isPresented: $isDeleteConfirmationPresented
        ) {
            Button("Delete Page", role: .destructive) {
                session.remove(pageID: pageID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only removes the page from the current scan.")
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("PAGE \(session.pageNumber(for: pageID) ?? 1) OF \(session.pages.count)", systemImage: "doc")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(ScanTheme.secondaryInk)
                Spacer()
                Text("Preview")
                    .font(.caption)
                    .foregroundStyle(ScanTheme.secondaryInk)
            }
            .padding(.horizontal, 4)

            Image(uiImage: page.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(ScanTheme.border, lineWidth: 1)
                }
                .accessibilityLabel("Scanned page \(session.pageNumber(for: pageID) ?? 1)")
        }
        .padding(14)
        .scanCard()
    }

    private func recognizedTextCard(_ page: ScannedPage) -> some View {
        NavigationLink {
            RecognizedTextView(session: session, pageID: pageID)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "text.viewfinder")
                    .font(.title3)
                    .foregroundStyle(ScanTheme.accent)
                    .frame(width: 46, height: 46)
                    .background(ScanTheme.accentSoft, in: RoundedRectangle(cornerRadius: 15))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Recognized text")
                        .font(.headline)
                        .foregroundStyle(ScanTheme.ink)
                    Text(textSummary(for: page))
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ScanTheme.secondaryInk)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .scanCard()
        }
        .buttonStyle(.plain)
        .disabled(page.quality == .analyzing)
    }

    private func textSummary(for page: ScannedPage) -> String {
        if page.quality == .analyzing { return "Recognizing text on device…" }
        if page.recognizedText.isEmpty { return "No readable text was found." }
        return page.recognizedText.replacingOccurrences(of: "\n", with: " ")
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
