import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL
    @State private var isResetPresented = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker(selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                } label: {
                    SettingsLabel("Theme", systemImage: "circle.lefthalf.filled")
                }
            }
            .listRowBackground(ScanTheme.surface)

            Section("Library") {
                Picker(selection: $settings.librarySortOrder) {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                } label: {
                    SettingsLabel("Sort scans", systemImage: "arrow.up.arrow.down")
                }
            }
            .listRowBackground(ScanTheme.surface)

            Section {
                Picker(selection: $settings.exportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                } label: {
                    SettingsLabel("File format", systemImage: "doc")
                }

                Picker(selection: $settings.compression) {
                    ForEach(CompressionPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                } label: {
                    SettingsLabel("Quality", systemImage: "slider.horizontal.3")
                }
            } header: {
                Text("Export defaults")
            }
            .listRowBackground(ScanTheme.surface)

            Section {
                Toggle(isOn: $settings.usesLanguageCorrection) {
                    SettingsLabel("Language correction", systemImage: "text.badge.checkmark")
                }
            } header: {
                Text("Text recognition")
            } footer: {
                Text("Uses language context to improve recognized text. Turn off for codes or unusual spellings. Applies when pages are added or edited; existing text stays as it is.")
            }
            .listRowBackground(ScanTheme.surface)

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("On your device")
                            .font(.body.weight(.medium))
                            .foregroundStyle(ScanTheme.ink)
                        Text("Scans and text recognition stay on your device. No account, ads, or analytics. You choose what to share when you export.")
                            .font(.subheadline)
                            .foregroundStyle(ScanTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    settingsIcon("lock.shield")
                }
                .padding(.vertical, 6)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    externalLabel("Device permissions", systemImage: "hand.raised")
                }
            } header: {
                Text("Privacy & permissions")
            }
            .listRowBackground(ScanTheme.surface)

            Section {
                Button {
                    isResetPresented = true
                } label: {
                    SettingsLabel("Reset settings", systemImage: "arrow.counterclockwise")
                }
            }
            .listRowBackground(ScanTheme.surface)

            aboutSection
        }
        .pickerStyle(.navigationLink)
        .foregroundStyle(ScanTheme.ink)
        .scrollContentBackground(.hidden)
        .background(ScanTheme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ScanTheme.background, for: .navigationBar)
        .alert("Reset settings?", isPresented: $isResetPresented) {
            Button("Reset Settings", role: .destructive) { settings.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Appearance, sorting, export defaults, and language correction will return to their original values. Your scans will not be changed.")
        }
    }

    private var aboutSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(ScanTheme.accent)
                    .frame(width: 72, height: 72)
                    .background(ScanTheme.accentSoft, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)

                VStack(spacing: 5) {
                    Text("MB Document Scanner")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(ScanTheme.ink)
                    Text("Marginally Better Document Scanner")
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                }

                Text(AppInformation.version)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ScanTheme.secondaryInk)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .listRowSeparator(.hidden)

            Link(destination: AppInformation.githubURL) {
                externalLabel("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Link(destination: AppInformation.issuesURL) {
                externalLabel("Report an issue", systemImage: "bubble.left.and.bubble.right")
            }

            NavigationLink {
                LicenseView()
            } label: {
                SettingsLabel("MIT License", systemImage: "doc.plaintext")
            }
        } header: {
            Text("About")
        } footer: {
            Text("Free and open source. Made for iPhone and iPad.")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
        }
        .listRowBackground(ScanTheme.surface)
    }

    private func externalLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            SettingsLabel(title, systemImage: systemImage)
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ScanTheme.secondaryInk)
                .accessibilityHidden(true)
        }
    }
}

private struct SettingsLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(ScanTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            settingsIcon(systemImage)
        }
        .padding(.vertical, 3)
    }
}

private func settingsIcon(_ systemImage: String) -> some View {
    Image(systemName: systemImage)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(ScanTheme.accent)
        .frame(width: 30, height: 30)
        .background(ScanTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
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
        .navigationTitle("MIT License")
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
