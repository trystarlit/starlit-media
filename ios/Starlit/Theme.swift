import SwiftUI
import UIKit

enum Theme {
    static let night = Color(red: 15/255, green: 13/255, blue: 11/255)      // #0F0D0B
    static let card = Color(red: 26/255, green: 23/255, blue: 20/255)       // #1A1714
    static let line = Color(red: 240/255, green: 233/255, blue: 223/255).opacity(0.12)
    static let ivory = Color(red: 240/255, green: 233/255, blue: 223/255)   // #F0E9DF
    static let muted = Color(red: 155/255, green: 144/255, blue: 131/255)   // #9B9083
    static let amber = Color(red: 244/255, green: 212/255, blue: 160/255)   // #F4D4A0
    static let glow = Color(red: 222/255, green: 180/255, blue: 118/255)    // #DEB476

    /// Brand font is Geist. Until the .ttf files are added to the project, fall back to the system font.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if UIFont(name: "Geist-Regular", size: size) != nil {
            let name: String
            switch weight {
            case .medium, .semibold, .bold: name = "Geist-Medium"
            case .light, .thin, .ultraLight: name = "Geist-Light"
            default: name = "Geist-Regular"
            }
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight)
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

/// Rounded choice card used in onboarding questions.
struct OptionCard: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(title)
                .font(Theme.font(19))
                .foregroundColor(selected ? Theme.amber : Theme.ivory)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Theme.amber : Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
