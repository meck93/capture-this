import ArgumentParser
import CaptureThisCore
import Foundation

struct PermissionsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "permissions",
    abstract: "Check and request permissions"
  )

  func run() async throws {
    let service = PermissionService()

    let screen = service.ensureScreenRecordingAccess()
    print("screen recording: \(screen ? "granted" : "denied")")

    let camera = await service.requestCameraAccess()
    print("camera: \(camera ? "granted" : "denied")")

    let mic = await service.requestMicrophoneAccess()
    print("microphone: \(mic ? "granted" : "denied")")
  }
}
