import SwiftUI

struct EmptyScanView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.blue.opacity(0.10))
                    .frame(width: 132, height: 132)

                Image(systemName: "doc.viewfinder.fill")
                    .font(.system(size: 62, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
            }
            .accessibilityHidden(true)

            Text("Scan Your First Document")
                .font(.title2.weight(.semibold))
                .padding(.top, 28)

            Text("Capture clean pages, recognize text, check scan quality, and export—entirely on your device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 42)
                .padding(.top, 10)

            Label("Private by design", systemImage: "lock.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 20)

            Spacer()
        }
    }
}
