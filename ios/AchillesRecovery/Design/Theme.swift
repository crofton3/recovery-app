import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Recovery Aurora tokens (Midnight Aurora). Source of truth: the design system artifact.
enum Aurora {
    static let bg = Color(hex: 0x070B14)
    static let card = Color(hex: 0x0F1626)
    static let cardRaised = Color(hex: 0x141C31)
    static let hairline = Color(hex: 0xEAF0FF, opacity: 0.08)
    static let borderControl = Color(hex: 0x5C6B8E)

    static let text = Color(hex: 0xEAF0FF)
    static let textMuted = Color(hex: 0x7B88A8)

    static let recovery = Color(hex: 0x00F5A0)
    static let strain = Color(hex: 0x00B4FF)
    static let sleep = Color(hex: 0x7C5CFF)
    static let sleepInk = Color(hex: 0xA593FF)
    static let nutrition = Color(hex: 0xFFB547)
    static let water = Color(hex: 0x4DE8FF)
    static let alert = Color(hex: 0xFF6B81)
    static let onAccent = Color(hex: 0x04110C)

    static let radiusLg: CGFloat = 22
    static let radiusMd: CGFloat = 16
    static let radiusSm: CGFloat = 10

    /// 150 to 300 ms. Animate transform and opacity only (rings use trim, a native arc fill).
    static let fast = Animation.easeOut(duration: 0.15)
    static let base = Animation.easeOut(duration: 0.22)
}

struct AuroraCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Aurora.card, in: RoundedRectangle(cornerRadius: Aurora.radiusLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Aurora.radiusLg, style: .continuous).stroke(Aurora.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }
}

extension View {
    func auroraCard() -> some View { modifier(AuroraCard()) }

    /// Uppercase metric label.
    func caption() -> some View {
        font(.system(size: 12, weight: .semibold)).tracking(0.7).textCase(.uppercase).foregroundStyle(Aurora.textMuted)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Aurora.recovery
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Aurora.onAccent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(tint, in: RoundedRectangle(cornerRadius: Aurora.radiusMd, style: .continuous))
            .shadow(color: tint.opacity(0.35), radius: 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Aurora.fast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Aurora.text)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Aurora.cardRaised, in: RoundedRectangle(cornerRadius: Aurora.radiusMd, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Aurora.fast, value: configuration.isPressed)
    }
}

struct Chip: View {
    var text: String
    var tint: Color = Aurora.recovery
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(tint.opacity(0.14), in: Capsule())
    }
}
