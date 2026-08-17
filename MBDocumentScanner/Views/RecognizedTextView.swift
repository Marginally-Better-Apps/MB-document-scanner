import SwiftUI

struct RecognizedTextView: View {
    @ObservedObject var session: ScanSession
    let pageID: UUID

    @State private var didCopy = false

    private var text: String {
        session.page(withID: pageID)?.recognizedText ?? ""
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
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
        .background(Color(uiColor: .systemBackground))
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
                .disabled(text.isEmpty)
            }
        }
    }
}

