import AppKit
import CaptureThisCore
import Foundation
import ScreenCaptureKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
  static let shared = AppState()

  @Published var recordingState: RecordingState = .idle {
    didSet {
      hotKeyService.setCancelHotKeyEnabled(recordingState.shouldEnableCancelHotKey)
    }
  }

  @Published var settings: RecordingSettings
  @Published var captureSource: CaptureSource = .display {
    didSet { engine.captureSource = captureSource }
  }

  @Published var recentRecordings: [Recording]
  @Published var errorMessage: String?
  @Published var presenterOverlayEnabled = false
  @Published var recordingStartDate: Date?
  @Published var permissionSetupState = PermissionSetupState()
  @Published var gifExportState: GIFExportState = .idle

  let engine: RecordingEngine
  let cameraService = CameraService()
  let hotKeyService = HotKeyService()
  let notificationService = NotificationService.shared
  let gifExportService = GIFExportService()

  private let contentSelector: GUIContentSelector
  private let directoryProvider: SandboxedDirectoryProvider
  let fileAccessService: FileAccessService

  lazy var hudController = HUDWindowController(appState: self)

  private init() {
    let loadedSettings = SettingsStore.load()
    settings = loadedSettings

    let selector = GUIContentSelector()
    let fileAccess = FileAccessService()
    let dirProvider = SandboxedDirectoryProvider(fileAccessService: fileAccess)
    contentSelector = selector
    directoryProvider = dirProvider
    fileAccessService = fileAccess

    // Engine init needs observer; use temporary, reassign after init
    engine = RecordingEngine(
      contentSelector: selector,
      directoryProvider: dirProvider,
      observer: RecordingObserverStub(),
      settings: loadedSettings
    )

    recentRecordings = RecordingStore.load()
    // Now set self as the real observer
    engine.setObserver(self)
    configureHotKeys()
  }

  func startOrStopRecording() {
    if recordingState == .idle, permissionSetupState.blocksRecording {
      openSetupForMissingPermissions()
      return
    }
    engine.startOrStop()
  }

  func startRecording() {
    if permissionSetupState.blocksRecording {
      openSetupForMissingPermissions()
      return
    }
    engine.start()
  }

  func stopRecording() {
    engine.stop()
  }

  func cancelRecording() {
    if case .pickingSource = recordingState {
      hudController.hide()
    } else if case .countdown = recordingState {
      hudController.hide()
    }
    engine.cancel()
  }

  func updateSettings(_ newSettings: RecordingSettings) {
    let previous = settings
    settings = newSettings
    engine.updateSettings(newSettings)
    refreshPermissionSetupState()

    if previous.isCameraEnabled != newSettings.isCameraEnabled {
      if !newSettings.isCameraEnabled {
        cameraService.stopPreview()
      }
    }
  }

  func recordingDurationText(for date: Date) -> String {
    engine.recordingDuration(since: date)
  }

  func openRecording(_ recording: Recording) {
    openRecordingURL(recording.url)
  }

  func revealRecording(_ recording: Recording) {
    revealRecordingURL(recording.url)
  }

  func openRecordingURL(_ url: URL) {
    accessRecordingURL {
      NSWorkspace.shared.open(url)
    }
  }

  func revealRecordingURL(_ url: URL) {
    accessRecordingURL {
      NSWorkspace.shared.activateFileViewerSelecting([url])
    }
  }

  private func accessRecordingURL(action: @escaping () -> Void) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        _ = try await fileAccessService.ensureRecordingsDirectoryAccess()
        action()
        Task { @MainActor [weak self] in
          try? await Task.sleep(nanoseconds: 2_000_000_000)
          self?.fileAccessService.stopAccessingIfNeeded()
        }
      } catch {
        errorMessage = error.localizedDescription
        openSetupForMissingPermissions()
      }
    }
  }
}

enum GIFExportState: Equatable {
  case idle
  case exporting(UUID)

  func isExporting(_ recording: Recording) -> Bool {
    if case let .exporting(id) = self {
      return id == recording.id
    }
    return false
  }
}
