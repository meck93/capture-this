@testable import CaptureThisCore
import XCTest

final class TimeIntervalFormattingTests: XCTestCase {
  func testFormattedClock() {
    XCTAssertEqual(TimeInterval(0).formattedClock, "00:00")
    XCTAssertEqual(TimeInterval(5).formattedClock, "00:05")
    XCTAssertEqual(TimeInterval(65).formattedClock, "01:05")
    XCTAssertEqual(TimeInterval(600).formattedClock, "10:00")
  }
}
