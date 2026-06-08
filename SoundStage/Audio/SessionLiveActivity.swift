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
        guard activity != nil else { return }
        let content = ActivityContent(
            state: makeState(state, startDate: startDate, endDate: endDate, isPlaying: isPlaying),
            staleDate: endDate
        )
        Task { @MainActor in
            await self.activity?.update(content)
        }
    }

    func end() {
        Task { @MainActor in
            guard let activity = self.activity else { return }
            self.activity = nil
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
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
