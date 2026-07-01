import CaptureThisCore
import os
import ScreenCaptureKit

final class PickerService: NSObject {
  private var continuation: CheckedContinuation<SCContentFilter?, Error>?
  private let picker = SCContentSharingPicker.shared
  private let logger = Logger(subsystem: "com.capturethis.CaptureThis", category: "Picker")

  @MainActor
  func pickContent(allowedSource: CaptureSource) async throws -> SCContentFilter? {
    if continuation != nil {
      return nil
    }

    var config = SCContentSharingPickerConfiguration()
    switch allowedSource {
    case .display:
      config.allowedPickerModes = .singleDisplay
    case .window:
      config.allowedPickerModes = .singleWindow
    case .application:
      config.allowedPickerModes = .singleApplication
    }

    picker.defaultConfiguration = config
    picker.add(self)

    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      logger.notice("Activating content sharing picker")
      picker.isActive = true
      picker.present()
    }
  }

  @MainActor
  func cancel() {
    logger.notice("Canceling content sharing picker")
    picker.isActive = false
    continuation?.resume(returning: nil)
    continuation = nil
    picker.remove(self)
  }

  @MainActor
  func finishPicking(with filter: SCContentFilter?) {
    logger.notice("Finishing content sharing picker selection")
    picker.isActive = false
    continuation?.resume(returning: filter)
    continuation = nil
    picker.remove(self)
  }

  @MainActor
  func failPicking(with error: Error) {
    logger.error("Content sharing picker failed: \(error.localizedDescription, privacy: .public)")
    picker.isActive = false
    continuation?.resume(throwing: error)
    continuation = nil
    picker.remove(self)
  }
}

extension PickerService: SCContentSharingPickerObserver {
  func contentSharingPicker(
    _: SCContentSharingPicker,
    didUpdateWith filter: SCContentFilter,
    for _: SCStream?
  ) {
    Task { @MainActor in
      finishPicking(with: filter)
    }
  }

  func contentSharingPicker(_: SCContentSharingPicker, didCancelFor _: SCStream?) {
    Task { @MainActor in
      finishPicking(with: nil)
    }
  }

  func contentSharingPickerStartDidFailWithError(_ error: Error) {
    Task { @MainActor in
      failPicking(with: error)
    }
  }
}
