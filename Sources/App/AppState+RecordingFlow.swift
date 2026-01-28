import AppKit
import Foundation
import ReplayKit
import ScreenCaptureKit

extension AppState {
  func prepareRecordingFlow() async {
    do {
      try await ensurePermissionsIfNeeded()
      await beginPicking()
    } catch {
      handleError(error)
    }
  }

  func beginPicking() async {
    recordingState = .pickingSource
    hudController.show()

    do {
      let filter = try await pickerService.pickContent(allowedSource: captureSource)
      guard let filter else {
        pendingFilter = nil
        recordingState = .idle
        hudController.hide()
        return
      }

      pendingFilter = filter
      startCountdownIfNeeded(with: filter)
    } catch {
      handleError(error)
    }
  }

  func startCountdownIfNeeded(with filter: SCContentFilter) {
    countdownTask?.cancel()

    let total = max(settings.countdownSeconds, 0)
    if total == 0 {
      Task { [weak self] in
        await self?.beginRecording(with: filter)
      }
      return
    }

    countdownTask = Task { [weak self] in
      await self?.runCountdown(total: total, filter: filter)
    }
  }

  func runCountdown(total: Int, filter: SCContentFilter) async {
    hudController.show()

    for remaining in stride(from: total, through: 1, by: -1) {
      if Task.isCancelled { return }
      recordingState = .countdown(remaining)
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    if Task.isCancelled { return }
    await beginRecording(with: filter)
  }

  func beginRecording(with filter: SCContentFilter) async {
    do {
      try await ensurePermissionsIfNeeded()
      if settings.isCameraEnabled {
        try cameraService.startPreview()
      }

      let directory = try await fileAccessService.ensureRecordingsDirectoryAccess()
      let outputURL = makeOutputURL(in: directory)
      currentOutputURL = outputURL

      let config = makeStreamConfiguration()

      try await captureService.startRecording(
        filter: filter,
        configuration: config,
        outputURL: outputURL,
        presenterOverlayHandler: { [weak self] enabled in
          Task { @MainActor in
            self?.presenterOverlayEnabled = enabled
          }
        },
        errorHandler: { [weak self] error in
          Task { @MainActor in
            self?.handleError(error)
          }
        }
      )

      recordingStartDate = Date()
      recordingState = .recording(isPaused: false)
      hudController.show()
    } catch {
      handleError(error)
    }
  }

  func ensurePermissionsIfNeeded() async throws {
    if !permissionService.ensureScreenRecordingAccess() {
      throw AppError.screenRecordingDenied
    }

    if settings.isCameraEnabled {
      let granted = await permissionService.requestCameraAccess()
      if !granted {
        throw AppError.permissionDenied
      }
    }

    if settings.isMicrophoneEnabled {
      let granted = await permissionService.requestMicrophoneAccess()
      if !granted {
        throw AppError.permissionDenied
      }
    }
  }

  func makeStreamConfiguration() -> SCStreamConfiguration {
    let config = SCStreamConfiguration()
    config.showsCursor = true
    config.queueDepth = 5
    config.excludesCurrentProcessAudio = true

    if settings.isSystemAudioEnabled {
      config.capturesAudio = true
      config.sampleRate = 48000
      config.channelCount = 2
    } else {
      config.capturesAudio = false
    }

    if settings.isMicrophoneEnabled {
      config.captureMicrophone = true
      config.microphoneCaptureDeviceID = AudioDeviceHelper.defaultMicrophoneID
    } else {
      config.captureMicrophone = false
    }

    return config
  }

  func makeOutputURL(in directory: URL) -> URL {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let safeTimestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let filename = "CaptureThis_\(safeTimestamp).mp4"
    return directory.appendingPathComponent(filename)
  }

  func stopRecording(discard: Bool) async {
    guard recordingState.isRecording || recordingState == .stopping else { return }
    recordingState = .stopping

    do {
      let outputURL = try await captureService.stopRecording()
      cameraService.stopPreview()
      fileAccessService.stopAccessingIfNeeded()

      if discard {
        try? FileManager.default.removeItem(at: outputURL)
        recordingState = .idle
        hudController.hide()
        return
      }

      let createdAt = recordingStartDate ?? Date()
      let duration = Date().timeIntervalSince(createdAt)
      let captureType: Recording.CaptureType = switch captureSource {
      case .display:
        .display
      case .window:
        .window
      case .application:
        .application
      }

      let recording = Recording(
        id: UUID(),
        url: outputURL,
        createdAt: createdAt,
        duration: duration,
        captureType: captureType
      )

      recentRecordings = RecordingStore.add(recording, to: recentRecordings)
      RecordingStore.save(recentRecordings)
      notificationService.sendRecordingCompleteNotification(for: recording)

      recordingState = .idle
      hudController.hide()
    } catch {
      handleError(error)
    }
  }

  func handleError(_ error: Error) {
    if recoverRecordingIfPossible(from: error) {
      return
    }

    let message: String = if let appError = error as? AppError {
      appError.localizedDescription
    } else {
      error.localizedDescription
    }

    errorMessage = message
    recordingState = .error(message)
    hudController.hide()
    cameraService.stopPreview()
    fileAccessService.stopAccessingIfNeeded()
  }

  private func recoverRecordingIfPossible(from error: Error) -> Bool {
    let nsError = error as NSError
    let replayKitDomain = RPRecordingErrorDomain
    let isConnectionError = nsError.domain == replayKitDomain
      && (nsError.code == -5814 || nsError.code == -5815)

    guard isConnectionError, let outputURL = currentOutputURL else {
      return false
    }

    let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
    guard let fileSize = attributes?[.size] as? NSNumber, fileSize.intValue > 0 else {
      return false
    }

    let createdAt = recordingStartDate ?? Date()
    let duration = Date().timeIntervalSince(createdAt)
    let captureType: Recording.CaptureType = switch captureSource {
    case .display:
      .display
    case .window:
      .window
    case .application:
      .application
    }

    let recording = Recording(
      id: UUID(),
      url: outputURL,
      createdAt: createdAt,
      duration: duration,
      captureType: captureType
    )

    recentRecordings = RecordingStore.add(recording, to: recentRecordings)
    RecordingStore.save(recentRecordings)
    notificationService.sendRecordingCompleteNotification(for: recording)

    errorMessage = nil
    recordingState = .idle
    hudController.hide()
    cameraService.stopPreview()
    fileAccessService.stopAccessingIfNeeded()

    return true
  }

  func configureHotKeys() {
    let handlers = HotKeyHandlers(
      startStop: { [weak self] in
        Task { @MainActor in
          self?.startOrStopRecording()
        }
      },
      pauseResume: { [weak self] in
        Task { @MainActor in
          self?.togglePauseResume()
        }
      },
      cancel: { [weak self] in
        Task { @MainActor in
          self?.cancelRecording()
        }
      },
      toggleHUD: { [weak self] in
        Task { @MainActor in
          self?.toggleHUD()
        }
      },
      openApp: { [weak self] in
        Task { @MainActor in
          self?.openMenuBarPopover()
        }
      }
    )

    hotKeyService.configure(handlers: handlers) { [weak self] error in
      Task { @MainActor in
        self?.handleError(error)
      }
    }
  }

  func togglePauseResume() {
    if case .recording = recordingState {
      errorMessage = "Pause/resume is not available yet."
    }
  }

  func toggleHUD() {
    if hudController.isVisible {
      hudController.hide()
    } else if recordingState != .idle {
      hudController.show()
    }
  }

  func openMenuBarPopover() {
    NSApp.activate(ignoringOtherApps: true)
    AppDelegate.shared?.showPopover()
  }
}
