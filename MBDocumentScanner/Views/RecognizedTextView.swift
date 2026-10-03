import SwiftUI

struct RecognizedTextView: View {
    @ObservedObject var session: ScanSession
    let pageID: UUID

    @State private var didCopy = false

    private var text: String {
        session.page(withID: pageID)?.recognizedText ?? ""
    }

    private var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    var body: some View {
        ScrollView {
            if text.isEmpty {
                ContentUnavailableView(
                    "No Text Found",
                    systemImage: "text.magnifyingglass",
                    description: Text("Try rescanning with brighter, even lighting and keep the page steady.")
                )
                .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.quote")
                            .font(.title3)
                            .foregroundStyle(ScanTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(ScanTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Page \(session.pageNumber(for: pageID) ?? 1)")
                                .font(.headline)
                                .foregroundStyle(ScanTheme.ink)
                            Text("\(wordCount) \(wordCount == 1 ? "word" : "words") · Recognized on device")
                                .font(.caption)
                                .foregroundStyle(ScanTheme.secondaryInk)
                        }
                    }

                    Text(text)
                        .font(.body)
                        .lineSpacing(7)
                        .foregroundStyle(ScanTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                        .scanCard()
                }
                .padding(20)
            }
        }
        .background(ScanTheme.background)
        .tint(ScanTheme.accent)
        .navigationTitle("Recognized Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = text
                    didCopy = true
                } label: {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .fontWeight(.semibold)
                .disabled(text.isEmpty)
            }
        }
        .sensoryFeedback(.success, trigger: didCopy)
        .onChange(of: text) { _, _ in didCopy = false }
    }
}
