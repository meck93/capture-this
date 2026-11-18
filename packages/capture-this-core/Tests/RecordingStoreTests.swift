@testable import CaptureThisCore
import XCTest

final class RecordingStoreTests: XCTestCase {
  func testAddRecording() {
    let recording = Recording(
      id: UUID(),
      url: URL(fileURLWithPath: "/tmp/test.mp4"),
      createdAt: Date(),
      duration: 10,
      captureType: .display
    )
    let list = RecordingStore.add(recording, to: [])
    XCTAssertEqual(list.count, 1)
    XCTAssertEqual(list.first?.id, recording.id)
  }

  func testMaxItems() {
    var list: [Recording] = []
    for idx in 0 ..< 25 {
      let rec = Recording(
        id: UUID(),
        url: URL(fileURLWithPath: "/tmp/test\(idx).mp4"),
        createdAt: Date(),
        duration: Double(idx),
        captureType: .display
      )
      list = RecordingStore.add(rec, to: list)
    }
    XCTAssertEqual(list.count, 20)
  }
}
