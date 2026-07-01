import SwiftUI

/// Shared design tokens so every surface uses the same spacing rhythm,
/// corner radii, and semantic colors instead of ad-hoc values.
enum Theme {
  enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
  }

  /// Single type ramp. macOS semantic fonts are smaller than they read
  /// on iOS, so we name them by role to keep every surface consistent.
  enum Typography {
    static let sectionTitle = Font.headline // 13 semibold — group/section titles
    static let rowTitle = Font.body // 13 — primary row text
    static let rowDetail = Font.callout // 12 — supporting text
    static let meta = Font.caption // 10 — timestamps / metadata
    static let badge = Font.caption2.weight(.bold) // 10 bold — status badges
  }

  enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 16
  }

  enum Palette {
    /// Primary brand / record accent.
    static let record = Color(red: 0.90, green: 0.22, blue: 0.24)
    static let paused = Color.orange
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let accent = Color.accentColor

    /// Subtle fill for contained rows / banners.
    static let subtleFill = Color.primary.opacity(0.06)
    static let hoverFill = Color.primary.opacity(0.09)
  }
}

// MARK: - Button styles

/// Full-width, filled, focal call-to-action. Used for the primary Record button.
struct ProminentActionButtonStyle: ButtonStyle {
  var tint: Color = Theme.Palette.accent
  var isEnabled: Bool = true

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, Theme.Spacing.xs + 2)
      .foregroundStyle(.white)
      .background(
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
          .fill(tint.opacity(isEnabled ? 1 : 0.4))
      )
      .opacity(configuration.isPressed ? 0.82 : 1)
      .contentShape(Rectangle())
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// Compact capsule button for secondary actions (permission prompts, etc.).
struct CapsuleActionButtonStyle: ButtonStyle {
  var tint: Color = Theme.Palette.accent

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 11, weight: .semibold))
      .padding(.horizontal, Theme.Spacing.md)
      .padding(.vertical, Theme.Spacing.xs + 1)
      .foregroundStyle(tint)
      .background(
        Capsule(style: .continuous)
          .fill(tint.opacity(configuration.isPressed ? 0.22 : 0.14))
      )
      .contentShape(Capsule())
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

/// Circular icon button used inside the floating recording HUD.
struct HUDIconButtonStyle: ButtonStyle {
  var tint = Color.primary

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(tint)
      .frame(width: 34, height: 34)
      .background(
        Circle().fill(Theme.Palette.subtleFill.opacity(configuration.isPressed ? 1.6 : 1))
      )
      .contentShape(Circle())
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

/// Full-width menu row: leading icon, label, trailing shortcut hint, with a
/// hover/pressed highlight — matches the native macOS menu idiom used for the
/// popover footer (Settings / Quit).
struct MenuRowButtonStyle: ButtonStyle {
  @State private var isHovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Theme.Spacing.sm)
      .padding(.vertical, Theme.Spacing.xs + 1)
      .background(
        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
          .fill(configuration.isPressed || isHovering ? Theme.Palette.hoverFill : .clear)
      )
      .contentShape(Rectangle())
      .onHover { isHovering = $0 }
      .animation(.easeOut(duration: 0.1), value: isHovering)
  }
}

/// Row content for `MenuRowButtonStyle`: leading icon, title, trailing shortcut.
struct MenuRowLabel: View {
  let title: String
  let systemImage: String
  var shortcut: String?

  var body: some View {
    HStack(spacing: Theme.Spacing.sm) {
      Image(systemName: systemImage)
        .font(.system(size: 12))
        .frame(width: 16)
      Text(title)
        .font(Theme.Typography.rowDetail)
      Spacer(minLength: Theme.Spacing.sm)
      if let shortcut {
        Text(shortcut)
          .font(Theme.Typography.rowDetail)
          .foregroundStyle(.tertiary)
      }
    }
    .foregroundStyle(.secondary)
  }
}

// MARK: - Reusable views

/// Contained, icon-led banner for inline errors / notices.
struct InlineBanner: View {
  enum Kind {
    case error
    case info

    var symbol: String {
      switch self {
      case .error: "exclamationmark.triangle.fill"
      case .info: "info.circle.fill"
      }
    }

    var tint: Color {
      switch self {
      case .error: Theme.Palette.danger
      case .info: Theme.Palette.accent
      }
    }
  }

  let kind: Kind
  let message: String

  var body: some View {
    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
      Image(systemName: kind.symbol)
        .foregroundStyle(kind.tint)
        .font(.system(size: 12))
      Text(message)
        .font(.caption)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(Theme.Spacing.sm)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
        .fill(kind.tint.opacity(0.12))
    )
  }
}
