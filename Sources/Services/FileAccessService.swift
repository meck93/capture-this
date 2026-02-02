import AppKit
import CaptureThisCore
import Foundation

@MainActor
final class FileAccessService {
  private let bookmarkKey = "CaptureThis.SaveFolderBookmark"
  private var securityScopedURL: URL?
  private var isAccessing = false

  func ensureRecordingsDirectoryAccess() async throws -> URL {
    if let url = resolveBookmark() {
      return url
    }

    guard let moviesURL = moviesDirectoryURL() else {
      throw AppError.fileWriteFailed
    }

    let panel = NSOpenPanel()
    panel.message = "Select the Movies folder or the CaptureThis folder in Movies."
    panel.directoryURL = moviesURL
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = "Grant Access"

    let response = panel.runModal()
    guard response == .OK, let selectedURL = panel.url else {
      throw AppError.permissionDenied
    }

    let normalizedSelected = normalizeURL(selectedURL)
    guard let recordingsURL = recordingsDirectory(for: normalizedSelected) else {
      throw AppError.invalidSaveLocation
    }

    let bookmark = try normalizedSelected.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )

    UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    securityScopedURL = normalizedSelected

    guard normalizedSelected.startAccessingSecurityScopedResource() else {
      throw AppError.permissionDenied
    }
    isAccessing = true

    try ensureDirectoryExists(at: recordingsURL)

    return recordingsURL
  }

  func stopAccessingIfNeeded() {
    guard isAccessing, let url = securityScopedURL else { return }
    url.stopAccessingSecurityScopedResource()
    isAccessing = false
  }

  private func moviesDirectoryURL() -> URL? {
    FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
  }

  private func recordingsDirectory(for selectedURL: URL) -> URL? {
    guard let moviesURL = moviesDirectoryURL().map(normalizeURL) else { return nil }
    let normalizedSelected = normalizeURL(selectedURL)
    let targetURL = moviesURL.appendingPathComponent("CaptureThis", isDirectory: true)

    if normalizedSelected == moviesURL {
      return targetURL
    }

    if normalizedSelected == normalizeURL(targetURL) {
      return targetURL
    }

    return nil
  }

  private func resolveBookmark() -> URL? {
    guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
    var isStale = false
    do {
      let url = try URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )

      if isStale {
        return nil
      }

      guard let recordingsURL = recordingsDirectory(for: normalizeURL(url)) else {
        return nil
      }

      securityScopedURL = url
      if url.startAccessingSecurityScopedResource() {
        isAccessing = true
        try? ensureDirectoryExists(at: recordingsURL)
        return recordingsURL
      }
      return nil
    } catch {
      return nil
    }
  }

  private func ensureDirectoryExists(at url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  private func normalizeURL(_ url: URL) -> URL {
    url.standardizedFileURL.resolvingSymlinksInPath()
  }
}
