import Foundation
import ScreenCaptureKit

extension RecordingEngine {
  func pause() async {
    guard case .recording(false) = state else {
      isPauseResumeTransitioning = false
      return
    }

    defer { isPauseResumeTransitioning = false }

    do {
      try await captureService.pauseRecording()
      lastPauseDate = nowProvider()
      setState(.recording(isPaused: true))
    } catch {
      await reportError(error)
    }
  }

  func resume() async {
    guard case .recording(true) = state else {
      isPauseResumeTransitioning = false
      return
    }

    defer { isPauseResumeTransitioning = false }

    do {
      try captureService.resumeRecording()
      if let lastPauseDate {
        pausedDuration += nowProvider().timeIntervalSince(lastPauseDate)
      }
      lastPauseDate = nil
      setState(.recording(isPaused: false))
    } catch {
      await reportError(error)
    }
  }

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

      let resolvedFilter = await augmentedFilterIfNeeded(from: filter)
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
        filter: resolvedFilter,
        configuration: config,
        outputURL: outputURL,
        options: options,
        handlers: handlers
      )

      recordingStartDate = nowProvider()
      pausedDuration = 0
      lastPauseDate = nil
      isPauseResumeTransitioning = false
      setState(.recording(isPaused: false))
    } catch {
      await reportError(error)
    }
  }

  private func augmentedFilterIfNeeded(from filter: SCContentFilter) async -> SCContentFilter {
    guard captureSource == .application else { return filter }
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return filter }

    let currentApplications = filter.includedApplications
    if currentApplications.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
      return filter
    }

    do {
      let content = try await SCShareableContent.current
      guard let captureApp = content.applications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
        return filter
      }

      guard let display = filter.includedDisplays.first ?? content.displays.first else {
        return filter
      }

      var updatedApplications = currentApplications
      updatedApplications.append(captureApp)
      return SCContentFilter(display: display, including: updatedApplications, exceptingWindows: [])
    } catch {
      return filter
    }
  }

  func stopRecording(discard: Bool) async {
    guard state.isRecording || state == .stopping else { return }
    setState(.stopping)
    isPauseResumeTransitioning = false
    defer { directoryProvider.stopAccessing() }

    do {
      if discard {
        await captureService.discardRecording()
        setState(.idle)
        return
      }

      let outputURL = try await captureService.stopRecording()
      let recording = makeRecording(outputURL: outputURL)
      let updated = RecordingStore.add(recording, to: RecordingStore.load())
      RecordingStore.save(updated)

      await MainActor.run { [weak self, recording] in
        self?.observer?.engineDidFinishRecording(recording)
      }
      setState(.idle)
    } catch {
      if let recoveredURL = await captureService.recoverPartialRecording() {
        let recording = makeRecording(outputURL: recoveredURL)
        let updated = RecordingStore.add(recording, to: RecordingStore.load())
        RecordingStore.save(updated)

        await MainActor.run { [weak self, recording] in
          self?.observer?.engineDidFinishRecording(recording)
        }

        setState(.idle)
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
    isPauseResumeTransitioning = false
    lastPauseDate = nil
  }
}
