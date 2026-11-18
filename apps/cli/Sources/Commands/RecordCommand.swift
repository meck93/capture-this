import ArgumentParser
import CaptureThisCore
import Foundation
import ScreenCaptureKit

struct RecordCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "record",
    abstract: "Record the screen"
  )

  @Option(name: .long, help: "Source type: display, window, application")
  var source: String = "display"

  @Option(name: .long, help: "Recording duration in seconds (0 = manual stop)")
  var duration: Int = 0

  @Option(name: .long, help: "Output format: mp4, mov")
  var format: String = "mp4"

  @Option(name: .long, help: "Quality: standard, high")
  var quality: String = "standard"

  @Option(name: .long, help: "Output directory")
  var outputDir: String?

  @Option(name: .long, help: "Display index (0-based)")
  var displayIndex: Int?

  @Flag(name: .long, help: "Enable microphone")
  var mic = false

  @Flag(name: .long, help: "Enable system audio")
  var systemAudio = false

  func run() async throws {
    let observer = CLIObserver()
    let engine = makeEngine(observer: observer)

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      observer.onFinish = { recording in
        print(recording.url.path)
        continuation.resume()
      }
      observer.onError = { error in
        FileHandle.standardError.write("error: \(error.localizedDescription)\n")
        continuation.resume()
      }

      engine.start()
      scheduleStop(engine: engine)
    }
  }

  private func makeEngine(observer: CLIObserver) -> RecordingEngine {
    let captureSource: CaptureSource = switch source {
    case "window": .window
    case "application": .application
    default: .display
    }

    let settings = RecordingSettings(
      countdownSeconds: 0,
      isCameraEnabled: false,
      isMicrophoneEnabled: mic,
      isSystemAudioEnabled: systemAudio,
      outputFormat: format == "mov" ? .mov : .mp4,
      recordingQuality: quality == "high" ? .high : .standard
    )

    let dir: URL = if let outputDir {
      URL(fileURLWithPath: outputDir, isDirectory: true)
    } else {
      FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies/CaptureThis", isDirectory: true)
    }

    let selector = IndexedContentSelector(displayIndex: displayIndex)
    let dirProvider = SimpleDirectoryProvider(directory: dir)

    let engine = RecordingEngine(
      contentSelector: selector,
      directoryProvider: dirProvider,
      observer: observer,
      settings: settings
    )
    engine.captureSource = captureSource
    return engine
  }

  private func scheduleStop(engine: RecordingEngine) {
    if duration > 0 {
      Task {
        try? await Task.sleep(nanoseconds: UInt64(duration) * 1_000_000_000)
        engine.stop()
      }
    } else {
      FileHandle.standardError.write("press Ctrl+C to stop recording\n")
      signal(SIGINT, SIG_IGN)
      let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
      sigintSource.setEventHandler { engine.stop() }
      sigintSource.resume()
    }
  }
}

private final class IndexedContentSelector: ContentSelector {
  let displayIndex: Int?

  init(displayIndex: Int?) {
    self.displayIndex = displayIndex
  }

  func selectContent(source: CaptureSource) async throws -> SCContentFilter? {
    let content = try await SCShareableContent.current
    switch source {
    case .display:
      let displays = content.displays
      let idx = displayIndex ?? 0
      guard idx < displays.count else { return nil }
      return SCContentFilter(display: displays[idx], excludingWindows: [])
    case .window:
      guard let window = content.windows.first(where: { $0.isOnScreen }) else { return nil }
      return SCContentFilter(desktopIndependentWindow: window)
    case .application:
      guard let app = content.applications.first(where: { !$0.bundleIdentifier.isEmpty }),
            let display = content.displays.first
      else { return nil }
      return SCContentFilter(display: display, including: [app], exceptingWindows: [])
    }
  }

  func cancel() async {}
}
