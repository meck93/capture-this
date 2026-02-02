import Foundation

public struct Recording: Identifiable, Codable, Sendable {
  public let id: UUID
  public let url: URL
  public let createdAt: Date
  public let duration: TimeInterval?
  public let captureType: CaptureType

  public enum CaptureType: String, Codable, Sendable {
    case display
    case window
    case application
  }

  public init(id: UUID, url: URL, createdAt: Date, duration: TimeInterval?, captureType: CaptureType) {
    self.id = id
    self.url = url
    self.createdAt = createdAt
    self.duration = duration
    self.captureType = captureType
  }
}
