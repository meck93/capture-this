import Foundation
import ScreenCaptureKit

extension RecordingEngine {
  func prepareRecordingFlow() async {
    do {
      try await ensurePermissions()
      await beginPicking()
    } catch {
      await reportError(error)
    }
  }

  func beginPicking() async {
    setState(.pickingSource)

    do {
      let filter = try await contentSelector.selectContent(source: captureSource)
      guard let filter else {
        pendingFilter = nil
        setState(.idle)
        return
      }

      pendingFilter = filter
      startCountdownIfNeeded(with: filter)
    } catch {
      await reportError(error)
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
    for remaining in stride(from: total, through: 1, by: -1) {
      if Task.isCancelled { return }
      setState(.countdown(remaining))
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    if Task.isCancelled { return }
    await beginRecording(with: filter)
  }

  func beginRecording(with filter: SCContentFilter) async {
    do {
      try await ensurePermissions()

      let directory = try await directoryProvider.recordingsDirectory()
      let outputURL = makeOutputURL(in: directory)
      currentOutputURL = outputURL

      let config = makeStreamConfiguration()
      let options = CaptureRecordingOptions(
        preferredFileType: preferredOutputFileType(),
        preferredVideoCodec: preferredVideoCodecType()
      )
      let handlers = CaptureRecordingHandlers(
        presenterOverlay: { _ in },
        error: { [weak self] error in
          Task { [weak self] in
            await self?.reportError(error)
          }
        }
      )

      try await captureService.startRecording(
        filter: filter,
        configuration: config,
        outputURL: outputURL,
        options: options,
        handlers: handlers
      )

      recordingStartDate = Date()
      setState(.recording(isPaused: false))
    } catch {
      await reportError(error)
    }
  }

  func stopRecording(discard: Bool) async {
    guard state.isRecording || state == .stopping else { return }
    setState(.stopping)

    do {
      let outputURL = try await captureService.stopRecording()
      directoryProvider.stopAccessing()

      if discard {
        try? FileManager.default.removeItem(at: outputURL)
        setState(.idle)
        return
      }

      let recording = makeRecording(outputURL: outputURL)
      let updated = RecordingStore.add(recording, to: RecordingStore.load())
      RecordingStore.save(updated)

      await MainActor.run { [weak self, recording] in
        self?.observer?.engineDidFinishRecording(recording)
      }
      setState(.idle)
    } catch {
      if recoverRecordingIfPossible(from: error) {
        return
      }
      await reportError(error)
    }
  }

  func ensurePermissions() async throws {
    if !permissionService.ensureScreenRecordingAccess() {
      throw AppError.screenRecordingDenied
    }

    if settings.isCameraEnabled {
      let granted = await permissionService.requestCameraAccess()
      if !granted { throw AppError.permissionDenied }
    }

    if settings.isMicrophoneEnabled {
      let granted = await permissionService.requestMicrophoneAccess()
      if !granted { throw AppError.permissionDenied }
    }
  }

  func reportError(_ error: Error) async {
    let message: String = if let appError = error as? AppError {
      appError.localizedDescription
    } else {
      error.localizedDescription
    }

    setState(.error(message))
    directoryProvider.stopAccessing()
  }

  func recoverRecordingIfPossible(from error: Error) -> Bool {
    let nsError = error as NSError
    let isConnectionError = nsError.domain == "com.apple.ReplayKit.RPRecordingErrorDomain"
      && (nsError.code == -5814 || nsError.code == -5815)

    guard isConnectionError, let outputURL = currentOutputURL else {
      return false
    }

    let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
    guard let fileSize = attributes?[.size] as? NSNumber, fileSize.intValue > 0 else {
      return false
    }

    let recording = makeRecording(outputURL: outputURL)
    let updated = RecordingStore.add(recording, to: RecordingStore.load())
    RecordingStore.save(updated)

    Task { @MainActor [weak self, recording] in
      self?.observer?.engineDidFinishRecording(recording)
    }

    setState(.idle)
    directoryProvider.stopAccessing()
    return true
  }
}
