@testable import CaptureThisCore
import XCTest

final class GIFExportServiceTests: XCTestCase {
  func testStandardPolicyMatchesProductLimits() {
    let policy = GIFExportPolicy.standard

    XCTAssertEqual(policy.maxDuration, 10)
    XCTAssertEqual(policy.targetWidth, 720)
    XCTAssertEqual(policy.targetFramesPerSecond, 12)
    XCTAssertEqual(policy.warningFileSize, 10 * 1024 * 1024)
  }

  func testEstimateFileSizeUsesFrameCountAndScaledSize() {
    let service = GIFExportService(policy: .standard)

    let estimate = service.estimateFileSize(
      frameCount: 120,
      scaledSize: CGSize(width: 720, height: 405)
    )

    XCTAssertEqual(estimate, 11_664_000)
    XCTAssertGreaterThan(estimate, GIFExportPolicy.standard.warningFileSize)
  }

  func testEstimateFileSizeHasMinimumPerFrameCost() {
    let service = GIFExportService(policy: .standard)

    let estimate = service.estimateFileSize(
      frameCount: 3,
      scaledSize: CGSize(width: 10, height: 10)
    )

    XCTAssertEqual(estimate, 96000)
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
