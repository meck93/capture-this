import AppKit
import CaptureThisCore
import Foundation
import os

@MainActor
final class FileAccessService {
  private let bookmarkKey = "CaptureThis.SaveFolderBookmark"
  private let logger = Logger(subsystem: "com.capturethis.CaptureThis", category: "FileAccess")
  private var securityScopedURL: URL?
  private var accessCount = 0

  func recordingsDirectoryAccessStatus() -> PermissionStatus {
    resolveBookmark(startAccessing: false) == nil ? .notDetermined : .granted
  }

  func ensureRecordingsDirectoryAccess() async throws -> URL {
    if let url = resolveBookmark(startAccessing: true) {
      logger.debug("Using saved folder bookmark for recordings directory: \(url.path, privacy: .private)")
      return url
    }

    guard let moviesURL = moviesDirectoryURL() else {
      logger.error("Unable to resolve Movies directory")
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
      logger.notice("User cancelled folder access prompt")
      throw AppError.permissionDenied
    }

    let normalizedSelected = normalizeURL(selectedURL)
    guard let recordingsURL = recordingsDirectory(for: normalizedSelected) else {
      logger.error("Rejected selected save location: \(normalizedSelected.path, privacy: .private)")
      throw AppError.invalidSaveLocation
    }

    let bookmark = try createBookmark(for: normalizedSelected)

    UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    securityScopedURL = normalizedSelected

    guard normalizedSelected.startAccessingSecurityScopedResource() else {
      logger.error(
        "Failed to start security-scoped access for selected URL: \(normalizedSelected.path, privacy: .private)"
      )
      throw AppError.permissionDenied
    }
    accessCount += 1

    try ensureDirectoryExists(at: recordingsURL)
    logger.notice(
      """
      Saved folder bookmark. selected=\(normalizedSelected.path, privacy: .private), \
      recordings=\(recordingsURL.path, privacy: .private), bytes=\(bookmark.count)
      """
    )

    return recordingsURL
  }

  func stopAccessingIfNeeded() {
    guard accessCount > 0, let url = securityScopedURL else { return }
    url.stopAccessingSecurityScopedResource()
    accessCount -= 1
    let remainingAccessCount = accessCount
    logger.debug(
      "Stopped security-scoped access for URL: \(url.path, privacy: .private), remaining=\(remainingAccessCount)"
    )
  }

  private func moviesDirectoryURL() -> URL? {
    FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
  }

  private func createBookmark(for url: URL) throws -> Data {
    do {
      return try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
    } catch {
      logger.error(
        "Failed to create folder bookmark: \(url.path, privacy: .private), error=\(error.localizedDescription)"
      )
      throw error
    }
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

  private func resolveBookmark(startAccessing: Bool) -> URL? {
    guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
      logger.debug("No saved folder bookmark found")
      return nil
    }

    logger.debug("Resolving saved folder bookmark. bytes=\(data.count)")
    var isStale = false
    do {
      let url = try URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )

      if isStale {
        logger.notice("Saved folder bookmark is stale for URL: \(url.path, privacy: .private)")
        return nil
      }

      guard let recordingsURL = recordingsDirectory(for: normalizeURL(url)) else {
        logger.error(
          "Saved folder bookmark resolved outside allowed save locations: \(url.path, privacy: .private)"
        )
        return nil
      }

      securityScopedURL = url
      guard startAccessing else {
        return recordingsURL
      }

      if url.startAccessingSecurityScopedResource() {
        accessCount += 1
        do {
          try ensureDirectoryExists(at: recordingsURL)
        } catch {
          logger.error(
            """
            Failed to create recordings directory from saved bookmark: \
            \(recordingsURL.path, privacy: .private): \(error.localizedDescription)
            """
          )
          return nil
        }
        return recordingsURL
      }
      logger.error(
        "Saved folder bookmark resolved, but security-scoped access failed for URL: \(url.path, privacy: .private)"
      )
      return nil
    } catch {
      logger.error("Failed to resolve saved folder bookmark: \(error.localizedDescription)")
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
