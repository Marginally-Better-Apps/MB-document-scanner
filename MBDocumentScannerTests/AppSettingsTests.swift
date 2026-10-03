import XCTest
@testable import MBDocumentScanner

@MainActor
final class AppSettingsTests: XCTestCase {
    func testNewSettingsUseRecommendedDefaults() throws {
        try withDefaults { defaults in
            assertRecommendedDefaults(AppSettings(defaults: defaults))
        }
    }

    func testAllPreferencesPersistAcrossSettingsInstances() throws {
        try withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.appearance = .dark
            settings.exportFormat = .images
            settings.compression = .bestQuality
            settings.librarySortOrder = .oldest
            settings.usesLanguageCorrection = false

            let restored = AppSettings(defaults: defaults)

            XCTAssertEqual(restored.appearance, .dark)
            XCTAssertEqual(restored.exportFormat, .images)
            XCTAssertEqual(restored.compression, .bestQuality)
            XCTAssertEqual(restored.librarySortOrder, .oldest)
            XCTAssertFalse(restored.usesLanguageCorrection)
        }
    }

    func testUnknownPreferencesFallBackToRecommendedDefaults() throws {
        try withDefaults { defaults in
            defaults.set("unknown", forKey: "settings.appearance")
            defaults.set("unknown", forKey: "settings.exportFormat")
            defaults.set("unknown", forKey: "settings.compression")
            defaults.set("unknown", forKey: "settings.librarySortOrder")
            defaults.set("unknown", forKey: "settings.usesLanguageCorrection")

            assertRecommendedDefaults(AppSettings(defaults: defaults))
        }
    }

    func testResetRestoresDefaultsAndPreservesUnrelatedPreferences() throws {
        try withDefaults { defaults in
            defaults.set("keep me", forKey: "unrelatedPreference")
            let settings = AppSettings(defaults: defaults)
            settings.appearance = .light
            settings.exportFormat = .images
            settings.compression = .smaller
            settings.librarySortOrder = .title
            settings.usesLanguageCorrection = false

            settings.reset()

            assertRecommendedDefaults(settings)
            assertRecommendedDefaults(AppSettings(defaults: defaults))
            XCTAssertEqual(defaults.string(forKey: "unrelatedPreference"), "keep me")
            for key in [
                "settings.appearance",
                "settings.exportFormat",
                "settings.compression",
                "settings.librarySortOrder",
                "settings.usesLanguageCorrection"
            ] {
                XCTAssertNil(defaults.object(forKey: key))
            }
        }
    }

    func testDateSortOrdersUseTheSelectedDateAndDirection() {
        let first = makeSession(title: "First", created: 1, modified: 3)
        let second = makeSession(title: "Second", created: 2, modified: 1)
        let third = makeSession(title: "Third", created: 3, modified: 2)
        let documents = [second, first, third]

        XCTAssertEqual(LibrarySortOrder.recent.sorted(documents).map(\.id), [first.id, third.id, second.id])
        XCTAssertEqual(LibrarySortOrder.newest.sorted(documents).map(\.id), [third.id, second.id, first.id])
        XCTAssertEqual(LibrarySortOrder.oldest.sorted(documents).map(\.id), [first.id, second.id, third.id])
    }

    func testTitleSortUsesNaturalNumberOrder() {
        let first = makeSession(title: "Receipt 1")
        let second = makeSession(title: "Receipt 2")
        let tenth = makeSession(title: "Receipt 10")

        XCTAssertEqual(
            LibrarySortOrder.title.sorted([tenth, second, first]).map(\.id),
            [first.id, second.id, tenth.id]
        )
    }

    func testMatchingTitlesUseDatesThenStableIdentifiersToBreakTies() throws {
        let firstID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let secondID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let first = makeSession(id: firstID, title: "Receipt", created: 3, modified: 4)
        let second = makeSession(id: secondID, title: "Receipt", created: 3, modified: 4)
        let earlierCreation = makeSession(title: "Receipt", created: 2, modified: 4)
        let earlierModification = makeSession(title: "Receipt", created: 3, modified: 3)
        let documents = [earlierModification, second, earlierCreation, first]

        XCTAssertEqual(
            LibrarySortOrder.title.sorted(documents).map(\.id),
            [first.id, second.id, earlierCreation.id, earlierModification.id]
        )
        for order in LibrarySortOrder.allCases {
            XCTAssertEqual(order.sorted([second, first]).map(\.id), [first.id, second.id])
            XCTAssertEqual(order.sorted([first, second]).map(\.id), [first.id, second.id])
        }
    }

    private func assertRecommendedDefaults(
        _ settings: AppSettings,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(settings.appearance, .system, file: file, line: line)
        XCTAssertEqual(settings.exportFormat, .pdf, file: file, line: line)
        XCTAssertEqual(settings.compression, .balanced, file: file, line: line)
        XCTAssertEqual(settings.librarySortOrder, .recent, file: file, line: line)
        XCTAssertTrue(settings.usesLanguageCorrection, file: file, line: line)
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    private func makeSession(
        id: UUID = UUID(),
        title: String,
        created: TimeInterval = 1,
        modified: TimeInterval = 1
    ) -> ScanSession {
        ScanSession(
            id: id,
            title: title,
            createdAt: Date(timeIntervalSince1970: created),
            modifiedAt: Date(timeIntervalSince1970: modified)
        )
    }
}
