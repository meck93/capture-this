import AppKit
import CaptureThisCore
import Foundation

extension AppState {
  func exportGIF(for recording: Recording) {
    Task { @MainActor in
      await exportGIF(recording, confirmLargeExport: true)
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
      await exportGIF(recording, confirmLargeExport: true)
    }
  }

  private func exportGIF(_ recording: Recording, confirmLargeExport: Bool) async {
    gifExportState = .exporting(recording.id)
    errorMessage = nil

    do {
      let estimate = try await gifExportService.estimate(for: recording)
      if confirmLargeExport, estimate.exceedsWarningThreshold, !confirmLargeGIFExport(estimate: estimate) {
        gifExportState = .idle
        return
      }

      let outputURL = try await gifExportService.export(recording: recording)
      gifExportState = .idle
      notificationService.sendGIFExportCompleteNotification(url: outputURL)
      revealRecordingURL(outputURL)
    } catch {
      gifExportState = .idle
      errorMessage = error.localizedDescription
    }
  }

  private func confirmLargeGIFExport(estimate: GIFExportEstimate) -> Bool {
    let alert = NSAlert()
    alert.messageText = String(localized: "Large GIF export")
    alert.informativeText = """
    This GIF is estimated to be \(ByteCountFormatter.string(
      fromByteCount: estimate.estimatedFileSize,
      countStyle: .file
    )). GIFs can be much larger than videos.
    """
    alert.addButton(withTitle: String(localized: "Export GIF"))
    alert.addButton(withTitle: String(localized: "Cancel"))
    alert.alertStyle = .warning
    return alert.runModal() == .alertFirstButtonReturn
  }
}
