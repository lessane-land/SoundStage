import Foundation
import ActivityKit

/// Starts, updates and ends the sleep-session Live Activity (lock screen /
/// Dynamic Island). The countdown itself self-updates in the widget from the
/// end date, so the app only pushes updates on meaningful changes.
@MainActor
final class SessionLiveActivity {

    private var activity: Activity<SoundStageSessionAttributes>?

    func start(state: BinauralState, startDate: Date, endDate: Date?, isPlaying: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let content = ActivityContent(
            state: makeState(state, startDate: startDate, endDate: endDate, isPlaying: isPlaying),
            staleDate: endDate
        )
        activity = try? Activity.request(
            attributes: SoundStageSessionAttributes(title: "Sleep session"),
            content: content
        )
    }

    func update(state: BinauralState, startDate: Date, endDate: Date?, isPlaying: Bool) {
        guard let activity else { return }
        let content = ActivityContent(
            state: makeState(state, startDate: startDate, endDate: endDate, isPlaying: isPlaying),
            staleDate: endDate
        )
        Task { @MainActor in await activity.update(content) }
    }

    func end() {
        guard let activity else { return }
        let current = activity.content.state
        self.activity = nil
        Task { @MainActor in await activity.end(ActivityContent(state: current, staleDate: nil), dismissalPolicy: .immediate) }
    }

    private func makeState(_ state: BinauralState, startDate: Date, endDate: Date?, isPlaying: Bool) -> SoundStageSessionAttributes.ContentState {
        let hz = state.beatHz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(state.beatHz))" : String(format: "%.1f", state.beatHz)
        return .init(
            stateName: state.name,
            bandHz: "\(state.band.uppercased()) · \(hz) Hz",
            fromHex: state.fromHex,
            toHex: state.toHex,
            startDate: startDate,
            endDate: endDate,
            isPlaying: isPlaying
        )
    }
}
