@testable import CaptureThisCore
import XCTest

final class RecordingSettingsTests: XCTestCase {
  func testDefaultSettings() {
    let settings = RecordingSettings()
    XCTAssertEqual(settings.countdownSeconds, 3)
    XCTAssertTrue(settings.isCameraEnabled)
    XCTAssertTrue(settings.isMicrophoneEnabled)
    XCTAssertFalse(settings.isSystemAudioEnabled)
    XCTAssertEqual(settings.outputFormat, .mp4)
    XCTAssertEqual(settings.recordingQuality, .standard)
  }

  func testUpdating() {
    let settings = RecordingSettings()
    let updated = settings.updating(countdownSeconds: 5, cameraEnabled: false, recordingQuality: .high)
    XCTAssertEqual(updated.countdownSeconds, 5)
    XCTAssertFalse(updated.isCameraEnabled)
    XCTAssertEqual(updated.recordingQuality, .high)
    // Unchanged fields
    XCTAssertTrue(updated.isMicrophoneEnabled)
    XCTAssertEqual(updated.outputFormat, .mp4)
  }
}
