import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL
    @State private var isResetPresented = false

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }

                Picker("Sort Scans By", selection: $settings.librarySortOrder) {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
            }

            Section {
                Picker("Share As", selection: $settings.exportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }

                Picker("File Size", selection: $settings.compression) {
                    ForEach(CompressionPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
            } header: {
                Text("Sharing")
            } footer: {
                Text("Used when you tap Share on a scan.")
            }

            Section {
                Toggle("Auto-Correct Scanned Text", isOn: $settings.usesLanguageCorrection)
            } footer: {
                Text("Fixes small reading mistakes in scanned words. Turn this off for codes and serial numbers.")
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    externalLabel("Camera & Photos Access")
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Your scans stay on this device. Nothing is uploaded unless you share it.")
            }

            Section {
                Link(destination: AppInformation.githubURL) {
                    externalLabel("Source Code")
                }

                Link(destination: AppInformation.issuesURL) {
                    externalLabel("Report a Problem")
                }

                NavigationLink("License") {
                    LicenseView()
                }
            } header: {
                Text("About")
            } footer: {
                Text("MB Document Scanner, \(AppInformation.version)")
            }

            Section {
                Button("Reset Settings", role: .destructive) {
                    isResetPresented = true
                }
            }
        }
        .pickerStyle(.navigationLink)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Reset Settings?", isPresented: $isResetPresented) {
            Button("Reset", role: .destructive) { settings.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your scans won’t be changed.")
        }
    }

    private func externalLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(ScanTheme.ink)
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
