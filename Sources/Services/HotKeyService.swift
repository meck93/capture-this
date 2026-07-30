import CaptureThisCore
import Carbon
import Foundation

struct HotKeyHandlers {
  let startStop: () -> Void
  let pauseResume: () -> Void
  let cancel: () -> Void
  let openApp: () -> Void
}

final class HotKeyService {
  private struct RegisteredHotKey {
    let action: ShortcutAction
    let binding: ShortcutBinding
    let reference: EventHotKeyRef
  }

  private struct RegistrationError: LocalizedError {
    let action: ShortcutAction
    let status: OSStatus

    var errorDescription: String? {
      String(
        format: String(localized: "shortcut.registration.unavailable"),
        action.displayName,
        status
      )
    }
  }

  fileprivate weak static var activeService: HotKeyService?
  private static let eventHotKeySignature: UInt32 = {
    let string = "CTHK"
    var result: FourCharCode = 0
    for character in string.utf16 {
      result = (result << 8) + FourCharCode(character)
    }
    return result
  }()

  private static let eventSpec = [
    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
  ]

  private var handlers: [ShortcutAction: () -> Void] = [:]
  private var registeredHotKeys: [UInt32: RegisteredHotKey] = [:]
  private var nextHotKeyID: UInt32 = 0
  private var eventHandler: EventHandlerRef?
  private var shortcutSettings = KeyboardShortcutSettings()
  private var recordingState: RecordingState = .idle
  private var onError: ((Error) -> Void)?

  func configure(
    handlers: HotKeyHandlers,
    settings: KeyboardShortcutSettings,
    recordingState: RecordingState,
    onError: @escaping (Error) -> Void
  ) {
    self.handlers = [
      .startStop: handlers.startStop,
      .pauseResume: handlers.pauseResume,
      .cancel: handlers.cancel,
      .openApp: handlers.openApp
    ]
    self.onError = onError
    guard validate(settings) else { return }
    shortcutSettings = settings
    self.recordingState = recordingState
    _ = applyCurrentSettings()
  }

  @discardableResult
  func updateShortcutSettings(_ settings: KeyboardShortcutSettings) -> Bool {
    guard validate(settings) else { return false }
    let previous = shortcutSettings
    shortcutSettings = settings

    guard applyCurrentSettings() else {
      shortcutSettings = previous
      return false
    }
    return true
  }

  func setRecordingState(_ state: RecordingState) {
    recordingState = state
    _ = applyCurrentSettings()
  }

  deinit {
    unregisterAll()
    removeEventHandler()
    if Self.activeService === self {
      Self.activeService = nil
    }
  }

  private func applyCurrentSettings() -> Bool {
    let previousBindings = registeredHotKeys.values.reduce(into: [ShortcutAction: ShortcutBinding]()) {
      $0[$1.action] = $1.binding
    }

    unregisterAll()

    do {
      let desiredBindings = desiredBindings()
      registeredHotKeys = try register(desiredBindings)
      if !registeredHotKeys.isEmpty {
        try installEventHandler()
      } else {
        removeEventHandler()
      }
      return true
    } catch {
      unregisterAll()
      do {
        registeredHotKeys = try register(previousBindings)
        if !registeredHotKeys.isEmpty {
          try installEventHandler()
        }
      } catch {
        registeredHotKeys = [:]
        removeEventHandler()
      }
      onError?(error)
      return false
    }
  }

  private func validate(_ settings: KeyboardShortcutSettings) -> Bool {
    var seen: [ShortcutBinding: ShortcutAction] = [:]
    for action in ShortcutAction.allCases {
      guard let binding = settings.binding(for: action) else { continue }
      if binding.modifiers == 0, binding.keyCode != UInt32(kVK_Escape) {
        onError?(ModifierRequiredShortcutError(action: action))
        return false
      }
      if let duplicate = seen[binding] {
        onError?(DuplicateShortcutError(first: duplicate, second: action))
        return false
      }
      seen[binding] = action
    }
    return true
  }

  private func desiredBindings() -> [ShortcutAction: ShortcutBinding] {
    guard shortcutSettings.isEnabled else { return [:] }

    return ShortcutAction.allCases.reduce(into: [ShortcutAction: ShortcutBinding]()) { result, action in
      guard let binding = shortcutSettings.binding(for: action), shouldRegister(action) else { return }
      result[action] = binding
    }
  }

  private func shouldRegister(_ action: ShortcutAction) -> Bool {
    switch action {
    case .pauseResume:
      recordingState.isRecording
    case .cancel:
      recordingState.shouldEnableCancelHotKey
    case .startStop, .openApp:
      true
    }
  }

  private func register(_ bindings: [ShortcutAction: ShortcutBinding]) throws -> [UInt32: RegisteredHotKey] {
    var registered: [UInt32: RegisteredHotKey] = [:]

    for action in ShortcutAction.allCases {
      guard let binding = bindings[action] else { continue }

      nextHotKeyID += 1
      let hotKeyID = EventHotKeyID(signature: Self.eventHotKeySignature, id: nextHotKeyID)
      var reference: EventHotKeyRef?
      let status = RegisterEventHotKey(
        binding.keyCode,
        binding.modifiers,
        hotKeyID,
        GetEventDispatcherTarget(),
        0,
        &reference
      )

      guard status == noErr, let reference else {
        for hotKey in registered.values {
          UnregisterEventHotKey(hotKey.reference)
        }
        throw RegistrationError(action: action, status: status)
      }

      registered[nextHotKeyID] = RegisteredHotKey(
        action: action,
        binding: binding,
        reference: reference
      )
    }

    return registered
  }

  private func unregisterAll() {
    for hotKey in registeredHotKeys.values {
      UnregisterEventHotKey(hotKey.reference)
    }
    registeredHotKeys.removeAll()
  }

  private func installEventHandler() throws {
    guard eventHandler == nil else { return }

    Self.activeService = self
    var handler: EventHandlerRef?
    let status = InstallEventHandler(
      GetEventDispatcherTarget(),
      captureThisHotKeyEventHandler,
      Self.eventSpec.count,
      Self.eventSpec,
      nil,
      &handler
    )

    guard status == noErr, let handler else {
      Self.activeService = nil
      throw EventHandlerError(status: status)
    }
    eventHandler = handler
  }

  private func removeEventHandler() {
    if let eventHandler {
      RemoveEventHandler(eventHandler)
      self.eventHandler = nil
    }
    if Self.activeService === self {
      Self.activeService = nil
    }
  }

  fileprivate func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let error = GetEventParameter(
      event,
      UInt32(kEventParamDirectObject),
      UInt32(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotKeyID
    )
    guard error == noErr else { return error }
    guard hotKeyID.signature == Self.eventHotKeySignature,
          let hotKey = registeredHotKeys[hotKeyID.id]
    else {
      return OSStatus(eventNotHandledErr)
    }

    guard GetEventKind(event) == UInt32(kEventHotKeyPressed),
          let handler = handlers[hotKey.action]
    else {
      return OSStatus(eventNotHandledErr)
    }

    handler()
    return noErr
  }
}

private struct DuplicateShortcutError: LocalizedError {
  let first: ShortcutAction
  let second: ShortcutAction

  var errorDescription: String? {
    String(
      format: String(localized: "shortcut.duplicate"),
      first.displayName,
      second.displayName
    )
  }
}

private struct EventHandlerError: LocalizedError {
  let status: OSStatus

  var errorDescription: String? {
    String(format: String(localized: "shortcut.registration.failed"), status)
  }
}

private struct ModifierRequiredShortcutError: LocalizedError {
  let action: ShortcutAction

  var errorDescription: String? {
    String(format: String(localized: "shortcut.modifier.required"), action.displayName)
  }
}

private func captureThisHotKeyEventHandler(
  eventHandlerCall _: EventHandlerCallRef?,
  event: EventRef?,
  userData _: UnsafeMutableRawPointer?
) -> OSStatus {
  HotKeyService.activeService?.handleCarbonEvent(event) ?? OSStatus(eventNotHandledErr)
}
