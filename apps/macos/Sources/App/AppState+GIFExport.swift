import AppKit
import CaptureThisCore
import Foundation

extension AppState {
  func exportGIF(for recording: Recording) {
    Task { @MainActor in
      await exportGIF(recording)
    }
  }

  func exportGIFFromNotification(fileURL: URL) {
    let recording = recentRecordings.first { $0.url == fileURL } ?? Recording(
      id: UUID(),
      url: fileURL,
      createdAt: Date(),
      duration: nil,
      captureType: .display
    )

    Task { @MainActor in
      await exportGIF(recording)
    }
  }

  private func exportGIF(_ recording: Recording) async {
    gifExportState = .exporting(recording.id)
    errorMessage = nil

    do {
      let outputURL = try await withRecordingsDirectoryAccess {
        let gifExportService = GIFExportService(policy: GIFExportPolicy(quality: settings.gifExportQuality))
        return try await gifExportService.export(recording: recording)
      }
      gifExportState = .idle
      notificationService.sendGIFExportCompleteNotification(url: outputURL)
      revealRecordingURL(outputURL)
    } catch {
      gifExportState = .idle
      errorMessage = error.localizedDescription
    }
  }
}
