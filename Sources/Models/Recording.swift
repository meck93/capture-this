import Foundation

struct Recording: Identifiable, Codable {
  let id: UUID
  let url: URL
  let createdAt: Date
  let duration: TimeInterval?
  let captureType: CaptureType

  enum CaptureType: String, Codable {
    case display
    case window
    case application
  }
}
