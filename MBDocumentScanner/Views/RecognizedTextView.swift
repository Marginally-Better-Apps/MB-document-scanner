import SwiftUI

struct RecognizedTextView: View {
    @ObservedObject var session: ScanSession
    let pageID: UUID

    @State private var didCopy = false

    private var text: String {
        session.page(withID: pageID)?.recognizedText ?? ""
    }

    var body: some View {
        Group {
            if text.isEmpty {
                ContentUnavailableView(
                    "No Text Found",
                    systemImage: "text.magnifyingglass",
                    description: Text("Try rescanning with brighter, even lighting and keep the page steady.")
                )
            } else {
                ScrollView {
                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
                .safeAreaInset(edge: .bottom) { actionBar }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Recognized Text")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var actionBar: some View {
        BottomActionBar {
            HStack(spacing: 12) {
                Button(action: copyText) {
                    Label(didCopy ? "Copied" : "Copy All", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderedProminent)

                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }

    private func copyText() {
        UIPasteboard.general.string = text
        Haptics.success()
        withAnimation { didCopy = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { didCopy = false }
        }
    }
}
