import XCTest

@testable import ShellCove

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "shellcove-settings-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testFreshDefaults() {
        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.appearance, .system)
        XCTAssertEqual(settings.terminalFontSize, SettingsStore.defaultFontSize)
        XCTAssertEqual(settings.connectTimeoutSeconds, SettingsStore.defaultConnectTimeout)
        XCTAssertFalse(settings.autoProbeOnDetailOpen)
        XCTAssertNil(settings.appearance.colorScheme)
    }

    func testChangesArePersistedAndReloaded() {
        let settings = SettingsStore(defaults: defaults)
        settings.appearance = .dark
        settings.terminalFontSize = 14.5
        settings.connectTimeoutSeconds = 30
        settings.autoProbeOnDetailOpen = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertEqual(reloaded.appearance.colorScheme, .dark)
        XCTAssertEqual(reloaded.terminalFontSize, 14.5)
        XCTAssertEqual(reloaded.connectTimeoutSeconds, 30)
        XCTAssertTrue(reloaded.autoProbeOnDetailOpen)
    }

    func testStoredOutOfRangeValuesAreClamped() {
        defaults.set(99.0, forKey: SettingsKey.terminalFontSize)
        defaults.set(1, forKey: SettingsKey.connectTimeoutSeconds)

        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.terminalFontSize, SettingsStore.fontSizeRange.upperBound)
        XCTAssertEqual(settings.connectTimeoutSeconds, SettingsStore.connectTimeoutRange.lowerBound)
    }

    func testUnknownAppearanceFallsBackToSystem() {
        defaults.set("neon", forKey: SettingsKey.appearance)

        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.appearance, .system)
    }
}
