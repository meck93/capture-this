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

    startStopHotKey = HotKey(keyCombo: KeyCombo(key: .r, modifiers: [.command, .shift]))
    pauseResumeHotKey = HotKey(keyCombo: KeyCombo(key: .p, modifiers: [.command, .shift]))
    toggleHUDHotKey = HotKey(keyCombo: KeyCombo(key: .h, modifiers: [.command, .shift]))
    openAppHotKey = HotKey(keyCombo: KeyCombo(key: .c, modifiers: [.command, .shift]))

    startStopHotKey?.keyDownHandler = handlers.startStop
    pauseResumeHotKey?.keyDownHandler = handlers.pauseResume
    toggleHUDHotKey?.keyDownHandler = handlers.toggleHUD
    openAppHotKey?.keyDownHandler = handlers.openApp
  }

  func setCancelHotKeyEnabled(_ enabled: Bool) {
    if enabled {
      guard cancelHotKey == nil, let cancelHandler else { return }
      cancelHotKey = HotKey(keyCombo: KeyCombo(key: .escape, modifiers: []))
      cancelHotKey?.keyDownHandler = cancelHandler
    } else {
      cancelHotKey = nil
    }
  }
}
