import AVFoundation
@testable import CaptureThisCore
import ScreenCaptureKit
import XCTest

final class CaptureServiceRefactorTests: XCTestCase {
  func testPauseRecordingRejectsSecondPauseWhileTransitionInFlight() async throws {
    let stream = MockCaptureStream()
    let service = makeService(stream: stream)
    let baseURL = temporaryFileURL(name: "pause-in-flight.mp4")

    service.installTestSession(
      stream: stream,
      recordingOutput: MockRecordingOutput(),
      baseOutputURL: baseURL,
      outputFileType: .mp4,
      paused: false
    )

    let firstPause = Task {
      try await service.pauseRecording()
    }

    await waitUntil { stream.removeRecordingOutputCallCount == 1 }

    do {
      try await service.pauseRecording()
      XCTFail("Expected second pause to fail while transition is in flight")
    } catch let appError as AppError {
      guard case .captureFailed = appError else {
        return XCTFail("Unexpected app error: \(appError)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    service.handleRecordingOutputDidFinish()
    try await firstPause.value
    XCTAssertEqual(service.phaseForTesting(), "paused")
  }

  func testStopRecordingWaitsForPauseTransitionThenStops() async throws {
    let stream = MockCaptureStream()
    let service = makeService(stream: stream)
    let folder = makeTemporaryDirectory()
    let finalURL = folder.appendingPathComponent("final-stop.mp4")
    let activeSegmentURL = folder.appendingPathComponent("segment-stop.mp4")
    try Data(repeating: 7, count: 16).write(to: activeSegmentURL)

    service.installTestSession(
      stream: stream,
      recordingOutput: MockRecordingOutput(),
      baseOutputURL: finalURL,
      outputFileType: .mp4,
      activeSegmentURL: activeSegmentURL,
      paused: false
    )

    let pauseTask = Task {
      try await service.pauseRecording()
    }

    await waitUntil { stream.removeRecordingOutputCallCount == 1 }

    let stopTask = Task {
      try await service.stopRecording()
    }

    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(stream.stopCaptureCallCount, 0)
    XCTAssertEqual(service.phaseForTesting(), "pausing")

    service.handleRecordingOutputDidFinish()

    try await pauseTask.value
    let stoppedURL = try await stopTask.value
    XCTAssertEqual(stoppedURL.standardizedFileURL, finalURL.standardizedFileURL)
    XCTAssertEqual(stream.stopCaptureCallCount, 1)
    XCTAssertEqual(service.phaseForTesting(), "idle")
    XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
  }

  func testDiscardRecordingWaitsForPauseTransitionThenTearsDown() async throws {
    let stream = MockCaptureStream()
    let service = makeService(stream: stream)
    let folder = makeTemporaryDirectory()
    let finalURL = folder.appendingPathComponent("final-discard.mp4")
    let activeSegmentURL = folder.appendingPathComponent("segment-discard.mp4")
    try Data(repeating: 3, count: 32).write(to: activeSegmentURL)

    service.installTestSession(
      stream: stream,
      recordingOutput: MockRecordingOutput(),
      baseOutputURL: finalURL,
      outputFileType: .mp4,
      activeSegmentURL: activeSegmentURL,
      paused: false
    )

    let pauseTask = Task {
      try await service.pauseRecording()
    }

    await waitUntil { stream.removeRecordingOutputCallCount == 1 }

    let discardTask = Task {
      await service.discardRecording()
    }

    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(stream.stopCaptureCallCount, 0)
    XCTAssertEqual(service.phaseForTesting(), "pausing")

    service.handleRecordingOutputDidFinish()

    try await pauseTask.value
    await discardTask.value

    XCTAssertEqual(stream.stopCaptureCallCount, 1)
    XCTAssertEqual(service.phaseForTesting(), "idle")
    XCTAssertFalse(FileManager.default.fileExists(atPath: activeSegmentURL.path))
  }

  func testResumeRecordingFailureRollsBackPhaseAndSegmentIndex() {
    let stream = MockCaptureStream()
    stream.addRecordingOutputError = AppError.captureFailed

    let service = makeService(stream: stream)
    let baseURL = temporaryFileURL(name: "resume-rollback.mp4")

    service.installTestSession(
      stream: stream,
      recordingOutput: nil,
      baseOutputURL: baseURL,
      outputFileType: .mp4,
      segmentIndex: 2,
      paused: true
    )

    do {
      try service.resumeRecording()
      XCTFail("Expected resume failure")
    } catch let appError as AppError {
      guard case .captureFailed = appError else {
        return XCTFail("Unexpected app error: \(appError)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(stream.addRecordingOutputCallCount, 1)
    XCTAssertEqual(service.phaseForTesting(), "paused")
    XCTAssertEqual(service.segmentIndexForTesting(), 2)
  }

  func testRecoverPartialRecordingReturnsLargestSegmentWhenStitchFails() async throws {
    let stream = MockCaptureStream()
    let merger = MockFailingMerger()
    let stitcher = SegmentStitcher(fileManager: .default, merger: merger)
    let service = makeService(stream: stream, stitcher: stitcher)

    let folder = makeTemporaryDirectory()
    let smallSegment = folder.appendingPathComponent("small.mp4")
    let largeSegment = folder.appendingPathComponent("large.mp4")
    let emptySegment = folder.appendingPathComponent("empty.mp4")
    try Data(repeating: 1, count: 8).write(to: smallSegment)
    try Data(repeating: 2, count: 32).write(to: largeSegment)
    try Data().write(to: emptySegment)

    let finalURL = folder.appendingPathComponent("final.mp4")
    service.installTestSession(
      stream: stream,
      recordingOutput: nil,
      baseOutputURL: finalURL,
      outputFileType: .mp4,
      segmentURLs: [smallSegment, largeSegment, emptySegment],
      segmentIndex: 2,
      paused: true
    )

    let recovered = await service.recoverPartialRecording()

    XCTAssertEqual(recovered?.standardizedFileURL, largeSegment.standardizedFileURL)
    XCTAssertTrue(FileManager.default.fileExists(atPath: largeSegment.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
  }

  func testStopAndResetStopsActiveStreamWithoutRecordingOutput() async throws {
    let stream = MockCaptureStream()
    let service = makeService(stream: stream)

    service.installTestSession(
      stream: stream,
      recordingOutput: nil,
      baseOutputURL: temporaryFileURL(name: "stop-reset.mp4"),
      outputFileType: .mp4,
      paused: true
    )

    try await service.stopAndReset(clearSegmentState: false)

    XCTAssertEqual(stream.stopCaptureCallCount, 1)
  }

  private func makeService(
    stream: MockCaptureStream,
    stitcher: SegmentStitcher = SegmentStitcher(fileManager: .default, merger: MockPassThroughMerger())
  ) -> CaptureService {
    CaptureService(
      stitcher: stitcher,
      fileManager: .default,
      streamBuilder: MockCaptureStreamBuilder(stream: stream),
      recordingOutputBuilder: MockRecordingOutputBuilder()
    )
  }

  private func waitUntil(
    timeout: TimeInterval = 1,
    check: @escaping () -> Bool
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if check() {
        return
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for condition")
  }

  private func temporaryFileURL(name: String) -> URL {
    makeTemporaryDirectory().appendingPathComponent(name)
  }

  private func makeTemporaryDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}

private final class MockCaptureStreamBuilder: CaptureStreamBuilding {
  let stream: MockCaptureStream

  init(stream: MockCaptureStream) {
    self.stream = stream
  }

  func makeStream(
    filter _: SCContentFilter,
    configuration _: SCStreamConfiguration,
    delegate _: SCStreamDelegate?
  ) -> any CaptureStreamControlling {
    stream
  }
}

private final class MockRecordingOutputBuilder: CaptureRecordingOutputBuilding {
  func makeRecordingOutput(
    configuration _: SCRecordingOutputConfiguration,
    delegate _: SCRecordingOutputDelegate
  ) -> any CaptureRecordingOutputControlling {
    MockRecordingOutput()
  }
}

private final class MockCaptureStream: CaptureStreamControlling {
  var addRecordingOutputCallCount = 0
  var removeRecordingOutputCallCount = 0
  var stopCaptureCallCount = 0

  var addRecordingOutputError: Error?

  func addStreamOutput(
    _: SCStreamOutput,
    type _: SCStreamOutputType,
    sampleHandlerQueue _: DispatchQueue?
  ) throws {}

  func removeStreamOutput(_: SCStreamOutput, type _: SCStreamOutputType) throws {}

  func addRecordingOutput(_: any CaptureRecordingOutputControlling) throws {
    addRecordingOutputCallCount += 1
    if let addRecordingOutputError {
      throw addRecordingOutputError
    }
  }

  func removeRecordingOutput(_: any CaptureRecordingOutputControlling) throws {
    removeRecordingOutputCallCount += 1
  }

  func startCapture() async throws {}

  func stopCapture() async throws {
    stopCaptureCallCount += 1
  }
}

private final class MockRecordingOutput: CaptureRecordingOutputControlling {}

private final class MockFailingMerger: SegmentMerging {
  func merge(segments _: [URL], destination _: URL, outputFileType _: AVFileType) async throws -> URL {
    throw AppError.fileWriteFailed
  }
}

private final class MockPassThroughMerger: SegmentMerging {
  func merge(segments _: [URL], destination: URL, outputFileType _: AVFileType) async throws -> URL {
    destination
  }
}
