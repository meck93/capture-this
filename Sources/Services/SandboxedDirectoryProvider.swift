import CaptureThisCore
import Foundation

final class SandboxedDirectoryProvider: OutputDirectoryProvider, @unchecked Sendable {
  private let fileAccessService: FileAccessService

  @MainActor
  init() {
    fileAccessService = FileAccessService()
  }

  func recordingsDirectory() async throws -> URL {
    try await fileAccessService.ensureRecordingsDirectoryAccess()
  }

  func stopAccessing() {
    Task { @MainActor [fileAccessService] in
      fileAccessService.stopAccessingIfNeeded()
    }
  }
}
