import AVFoundation
import Foundation
import ScreenCaptureKit

public final class RecordingEngine {
  public private(set) var state: RecordingState = .idle
  public var settings: RecordingSettings
  public var captureSource: CaptureSource = .display

  public let captureService: any CaptureServicing
  public let permissionService: any PermissionServicing

  let contentSelector: ContentSelector
  let directoryProvider: OutputDirectoryProvider
  weak var observer: RecordingObserver?

  var countdownTask: Task<Void, Never>?
  var currentOutputURL: URL?
  var recordingStartDate: Date?
  var pendingFilter: SCContentFilter?
  var pausedDuration: TimeInterval = 0
  var lastPauseDate: Date?
  var isPauseResumeTransitioning = false
  let nowProvider: () -> Date

  public init(
    contentSelector: ContentSelector,
    directoryProvider: OutputDirectoryProvider,
    observer: RecordingObserver,
    settings: RecordingSettings = SettingsStore.load(),
    captureService: any CaptureServicing = CaptureService(),
    permissionService: any PermissionServicing = PermissionService(),
    nowProvider: @escaping () -> Date = Date.init
  ) {
    self.contentSelector = contentSelector
    self.directoryProvider = directoryProvider
    self.observer = observer
    self.settings = settings
    self.captureService = captureService
    self.permissionService = permissionService
    self.nowProvider = nowProvider
  }

  public func setObserver(_ observer: RecordingObserver) {
    self.observer = observer
  }

  // MARK: - Public API

  public func startOrStop() {
    switch state {
    case .idle, .error:
      start()
    case .recording:
      stop()
    case .countdown, .pickingSource, .stopping:
      break
    }
  }

  public func start() {
    switch state {
    case .idle, .error:
      break
    default:
      return
    }

    setState(.idle)

    Task { [weak self] in
      await self?.prepareRecordingFlow()
    }
  }

  public func stop() {
    Task { [weak self] in
      await self?.stopRecording(discard: false)
    }
  }

  public func pauseResume() {
    guard case let .recording(isPaused) = state else { return }
    guard !isPauseResumeTransitioning else { return }

    isPauseResumeTransitioning = true
    Task { [weak self] in
      if isPaused {
        await self?.resume()
      } else {
        await self?.pause()
      }
    }
  }

  public func cancel() {
    switch state {
    case .countdown:
      countdownTask?.cancel()
      countdownTask = nil
      pendingFilter = nil
      setState(.idle)
    case .pickingSource:
      pendingFilter = nil
      Task { [weak self] in
        await self?.contentSelector.cancel()
      }
      setState(.idle)
    case .recording:
      Task { [weak self] in
        await self?.stopRecording(discard: true)
      }
    case .idle, .stopping, .error:
      break
    }
  }

  public func updateSettings(_ newSettings: RecordingSettings) {
    settings = newSettings
    SettingsStore.save(newSettings)
  }

  public func recordingDuration(since date: Date) -> String {
    effectiveDuration(since: date).formattedClock
  }

  public var currentRecordingStartDate: Date? {
    recordingStartDate
  }

  // MARK: - Configuration

  public func makeStreamConfiguration() -> SCStreamConfiguration {
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

  public func makeOutputURL(in directory: URL) -> URL {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let safeTimestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let filename = "CaptureThis_\(safeTimestamp).\(preferredOutputExtension())"
    return directory.appendingPathComponent(filename)
  }

  func setState(_ newState: RecordingState) {
    state = newState
    Task { @MainActor [weak self, newState] in
      self?.observer?.engineDidChangeState(newState)
    }
  }

  func preferredOutputFileType() -> AVFileType {
    switch settings.outputFormat {
    case .mov: .mov
    case .mp4: .mp4
    }
  }

  func preferredVideoCodecType() -> AVVideoCodecType {
    switch settings.recordingQuality {
    case .high: .hevc
    case .standard: .h264
    }
  }

  func preferredOutputExtension() -> String {
    switch settings.outputFormat {
    case .mov: "mov"
    case .mp4: "mp4"
    }
  }

  func makeRecording(outputURL: URL) -> Recording {
    let createdAt = recordingStartDate ?? nowProvider()
    let duration = effectiveDuration(since: createdAt)
    let captureType: Recording.CaptureType = switch captureSource {
    case .display: .display
    case .window: .window
    case .application: .application
    }
    return Recording(id: UUID(), url: outputURL, createdAt: createdAt, duration: duration, captureType: captureType)
  }

  func effectiveDuration(since date: Date) -> TimeInterval {
    let now = nowProvider()
    var duration = now.timeIntervalSince(date) - pausedDuration

    if case .recording(true) = state, let lastPauseDate {
      duration -= now.timeIntervalSince(lastPauseDate)
    }

    return max(duration, 0)
  }
}
