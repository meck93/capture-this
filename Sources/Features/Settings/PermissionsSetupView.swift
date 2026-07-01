import CaptureThisCore
import SwiftUI

struct PermissionsSetupView: View {
  let state: PermissionSetupState
  let action: (PermissionSetupKind) -> Void

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
        if index > 0 {
          Divider()
        }
        PermissionSetupRow(item: item) {
          action(item.kind)
        }
      }
    }
    .overlay(
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(Color.primary.opacity(0.08)),
      alignment: .top
    )
    .overlay(
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(Color.primary.opacity(0.08)),
      alignment: .bottom
    )
  }
}

private struct PermissionSetupRow: View {
  let item: PermissionSetupItem
  let action: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: Theme.Spacing.sm) {
      Image(systemName: symbolName)
        .foregroundStyle(symbolColor)
        .font(.system(size: 15))
        .frame(width: 18)

      VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
        HStack(spacing: Theme.Spacing.xs + 2) {
          Text(item.kind.title)
            .font(Theme.Typography.rowTitle)
            .foregroundStyle(item.status.isGranted ? .secondary : .primary)
          // Granted is self-evident from the green check; only badge the
          // states that carry extra info (Required / Optional / Denied …).
          if !item.status.isGranted {
            statusBadge
          }
        }
        Text(item.kind.detail)
          .font(Theme.Typography.rowDetail)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: Theme.Spacing.sm)

      if let actionTitle = item.actionTitle {
        Button(actionTitle, action: action)
          .buttonStyle(CapsuleActionButtonStyle(tint: actionTint))
      }
    }
    .padding(.vertical, Theme.Spacing.sm)
    .padding(.horizontal, Theme.Spacing.xxs)
    .background(needsAttention ? Theme.Palette.warning.opacity(0.06) : .clear)
  }

  private var statusBadge: some View {
    Text(item.statusTitle.uppercased())
      .font(Theme.Typography.badge)
      .foregroundStyle(symbolColor)
      .padding(.horizontal, Theme.Spacing.xs + 1)
      .padding(.vertical, 1)
      .background(Capsule().fill(symbolColor.opacity(0.15)))
  }

  /// A required, not-yet-granted permission is the only thing that should feel urgent.
  private var needsAttention: Bool {
    item.isRequired && !item.status.isGranted
  }

  private var symbolName: String {
    switch item.status {
    case .granted:
      "checkmark.circle.fill"
    case .denied:
      "exclamationmark.triangle.fill"
    case .notDetermined, .unknown:
      item.isRequired ? "exclamationmark.circle" : "bell"
    }
  }

  private var symbolColor: Color {
    switch item.status {
    case .granted:
      Theme.Palette.success
    case .denied:
      Theme.Palette.danger
    case .notDetermined, .unknown:
      item.isRequired ? Theme.Palette.warning : .secondary
    }
  }

  private var actionTint: Color {
    needsAttention ? Theme.Palette.warning : Theme.Palette.accent
  }
}
