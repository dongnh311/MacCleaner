import SwiftUI

/// Standard module header used across every feature view.
struct ModuleHeader<Trailing: View>: View {

    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    @ViewBuilder let trailing: () -> Trailing

    init(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color = .accentColor,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .heroIconBackdrop(color: accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.titleMedium)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        // No solid bar: the unified backdrop drawn at the root level
        // bleeds through so the header reads as part of one continuous
        // canvas instead of an opaque strip.
        .background(Color.clear)
    }
}

/// Compact section header for inside scrollable content.
struct SectionHeading: View {
    let title: String
    let count: Int?

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            if let count {
                Text("\(count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}

/// Status badge — used for safety levels, severities, scope chips.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Borderless icon button with idle/hover tints. Lives behind
/// `InfoButton`, `CloseButton`, and `KillProcessButton` so they share one
/// implementation and the @State hover plumbing isn't copy-pasted.
struct HoverIconButton: View {
    let icon: String
    var size: CGFloat = 16
    let idleColor: Color
    let hoverColor: Color
    var help: String? = nil
    var keyboardShortcut: KeyboardShortcut? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let button = Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(hovering ? hoverColor : idleColor)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.borderless)
        .onHover { hovering = $0 }

        return Group {
            if let shortcut = keyboardShortcut {
                button.keyboardShortcut(shortcut)
            } else {
                button
            }
        }
        .help(help ?? "")
    }
}

/// "i" trailing affordance for list rows that have a detail popup.
struct InfoButton: View {
    let action: () -> Void
    var body: some View {
        HoverIconButton(
            icon: "info.circle.fill",
            idleColor: .secondary,
            hoverColor: .accentColor,
            help: "View details",
            action: action
        )
    }
}

/// Close affordance for sheets / popups. Bound to ⎋ via `.cancelAction`.
struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        HoverIconButton(
            icon: "xmark.circle.fill",
            size: 18,
            idleColor: .secondary,
            hoverColor: .primary,
            help: "Close (⎋)",
            keyboardShortcut: .cancelAction,
            action: action
        )
    }
}

/// Standard chrome for an in-app detail popup: title + subtitle + close
/// button + scrollable content area + `PopupBackground` so it blends
/// with the rest of the app's chrome. Used for "click row → show me
/// what's inside" sheets across Cleanup / Malware / Performance.
struct DetailSheet<Content: View>: View {
    let title: String
    let subtitle: String?
    let accent: Color
    let onClose: () -> Void
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: () -> Content

    init(title: String,
         subtitle: String? = nil,
         accent: Color = .accentColor,
         width: CGFloat = 560,
         height: CGFloat = 480,
         onClose: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.width = width
        self.height = height
        self.onClose = onClose
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.titleMedium)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                CloseButton(action: onClose)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)
            Divider()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: width, height: height)
        .background(PopupBackground(accent: accent))
    }
}

/// Empty state — large hierarchical icon + title + optional secondary text + optional action.
struct EmptyStateView<Action: View>: View {
    let icon: String
    let title: String
    let message: String?
    let tint: Color
    @ViewBuilder let action: () -> Action

    init(
        icon: String,
        title: String,
        message: String? = nil,
        tint: Color = .accentColor,
        @ViewBuilder action: @escaping () -> Action = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.tint = tint
        self.action = action
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .heroIconBackdrop(color: tint)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            action()
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
