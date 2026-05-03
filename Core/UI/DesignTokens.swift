import SwiftUI

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 10
    static let xl: CGFloat = 14
}

extension View {
    /// Card surface — subtle background + rounded corners + low-elevation shadow.
    func cardStyle(radius: CGFloat = Radius.lg) -> some View {
        self
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    /// Hero gradient backdrop — used behind module icons.
    func heroIconBackdrop(color: Color) -> some View {
        self
            .padding(14)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.18), color.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(color.opacity(0.25), lineWidth: 0.5)
            )
    }
}

extension Font {
    static let titleLarge = Font.system(size: 22, weight: .semibold)
    static let titleMedium = Font.system(size: 17, weight: .semibold)
    static let titleSmall = Font.system(size: 13, weight: .semibold)
    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)
}
