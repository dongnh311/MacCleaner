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
