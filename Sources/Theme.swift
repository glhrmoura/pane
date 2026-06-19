import AppKit
import CoreText
import SwiftUI

enum Palette {
    static let paper = dynamic(light: 0xFAFAF7, dark: 0x17181A)
    static let wall = dynamic(light: 0xE6E6E2, dark: 0x0D0E0F)
    static let ink = dynamic(light: 0x111214, dark: 0xECECE8)
    static let inkSoft = dynamic(light: 0x55575D, dark: 0xA4A6AB)
    static let inkFaint = dynamic(light: 0x8A8C92, dark: 0x6E7076)
    static let rule = dynamic(light: 0xD9D9D4, dark: 0x2C2E31)
    static let well = dynamic(light: 0xEFEFEB, dark: 0x202124)
    static let now = dynamic(light: 0x2B3BFF, dark: 0x7D88FF)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum Typeface {
    static let family = "Big Shoulders Display"
    private static let weightAxis = 2_003_265_652

    static func register() {
        guard let url = Bundle.main.url(forResource: "BigShouldersDisplay", withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: "BigShouldersDisplay", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func display(_ size: CGFloat, weight: CGFloat = 800) -> Font {
        let base = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: family,
        ] as CFDictionary)
        let varied = CTFontDescriptorCreateCopyWithAttributes(base, [
            kCTFontVariationAttribute: [weightAxis: weight],
        ] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(varied, size, nil)
        if (CTFontCopyFamilyName(font) as String) != family {
            return .system(size: size, weight: .black).width(.compressed)
        }
        return Font(font)
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: CGFloat = 800) -> Font {
        Typeface.display(size, weight: weight)
    }

    static let caption1 = Font.system(size: 12, weight: .regular)
    static let captionStrong = Font.system(size: 12, weight: .semibold)
    static let label = Font.system(size: 13, weight: .medium)
    static let figures = Font.system(size: 11, weight: .semibold).monospacedDigit()
}

struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 18)
            .frame(height: 38)
            .foregroundStyle(prominent ? Palette.paper : Palette.ink)
            .background(prominent ? Palette.ink : Color.clear)
            .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: prominent ? 0 : 1.2))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.35)
            .offset(y: configuration.isPressed ? 1 : 0)
            .contentShape(Rectangle())
            .pointingHand(isEnabled)
    }
}

struct TextOption: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Palette.ink : (hovering ? Palette.ink : Palette.inkSoft))
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(height: selected ? 1.5 : 0)
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct InkSwitch: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { isOn.toggle() }
        } label: {
            HStack(spacing: 10) {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Rectangle()
                        .fill(isOn ? Palette.ink : Color.clear)
                        .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2))
                        .frame(width: 34, height: 18)
                    Rectangle()
                        .fill(isOn ? Palette.paper : Palette.ink)
                        .frame(width: 12, height: 12)
                        .padding(3)
                }
                Text(label)
                    .font(.label)
                    .foregroundStyle(Palette.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHand()
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct PaperSlip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Palette.paper)
            .overlay(Rectangle().strokeBorder(Palette.rule, lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

struct PageLift: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(progress * 62), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.45)
            .offset(y: -progress * 40)
            .opacity(1 - progress)
            .shadow(color: .black.opacity(0.25 * progress), radius: 18, y: 12)
    }
}

extension AnyTransition {
    static var pageTurn: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.35).delay(0.15)),
            removal: .modifier(active: PageLift(progress: 1), identity: PageLift(progress: 0))
        )
    }
}

struct PointingHand: ViewModifier {
    var enabled = true

    func body(content: Content) -> some View {
        content.onContinuousHover { phase in
            guard enabled else { return }
            switch phase {
            case .active: NSCursor.pointingHand.set()
            case .ended: NSCursor.arrow.set()
            }
        }
    }
}

extension View {
    func pointingHand(_ enabled: Bool = true) -> some View {
        modifier(PointingHand(enabled: enabled))
    }
}
