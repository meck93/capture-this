import AppKit
import CaptureThisCore
import SwiftUI

struct MenuBarView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      header

      SourceSegmentedControl(selection: $appState.captureSource)

      if appState.permissionSetupState.blocksRecording, appState.recordingState == .idle {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          HStack {
            Text("Permissions")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            Spacer()
            Button {
              appState.refreshPermissionSetupState()
            } label: {
              Image(systemName: "arrow.clockwise")
                .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Check permissions again")
          }
          PermissionsSetupView(
            state: appState.permissionSetupState,
            action: appState.performPermissionSetupAction(for:)
          )
        }
      } else {
        recordButton

        if let pauseResumeTitle = Self.pauseResumeButtonTitle(for: appState.recordingState) {
          Button(pauseResumeTitle) {
            appState.togglePauseResume()
          }
          .buttonStyle(.bordered)
          .controlSize(.large)
          .frame(maxWidth: .infinity)
        }
      }

      if let errorMessage = appState.errorMessage {
        InlineBanner(kind: .error, message: errorMessage)
      }

      Divider()

      recentRecordingsSection

      Divider()

      VStack(spacing: 0) {
        SettingsLink {
          MenuRowLabel(title: String(localized: "Settings"), systemImage: "gearshape")
        }
        .buttonStyle(MenuRowButtonStyle())

        Button {
          NSApp.terminate(nil)
        } label: {
          MenuRowLabel(title: String(localized: "Quit"), systemImage: "power")
        }
        .buttonStyle(MenuRowButtonStyle())
      }
    }
    .padding(Theme.Spacing.md)
    .frame(width: 320)
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: Theme.Spacing.sm) {
      Image(systemName: "record.circle")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.Palette.record)
      Text("CaptureThis")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
      Spacer()
      statusPill
    }
  }

  @ViewBuilder
  private var statusPill: some View {
    if let (label, color) = Self.statusPillContent(for: appState.recordingState) {
      HStack(spacing: Theme.Spacing.xs) {
        Circle()
          .fill(color)
          .frame(width: 6, height: 6)
        Text(label)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(color)
      }
      .padding(.horizontal, Theme.Spacing.sm)
      .padding(.vertical, Theme.Spacing.xxs + 1)
      .background(Capsule().fill(color.opacity(0.14)))
    }
  }

  // MARK: - Record button

  private var recordButton: some View {
    let state = appState.recordingState
    let disabled = Self.isRecordButtonDisabled(for: state)
    return Button {
      appState.startOrStopRecording()
    } label: {
      HStack(spacing: Theme.Spacing.sm) {
        Image(systemName: Self.recordButtonSymbol(for: state))
        Text(Self.recordButtonTitle(for: state))
      }
    }
    .buttonStyle(ProminentActionButtonStyle(tint: Theme.Palette.record, isEnabled: !disabled))
    .keyboardShortcut(.defaultAction)
    .disabled(disabled)
  }

  // MARK: - Recent recordings

  private var recentRecordingsSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      Text("Recent Recordings")
        .font(Theme.Typography.meta.weight(.semibold))
        .foregroundStyle(.secondary)

      if appState.recentRecordings.isEmpty {
        HStack(spacing: Theme.Spacing.sm) {
          Image(systemName: "tray")
            .foregroundStyle(.tertiary)
          Text("No recordings yet")
            .font(Theme.Typography.rowDetail)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.sm)
      } else {
        VStack(spacing: 0) {
          ForEach(appState.recentRecordings) { recording in
            RecordingRow(recording: recording)
          }
        }
      }
    }
  }
}

// MARK: - Source segmented control

/// Custom equal-width segmented control; the native `.segmented` Picker keeps
/// its intrinsic width and won't fill the popover, so we roll our own.
private struct SourceSegmentedControl: View {
  @Binding var selection: CaptureSource

  var body: some View {
    HStack(spacing: 0) {
      ForEach(CaptureSource.allCases) { source in
        let isSelected = source == selection
        Button {
          selection = source
        } label: {
          Text(source.displayName)
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs + 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
          RoundedRectangle(cornerRadius: Theme.Radius.sm - 1, style: .continuous)
            .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : .clear)
            .shadow(color: .black.opacity(isSelected ? 0.12 : 0), radius: 1, y: 0.5)
            .padding(1)
        )
      }
    }
    .padding(2)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
        .fill(Theme.Palette.subtleFill)
    )
  }
}

// MARK: - Recording row

private struct RecordingRow: View {
  @EnvironmentObject private var appState: AppState
  let recording: Recording
  @State private var isHovering = false

  var body: some View {
    HStack(spacing: Theme.Spacing.sm) {
      Image(systemName: Self.symbol(for: recording.captureType))
        .font(.system(size: 15))
        .foregroundStyle(Theme.Palette.accent)
        .frame(width: 20)

      VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
        Text(recording.url.lastPathComponent)
          .font(Theme.Typography.rowDetail)
          .lineLimit(1)
          .truncationMode(.middle)
        Text(subtitle)
          .font(Theme.Typography.meta)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: Theme.Spacing.xs)

      Menu {
        Button("Open") { appState.openRecording(recording) }
        Button("Reveal in Finder") { appState.revealRecording(recording) }
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 12))
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .foregroundStyle(.secondary)
      .help("Recording actions")
      .opacity(isHovering ? 1 : 0)
    }
    .padding(.horizontal, Theme.Spacing.sm)
    .padding(.vertical, Theme.Spacing.sm)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
        .fill(isHovering ? Theme.Palette.hoverFill : .clear)
    )
    .contentShape(Rectangle())
    .onTapGesture {
      appState.openRecording(recording)
    }
    .onHover { isHovering = $0 }
    .contextMenu {
      Button("Open") { appState.openRecording(recording) }
      Button("Reveal in Finder") {
        appState.revealRecording(recording)
      }
    }
    .help("Open \(recording.url.lastPathComponent)")
  }

  private var subtitle: String {
    var parts = [Self.relativeDate(recording.createdAt)]
    if let duration = recording.duration {
      parts.append(Self.durationText(duration))
    }
    return parts.joined(separator: " · ")
  }

  static func symbol(for type: Recording.CaptureType) -> String {
    switch type {
    case .display: "display"
    case .window: "macwindow"
    case .application: "app.badge"
    }
  }

  static func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  static func durationText(_ duration: TimeInterval) -> String {
    let total = Int(duration.rounded())
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

extension MenuBarView {
  static func recordButtonTitle(for state: RecordingState) -> String {
    switch state {
    case .recording(true):
      String(localized: "Paused")
    case .recording(false):
      String(localized: "Stop Recording")
    case .countdown:
      String(localized: "Counting down…")
    case .pickingSource:
      String(localized: "Picking source…")
    case .stopping:
      String(localized: "Stopping…")
    default:
      String(localized: "Record")
    }
  }

  static func recordButtonSymbol(for state: RecordingState) -> String {
    switch state {
    case .recording:
      "stop.fill"
    case .countdown, .pickingSource, .stopping:
      "hourglass"
    default:
      "record.circle.fill"
    }
  }

  static func isRecordButtonDisabled(for state: RecordingState) -> Bool {
    switch state {
    case .countdown, .pickingSource, .stopping:
      true
    default:
      false
    }
  }

  static func pauseResumeButtonTitle(for state: RecordingState) -> String? {
    if case let .recording(isPaused) = state {
      return isPaused ? String(localized: "Resume") : String(localized: "Pause")
    }
    return nil
  }

  static func statusPillContent(for state: RecordingState) -> (String, Color)? {
    switch state {
    case .recording(false):
      ("REC", Theme.Palette.record)
    case .recording(true):
      ("PAUSED", Theme.Palette.paused)
    case .countdown:
      ("STARTING", Theme.Palette.accent)
    case .stopping:
      ("STOPPING", .secondary)
    default:
      nil
    }
  }
}

#Preview {
  MenuBarView()
    .environmentObject(AppState.shared)
}
