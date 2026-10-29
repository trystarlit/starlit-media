import ManagedSettings
import UserNotifications

/// The shield's buttons. A shield can't open an app, so "i need it" leaves a note for starlit
/// (which opens on the "use a rest night?" sheet) and sends a notification as a shortcut.
class ShieldActionHandler: ShieldActionDelegate {
    override func handle(action: ManagedSettings.ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ManagedSettings.ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ManagedSettings.ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    private func respond(_ action: ManagedSettings.ShieldAction, _ done: @escaping (ShieldActionResponse) -> Void) {
        guard action == .secondaryButtonPressed else { return done(.close) }
        Lock.askUnlock = true
        let content = UNMutableNotificationContent()
        content.title = "starlit"
        content.body = "tap to open starlit and unlock for tonight."
        // .defer redraws the shield, which now says to open starlit (a Focus mode can hide the notification)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "unlock", content: content, trigger: nil)) { _ in
            done(.defer)
        }
    }
}
