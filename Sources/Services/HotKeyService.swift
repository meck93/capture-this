import Foundation
import HotKey

struct HotKeyHandlers {
  let startStop: () -> Void
  let pauseResume: () -> Void
  let cancel: () -> Void
  let toggleHUD: () -> Void
  let openApp: () -> Void
}

final class HotKeyService {
  private var startStopHotKey: HotKey?
  private var pauseResumeHotKey: HotKey?
  private var cancelHotKey: HotKey?
  private var toggleHUDHotKey: HotKey?
  private var openAppHotKey: HotKey?
  private var cancelHandler: (() -> Void)?
  private var onError: ((Error) -> Void)?

  func configure(handlers: HotKeyHandlers, onError: @escaping (Error) -> Void) {
    cancelHandler = handlers.cancel
    self.onError = onError

    do {
      startStopHotKey = try HotKey(keyCombo: KeyCombo(key: .r, modifiers: [.command, .shift]))
      pauseResumeHotKey = try HotKey(keyCombo: KeyCombo(key: .p, modifiers: [.command, .shift]))
      toggleHUDHotKey = try HotKey(keyCombo: KeyCombo(key: .h, modifiers: [.command, .shift]))
      openAppHotKey = try HotKey(keyCombo: KeyCombo(key: .c, modifiers: [.command, .shift]))

      startStopHotKey?.keyDownHandler = handlers.startStop
      pauseResumeHotKey?.keyDownHandler = handlers.pauseResume
      toggleHUDHotKey?.keyDownHandler = handlers.toggleHUD
      openAppHotKey?.keyDownHandler = handlers.openApp
    } catch {
      onError(error)
    }
  }

  func setCancelHotKeyEnabled(_ enabled: Bool) {
    if enabled {
      guard cancelHotKey == nil, let cancelHandler else { return }
      do {
        cancelHotKey = try HotKey(keyCombo: KeyCombo(key: .escape, modifiers: []))
        cancelHotKey?.keyDownHandler = cancelHandler
      } catch {
        onError?(error)
      }
    } else {
      cancelHotKey = nil
    }
  }
}
