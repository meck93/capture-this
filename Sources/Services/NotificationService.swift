import AppKit
import CaptureThisCore
import Foundation
import UserNotifications

final class NotificationService: NSObject {
  static let shared = NotificationService()

  private let center = UNUserNotificationCenter.current()

  override private init() {
    super.init()
    center.delegate = self
    registerCategories()
  }

  func requestAuthorization() async {
    _ = try? await center.requestAuthorization(options: [.alert, .sound])
  }

  func sendRecordingCompleteNotification(for recording: Recording) {
    Task {
      await requestAuthorization()

      let content = UNMutableNotificationContent()
      content.title = "Recording complete"
      content.body = recording.url.lastPathComponent
      content.categoryIdentifier = "recording.complete"
      content.userInfo = ["fileURL": recording.url.absoluteString]

      let request = UNNotificationRequest(
        identifier: recording.id.uuidString,
        content: content,
        trigger: nil
      )

      try? await center.add(request)
    }
  }

  private func registerCategories() {
    let openAction = UNNotificationAction(
      identifier: "recording.open",
      title: "Open",
      options: [.foreground]
    )

    let revealAction = UNNotificationAction(
      identifier: "recording.reveal",
      title: "Reveal in Finder",
      options: [.foreground]
    )

    let category = UNNotificationCategory(
      identifier: "recording.complete",
      actions: [openAction, revealAction],
      intentIdentifiers: [],
      options: []
    )

    center.setNotificationCategories([category])
  }
}

extension NotificationService: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    guard let urlString = response.notification.request.content.userInfo["fileURL"] as? String,
          let url = URL(string: urlString)
    else {
      return
    }

    switch response.actionIdentifier {
    case "recording.open":
      NSWorkspace.shared.open(url)
    case "recording.reveal":
      NSWorkspace.shared.activateFileViewerSelecting([url])
    default:
      break
    }
  }
}
