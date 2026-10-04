import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL
    @State private var isResetPresented = false

    var body: some View {
        Form {
            Section {
                appHeader
            }

            Section {
                Picker(selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                } label: {
                    SettingsLabel("Appearance", systemImage: "circle.lefthalf.filled", color: .indigo)
                }

                Picker(selection: $settings.librarySortOrder) {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                } label: {
                    SettingsLabel("Sort Scans", systemImage: "arrow.up.arrow.down", color: .blue)
                }
            }

            Section {
                Picker(selection: $settings.exportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                } label: {
                    SettingsLabel("File Format", systemImage: "doc.fill", color: .red)
                }

                Picker(selection: $settings.compression) {
                    ForEach(CompressionPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                } label: {
                    SettingsLabel("Quality", systemImage: "slider.horizontal.3", color: .orange)
                }
            } header: {
                Text("Export")
            }

            Section {
                Toggle(isOn: $settings.usesLanguageCorrection) {
                    SettingsLabel("Language Correction", systemImage: "character.cursor.ibeam", color: .green)
                }
            } header: {
                Text("Text Recognition")
            } footer: {
                Text("Uses language context to improve recognized text. Turn off for codes or unusual spellings. Applies to pages added or edited from now on.")
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    externalLabel("Camera & Photos Access", systemImage: "hand.raised.fill", color: .blue)
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Scans and text recognition stay on this device. No account, ads, or analytics. You choose what to share when you export.")
            }

            Section {
                Link(destination: AppInformation.githubURL) {
                    externalLabel("Source Code", systemImage: "chevron.left.forwardslash.chevron.right", color: .gray)
                }

                Link(destination: AppInformation.issuesURL) {
                    externalLabel("Report an Issue", systemImage: "exclamationmark.bubble.fill", color: .pink)
                }

                NavigationLink {
                    LicenseView()
                } label: {
                    SettingsLabel("License", systemImage: "doc.text.fill", color: .gray)
                }
            } header: {
                Text("About")
            }

            Section {
                Button("Reset Settings", role: .destructive) {
                    isResetPresented = true
                }
                .frame(maxWidth: .infinity)
            } footer: {
                Text("Free and open source. Made for iPhone and iPad.")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
        }
        .pickerStyle(.navigationLink)
        .scrollContentBackground(.hidden)
        .background(ScanTheme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Reset Settings?", isPresented: $isResetPresented) {
            Button("Reset", role: .destructive) { settings.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Appearance, sorting, export defaults, and language correction return to their original values. Your scans are not changed.")
        }
    }

    /// Like the account card at the top of Settings.
    private var appHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.32, green: 0.78, blue: 0.68), Color(red: 0.0, green: 0.42, blue: 0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("MB Document Scanner")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ScanTheme.ink)
                Text(AppInformation.version)
                    .font(.subheadline)
                    .foregroundStyle(ScanTheme.secondaryInk)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func externalLabel(_ title: String, systemImage: String, color: Color) -> some View {
        HStack {
            SettingsLabel(title, systemImage: systemImage, color: color)
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ScanTheme.tertiaryInk)
                .accessibilityHidden(true)
        }
    }
}

private enum AppInformation {
    static let githubURL = URL(string: "https://github.com/Eli410/MB-document-scanner")!
    static let issuesURL = githubURL.appendingPathComponent("issues")

    static var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }
}

private struct LicenseView: View {
    var body: some View {
        ScrollView {
            Text(Self.license)
                .font(.body)
                .foregroundStyle(ScanTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .background(ScanTheme.background)
        .navigationTitle("License")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let license = """
    MIT License

    Copyright (c) 2026 MB Document Scanner contributors

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
}
