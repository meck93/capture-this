import Foundation

public protocol OutputDirectoryProvider: AnyObject, Sendable {
  func recordingsDirectory() async throws -> URL
  func stopAccessing()
}
