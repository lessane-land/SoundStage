import CoreMotion
import Observation

/// Wraps `CMHeadphoneMotionManager` to report head yaw from AirPods (H1/H2),
/// for true head-tracked spatial audio. Only available on supported Apple
/// headphones; needs the motion-usage permission.
@MainActor
@Observable
final class HeadTracker {

    @ObservationIgnored private let manager = CMHeadphoneMotionManager()
    private(set) var isTracking = false

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// Starts updates, delivering yaw (radians) to `onYaw` off the main actor.
    func start(onYaw: @escaping @Sendable (Double) -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            onYaw(motion.attitude.yaw)
        }
        isTracking = true
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isTracking = false
    }
}
