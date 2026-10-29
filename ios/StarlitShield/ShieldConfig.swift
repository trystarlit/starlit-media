import ManagedSettings
import ManagedSettingsUI
import UIKit

/// What a resting app shows when it's opened at night.
class ShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { resting }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { resting }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { resting }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { resting }

    private var resting: ShieldConfiguration {
        let night = UIColor(red: 15/255, green: 13/255, blue: 11/255, alpha: 1)
        let ivory = UIColor(red: 240/255, green: 233/255, blue: 223/255, alpha: 1)
        let muted = UIColor(red: 155/255, green: 144/255, blue: 131/255, alpha: 1)
        let amber = UIColor(red: 244/255, green: 212/255, blue: 160/255, alpha: 1)
        // iOS draws the button text white whatever color we ask for, so the button needs a dark fill
        let button = UIColor(red: 150/255, green: 104/255, blue: 45/255, alpha: 1)
        let icon = UIImage(systemName: "moon.stars.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44))?
            .withTintColor(amber, renderingMode: .alwaysOriginal)
        let asked = Lock.askUnlock
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: night,
            icon: icon,
            title: .init(text: asked ? "open starlit to unlock" : "your phone is resting", color: ivory),
            subtitle: .init(text: asked ? "starlit will ask if you want to use a rest night for tonight."
                                        : "until \(Lock.clock(Lock.wakeMinutes)). tonight's star is waiting for you.", color: muted),
            primaryButtonLabel: .init(text: "back to sleep", color: ivory),
            primaryButtonBackgroundColor: button,
            secondaryButtonLabel: asked ? nil : .init(text: "i need it", color: muted)
        )
    }
}
