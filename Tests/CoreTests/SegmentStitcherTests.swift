import AVFoundation
@testable import CaptureThisCore
import XCTest

final class SegmentStitcherTests: XCTestCase {
  func testStitchSingleSegmentMovesFileToDestination() async throws {
    let tempDir = makeTemporaryDirectory()
    let segmentURL = tempDir.appendingPathComponent("segment_0.mp4")
    let destinationURL = tempDir.appendingPathComponent("final.mp4")
    try Data("segment".utf8).write(to: segmentURL)

    let stitcher = SegmentStitcher(fileManager: .default, merger: MockSegmentMerger())
    let result = try await stitcher.stitch(
      segments: [segmentURL],
      destination: destinationURL,
      outputFileType: .mp4
    )

    XCTAssertEqual(result, destinationURL)
    XCTAssertFalse(FileManager.default.fileExists(atPath: segmentURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
  }

  func testStitchNoSegmentsThrowsFileWriteFailed() async {
    let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("no-segments.mp4")
    let stitcher = SegmentStitcher(fileManager: .default, merger: MockSegmentMerger())

    do {
      _ = try await stitcher.stitch(segments: [], destination: destinationURL, outputFileType: .mp4)
      XCTFail("Expected error")
    } catch let error as AppError {
      guard case .fileWriteFailed = error else {
        return XCTFail("Unexpected AppError: \(error)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testStitchFailurePreservesSegmentFiles() async throws {
    let tempDir = makeTemporaryDirectory()
    let segmentA = tempDir.appendingPathComponent("segment_a.mp4")
    let segmentB = tempDir.appendingPathComponent("segment_b.mp4")
    let destinationURL = tempDir.appendingPathComponent("final.mp4")

    try Data("a".utf8).write(to: segmentA)
    try Data("b".utf8).write(to: segmentB)

    let merger = MockSegmentMerger()
    merger.error = AppError.fileWriteFailed
    let stitcher = SegmentStitcher(fileManager: .default, merger: merger)

    do {
      _ = try await stitcher.stitch(
        segments: [segmentA, segmentB],
        destination: destinationURL,
        outputFileType: .mp4
      )
      XCTFail("Expected failure")
    } catch {
      XCTAssertTrue(FileManager.default.fileExists(atPath: segmentA.path))
      XCTAssertTrue(FileManager.default.fileExists(atPath: segmentB.path))
      XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
    }
  }

  func testSuccessfulStitchCleansUpTempSegments() async throws {
    let tempDir = makeTemporaryDirectory()
    let segmentA = tempDir.appendingPathComponent("segment_a.mp4")
    let segmentB = tempDir.appendingPathComponent("segment_b.mp4")
    let destinationURL = tempDir.appendingPathComponent("final.mp4")

    try Data("a".utf8).write(to: segmentA)
    try Data("b".utf8).write(to: segmentB)

    let merger = MockSegmentMerger()
    merger.resultWriter = { destination in
      try Data("stitched".utf8).write(to: destination)
      return destination
    }

    let stitcher = SegmentStitcher(fileManager: .default, merger: merger)
    _ = try await stitcher.stitch(
      segments: [segmentA, segmentB],
      destination: destinationURL,
      outputFileType: .mp4
    )

    XCTAssertFalse(FileManager.default.fileExists(atPath: segmentA.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: segmentB.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
  }

  private func makeTemporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}

private final class MockSegmentMerger: SegmentMerging {
  var error: Error?
  var resultWriter: ((URL) throws -> URL)?

  func merge(segments _: [URL], destination: URL, outputFileType _: AVFileType) async throws -> URL {
    if let error {
      throw error
    }

    if let resultWriter {
      return try resultWriter(destination)
    }

    try Data("merged".utf8).write(to: destination)
    return destination
  }
}
