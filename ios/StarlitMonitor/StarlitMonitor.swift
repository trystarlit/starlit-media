import DeviceActivity

/// iOS runs this at bedtime and wake time, even when starlit is closed.
class StarlitMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Lock.startNight()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        Lock.endNight()
    }
}
