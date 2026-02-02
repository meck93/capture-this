@testable import CaptureThisCore
import ScreenCaptureKit
import XCTest

final class RecordingEngineTests: XCTestCase {
  func testInitialState() {
    let engine = makeEngine()
    XCTAssertEqual(engine.state, .idle)
  }

  func testMakeOutputURL() {
    let engine = makeEngine()
    let dir = URL(fileURLWithPath: "/tmp/test")
    let url = engine.makeOutputURL(in: dir)
    XCTAssertTrue(url.lastPathComponent.hasPrefix("CaptureThis_"))
    XCTAssertTrue(url.lastPathComponent.hasSuffix(".mp4"))
    XCTAssertEqual(url.deletingLastPathComponent().path, "/tmp/test")
  }

  func testMakeOutputURLMOV() {
    let settings = RecordingSettings(outputFormat: .mov)
    let engine = makeEngine(settings: settings)
    let url = engine.makeOutputURL(in: URL(fileURLWithPath: "/tmp"))
    XCTAssertTrue(url.lastPathComponent.hasSuffix(".mov"))
  }

  func testMakeStreamConfiguration() {
    let settings = RecordingSettings(
      isMicrophoneEnabled: true,
      isSystemAudioEnabled: true
    )
    let engine = makeEngine(settings: settings)
    let config = engine.makeStreamConfiguration()
    XCTAssertTrue(config.capturesAudio)
    XCTAssertTrue(config.captureMicrophone)
    XCTAssertTrue(config.showsCursor)
  }

  func testMakeStreamConfigNoAudio() {
    let settings = RecordingSettings(
      isMicrophoneEnabled: false,
      isSystemAudioEnabled: false
    )
    let engine = makeEngine(settings: settings)
    let config = engine.makeStreamConfiguration()
    XCTAssertFalse(config.capturesAudio)
    XCTAssertFalse(config.captureMicrophone)
  }

  func testUpdateSettings() {
    let engine = makeEngine()
    let newSettings = RecordingSettings(countdownSeconds: 10)
    engine.updateSettings(newSettings)
    XCTAssertEqual(engine.settings.countdownSeconds, 10)
  }

  // MARK: - Helpers

  private func makeEngine(settings: RecordingSettings = RecordingSettings()) -> RecordingEngine {
    RecordingEngine(
      contentSelector: MockContentSelector(),
      directoryProvider: MockDirectoryProvider(),
      observer: MockObserver(),
      settings: settings
    )
  }
}

private final class MockContentSelector: ContentSelector {
  func selectContent(source _: CaptureSource) async throws -> SCContentFilter? {
    nil
  }

  func cancel() async {}
}

private final class MockDirectoryProvider: OutputDirectoryProvider, @unchecked Sendable {
  func recordingsDirectory() async throws -> URL {
    URL(fileURLWithPath: "/tmp/CaptureThisTests")
  }

  func stopAccessing() {}
}

private final class MockObserver: RecordingObserver {
  @MainActor func engineDidChangeState(_: RecordingState) {}
  @MainActor func engineDidFinishRecording(_: Recording) {}
  @MainActor func engineDidEncounterError(_: Error) {}
}
