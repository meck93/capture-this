import Foundation

public final class SimpleDirectoryProvider: OutputDirectoryProvider, @unchecked Sendable {
  private let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  public func recordingsDirectory() async throws -> URL {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  public func stopAccessing() {}
}
