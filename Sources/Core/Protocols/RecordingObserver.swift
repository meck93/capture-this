import Foundation

public protocol RecordingObserver: AnyObject {
  @MainActor func engineDidChangeState(_ state: RecordingState)
  @MainActor func engineDidFinishRecording(_ recording: Recording)
  @MainActor func engineDidEncounterError(_ error: Error)
}
