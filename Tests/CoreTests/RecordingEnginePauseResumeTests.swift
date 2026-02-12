@testable import CaptureThisCore
import ScreenCaptureKit
import XCTest

final class RecordingEnginePauseResumeTests: XCTestCase {
  private var originalRecordings: [Recording] = []

  override func setUp() {
    super.setUp()
    originalRecordings = RecordingStore.load()
  }

  override func tearDown() {
    RecordingStore.save(originalRecordings)
    super.tearDown()
  }

  func testPauseResumeTogglesStateAndCallsCaptureService() async {
    let captureService = MockCaptureService()
    let now = Date(timeIntervalSince1970: 100)
    let engine = makeEngine(captureService: captureService, now: now)

    engine.setState(.recording(isPaused: false))
    engine.pauseResume()

    await waitUntil { captureService.pauseCallCount == 1 }
    await waitUntil { engine.state == .recording(isPaused: true) }

    engine.pauseResume()

    await waitUntil { captureService.resumeCallCount == 1 }
    await waitUntil { engine.state == .recording(isPaused: false) }
  }

  func testPauseResumeIgnoresRapidDuplicateTransitions() async {
    let captureService = MockCaptureService()
    let pauseGate = PauseGate()
    captureService.pauseBlock = {
      await pauseGate.wait()
    }

    let engine = makeEngine(captureService: captureService, now: Date(timeIntervalSince1970: 100))
    engine.setState(.recording(isPaused: false))

    engine.pauseResume()
    engine.pauseResume()

    await waitUntil { captureService.pauseCallCount == 1 }
    XCTAssertEqual(captureService.pauseCallCount, 1)

    await pauseGate.resume()

    await waitUntil { engine.state == .recording(isPaused: true) }
    XCTAssertEqual(captureService.pauseCallCount, 1)
  }

  func testRecordingDurationExcludesPausedTime() {
    var currentTime = Date(timeIntervalSince1970: 1000)
    let engine = makeEngine(captureService: MockCaptureService(), nowProvider: { currentTime })
    let start = currentTime.addingTimeInterval(-10)

    engine.pausedDuration = 3
    engine.setState(.recording(isPaused: false))
    XCTAssertEqual(engine.recordingDuration(since: start), "00:07")

    currentTime = currentTime.addingTimeInterval(5)
    engine.lastPauseDate = currentTime.addingTimeInterval(-2)
    engine.setState(.recording(isPaused: true))
    XCTAssertEqual(engine.recordingDuration(since: start), "00:10")
  }

  func testStopWhilePausedUsesStopRecordingAndPersistsRecording() async {
    let captureService = MockCaptureService()
    let observer = MockObserver()
    let outputURL = temporaryFileURL(name: "stop-paused.mp4")
    FileManager.default.createFile(atPath: outputURL.path, contents: Data("ok".utf8))
    captureService.stopRecordingURL = outputURL

    let now = Date(timeIntervalSince1970: 200)
    let engine = makeEngine(captureService: captureService, observer: observer, now: now)
    engine.recordingStartDate = now.addingTimeInterval(-10)
    engine.setState(.recording(isPaused: true))

    await engine.stopRecording(discard: false)

    XCTAssertEqual(captureService.stopCallCount, 1)
    XCTAssertEqual(captureService.discardCallCount, 0)
    XCTAssertEqual(engine.state, .idle)

    let finishedCount = await MainActor.run { observer.finishedRecordings.count }
    XCTAssertEqual(finishedCount, 1)
    XCTAssertTrue(RecordingStore.load().contains { $0.url == outputURL })
  }

  func testDiscardWhilePausedCallsDiscardAndDoesNotPersist() async {
    let captureService = MockCaptureService()
    let observer = MockObserver()

    let now = Date(timeIntervalSince1970: 300)
    let engine = makeEngine(captureService: captureService, observer: observer, now: now)
    engine.recordingStartDate = now.addingTimeInterval(-10)
    engine.setState(.recording(isPaused: true))

    let preCount = RecordingStore.load().count
    await engine.stopRecording(discard: true)

    XCTAssertEqual(captureService.discardCallCount, 1)
    XCTAssertEqual(captureService.stopCallCount, 0)
    XCTAssertEqual(engine.state, .idle)

    let finishedCount = await MainActor.run { observer.finishedRecordings.count }
    XCTAssertEqual(finishedCount, 0)
    XCTAssertEqual(RecordingStore.load().count, preCount)
  }

  func testStopFailureRecoversFromRecoverPartialRecording() async {
    let captureService = MockCaptureService()
    captureService.stopRecordingError = AppError.captureFailed

    let recoveredURL = temporaryFileURL(name: "recovered.mp4")
    FileManager.default.createFile(atPath: recoveredURL.path, contents: Data("ok".utf8))
    captureService.recoveredURL = recoveredURL

    let observer = MockObserver()
    let now = Date(timeIntervalSince1970: 400)
    let engine = makeEngine(captureService: captureService, observer: observer, now: now)
    engine.recordingStartDate = now.addingTimeInterval(-10)
    engine.setState(.recording(isPaused: false))

    await engine.stopRecording(discard: false)

    XCTAssertEqual(captureService.stopCallCount, 1)
    XCTAssertEqual(captureService.recoverCallCount, 1)
    XCTAssertEqual(engine.state, .idle)

    let finished = await MainActor.run { observer.finishedRecordings }
    XCTAssertEqual(finished.count, 1)
    XCTAssertEqual(finished.first?.url, recoveredURL)
  }

  // MARK: - Helpers

  private func makeEngine(
    captureService: MockCaptureService,
    observer: MockObserver = MockObserver(),
    now: Date? = nil,
    nowProvider: (() -> Date)? = nil
  ) -> RecordingEngine {
    let resolvedNowProvider: () -> Date = if let nowProvider {
      nowProvider
    } else if let now {
      { now }
    } else {
      Date.init
    }

    return RecordingEngine(
      contentSelector: TestContentSelector(),
      directoryProvider: TestDirectoryProvider(),
      observer: observer,
      settings: RecordingSettings(),
      captureService: captureService,
      permissionService: MockPermissionService(),
      nowProvider: resolvedNowProvider
    )
  }

  private func waitUntil(
    timeout: TimeInterval = 1,
    check: @escaping () -> Bool
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if check() { return }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for condition")
  }

  private func temporaryFileURL(name: String) -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.appendingPathComponent(name)
  }
}

private final class TestContentSelector: ContentSelector {
  func selectContent(source _: CaptureSource) async throws -> SCContentFilter? {
    nil
  }

  func cancel() async {}
}

private final class TestDirectoryProvider: OutputDirectoryProvider, @unchecked Sendable {
  func recordingsDirectory() async throws -> URL {
    URL(fileURLWithPath: "/tmp/CaptureThisTests")
  }

  func stopAccessing() {}
}

private final class MockCaptureService: CaptureServicing {
  var pauseCallCount = 0
  var resumeCallCount = 0
  var stopCallCount = 0
  var discardCallCount = 0
  var recoverCallCount = 0

  var stopRecordingURL = URL(fileURLWithPath: "/tmp/CaptureThis/mock-stop.mp4")
  var stopRecordingError: Error?
  var recoveredURL: URL?

  var pauseBlock: (() async throws -> Void)?

  func startRecording(
    filter _: SCContentFilter,
    configuration _: SCStreamConfiguration,
    outputURL _: URL,
    options _: CaptureRecordingOptions,
    handlers _: CaptureRecordingHandlers
  ) async throws {}

  func pauseRecording() async throws {
    pauseCallCount += 1
    try await pauseBlock?()
  }

  func resumeRecording() throws {
    resumeCallCount += 1
  }

  func stopRecording() async throws -> URL {
    stopCallCount += 1
    if let stopRecordingError {
      throw stopRecordingError
    }
    return stopRecordingURL
  }

  func discardRecording() async {
    discardCallCount += 1
  }

  func recoverPartialRecording() async -> URL? {
    recoverCallCount += 1
    return recoveredURL
  }
}

private final class MockPermissionService: PermissionServicing {
  func ensureScreenRecordingAccess() -> Bool {
    true
  }

  func requestCameraAccess() async -> Bool {
    true
  }

  func requestMicrophoneAccess() async -> Bool {
    true
  }
}

private final class MockObserver: RecordingObserver {
  var finishedRecordings: [Recording] = []

  @MainActor func engineDidChangeState(_: RecordingState) {}

  @MainActor
  func engineDidFinishRecording(_ recording: Recording) {
    finishedRecordings.append(recording)
  }

  @MainActor func engineDidEncounterError(_: Error) {}
}

private actor PauseGate {
  private var continuation: CheckedContinuation<Void, Never>?

  func wait() async {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}
