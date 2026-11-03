import DeviceActivity

/// iOS runs this at bedtime and wake time, even when starlit is closed. The "morning" activity starts at
/// wake time too, as a backup in case the bedtime interval's end is skipped.
class StarlitMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == Lock.morning { Lock.endNight() } else { Lock.startNight() }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        Lock.endNight()
    }
}
