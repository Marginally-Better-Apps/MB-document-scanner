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
                    description: Text("Try retaking the page in brighter light.")
                )
                .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(wordCount) \(wordCount == 1 ? "word" : "words")")
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                        .padding(.horizontal, 20)

                    Text(text)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundStyle(ScanTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .scanCard()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .background(ScanTheme.background)
        .navigationTitle("Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: text) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(text.isEmpty)
                .accessibilityLabel("Share text")
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    UIPasteboard.general.string = text
                    didCopy = true
                } label: {
                    ActionLabel(didCopy ? "Copied" : "Copy All Text", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .prominentActionStyle()
                .disabled(text.isEmpty)
            }
        }
        .sensoryFeedback(.success, trigger: didCopy)
        .onChange(of: text) { _, _ in didCopy = false }
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
        }
    }
}
