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
    static let on = dynamic(light: 0x1F9D55, dark: 0x34C759)

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
    static let family = "Outfit"
    private static let weightAxis = 2_003_265_652

    static func register() {
        guard let url = Bundle.main.url(forResource: "Outfit", withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: "Outfit", withExtension: "ttf") else { return }
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
            return .system(size: size, weight: .black)
        }
        return Font(font)
    }

    static func text(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        let value: CGFloat = switch weight {
        case .ultraLight: 200
        case .thin: 100
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
        return display(size, weight: value)
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: CGFloat = 800) -> Font {
        Typeface.display(size, weight: weight)
    }

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Typeface.text(size, weight)
    }

    static let caption1 = Font.ui(12)
    static let captionStrong = Font.ui(12, .semibold)
    static let label = Font.ui(13, .medium)
    static let figures = Font.ui(11, .semibold).monospacedDigit()
}

struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(14, .semibold))
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
                .font(.ui(12, .medium))
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
                        .fill(isOn ? Palette.on : Color.clear)
                        .overlay(Rectangle().strokeBorder(isOn ? Palette.on : Palette.ink, lineWidth: 1.2))
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
            .font(.ui(13, .medium))
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

final class InkScroller: NSScroller {
    private static let ink = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor(hex: isDark ? 0xECECE8 : 0x111214)
    }

    private var hovering = false {
        didSet { if hovering != oldValue { needsDisplay = true } }
    }

    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        drawKnob()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        let knob = rect(for: .knob)
        guard knob.height > 0 else { return }
        let active = hovering || hitPart == .knob
        let thickness: CGFloat = active ? 5 : 3
        let bar = NSRect(
            x: bounds.maxX - thickness - 3,
            y: knob.minY + 3,
            width: thickness,
            height: max(knob.height - 6, 12)
        )
        Self.ink.withAlphaComponent(active ? 0.55 : 0.3).setFill()
        bar.fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        hovering = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hovering = false
    }
}

private struct InkScrollerInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ nsView: Probe, context: Context) {}

    final class Probe: NSView {
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.install() }
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSScroller.preferredScrollerStyleDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.install() }
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        private func install() {
            guard let scrollView = enclosingScrollView else { return }
            if !(scrollView.verticalScroller is InkScroller) {
                scrollView.verticalScroller = InkScroller()
            }
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            scrollView.hasHorizontalScroller = false
        }
    }
}

extension View {
    func inkScroller() -> some View {
        background(InkScrollerInstaller())
    }
}
