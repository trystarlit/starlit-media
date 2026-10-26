import SwiftUI

/// iPhone-style scroll wheel for times, 15-minute steps. Snaps to the middle row with a haptic tick.
struct WheelPicker: View {
    var values: [Int]
    @Binding var selection: Int
    @State private var pos: Int?
    private let rowH: CGFloat = 56
    private let height: CGFloat = 250

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
                .frame(height: rowH)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { v in
                        row(v).id(v)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.3)) { pos = v } }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, (height - rowH) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $pos, anchor: .center)
        }
        .frame(height: height)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3),
                                     .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .onAppear { pos = values.contains(selection) ? selection : values.first }
        .onChange(of: pos) { _, v in
            guard let v, v != selection else { return }
            selection = v
            Haptics.select()
        }
    }

    private func row(_ v: Int) -> some View {
        let on = pos == v
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(UserStore.clock(v)).font(Theme.font(30, .light)).monospacedDigit().tracking(-1)
            Text(UserStore.ampm(v)).font(Theme.font(15)).opacity(0.7)
        }
        .foregroundColor(on ? Theme.amber : Theme.muted)
        .scaleEffect(on ? 1.15 : 1)
        .animation(.easeOut(duration: 0.15), value: on)
        .frame(maxWidth: .infinity)
        .frame(height: rowH)
        .contentShape(Rectangle())
    }
}

/// Bottom sheet with a wheel and a done button (edit bedtime / wake up after onboarding).
struct TimeSheet: View {
    var title: String
    var values: [Int]
    @Binding var value: Int
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Int

    init(title: String, values: [Int], value: Binding<Int>) {
        self.title = title; self.values = values; self._value = value
        self._draft = State(initialValue: value.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Theme.font(24)).foregroundColor(Theme.ivory).padding(.top, 26)
            WheelPicker(values: values, selection: $draft)
            PrimaryButton(title: "done") { value = draft; Haptics.success(); dismiss() }
        }
        .padding(.horizontal, 26).padding(.bottom, 10)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(red: 28/255, green: 25/255, blue: 21/255))
    }
}

extension Array where Element == Int {
    static func times(_ from: Int, _ to: Int, step: Int = 15) -> [Int] { Array(stride(from: from, through: to, by: step)) }
}
