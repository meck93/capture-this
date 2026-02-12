import Foundation
import ScreenCaptureKit

public protocol CaptureServicing: AnyObject {
  func startRecording(
    filter: SCContentFilter,
    configuration: SCStreamConfiguration,
    outputURL: URL,
    options: CaptureRecordingOptions,
    handlers: CaptureRecordingHandlers
  ) async throws

  func pauseRecording() async throws
  func resumeRecording() throws
  func stopRecording() async throws -> URL
  func discardRecording() async
  func recoverPartialRecording() async -> URL?
}
