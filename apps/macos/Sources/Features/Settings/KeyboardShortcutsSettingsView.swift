import AppKit
import CaptureThisCore
import Carbon
import HotKey
import SwiftUI

struct KeyboardShortcutsSettingsSection: View {
  @Binding var settings: KeyboardShortcutSettings
  let errorMessage: String?

  var body: some View {
    Section {
      Toggle(isOn: $settings.isEnabled) {
        Label(String(localized: "Enable global shortcuts"), systemImage: "keyboard")
      }

      ForEach(ShortcutAction.allCases) { action in
        HStack(spacing: Theme.Spacing.sm) {
          Text(action.displayName)
            .font(Theme.Typography.rowDetail)
          Spacer(minLength: Theme.Spacing.sm)

          ShortcutRecorderButton(shortcut: binding(for: action))

          Button(String(localized: "Clear")) {
            settings = settings.updating(action, with: nil)
          }
          .buttonStyle(.borderless)
          .disabled(settings.binding(for: action) == nil)
        }
      }

      if let errorMessage {
        InlineBanner(kind: .error, message: errorMessage)
      }
    } header: {
      HStack {
        Text(String(localized: "Keyboard Shortcuts"))
        Spacer()
        Button(String(localized: "Reset to Defaults")) {
          settings = KeyboardShortcutSettings()
        }
        .buttonStyle(.borderless)
        .font(Theme.Typography.rowDetail)
      }
    } footer: {
      Text(
        String(
          localized: "settings.shortcuts.footer"
        )
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private func binding(for action: ShortcutAction) -> Binding<ShortcutBinding?> {
    Binding(
      get: { settings.binding(for: action) },
      set: { settings = settings.updating(action, with: $0) }
    )
  }
}

private struct ShortcutRecorderButton: View {
  @Binding var shortcut: ShortcutBinding?
  @StateObject private var recorder = ShortcutRecorder()

  var body: some View {
    Button {
      recorder.start { binding in
        shortcut = binding
      }
    } label: {
      Text(recorder.isRecording ? String(localized: "Press shortcut…") : displayName)
        .font(Theme.Typography.rowDetail)
        .foregroundStyle(recorder.isRecording ? Theme.Palette.accent : .secondary)
        .frame(minWidth: 100, alignment: .trailing)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
          RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .fill(Theme.Palette.subtleFill)
        )
    }
    .buttonStyle(.plain)
    .help(String(localized: "Record a shortcut"))
    .onDisappear {
      recorder.stop()
    }
  }

  private var displayName: String {
    guard let shortcut else { return String(localized: "Not set") }
    let combo = KeyCombo(carbonKeyCode: shortcut.keyCode, carbonModifiers: shortcut.modifiers)
    return combo.description.isEmpty ? String(localized: "Not set") : combo.description
  }
}

private final class ShortcutRecorder: ObservableObject {
  @Published private(set) var isRecording = false
  private var monitor: Any?

  func start(onCapture: @escaping (ShortcutBinding) -> Void) {
    stop()
    isRecording = true

    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, isRecording else { return event }

      let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
      guard !modifiers.isEmpty || event.keyCode == UInt16(kVK_Escape) else {
        return nil
      }

      var combo = KeyCombo(carbonKeyCode: UInt32(event.keyCode), carbonModifiers: 0)
      combo.modifiers = modifiers
      let binding = ShortcutBinding(
        keyCode: combo.carbonKeyCode,
        modifiers: combo.carbonModifiers
      )

      DispatchQueue.main.async { [weak self] in
        self?.stop()
        onCapture(binding)
      }
      return nil
    }
  }

  func stop() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
    isRecording = false
  }

  deinit {
    stop()
  }
}
