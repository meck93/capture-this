@testable import CaptureThisCore
import XCTest

final class KeyboardShortcutSettingsTests: XCTestCase {
  func testDefaultsAvoidCommandPaletteBinding() {
    let settings = KeyboardShortcutSettings()

    XCTAssertFalse(settings.isEnabled)
    XCTAssertEqual(settings.startStop, ShortcutBinding(keyCode: 15, modifiers: 768))
    XCTAssertNil(settings.pauseResume)
    XCTAssertEqual(settings.openApp, ShortcutBinding(keyCode: 8, modifiers: 768))
    XCTAssertEqual(settings.cancel, ShortcutBinding(keyCode: 53, modifiers: 0))
  }

  func testUpdatingCanAssignAndClearShortcut() {
    let binding = ShortcutBinding(keyCode: 12, modifiers: 768)
    let assigned = KeyboardShortcutSettings().updating(.pauseResume, with: binding)

    XCTAssertEqual(assigned.pauseResume, binding)

    let cleared = assigned.updating(.pauseResume, with: nil)
    XCTAssertNil(cleared.pauseResume)
  }

  func testClearedShortcutRemainsClearedWhenPersisted() throws {
    let settings = KeyboardShortcutSettings().updating(.startStop, with: nil)
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(KeyboardShortcutSettings.self, from: data)

    XCTAssertNil(decoded.startStop)
  }
}
