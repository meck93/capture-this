import Foundation
import ScreenCaptureKit

public protocol ContentSelector: AnyObject {
  func selectContent(source: CaptureSource) async throws -> SCContentFilter?
  func cancel() async
}
