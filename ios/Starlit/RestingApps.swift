import SwiftUI
import FamilyControls

/// Choosing the apps that rest: Apple's picker with the real app icons once Screen Time is allowed,
/// the stand-in list before that.
struct RestingAppsPicker: View {
    @EnvironmentObject var store: UserStore
    @State private var picking = false

    var body: some View {
        if store.screenTimeOK {
            VStack(alignment: .leading, spacing: 14) {
                if store.restingCount > 0 {
                    RestingAppIcons(size: 46, names: true)
                } else {
                    Text("no apps yet").font(Theme.font(15)).foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 80).card()
                }
                Button { Haptics.tap(); picking = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: store.restingCount > 0 ? "pencil" : "plus").font(.system(size: 14, weight: .medium))
                        Text(store.restingCount > 0 ? "change apps" : "choose apps").font(Theme.font(16))
                    }
                    .foregroundColor(Theme.amber)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.selected))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.amber.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(PressStyle())
            }
            .familyActivityPicker(isPresented: $picking, selection: $store.selection)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(KeepsUpStep.apps, id: \.self) { a in
                    OptionCard(title: a, selected: store.keepsUp.contains(a), tick: true, leading: KeepsUpStep.icon(a)) {
                        if store.keepsUp.contains(a) { store.keepsUp.remove(a) } else { store.keepsUp.insert(a) }
                    }
                }
            }
        }
    }
}

/// The real icons of the resting apps (and categories). Only the app can draw these; it never sees which apps they are.
struct RestingAppIcons: View {
    @EnvironmentObject var store: UserStore
    var size: CGFloat = 28
    var names = false
    var limit = Int.max

    var body: some View {
        let apps = Array(store.selection.applicationTokens).prefix(limit)
        let cats = Array(store.selection.categoryTokens).prefix(max(0, limit - apps.count))
        if names {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(apps, id: \.self) { named(Label($0)) }
                ForEach(cats, id: \.self) { named(Label($0)) }
            }
        } else {
            HStack(spacing: 6) {
                ForEach(apps, id: \.self) { icon(Label($0)) }
                ForEach(cats, id: \.self) { icon(Label($0)) }
            }
        }
    }

    private func icon(_ label: some View) -> some View {
        label.labelStyle(.iconOnly)
            .scaleEffect(size / 28)
            .frame(width: size, height: size)
    }

    private func named(_ label: some View) -> some View {
        label.labelStyle(.titleAndIcon)
            .font(Theme.font(15)).foregroundColor(Theme.ivory).lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .card(16)
    }
}
