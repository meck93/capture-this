import CaptureThisCore
import ScreenCaptureKit

final class GUIContentSelector: ContentSelector {
  private let pickerService: PickerService

  @MainActor
  init() {
    pickerService = PickerService()
  }

  func selectContent(source: CaptureSource) async throws -> SCContentFilter? {
    try await pickerService.pickContent(allowedSource: source)
  }

  func cancel() async {
    await pickerService.cancel()
  }
}
