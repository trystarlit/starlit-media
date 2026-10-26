import UIKit

/// All haptics in one place (app-decisions-1026: picker ticks, hold-to-commit ramp, star lighting, "i need it" warning).
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func star() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 1.0) }

    /// Called repeatedly while holding to commit; intensity rises with progress (0...1).
    static func ramp(_ progress: Double) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: CGFloat(0.2 + 0.8 * progress))
    }
}
