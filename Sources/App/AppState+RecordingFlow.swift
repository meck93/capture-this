import AppKit
import CaptureThisCore
import Foundation

// MARK: - RecordingObserver

extension AppState: RecordingObserver {
  func engineDidChangeState(_ state: RecordingState) {
    recordingState = state

    switch state {
    case .pickingSource:
      hudController.show()
    case .countdown:
      hudController.show()
      if settings.isCameraEnabled {
        try? cameraService.startPreview()
      }
    case .recording:
      hudController.show()
      recordingStartDate = engine.currentRecordingStartDate
    case .idle:
      recordingStartDate = nil
      cameraService.stopPreview()
    case .stopping:
      break
    case .error:
      hudController.hide()
      cameraService.stopPreview()
      if case let .error(message) = state {
        errorMessage = message
      }
    }
  }

  func engineDidFinishRecording(_ recording: Recording) {
    recentRecordings = RecordingStore.add(recording, to: recentRecordings)
    RecordingStore.save(recentRecordings)
    notificationService.sendRecordingCompleteNotification(for: recording)
    hudController.hide()
    cameraService.stopPreview()
  }

  func engineDidEncounterError(_ error: Error) {
    let message: String = if let appError = error as? AppError {
      appError.localizedDescription
    } else {
      error.localizedDescription
    }
    errorMessage = message
    hudController.hide()
    cameraService.stopPreview()
  }
}

// MARK: - HotKeys

extension AppState {
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
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func togglePauseResume() {
    guard case .recording = recordingState else { return }
    engine.pauseResume()
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

// MARK: - Stub for init bootstrapping

final class RecordingObserverStub: RecordingObserver {
  func engineDidChangeState(_: RecordingState) {}
  func engineDidFinishRecording(_: Recording) {}
  func engineDidEncounterError(_: Error) {}
}
