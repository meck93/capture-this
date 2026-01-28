import ScreenCaptureKit

final class PickerService: NSObject {
  private var continuation: CheckedContinuation<SCContentFilter?, Error>?
  private let picker = SCContentSharingPicker.shared

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
      picker.isActive = true
      picker.present()
    }
  }

  @MainActor
  func cancel() {
    picker.isActive = false
    continuation?.resume(returning: nil)
    continuation = nil
    picker.remove(self)
  }

  @MainActor
  func finishPicking(with filter: SCContentFilter?) {
    continuation?.resume(returning: filter)
    continuation = nil
    picker.remove(self)
  }

  @MainActor
  func failPicking(with error: Error) {
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
