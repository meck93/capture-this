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

  let engine: RecordingEngine
  let cameraService = CameraService()
  let hotKeyService = HotKeyService()
  let notificationService = NotificationService.shared

  private let contentSelector: GUIContentSelector
  private let directoryProvider: SandboxedDirectoryProvider

  lazy var hudController = HUDWindowController(appState: self)

  private init() {
    let loadedSettings = SettingsStore.load()
    settings = loadedSettings

    let selector = GUIContentSelector()
    let dirProvider = SandboxedDirectoryProvider()
    contentSelector = selector
    directoryProvider = dirProvider

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
    engine.startOrStop()
  }

  func startRecording() {
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

    if previous.isCameraEnabled != newSettings.isCameraEnabled {
      if newSettings.isCameraEnabled {
        Task { @MainActor in
          let granted = await engine.permissionService.requestCameraAccess()
          if !granted {
            errorMessage = AppError.permissionDenied.localizedDescription
          }
        }
      } else {
        cameraService.stopPreview()
      }
    }
  }

  func recordingDurationText(for date: Date) -> String {
    Date().timeIntervalSince(date).formattedClock
  }
}
