import CaptureThisCore
import SwiftUI

/// The permissions list adapts to where it lives: `.settings` sits inside a
/// Form section that already draws a card, so it renders as a plain divided
/// table; `.popover` is standalone, so it wraps each group in its own card and
/// reveals reasons on hover to stay compact.
enum PermissionsSetupStyle {
  case settings
  case popover
}

struct PermissionsSetupView: View {
  let state: PermissionSetupState
  var style: PermissionsSetupStyle = .popover
  let action: (PermissionSetupKind) -> Void

  private var requiredItems: [PermissionSetupItem] {
    state.items.filter(\.isRequired)
  }

  private var optionalItems: [PermissionSetupItem] {
    state.items.filter { !$0.isRequired }
  }

  private var isPlain: Bool {
    style == .settings
  }

  var body: some View {
    VStack(alignment: .leading, spacing: isPlain ? Theme.Spacing.sm : Theme.Spacing.md) {
      group("Required", items: requiredItems)
      group("Optional", items: optionalItems)
    }
  }

  @ViewBuilder
  private func group(_ title: String, items: [PermissionSetupItem]) -> some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        Text(title.uppercased())
          .font(Theme.Typography.badge)
          .foregroundStyle(.tertiary)
          .padding(.horizontal, Theme.Spacing.xxs)

        VStack(spacing: 0) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if index > 0 {
              Divider()
            }
            PermissionSetupRow(item: item, style: style) {
              action(item.kind)
            }
          }
        }
        .background(groupBackground)
      }
    }
  }

  // The popover has no surrounding card, so each group gets its own; Settings
  // leans on the Form section's card and stays flat to avoid box-in-box.
  @ViewBuilder
  private var groupBackground: some View {
    if isPlain {
      Color.clear
    } else {
      RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
        .fill(Theme.Palette.subtleFill)
    }
  }
}

private struct PermissionSetupRow: View {
  let item: PermissionSetupItem
  let style: PermissionsSetupStyle
  let action: () -> Void

  @State private var isHovering = false

  private var alwaysShowsDetail: Bool {
    style == .settings
  }

  private var showsDetail: Bool {
    alwaysShowsDetail || isHovering
  }

  var body: some View {
    HStack(alignment: .center, spacing: Theme.Spacing.sm) {
      Image(systemName: symbolName)
        .foregroundStyle(symbolColor)
        .font(.system(size: 15))
        .frame(width: 18)

      VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
        Text(item.kind.title)
          .font(Theme.Typography.rowTitle)
          .foregroundStyle(item.status.isGranted ? .secondary : .primary)

        // Settings keeps every reason on screen; the popover surfaces them on
        // hover so its resting list stays a calm column of names.
        if showsDetail {
          Text(item.kind.detail)
            .font(Theme.Typography.rowDetail)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
        }
      }

      Spacer(minLength: Theme.Spacing.sm)

      if let actionTitle = item.actionTitle {
        Button(actionTitle, action: action)
          .buttonStyle(CapsuleActionButtonStyle())
      }
    }
    .padding(.vertical, Theme.Spacing.sm)
    .padding(.horizontal, alwaysShowsDetail ? Theme.Spacing.xxs : Theme.Spacing.sm)
    .contentShape(Rectangle())
    .onHover { hovering in
      guard !alwaysShowsDetail else { return }
      withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
    }
  }

  private var symbolName: String {
    switch item.status {
    case .granted:
      "checkmark.circle.fill"
    case .denied:
      "exclamationmark.triangle.fill"
    case .notDetermined, .unknown:
      "circle"
    }
  }

  // Only a genuine denial earns an alarm color. A not-yet-granted permission
  // is the expected first-run state, so it stays neutral instead of screaming.
  private var symbolColor: Color {
    switch item.status {
    case .granted:
      Theme.Palette.success
    case .denied:
      Theme.Palette.danger
    case .notDetermined, .unknown:
      Color.secondary
    }
  }
}
