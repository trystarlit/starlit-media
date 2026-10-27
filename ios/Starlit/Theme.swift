import SwiftUI
import UIKit

enum Theme {
    static let night = Color(red: 15/255, green: 13/255, blue: 11/255)      // #0F0D0B
    static let card = Color(red: 26/255, green: 23/255, blue: 20/255)       // #1A1714
    static let card2 = Color(red: 38/255, green: 33/255, blue: 28/255)      // #26211C
    static let selected = Color(red: 33/255, green: 28/255, blue: 22/255)   // #211C16
    static let line = Color(red: 240/255, green: 233/255, blue: 223/255).opacity(0.12)
    static let ivory = Color(red: 240/255, green: 233/255, blue: 223/255)   // #F0E9DF
    static let muted = Color(red: 155/255, green: 144/255, blue: 131/255)   // #9B9083
    static let amber = Color(red: 244/255, green: 212/255, blue: 160/255)   // #F4D4A0
    static let glow = Color(red: 222/255, green: 180/255, blue: 118/255)    // #DEB476

    /// Brand font is Geist. Each face is used only if its .ttf is in the app (UIAppFonts in Info.plist);
    /// a missing face (e.g. Geist-Light) falls back to Geist-Regular, then to the system font.
    /// Text follows Dynamic Type; display numbers (54pt+) stay fixed so big counters keep their layout.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black: name = "Geist-SemiBold"
        case .medium: name = "Geist-Medium"
        case .light, .thin, .ultraLight: name = "Geist-Light"
        default: name = "Geist-Regular"
        }
        let fixed = size >= 54
        let (style, uiStyle): (Font.TextStyle, UIFont.TextStyle) =
            size >= 28 ? (.largeTitle, .largeTitle) : size >= 20 ? (.title2, .title2) :
            size >= 15 ? (.body, .body) : size >= 13 ? (.footnote, .footnote) : (.caption, .caption1)
        for n in [name, "Geist-Regular"] where UIFont(name: n, size: size) != nil {
            return fixed ? .custom(n, fixedSize: size) : .custom(n, size: size, relativeTo: style)
        }
        return .system(size: fixed ? size : UIFontMetrics(forTextStyle: uiStyle).scaledValue(for: size), weight: weight)
    }
}

/// Big lowercase headline with one amber phrase: Headline("get your ", amber: "nights", " back.")
struct Headline: View {
    var before: String
    var amber: String
    var after: String
    var size: CGFloat = 38

    init(_ before: String, amber: String = "", _ after: String = "", size: CGFloat = 38) {
        self.before = before; self.amber = amber; self.after = after; self.size = size
    }

    var body: some View {
        (Text(before).foregroundColor(Theme.ivory)
         + Text(amber).foregroundColor(Theme.amber)
         + Text(after).foregroundColor(Theme.ivory))
            .font(Theme.font(size))
            .tracking(-size * 0.03)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PrimaryButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(Theme.font(17, .medium))
                .foregroundColor(Theme.night)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(Theme.ivory))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

/// Rounded choice card used in onboarding questions. `tick` shows the round check on the right (multi-select);
/// `icon` is an SF Symbol shown on the right.
struct OptionCard: View {
    var title: String
    var selected: Bool
    var tick: Bool = false
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack {
                Text(title).font(Theme.font(17))
                Spacer(minLength: 8)
                if let icon { Image(systemName: icon).font(.system(size: 17)) }
                if tick {
                    ZStack {
                        Circle().stroke(selected ? Theme.amber : Theme.line, lineWidth: 1.5)
                        if selected { Circle().fill(Theme.amber); Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.night) }
                    }
                    .frame(width: 20, height: 20)
                }
            }
            .foregroundColor(selected ? Theme.amber : Theme.ivory)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 18).fill(selected ? Theme.selected : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Theme.amber.opacity(0.7) : Theme.line, lineWidth: 1))
            .animation(.easeOut(duration: 0.2), value: selected)
        }
        .buttonStyle(PressStyle())
    }
}

/// Card background used across the app.
struct CardBG: ViewModifier {
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line, lineWidth: 1))
    }
}

/// Screen-enter animation: fade + rise + un-blur, staggered by index. With Reduce Motion it's a plain quick fade.
struct Rise: ViewModifier {
    var delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0)
            .offset(y: on || reduceMotion ? 0 : 14)
            .blur(radius: on || reduceMotion ? 0 : 6)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.9).delay(delay)) { on = true }
            }
    }
}

extension View {
    func card(_ radius: CGFloat = 22) -> some View { modifier(CardBG(radius: radius)) }
    func rise(_ i: Int) -> some View { modifier(Rise(delay: Double(i) * 0.06)) }
}

struct Label12: View {   // small lowercase label (brand: always lowercase)
    var text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text.lowercased()).font(Theme.font(12)).tracking(0.3).foregroundColor(Theme.muted) }
}

/// Legal pages linked from the paywall (App Store requires both for subscriptions).
enum Links {
    /// Apple's standard EULA. Swap for your own terms page if you write one.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Lives on the waitlist site (source: site/deploy/privacy/ in the starlit-context folder). Live once that folder is deployed.
    static let privacy = URL(string: "https://trystarlit.netlify.app/privacy/")!
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
