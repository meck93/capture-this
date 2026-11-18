@testable import CaptureThisCore
import XCTest

final class GIFExportServiceTests: XCTestCase {
  func testStandardPolicyMatchesProductLimits() {
    let policy = GIFExportPolicy.standard

    XCTAssertEqual(policy.maxDuration, 10)
    XCTAssertEqual(policy.targetWidth, 720)
    XCTAssertEqual(policy.targetFramesPerSecond, 12)
  }

  func testQualityPolicyMappings() {
    let compact = GIFExportPolicy(quality: .compact)
    XCTAssertEqual(compact.maxDuration, 10)
    XCTAssertEqual(compact.targetWidth, 1080)
    XCTAssertEqual(compact.targetFramesPerSecond, 15)

    let balanced = GIFExportPolicy(quality: .balanced)
    XCTAssertEqual(balanced.targetWidth, 1440)
    XCTAssertEqual(balanced.targetFramesPerSecond, 24)

    let high = GIFExportPolicy(quality: .high)
    XCTAssertEqual(high.targetWidth, 2160)
    XCTAssertEqual(high.targetFramesPerSecond, 24)
  }

  func testUniqueDestinationURLUsesOriginalNameWithGIFExtension() {
    let tempDir = makeTemporaryDirectory()
    let videoURL = tempDir.appendingPathComponent("recording.mp4")
    let service = GIFExportService(policy: .standard)

    let destination = service.uniqueDestinationURL(for: videoURL)

    XCTAssertEqual(destination, tempDir.appendingPathComponent("recording.gif"))
  }

  func testUniqueDestinationURLAvoidsExistingFiles() throws {
    let tempDir = makeTemporaryDirectory()
    let videoURL = tempDir.appendingPathComponent("recording.mp4")
    try Data().write(to: tempDir.appendingPathComponent("recording.gif"))
    try Data().write(to: tempDir.appendingPathComponent("recording-2.gif"))
    let service = GIFExportService(policy: .standard)

    let destination = service.uniqueDestinationURL(for: videoURL)

    XCTAssertEqual(destination, tempDir.appendingPathComponent("recording-3.gif"))
  }

  private func makeTemporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
