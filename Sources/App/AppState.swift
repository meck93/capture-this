import AppKit
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
  @Published var captureSource: CaptureSource = .display
  @Published var recentRecordings: [Recording]
  @Published var errorMessage: String?
  @Published var presenterOverlayEnabled = false
  @Published var recordingStartDate: Date?

  let captureService = CaptureService()
  let pickerService = PickerService()
  let permissionService = PermissionService()
  let cameraService = CameraService()
  let fileAccessService = FileAccessService()
  let notificationService = NotificationService.shared
  let hotKeyService = HotKeyService()

  lazy var hudController = HUDWindowController(appState: self)

  var countdownTask: Task<Void, Never>?
  var currentOutputURL: URL?
  var pendingFilter: SCContentFilter?

  private init() {
    settings = SettingsStore.load()
    recentRecordings = RecordingStore.load()
    configureHotKeys()
  }

  func startOrStopRecording() {
    switch recordingState {
    case .idle, .error:
      startRecording()
    case .recording:
      stopRecording()
    case .countdown, .pickingSource, .stopping:
      break
    }
  }

  func startRecording() {
    switch recordingState {
    case .idle, .error:
      break
    default:
      return
    }

    errorMessage = nil
    recordingState = .idle

    Task { [weak self] in
      await self?.prepareRecordingFlow()
    }
  }

  func stopRecording() {
    Task { [weak self] in
      await self?.stopRecording(discard: false)
    }
  }

  func cancelRecording() {
    switch recordingState {
    case .countdown:
      countdownTask?.cancel()
      countdownTask = nil
      pendingFilter = nil
      recordingState = .idle
      hudController.hide()
    case .pickingSource:
      pendingFilter = nil
      pickerService.cancel()
      recordingState = .idle
      hudController.hide()
    case .recording:
      Task { [weak self] in
        await self?.stopRecording(discard: true)
      }
    case .idle, .stopping, .error:
      break
    }
  }

  func updateSettings(_ newSettings: RecordingSettings) {
    settings = newSettings
    SettingsStore.save(newSettings)
  }

  func recordingDurationText(for date: Date) -> String {
    let duration = Date().timeIntervalSince(date)
    return duration.formattedClock
  }
}
