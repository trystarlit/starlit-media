# starlit iOS app (v0.2: onboarding + tonight / sky / you)

What's here (matches the approved web preview, 10-26):
- onboarding: name, goals (+ all of the above), scroll-wheel bedtimes, mirror, mornings, apps, how it works, full-screen "tap your first star", hold-to-commit (stars spiral in and become the logo), paywall mock with logo
- tabs on a glass bar: tonight (sky card → your sky, countdown, times, streak), sky (3D, drag sideways, springs back, tap a star), you (stats, goals, settings)
- moments: rest now, locked-app screen + "i need it", goodnight, morning, streak screen; tonight's star lights up in your sky after a kept night
- needs **iOS 17+** (set the project's deployment target to 17.0)
Not yet: the real bedtime lock (Screen Time / Family Controls) and real purchases — those need the paid Apple Developer account.

## Run it in the iPhone simulator (on a Mac)
1. Install **Xcode** from the Mac App Store (big download, ~1h).
2. Xcode → File → New → Project → iOS → **App**. Product name `Starlit`, Interface **SwiftUI**, Language **Swift**. Save it anywhere.
3. In the left sidebar, delete the two files Xcode made (`StarlitApp.swift`/`ContentView.swift`) → Move to Trash.
4. Drag every `.swift` file from this `ios/Starlit/` folder into the sidebar's `Starlit` folder → check "Copy items if needed".
5. Top bar: pick a simulator like **iPhone 16**, press **▶︎ Run** (Cmd+R).

Tips
- Haptics only work on a real iPhone, not the simulator.
- You tab → preview screens: "morning: kept your night" fakes keeping a night (star lights up → streak screen); "restart onboarding" restarts the flow.
- This code has not been compiled yet (no Mac on my side). If Xcode shows red errors, screenshot them and send them over.
- To run on your own iPhone: plug it in, pick it as the run target, Xcode → Settings → Accounts → add your Apple ID, then Signing & Capabilities → Team = your name. (Free accounts: the app expires after 7 days; just run it again.)
