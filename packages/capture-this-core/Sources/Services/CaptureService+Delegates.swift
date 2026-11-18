import Foundation
import ScreenCaptureKit

extension CaptureService: SCStreamDelegate {
  public func stream(_: SCStream, didStopWithError error: Error) {
    handleStreamDidStop(with: error)
  }

  public func stream(_: SCStream, outputEffectDidStart didStart: Bool) {
    handleOutputEffectDidStart(didStart)
  }
}

extension CaptureService: SCRecordingOutputDelegate {
  public func recordingOutputDidFinishRecording(_: SCRecordingOutput) {
    handleRecordingOutputDidFinish()
  }

  public func recordingOutput(_: SCRecordingOutput, didFailWithError error: Error) {
    recordingOutputDidFail(error)
  }
}
